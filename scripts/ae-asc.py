#!/usr/bin/env python3
"""ae-asc.py — App Store Connect API CLI for ae-platform.

Replaces Playwright browser automation for ASC operations with direct REST API calls.
Handles: JWT auth (ES256), Bundle ID / App / TestFlight management.

Usage:
    ae-asc.py [--pretty] [--key-id ID] [--issuer-id ID] [--key-path PATH] <command> [args]

Exit codes:
    0 = success
    1 = API error
    2 = auth error
    3 = network error
"""

import argparse
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ── Dependency Check ────────────────────────────────────

try:
    import jwt
except ImportError:
    print("[ae-asc] 错误: 缺少 PyJWT。请安装:", file=sys.stderr)
    print("  pip3 install PyJWT cryptography", file=sys.stderr)
    sys.exit(2)

try:
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
except ImportError:
    print("[ae-asc] 错误: 缺少 cryptography。请安装:", file=sys.stderr)
    print("  pip3 install PyJWT cryptography", file=sys.stderr)
    sys.exit(2)


# ── Constants ───────────────────────────────────────────

ASC_API = "https://api.appstoreconnect.apple.com/v1"

CRED_PATHS = [
    os.path.expanduser("~/.config/ae/credentials.env"),
    os.path.expanduser("~/.config/ae-pm/credentials.env"),
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

CA_CERT_PATHS = [
    "/etc/ssl/cert.pem",                    # macOS system
    "/etc/ssl/certs/ca-certificates.crt",   # Debian/Ubuntu
    "/etc/pki/tls/certs/ca-bundle.crt",     # RHEL/CentOS
]


# ── Auth ────────────────────────────────────────────────

def load_credentials(key_id_override=None, issuer_id_override=None, key_path_override=None):
    """Load ASC credentials: CLI flags -> env -> credentials files.

    Returns (key_id, issuer_id, key_path) tuple.
    """
    key_id = key_id_override or os.environ.get("ASC_KEY_ID", "")
    issuer_id = issuer_id_override or os.environ.get("ASC_ISSUER_ID", "")
    key_path = key_path_override or os.environ.get("ASC_KEY_PATH", "")

    if key_id and issuer_id and key_path:
        return key_id, issuer_id, os.path.expanduser(key_path)

    for path in CRED_PATHS:
        if not os.path.isfile(path):
            continue
        try:
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if not key_id and line.startswith("ASC_KEY_ID="):
                        key_id = line.split("=", 1)[1].strip().strip('"').strip("'")
                    elif not issuer_id and line.startswith("ASC_ISSUER_ID="):
                        issuer_id = line.split("=", 1)[1].strip().strip('"').strip("'")
                    elif not key_path and line.startswith("ASC_KEY_PATH="):
                        key_path = line.split("=", 1)[1].strip().strip('"').strip("'")
        except OSError:
            continue

    return key_id, issuer_id, os.path.expanduser(key_path) if key_path else ""


def generate_jwt(key_id, issuer_id, key_path):
    """Generate ASC API JWT token (valid 20 min)."""
    if not os.path.isfile(key_path):
        error_exit(f".p8 密钥文件不存在: {key_path}", EXIT_AUTH_ERROR)

    with open(key_path, "rb") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def require_jwt(args):
    """Load credentials and generate JWT. Exit on failure."""
    key_id, issuer_id, key_path = load_credentials(
        getattr(args, "key_id", None),
        getattr(args, "issuer_id", None),
        getattr(args, "key_path", None),
    )
    if not key_id or not issuer_id or not key_path:
        missing = []
        if not key_id:
            missing.append("ASC_KEY_ID")
        if not issuer_id:
            missing.append("ASC_ISSUER_ID")
        if not key_path:
            missing.append("ASC_KEY_PATH")
        error_exit(
            f"缺少 ASC 凭据: {', '.join(missing)}。"
            f"请在 ~/.config/ae/credentials.env 中配置，或使用 --key-id / --issuer-id / --key-path 参数",
            EXIT_AUTH_ERROR,
        )
    return generate_jwt(key_id, issuer_id, key_path)


def clear_proxy():
    """Remove all proxy env vars before API calls."""
    for var in PROXY_VARS:
        os.environ.pop(var, None)


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


# ── HTTP Layer ──────────────────────────────────────────

def strip_control_chars(text):
    """Remove non-printable control characters (except \\n \\t) from API responses."""
    return re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', text)


def parse_asc_errors(err_data):
    """Extract human-readable error message from ASC JSON:API errors."""
    errors = err_data.get("errors", [])
    if errors:
        parts = []
        for e in errors:
            detail = e.get("detail", e.get("title", ""))
            code = e.get("code", "")
            if code:
                parts.append(f"{code}: {detail}")
            else:
                parts.append(detail)
        return "; ".join(parts)
    return json.dumps(err_data, ensure_ascii=False)


def api_request(method, url, body=None, jwt_token=None, timeout=30):
    """Make HTTP request to ASC API with retry and robust JSON parsing.

    Returns parsed JSON dict on success.
    Calls sys.exit() on unrecoverable errors.
    """
    clear_proxy()
    ctx = _ssl_context()

    if body is not None:
        data = json.dumps(body).encode("utf-8")
    else:
        data = None

    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Content-Type": "application/json",
    }

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
                err_data = {"raw": err_body if "err_body" in dir() else ""}

            # Auth errors -- no retry
            if status in (401, 403):
                error_exit(
                    f"认证失败 (HTTP {status}): {parse_asc_errors(err_data)}",
                    EXIT_AUTH_ERROR,
                )

            # Conflict (e.g. duplicate Bundle ID) -- no retry
            if status == 409:
                error_exit(
                    f"资源冲突 (HTTP 409): {parse_asc_errors(err_data)}",
                    EXIT_API_ERROR,
                )

            # Not found
            if status == 404:
                error_exit(
                    f"资源不存在 (HTTP 404): {parse_asc_errors(err_data)}",
                    EXIT_API_ERROR,
                )

            # Retryable errors
            if status in (429, 500, 502, 503) and attempt < MAX_RETRIES - 1:
                delay = RETRY_BACKOFF * (2 ** attempt)
                print(f"[ae-asc] HTTP {status}, 重试 ({attempt + 1}/{MAX_RETRIES})...",
                      file=sys.stderr)
                time.sleep(delay)
                last_error = e
                continue

            # Non-retryable API error
            error_exit(
                f"API 错误 (HTTP {status}): {parse_asc_errors(err_data)}",
                EXIT_API_ERROR,
            )

        except (urllib.error.URLError, OSError) as e:
            last_error = e
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_BACKOFF * (2 ** attempt)
                print(f"[ae-asc] 网络错误, 重试 ({attempt + 1}/{MAX_RETRIES})...",
                      file=sys.stderr)
                time.sleep(delay)
                continue

    error_exit(f"网络错误: {last_error}", EXIT_NETWORK_ERROR)


