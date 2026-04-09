#!/usr/bin/env python3
"""ae-git.py — Unified Gitee API CLI for ae-platform.

Replaces scattered curl + python3 -c patterns with a single robust tool.
Handles: auth, proxy clearing, JSON parsing, retry, control char stripping.

Usage:
    ae-git.py [--pretty] [--token TOKEN] [--owner OWNER] <command> [args]

Exit codes:
    0 = success
    1 = API error
    2 = auth error
    3 = network error
"""

import argparse
import base64
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

# ── Constants ────────────────────────────────────────────

GITEE_API = "https://gitee.com/api/v5"
GITEE_ENTERPRISE_API = "https://gitee.com/api/v5/enterprises"
DEFAULT_OWNER = "turningsyn"
CRED_PATHS = [
    os.path.expanduser("~/.config/ae/credentials.env"),
    os.path.expanduser("~/.config/ae-pm/credentials.env"),
    os.path.expanduser("~/.config/agentrunzo/credentials.env"),
]

EXIT_SUCCESS = 0
EXIT_API_ERROR = 1
EXIT_AUTH_ERROR = 2
EXIT_NETWORK_ERROR = 3

MAX_RETRIES = 3
RETRY_BACKOFF = 1.0  # seconds

PROXY_VARS = (
    "http_proxy", "https_proxy",
    "HTTP_PROXY", "HTTPS_PROXY",
    "ALL_PROXY", "all_proxy",
)

# CA cert search paths for macOS/Linux
CA_CERT_PATHS = [
    "/etc/ssl/cert.pem",                    # macOS system
    "/etc/ssl/certs/ca-certificates.crt",   # Debian/Ubuntu
    "/etc/pki/tls/certs/ca-bundle.crt",     # RHEL/CentOS
]


# ── Auth & Proxy ─────────────────────────────────────────

def load_token(override=None):
    """Load Gitee token: CLI flag → env → credentials files."""
    if override:
        return override

    token = os.environ.get("GITEE_TOKEN", "")
    if token:
        return token

    for path in CRED_PATHS:
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("GITEE_TOKEN="):
                            token = line.split("=", 1)[1].strip().strip('"').strip("'")
                            if token:
                                return token
            except OSError:
                continue

    return ""


def clear_proxy():
    """Remove all proxy env vars before Gitee API calls."""
    for var in PROXY_VARS:
        os.environ.pop(var, None)


def _ssl_context():
    """Build an SSL context that works on macOS/Linux even without certifi."""
    # Try certifi first (pip-installed CA bundle)
    try:
        import certifi
        ctx = ssl.create_default_context(cafile=certifi.where())
        return ctx
    except ImportError:
        pass
    # Fall back to common system CA paths
    for path in CA_CERT_PATHS:
        if os.path.isfile(path):
            ctx = ssl.create_default_context(cafile=path)
            return ctx
    # Last resort: default context (may fail on some macOS installs)
    return ssl.create_default_context()


# ── HTTP Layer ───────────────────────────────────────────

def strip_control_chars(text):
    """Remove non-printable control characters (except \\n \\t) from API responses."""
    return re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', text)


