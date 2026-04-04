#!/usr/bin/env python3
"""WDA HTTP API CLI — fallback when mobile-mcp tools are unavailable.

Usage:
    python3 wda-cli.py screenshot [--save PATH]     # Take screenshot
    python3 wda-cli.py tap X Y                       # Tap at coordinates
    python3 wda-cli.py launch BUNDLE_ID              # Launch app
    python3 wda-cli.py source [--format xml|json]    # Get element tree
    python3 wda-cli.py swipe X1 Y1 X2 Y2 [--duration 0.5]  # Swipe
    python3 wda-cli.py apps                          # List installed apps
    python3 wda-cli.py status                        # Check WDA status
    python3 wda-cli.py session                       # Get/create session

    # Custom WDA URL
    python3 wda-cli.py --url http://localhost:8200 screenshot
"""

import sys
import argparse
import json
import base64
import os
import urllib.request
import urllib.error


WDA_URL = "http://localhost:8100"


def wda_request(path, method="GET", body=None, url_base=None):
    """Make a WDA HTTP request."""
    base = url_base or WDA_URL
    full_url = f"{base}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        full_url, data=data, method=method,
        headers={"Content-Type": "application/json"} if data else {},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.URLError as e:
        print(f"Error: WDA request failed — {e}", file=sys.stderr)
        print(f"URL: {full_url}", file=sys.stderr)
        print("Is WDA running? Run: bash wda-start.sh", file=sys.stderr)
        sys.exit(1)


def get_session_id(url_base=None):
    """Get existing session ID or create one."""
    data = wda_request("/status", url_base=url_base)
    sid = data.get("sessionId") or ""
    if not sid:
        val = data.get("value", {})
        sid = val.get("sessionId", "") if isinstance(val, dict) else ""
    if sid:
        return sid
    # Create new session
    resp = wda_request("/session", method="POST",
                       body={"capabilities": {}}, url_base=url_base)
    return resp.get("sessionId", "")


def cmd_status(args):
    data = wda_request("/status", url_base=args.url)
    print(json.dumps(data, indent=2))


def cmd_session(args):
    sid = get_session_id(args.url)
    print(f"Session: {sid}")


def cmd_screenshot(args):
    data = wda_request("/screenshot", url_base=args.url)
    img_bytes = base64.b64decode(data["value"])

    MIN_VALID = 80_000
    if len(img_bytes) < MIN_VALID:
        print(f"Warning: screenshot may be black ({len(img_bytes)} bytes)", file=sys.stderr)
        # Retry once
        import time; time.sleep(2)
        data = wda_request("/screenshot", url_base=args.url)
        img_bytes = base64.b64decode(data["value"])

    if args.save:
        os.makedirs(os.path.dirname(args.save) or ".", exist_ok=True)
        with open(args.save, "wb") as f:
            f.write(img_bytes)
        print(f"Saved: {args.save} ({len(img_bytes)} bytes)")
    else:
        # Write to stdout as base64 for piping
        print(f"Screenshot: {len(img_bytes)} bytes")
        # Save to temp
        import tempfile
        tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        tmp.write(img_bytes)
        tmp.close()
        print(f"Temp: {tmp.name}")


def cmd_tap(args):
    sid = get_session_id(args.url)
    wda_request(f"/session/{sid}/wda/tap/0", method="POST",
                body={"x": args.x, "y": args.y}, url_base=args.url)
    print(f"Tapped ({args.x}, {args.y})")


def cmd_swipe(args):
    sid = get_session_id(args.url)
    wda_request(f"/session/{sid}/wda/dragfromtoforduration", method="POST",
                body={
                    "fromX": args.x1, "fromY": args.y1,
                    "toX": args.x2, "toY": args.y2,
                    "duration": args.duration,
                }, url_base=args.url)
    print(f"Swiped ({args.x1},{args.y1}) → ({args.x2},{args.y2})")


def cmd_launch(args):
    sid = get_session_id(args.url)
    wda_request(f"/session/{sid}/wda/apps/launch", method="POST",
                body={"bundleId": args.bundle_id}, url_base=args.url)
    print(f"Launched: {args.bundle_id}")


def cmd_source(args):
    fmt = args.format or "xml"
    data = wda_request(f"/source?format={fmt}", url_base=args.url)
    content = data.get("value", "")
    if args.save:
        ext = ".xml" if fmt == "xml" else ".json"
        with open(args.save, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Saved: {args.save}")
    else:
        print(content)


def cmd_apps(args):
    sid = get_session_id(args.url)
    # List installed apps via idb or WDA
    # WDA doesn't have a direct "list apps" endpoint, use ios CLI
    import subprocess
    try:
        result = subprocess.run(["ios", "apps", "--list"],
                                capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print("Failed to list apps via ios CLI", file=sys.stderr)
            print("Try: ios apps --list", file=sys.stderr)
    except FileNotFoundError:
        print("ios CLI not found. Install go-ios.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="WDA HTTP API CLI")
    parser.add_argument("--url", default=WDA_URL, help="WDA base URL")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("status", help="Check WDA status")
    sub.add_parser("session", help="Get/create session")

    p_ss = sub.add_parser("screenshot", help="Take screenshot")
    p_ss.add_argument("--save", metavar="PATH", help="Save to file")

    p_tap = sub.add_parser("tap", help="Tap at coordinates")
    p_tap.add_argument("x", type=float)
    p_tap.add_argument("y", type=float)

    p_swipe = sub.add_parser("swipe", help="Swipe gesture")
    p_swipe.add_argument("x1", type=float)
    p_swipe.add_argument("y1", type=float)
    p_swipe.add_argument("x2", type=float)
    p_swipe.add_argument("y2", type=float)
    p_swipe.add_argument("--duration", type=float, default=0.5)

    p_launch = sub.add_parser("launch", help="Launch app")
    p_launch.add_argument("bundle_id")

    p_src = sub.add_parser("source", help="Get element tree")
    p_src.add_argument("--format", choices=["xml", "json"], default="xml")
    p_src.add_argument("--save", metavar="PATH", help="Save to file")

    sub.add_parser("apps", help="List installed apps")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    cmds = {
        "status": cmd_status, "session": cmd_session,
        "screenshot": cmd_screenshot, "tap": cmd_tap,
        "swipe": cmd_swipe, "launch": cmd_launch,
        "source": cmd_source, "apps": cmd_apps,
    }
    cmds[args.command](args)


if __name__ == "__main__":
    main()
