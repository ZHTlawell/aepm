#!/usr/bin/env python3
"""sensors-query.py — 神策数据 SQL 查询 CLI

封装神策分析平台的 Query API，通过 HTTP header token 认证，支持 SQL 查询。
避免重复踩坑：认证方式是 header `token: {api_secret}`，不是 URL 参数。

Usage:
    sensors-query.py sql "select event, count(*) as cnt from events group by event order by cnt desc limit 10"
    sensors-query.py sql "select * from events limit 5" --format json
    sensors-query.py events                          # 列出所有事件及数量
    sensors-query.py events --top 20                 # Top N 事件
    sensors-query.py count                           # 总事件数
    sensors-query.py count --days 7                  # 最近 N 天事件数
    sensors-query.py fields                          # 列出所有字段
    sensors-query.py fields --event home_exposure    # 某事件的字段

Options:
    --project   项目名 (默认 auroredgetech)
    --format    输出格式: tsv(默认) | json | csv
    --host      神策后台地址 (默认从环境变量或配置读取)

Env:
    SENSORS_HOST        神策后台地址
    SENSORS_API_SECRET  API Secret (token)

Exit codes:
    0 = success
    1 = API/query error
    2 = auth error (token 无效或缺失)
    3 = network error
"""

import argparse
import csv
import io
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

# ── Constants ────────────────────────────────────────────

DEFAULT_HOST = "https://shenzhentuling-pro.cloud.sensorsjourney.com"
DEFAULT_PROJECT = "auroredgetech"
API_PATH = "/api/sql/query"

CRED_PATHS = [
    os.path.expanduser("~/.config/ae/sensors.env"),
    os.path.expanduser("~/.config/ae-pm/sensors.env"),
]

EXIT_SUCCESS = 0
EXIT_API_ERROR = 1
EXIT_AUTH_ERROR = 2
EXIT_NETWORK_ERROR = 3

# ── Auth ─────────────────────────────────────────────────

def load_token():
    """从环境变量或配置文件加载 API Secret."""
    token = os.environ.get("SENSORS_API_SECRET")
    if token:
        return token.strip()

    for path in CRED_PATHS:
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("#") or "=" not in line:
                            continue
                        key, val = line.split("=", 1)
                        if key.strip() == "SENSORS_API_SECRET":
                            return val.strip().strip('"').strip("'")
            except OSError:
                continue
    return None


def get_host():
    """从环境变量或默认值获取神策后台地址."""
    return os.environ.get("SENSORS_HOST", DEFAULT_HOST).rstrip("/")

# ── SSL ──────────────────────────────────────────────────

CA_CERT_PATHS = [
    "/etc/ssl/cert.pem",                    # macOS system
    "/etc/ssl/certs/ca-certificates.crt",   # Debian/Ubuntu
    "/etc/pki/tls/certs/ca-bundle.crt",     # RHEL/CentOS
]

PROXY_VARS = (
    "http_proxy", "https_proxy",
    "HTTP_PROXY", "HTTPS_PROXY",
    "ALL_PROXY", "all_proxy",
)