def api_request(method, url, body=None, token=None, timeout=30):
    """Make HTTP request to Gitee API with retry and robust JSON parsing.

    Returns parsed JSON dict on success.
    Calls sys.exit() on unrecoverable errors.
    """
    clear_proxy()
    ctx = _ssl_context()

    if body is not None:
        data = json.dumps(body).encode("utf-8")
    else:
        data = None

    headers = {"Content-Type": "application/json"} if data else {}

    last_error = None
    for attempt in range(MAX_RETRIES):
        try:
            req = urllib.request.Request(url, data=data, headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                raw = strip_control_chars(raw)
                if not raw.strip():
                    return {}
                return json.loads(raw)

        except urllib.error.HTTPError as e:
            status = e.code
            try:
                err_body = e.read().decode("utf-8", errors="replace")
                err_body = strip_control_chars(err_body)
                err_data = json.loads(err_body) if err_body.strip() else {}
            except (json.JSONDecodeError, OSError):
                err_data = {"raw": err_body if 'err_body' in dir() else ""}

            # Auth errors — no retry
            if status in (401, 403):
                error_exit(
                    f"认证失败 (HTTP {status}): {err_data.get('message', '')}",
                    EXIT_AUTH_ERROR,
                )

            # Retryable errors
            if status in (429, 500, 502, 503) and attempt < MAX_RETRIES - 1:
                delay = RETRY_BACKOFF * (2 ** attempt)
                print(f"[ae-git] HTTP {status}, 重试 ({attempt + 1}/{MAX_RETRIES})...",
                      file=sys.stderr)
                time.sleep(delay)
                last_error = e
                continue

            # Non-retryable API error
            error_exit(
                f"API 错误 (HTTP {status}): {err_data.get('message', json.dumps(err_data, ensure_ascii=False))}",
                EXIT_API_ERROR,
            )

        except (urllib.error.URLError, OSError) as e:
            last_error = e
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_BACKOFF * (2 ** attempt)
                print(f"[ae-git] 网络错误, 重试 ({attempt + 1}/{MAX_RETRIES})...",
                      file=sys.stderr)
                time.sleep(delay)
                continue

    error_exit(f"网络错误: {last_error}", EXIT_NETWORK_ERROR)


# ── Output Helpers ───────────────────────────────────────

def output(data, pretty=False):
    """Write JSON to stdout."""
    if pretty:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print(json.dumps(data, ensure_ascii=False))


def error_exit(message, code=EXIT_API_ERROR):
    """Print error to stderr and exit."""
    print(f"[ae-git] 错误: {message}", file=sys.stderr)
    sys.exit(code)


# ── Issue Commands ───────────────────────────────────────

def cmd_issues_create(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    url = f"{GITEE_API}/repos/{args.owner}/issues"
    body = {
        "access_token": token,
        "repo": args.repo,
        "title": args.title,
        "body": args.body,
    }
    result = api_request("POST", url, body)
    output({
        "number": result.get("number", ""),
        "html_url": result.get("html_url", ""),
        "title": result.get("title", ""),
        "state": result.get("state", ""),
    }, args.pretty)


def cmd_issues_comment(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    url = f"{GITEE_API}/repos/{args.owner}/{args.repo}/issues/{args.number}/comments"
    body = {
        "access_token": token,
        "body": args.body,
    }
    result = api_request("POST", url, body)
    output({
        "id": result.get("id", ""),
        "html_url": result.get("html_url", ""),
        "issue_url": f"https://e.gitee.com/{args.owner}/issues/list?issue={args.number}",
    }, args.pretty)


def cmd_issues_get(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    # Enterprise issue endpoint (supports alphanumeric issue numbers like II8R1M)
    url = f"{GITEE_ENTERPRISE_API}/{args.owner}/issues/{args.number}?access_token={token}"
    result = api_request("GET", url)
    output({
        "number": result.get("number", ""),
        "html_url": result.get("html_url", ""),
        "title": result.get("title", ""),
        "state": result.get("state", ""),
        "body": result.get("body", ""),
        "created_at": result.get("created_at", ""),
        "updated_at": result.get("updated_at", ""),
        "issue_state": result.get("issue_state_detail", {}).get("title", ""),
    }, args.pretty)


def cmd_issues_list(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    issues = []
    page = 1
    per_page = min(args.per_page, 100)

    while True:
        url = (f"{GITEE_API}/repos/{args.owner}/{args.repo}/issues"
               f"?access_token={token}&state={args.state}"
               f"&per_page={per_page}&page={page}&sort=updated&direction=desc")
        batch = api_request("GET", url)

        if not isinstance(batch, list):
            break

        for item in batch:
            issues.append({
                "number": item.get("number", ""),
                "title": item.get("title", ""),
                "state": item.get("state", ""),
                "html_url": item.get("html_url", ""),
                "updated_at": item.get("updated_at", ""),
            })

        # Stop if we got less than requested (last page) or reached limit
        if len(batch) < per_page or len(issues) >= args.per_page:
            break
        page += 1

    output({"issues": issues[:args.per_page], "total": len(issues)}, args.pretty)


def cmd_issues_close(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    # Enterprise endpoint for closing issues
    url = f"{GITEE_ENTERPRISE_API}/{args.owner}/issues/{args.number}"
    body = {
        "access_token": token,
        "state": "closed",
    }
    result = api_request("PATCH", url, body)
    output({
        "number": result.get("number", ""),
        "state": result.get("state", result.get("issue_state_detail", {}).get("title", "")),
        "html_url": result.get("html_url", ""),
    }, args.pretty)


# ── Upload Command ───────────────────────────────────────

def cmd_upload_image(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    file_path = args.file
    if not os.path.isfile(file_path):
        error_exit(f"文件不存在: {file_path}", EXIT_API_ERROR)

    basename = os.path.basename(file_path)
    ts = int(time.time())
    date_path = datetime.now().strftime("%Y/%m")
    remote_path = f"_attachments/{date_path}/{ts}-{basename}"

    with open(file_path, "rb") as f:
        content_b64 = base64.b64encode(f.read()).decode()

    url = f"{GITEE_API}/repos/{args.owner}/{args.repo}/contents/{remote_path}"
    body = {
        "access_token": token,
        "message": f"chore: upload attachment {basename}",
        "content": content_b64,
    }
    result = api_request("POST", url, body, timeout=60)

    download_url = result.get("content", {}).get("download_url", "")
    output({
        "download_url": download_url,
        "path": remote_path,
    }, args.pretty)


# ── Auth Commands ────────────────────────────────────────

def cmd_auth_validate(args):
    token = load_token(args.token)
    if not token:
        output({"valid": False, "http_status": 0, "error": "token not found"}, args.pretty)
        sys.exit(EXIT_AUTH_ERROR)

    clear_proxy()
    ctx = _ssl_context()

    url = f"{GITEE_API}/user?access_token={token}"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
            output({"valid": True, "http_status": resp.status}, args.pretty)
    except urllib.error.HTTPError as e:
        output({"valid": False, "http_status": e.code}, args.pretty)
        sys.exit(EXIT_AUTH_ERROR)
    except (urllib.error.URLError, OSError) as e:
        output({"valid": False, "http_status": 0, "error": str(e)}, args.pretty)
        sys.exit(EXIT_NETWORK_ERROR)


def cmd_auth_user(args):
    token = load_token(args.token)
    if not token:
        error_exit("未找到 GITEE_TOKEN，请运行 ae setup 配置", EXIT_AUTH_ERROR)

    url = f"{GITEE_API}/user?access_token={token}"
    result = api_request("GET", url)
    output({
        "login": result.get("login", ""),
        "name": result.get("name", ""),
        "id": result.get("id", ""),
    }, args.pretty)


# ── CLI Setup ────────────────────────────────────────────

def build_parser():
    # Shared global options inherited by all subcommands
    global_opts = argparse.ArgumentParser(add_help=False)
    global_opts.add_argument("--pretty", action="store_true", help="Human-readable output")
    global_opts.add_argument("--token", help="Override Gitee token")
    global_opts.add_argument("--owner", default=DEFAULT_OWNER, help="Gitee org/user")

    parser = argparse.ArgumentParser(
        prog="ae-git",
        description="AE Git platform CLI — unified Gitee API tool",
        parents=[global_opts],
    )

    sub = parser.add_subparsers(dest="command")

    # ── issues ──
    issues = sub.add_parser("issues", help="Issue operations", parents=[global_opts])
    issues_sub = issues.add_subparsers(dest="action")

    p = issues_sub.add_parser("create", help="Create a new issue", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--body", default="")

    p = issues_sub.add_parser("comment", help="Comment on an issue", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--number", required=True)
    p.add_argument("--body", required=True)

    p = issues_sub.add_parser("get", help="Get issue details", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--number", required=True)

    p = issues_sub.add_parser("list", help="List issues", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--state", default="open", choices=["open", "closed", "all"])
    p.add_argument("--per-page", type=int, default=20)

    p = issues_sub.add_parser("close", help="Close an issue", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--number", required=True)

    # ── upload-image ──
    p = sub.add_parser("upload-image", help="Upload image to Gitee repo", parents=[global_opts])
    p.add_argument("--repo", required=True)
    p.add_argument("--file", required=True)

    # ── auth ──
    auth = sub.add_parser("auth", help="Auth operations", parents=[global_opts])
    auth_sub = auth.add_subparsers(dest="action")
    auth_sub.add_parser("validate", help="Validate Gitee token", parents=[global_opts])
    auth_sub.add_parser("user", help="Get authenticated user info", parents=[global_opts])

    return parser


COMMANDS = {
    ("issues", "create"): cmd_issues_create,
    ("issues", "comment"): cmd_issues_comment,
    ("issues", "get"): cmd_issues_get,
    ("issues", "list"): cmd_issues_list,
    ("issues", "close"): cmd_issues_close,
    ("upload-image", None): cmd_upload_image,
    ("auth", "validate"): cmd_auth_validate,
    ("auth", "user"): cmd_auth_user,
}


def main():
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    action = getattr(args, "action", None)
    handler = COMMANDS.get((args.command, action))

    if not handler:
        parser.print_help()
        sys.exit(1)

    handler(args)


if __name__ == "__main__":
    main()