# ── JSON:API Helpers ────────────────────────────────────

def parse_jsonapi(response):
    """Flatten JSON:API response to {id, type, ...attributes} or list thereof."""
    data = response.get("data")
    if data is None:
        return response
    if isinstance(data, list):
        return [{"id": item["id"], "type": item["type"], **item.get("attributes", {})}
                for item in data]
    if isinstance(data, dict):
        return {"id": data["id"], "type": data["type"], **data.get("attributes", {})}
    return response


def jsonapi_body(resource_type, attributes, relationships=None):
    """Build a JSON:API request body."""
    body = {
        "data": {
            "type": resource_type,
            "attributes": attributes,
        }
    }
    if relationships:
        body["data"]["relationships"] = relationships
    return body


# ── Output Helpers ──────────────────────────────────────

def output(data, pretty=False):
    """Write JSON to stdout."""
    if pretty:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print(json.dumps(data, ensure_ascii=False))


def error_exit(message, code=EXIT_API_ERROR):
    """Print error to stderr and exit."""
    print(f"[ae-asc] 错误: {message}", file=sys.stderr)
    sys.exit(code)


# ── Helper: Resolve Bundle ID identifier → resource ID ──

def resolve_bundle_id(identifier, jwt_token):
    """Resolve a human-readable Bundle ID (e.g. com.example.app) to its ASC resource ID."""
    url = f"{ASC_API}/bundleIds?filter[identifier]={urllib.parse.quote(identifier)}&limit=1"
    result = api_request("GET", url, jwt_token=jwt_token)
    items = result.get("data", [])
    if not items:
        error_exit(f"Bundle ID '{identifier}' 未在 ASC 注册。请先运行: ae asc bundle-id register --identifier {identifier} --name \"<名称>\"")
    return items[0]["id"]