def _ssl_context():
    """Build an SSL context that works on macOS/Linux even without certifi."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    for path in CA_CERT_PATHS:
        if os.path.isfile(path):
            return ssl.create_default_context(cafile=path)
    return ssl.create_default_context()


def _clear_proxy():
    for var in PROXY_VARS:
        os.environ.pop(var, None)

# ── Query ────────────────────────────────────────────────

def query(sql, project, host, token):
    """执行 SQL 查询，返回 TSV 文本."""
    _clear_proxy()
    ctx = _ssl_context()
    url = f"{host}{API_PATH}?project={urllib.request.quote(project)}&q={urllib.request.quote(sql)}"
    req = urllib.request.Request(url, headers={"token": token})

    try:
        with urllib.request.urlopen(req, timeout=120, context=ctx) as resp:
            return resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        if e.code == 401:
            print(f"[sensors-query] 认证失败 (401): token 无效或已过期", file=sys.stderr)
            print(f"  提示: token 通过 HTTP header 传递，不是 URL 参数", file=sys.stderr)
            sys.exit(EXIT_AUTH_ERROR)
        else:
            print(f"[sensors-query] API 错误 (HTTP {e.code}): {body}", file=sys.stderr)
            sys.exit(EXIT_API_ERROR)
    except urllib.error.URLError as e:
        print(f"[sensors-query] 网络错误: {e.reason}", file=sys.stderr)
        sys.exit(EXIT_NETWORK_ERROR)


def parse_tsv(tsv_text):
    """将 TSV 文本解析为 (headers, rows) 列表."""
    lines = tsv_text.strip().split("\n")
    if not lines:
        return [], []
    headers = lines[0].split("\t")
    rows = [line.split("\t") for line in lines[1:] if line.strip()]
    return headers, rows

# ── Output Formatters ────────────────────────────────────

def output_tsv(tsv_text):
    """直接输出 TSV."""
    print(tsv_text.rstrip())


def output_json(tsv_text):
    """TSV → JSON 输出."""
    headers, rows = parse_tsv(tsv_text)
    records = [dict(zip(headers, row)) for row in rows]
    print(json.dumps(records, ensure_ascii=False, indent=2))


def output_csv(tsv_text):
    """TSV → CSV 输出."""
    headers, rows = parse_tsv(tsv_text)
    writer = csv.writer(sys.stdout)
    writer.writerow(headers)
    writer.writerows(rows)


FORMATTERS = {
    "tsv": output_tsv,
    "json": output_json,
    "csv": output_csv,
}

# ── Subcommands ──────────────────────────────────────────

def cmd_sql(args, project, host, token):
    """执行自定义 SQL."""
    result = query(args.sql, project, host, token)
    FORMATTERS[args.format](result)


def cmd_events(args, project, host, token):
    """列出事件及数量."""
    top = args.top or 50
    sql = f"select event, count(*) as cnt from events group by event order by cnt desc limit {top}"
    result = query(sql, project, host, token)
    FORMATTERS[args.format](result)


def cmd_count(args, project, host, token):
    """查询事件总数."""
    if args.days:
        sql = f"select count(*) as cnt from events where date >= date_sub(current_date(), {args.days})"
    else:
        sql = "select count(*) as cnt from events"
    result = query(sql, project, host, token)
    headers, rows = parse_tsv(result)
    if rows:
        print(rows[0][0])
    else:
        print("0")


def cmd_fields(args, project, host, token):
    """列出字段."""
    if args.event:
        sql = f"select * from events where event = '{args.event}' limit 1"
    else:
        sql = "select * from events limit 1"
    result = query(sql, project, host, token)
    headers, _ = parse_tsv(result)
    for h in headers:
        print(h)

# ── CLI ──────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="sensors-query",
        description="神策数据 SQL 查询 CLI — 认证方式: HTTP header token",
    )
    parser.add_argument("--project", default=DEFAULT_PROJECT, help=f"项目名 (默认 {DEFAULT_PROJECT})")
    parser.add_argument("--format", choices=["tsv", "json", "csv"], default="tsv", help="输出格式")
    parser.add_argument("--host", default=None, help="神策后台地址")
    parser.add_argument("--token", default=None, help="API Secret (优先级高于环境变量)")

    sub = parser.add_subparsers(dest="command", required=True)

    # sql
    p_sql = sub.add_parser("sql", help="执行自定义 SQL")
    p_sql.add_argument("sql", help="SQL 语句")

    # events
    p_events = sub.add_parser("events", help="列出事件及数量")
    p_events.add_argument("--top", type=int, default=50, help="显示 Top N (默认 50)")

    # count
    p_count = sub.add_parser("count", help="查询事件总数")
    p_count.add_argument("--days", type=int, default=None, help="最近 N 天")

    # fields
    p_fields = sub.add_parser("fields", help="列出字段")
    p_fields.add_argument("--event", default=None, help="指定事件名")

    args = parser.parse_args()

    # Resolve token
    token = args.token or load_token()
    if not token:
        print("[sensors-query] 错误: 未找到 API Secret", file=sys.stderr)
        print("  设置方式 (任选其一):", file=sys.stderr)
        print("    1. 环境变量: export SENSORS_API_SECRET=xxx", file=sys.stderr)
        print("    2. 配置文件: ~/.config/ae/sensors.env", file=sys.stderr)
        print("    3. 命令行:   --token xxx", file=sys.stderr)
        sys.exit(EXIT_AUTH_ERROR)

    host = args.host or get_host()
    project = args.project

    handlers = {
        "sql": cmd_sql,
        "events": cmd_events,
        "count": cmd_count,
        "fields": cmd_fields,
    }
    handlers[args.command](args, project, host, token)


if __name__ == "__main__":
    main()