# ── Auth Commands ───────────────────────────────────────

def cmd_auth_validate(args):
    jwt_token = require_jwt(args)
    # Verify by fetching apps list (lightest authenticated endpoint)
    url = f"{ASC_API}/apps?limit=1"
    result = api_request("GET", url, jwt_token=jwt_token)
    app_count = len(result.get("data", []))
    output({"valid": True, "apps_accessible": app_count > 0}, args.pretty)


# ── App Commands ────────────────────────────────────────

def cmd_app_list(args):
    jwt_token = require_jwt(args)
    url = f"{ASC_API}/apps?limit={args.limit}"
    if args.filter_bundle_id:
        url += f"&filter[bundleId]={urllib.parse.quote(args.filter_bundle_id)}"
    result = api_request("GET", url, jwt_token=jwt_token)
    items = parse_jsonapi(result)
    if isinstance(items, list):
        apps = [{"id": a["id"], "name": a.get("name", ""), "bundleId": a.get("bundleId", ""),
                 "sku": a.get("sku", ""), "primaryLocale": a.get("primaryLocale", "")}
                for a in items]
        output({"apps": apps, "total": len(apps)}, args.pretty)
    else:
        output(items, args.pretty)


def cmd_app_create(args):
    jwt_token = require_jwt(args)
    # Resolve bundle-id identifier to ASC resource ID
    bundle_id_resource_id = resolve_bundle_id(args.bundle_id, jwt_token)

    body = jsonapi_body("apps", {
        "name": args.name,
        "bundleId": args.bundle_id,
        "sku": args.sku,
        "primaryLocale": args.locale,
    }, relationships={
        "bundleId": {
            "data": {"type": "bundleIds", "id": bundle_id_resource_id}
        }
    })

    result = api_request("POST", f"{ASC_API}/apps", body=body, jwt_token=jwt_token)
    app = parse_jsonapi(result)
    output({
        "id": app.get("id", ""),
        "name": app.get("name", ""),
        "bundleId": app.get("bundleId", ""),
        "sku": app.get("sku", ""),
    }, args.pretty)


# ── Bundle ID Commands ──────────────────────────────────

def cmd_bundle_id_list(args):
    jwt_token = require_jwt(args)
    url = f"{ASC_API}/bundleIds?limit={args.limit}"
    if args.filter_identifier:
        url += f"&filter[identifier]={urllib.parse.quote(args.filter_identifier)}"
    result = api_request("GET", url, jwt_token=jwt_token)
    items = parse_jsonapi(result)
    if isinstance(items, list):
        bids = [{"id": b["id"], "identifier": b.get("identifier", ""),
                 "name": b.get("name", ""), "platform": b.get("platform", "")}
                for b in items]
        output({"bundleIds": bids, "total": len(bids)}, args.pretty)
    else:
        output(items, args.pretty)


def cmd_bundle_id_register(args):
    jwt_token = require_jwt(args)
    body = jsonapi_body("bundleIds", {
        "identifier": args.identifier,
        "name": args.name,
        "platform": args.platform,
    })
    result = api_request("POST", f"{ASC_API}/bundleIds", body=body, jwt_token=jwt_token)
    bid = parse_jsonapi(result)
    output({
        "id": bid.get("id", ""),
        "identifier": bid.get("identifier", ""),
        "name": bid.get("name", ""),
        "platform": bid.get("platform", ""),
    }, args.pretty)


# ── TestFlight Commands ─────────────────────────────────

def cmd_testflight_list_builds(args):
    jwt_token = require_jwt(args)
    url = (f"{ASC_API}/builds?filter[app]={urllib.parse.quote(args.app_id)}"
           f"&sort=-uploadedDate&limit={args.limit}"
           f"&fields[builds]=version,uploadedDate,processingState,buildAudienceType,usesNonExemptEncryption")
    result = api_request("GET", url, jwt_token=jwt_token)
    items = parse_jsonapi(result)
    if isinstance(items, list):
        builds = [{"id": b["id"], "version": b.get("version", ""),
                   "uploadedDate": b.get("uploadedDate", ""),
                   "processingState": b.get("processingState", ""),
                   "usesNonExemptEncryption": b.get("usesNonExemptEncryption")}
                  for b in items]
        output({"builds": builds, "total": len(builds)}, args.pretty)
    else:
        output(items, args.pretty)


def cmd_testflight_create_group(args):
    jwt_token = require_jwt(args)
    is_internal = not args.external  # --external overrides default internal=true
    body = jsonapi_body("betaGroups", {
        "name": args.name,
        "isInternalGroup": is_internal,
    }, relationships={
        "app": {
            "data": {"type": "apps", "id": args.app_id}
        }
    })
    result = api_request("POST", f"{ASC_API}/betaGroups", body=body, jwt_token=jwt_token)
    group = parse_jsonapi(result)
    output({
        "id": group.get("id", ""),
        "name": group.get("name", ""),
        "isInternalGroup": group.get("isInternalGroup"),
    }, args.pretty)


def cmd_testflight_add_tester(args):
    jwt_token = require_jwt(args)
    body = jsonapi_body("betaTesters", {
        "email": args.email,
        "firstName": args.first_name,
        "lastName": args.last_name,
    }, relationships={
        "betaGroups": {
            "data": [{"type": "betaGroups", "id": args.group_id}]
        }
    })
    result = api_request("POST", f"{ASC_API}/betaTesters", body=body, jwt_token=jwt_token)
    tester = parse_jsonapi(result)
    output({
        "id": tester.get("id", ""),
        "email": tester.get("email", ""),
        "firstName": tester.get("firstName", ""),
        "lastName": tester.get("lastName", ""),
    }, args.pretty)


def cmd_testflight_set_compliance(args):
    jwt_token = require_jwt(args)
    uses_encryption = args.uses_encryption.lower() == "true"

    # Step 1: Get app ID from the build
    build_url = f"{ASC_API}/builds/{args.build_id}?fields[builds]=app"
    build_result = api_request("GET", build_url, jwt_token=jwt_token)
    app_rel = build_result.get("data", {}).get("relationships", {}).get("app", {}).get("data", {})
    app_id = app_rel.get("id", "")
    if not app_id:
        error_exit(f"无法从 Build {args.build_id} 获取 App ID")

    # Step 2: Find or create an encryption declaration for this app
    # Check existing declarations first
    decl_url = (f"{ASC_API}/appEncryptionDeclarations"
                f"?filter[app]={app_id}"
                f"&filter[usesEncryption]={str(uses_encryption).lower()}"
                f"&limit=1")
    decl_result = api_request("GET", decl_url, jwt_token=jwt_token)
    existing = decl_result.get("data", [])

    if existing:
        enc_decl_id = existing[0]["id"]
    else:
        # Create new declaration
        enc_body = jsonapi_body("appEncryptionDeclarations", {
            "usesEncryption": uses_encryption,
        }, relationships={
            "app": {"data": {"type": "apps", "id": app_id}}
        })
        enc_result = api_request("POST", f"{ASC_API}/appEncryptionDeclarations",
                                 body=enc_body, jwt_token=jwt_token)
        enc_decl_id = enc_result.get("data", {}).get("id", "")
        if not enc_decl_id:
            error_exit("无法创建出口合规声明")

    # Step 3: Link the declaration to the build
    link_body = {
        "data": {"type": "appEncryptionDeclarations", "id": enc_decl_id}
    }
    api_request("PATCH",
                f"{ASC_API}/builds/{args.build_id}/relationships/appEncryptionDeclaration",
                body=link_body, jwt_token=jwt_token)

    output({
        "build_id": args.build_id,
        "usesEncryption": uses_encryption,
        "encryptionDeclarationId": enc_decl_id,
        "status": "compliance_set",
    }, args.pretty)


# ── CLI Setup ───────────────────────────────────────────

def build_parser():
    global_opts = argparse.ArgumentParser(add_help=False)
    global_opts.add_argument("--pretty", action="store_true", help="Human-readable output")
    global_opts.add_argument("--key-id", dest="key_id", help="Override ASC Key ID")
    global_opts.add_argument("--issuer-id", dest="issuer_id", help="Override ASC Issuer ID")
    global_opts.add_argument("--key-path", dest="key_path", help="Override .p8 key file path")

    parser = argparse.ArgumentParser(
        prog="ae-asc",
        description="AE App Store Connect CLI — unified ASC API tool",
        parents=[global_opts],
    )

    sub = parser.add_subparsers(dest="command")

    # ── auth ──
    auth = sub.add_parser("auth", help="Auth operations", parents=[global_opts])
    auth_sub = auth.add_subparsers(dest="action")
    auth_sub.add_parser("validate", help="Validate ASC credentials", parents=[global_opts])

    # ── app ──
    app = sub.add_parser("app", help="App operations", parents=[global_opts])
    app_sub = app.add_subparsers(dest="action")

    p = app_sub.add_parser("list", help="List apps", parents=[global_opts])
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--filter-bundle-id", dest="filter_bundle_id", help="Filter by Bundle ID")

    p = app_sub.add_parser("create", help="Create a new app", parents=[global_opts])
    p.add_argument("--bundle-id", dest="bundle_id", required=True, help="Bundle ID identifier (e.g. com.example.app)")
    p.add_argument("--name", required=True, help="App name")
    p.add_argument("--sku", required=True, help="App SKU")
    p.add_argument("--locale", default="en-US", help="Primary locale (default: en-US)")

    # ── bundle-id ──
    bid = sub.add_parser("bundle-id", help="Bundle ID operations", parents=[global_opts])
    bid_sub = bid.add_subparsers(dest="action")

    p = bid_sub.add_parser("list", help="List Bundle IDs", parents=[global_opts])
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--filter-identifier", dest="filter_identifier", help="Filter by identifier")

    p = bid_sub.add_parser("register", help="Register a new Bundle ID", parents=[global_opts])
    p.add_argument("--identifier", required=True, help="Bundle ID (e.g. com.example.app)")
    p.add_argument("--name", required=True, help="Display name")
    p.add_argument("--platform", default="IOS", choices=["IOS", "MAC_OS", "UNIVERSAL"])

    # ── testflight ──
    tf = sub.add_parser("testflight", help="TestFlight operations", parents=[global_opts])
    tf_sub = tf.add_subparsers(dest="action")

    p = tf_sub.add_parser("list-builds", help="List recent builds", parents=[global_opts])
    p.add_argument("--app-id", dest="app_id", required=True, help="ASC App ID")
    p.add_argument("--limit", type=int, default=5)

    p = tf_sub.add_parser("create-group", help="Create a beta test group", parents=[global_opts])
    p.add_argument("--app-id", dest="app_id", required=True, help="ASC App ID")
    p.add_argument("--name", required=True, help="Group name")
    p.add_argument("--internal", action="store_true", default=True, help="Internal group (default: true)")
    p.add_argument("--external", action="store_true", help="External group")

    p = tf_sub.add_parser("add-tester", help="Add a beta tester", parents=[global_opts])
    p.add_argument("--group-id", dest="group_id", required=True, help="Beta group ID")
    p.add_argument("--email", required=True, help="Tester email")
    p.add_argument("--first-name", dest="first_name", required=True, help="First name")
    p.add_argument("--last-name", dest="last_name", required=True, help="Last name")

    p = tf_sub.add_parser("set-compliance", help="Set export compliance for a build", parents=[global_opts])
    p.add_argument("--build-id", dest="build_id", required=True, help="Build ID")
    p.add_argument("--uses-encryption", dest="uses_encryption", default="false",
                   choices=["true", "false"], help="Uses non-exempt encryption (default: false)")

    return parser


COMMANDS = {
    ("auth", "validate"): cmd_auth_validate,
    ("app", "list"): cmd_app_list,
    ("app", "create"): cmd_app_create,
    ("bundle-id", "list"): cmd_bundle_id_list,
    ("bundle-id", "register"): cmd_bundle_id_register,
    ("testflight", "list-builds"): cmd_testflight_list_builds,
    ("testflight", "create-group"): cmd_testflight_create_group,
    ("testflight", "add-tester"): cmd_testflight_add_tester,
    ("testflight", "set-compliance"): cmd_testflight_set_compliance,
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
