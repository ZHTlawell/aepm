#!/usr/bin/env python3
"""WDA HTTP API CLI — fallback when mobile-mcp tools are unavailable.

Usage:
    python3 wda-cli.py screenshot [--save PATH]     # Take screenshot
    python3 wda-cli.py tap X Y                       # Tap at logical point
    python3 wda-cli.py tap X Y --pixel                # Tap at pixel coords (auto ÷ scale)
    python3 wda-cli.py tap-element --by NAME --value V   # Tap by element (preferred — no coord guessing)
    python3 wda-cli.py alert-safe-tap X Y             # Check alert first, then tap (no-op if alert present)
    python3 wda-cli.py launch BUNDLE_ID              # Launch app
    python3 wda-cli.py source [--format xml|json]    # Get element tree
    python3 wda-cli.py swipe X1 Y1 X2 Y2 [--duration 0.5]  # Swipe
    python3 wda-cli.py scroll-to-top [--max-swipes 6] # Status-bar tap → fallback to swipe×N
    python3 wda-cli.py alert [--action accept|dismiss|text|buttons] [--button-label LABEL]
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

# Cache scale factor per session to avoid repeated WDA calls
_scale_cache = {}


def get_scale_factor(url_base=None):
    """Detect pixel/logical scale factor from WDA (screenshot width ÷ window width)."""
    base = url_base or WDA_URL
    if base in _scale_cache:
        return _scale_cache[base]
    try:
        # Get screenshot pixel width from PNG header
        req = urllib.request.Request(f"{base}/screenshot",
                                    headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        img_bytes = base64.b64decode(data["value"])
        pixel_w = int.from_bytes(img_bytes[16:20], 'big')

        # Get logical window size
        req2 = urllib.request.Request(f"{base}/window/size",
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req2, timeout=5) as resp:
            win = json.loads(resp.read())
        logical_w = win.get("value", {}).get("width", 0)

        if logical_w > 0:
            scale = round(pixel_w / logical_w)
            _scale_cache[base] = scale
            return scale
    except Exception as e:
        print(f"Warning: scale detection failed ({e}), using default @3x",
              file=sys.stderr)
    _scale_cache[base] = 3
    return 3  # default @3x for modern iPhones


def pixel_to_logical(x, y, url_base=None):
    """Convert pixel coordinates to logical points by dividing by scale factor."""
    scale = get_scale_factor(url_base)
    return int(round(x / scale)), int(round(y / scale))


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


def _do_tap(sid, x, y, url_base):
    actions = {
        "actions": [{
            "type": "pointer",
            "id": "finger1",
            "parameters": {"pointerType": "touch"},
            "actions": [
                {"type": "pointerMove", "duration": 0, "x": x, "y": y},
                {"type": "pointerDown", "button": 0},
                {"type": "pause", "duration": 50},
                {"type": "pointerUp", "button": 0},
            ]
        }]
    }
    wda_request(f"/session/{sid}/actions", method="POST",
                body=actions, url_base=url_base)


def cmd_tap(args):
    sid = get_session_id(args.url)
    x, y = int(args.x), int(args.y)
    if getattr(args, 'pixel', False):
        x, y = pixel_to_logical(args.x, args.y, args.url)
        scale = get_scale_factor(args.url)
        print(f"pixel→logical: ({int(args.x)},{int(args.y)}) ÷ {scale}x → ({x},{y})")
    _do_tap(sid, x, y, args.url)
    print(f"Tapped ({x}, {y})")


# WDA locator strategies — values accepted in /element "using" field
_LOCATOR_STRATEGIES = {
    "accessibility_id": "accessibility id",
    "name": "name",
    "label": "label",
    "xpath": "xpath",
    "predicate": "predicate string",
    "class_chain": "class chain",
    "link_text": "link text",
    "partial_link_text": "partial link text",
}


def _find_element(sid, strategy, value, url_base):
    """Find element via WDA /session/{sid}/element. Returns element UUID or None.

    Handles WDA's 404 "no such element" response gracefully (no sys.exit).
    """
    using = _LOCATOR_STRATEGIES.get(strategy, strategy)
    base = url_base or WDA_URL
    body = json.dumps({"using": using, "value": value}).encode()
    req = urllib.request.Request(
        f"{base}/session/{sid}/element",
        data=body, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    val = data.get("value")
    if not val or not isinstance(val, dict):
        return None
    # WDA returns {"ELEMENT": "UUID", "element-6066-11e4-a52e-4f735466cecf": "UUID"}
    return val.get("ELEMENT") or val.get("element-6066-11e4-a52e-4f735466cecf")


def _get_element_rect(sid, elem_id, url_base):
    resp = wda_request(f"/session/{sid}/element/{elem_id}/rect", url_base=url_base)
    return resp.get("value", {})


def cmd_tap_element(args):
    """Tap on an element found via accessibility_id / name / label / xpath / predicate.

    Physically prevents naked-coordinate tapping — agent must identify the element
    first. Fail fast with guidance if the element is not found.
    """
    sid = get_session_id(args.url)
    # Pre-tap alert check (iOS system alerts absorb all touches)
    alert_text = _alert_text(sid, args.url)
    if alert_text and not args.ignore_alert:
        print(f"Error: system alert present (text: {alert_text!r}).\n"
              f"Use 'wda-cli.py alert --action accept|dismiss [--button-label LABEL]' "
              f"to dismiss it before tapping.", file=sys.stderr)
        sys.exit(2)

    elem_id = _find_element(sid, args.by, args.value, args.url)
    if not elem_id:
        print(f"Error: element not found by {args.by}={args.value!r}.\n"
              f"Hint: dump the tree to disk (don't flood LLM context):\n"
              f"  wda-cli.py source --format xml --save /tmp/wda-tree.xml\n"
              f"  then grep / head the file instead of reading it whole.",
              file=sys.stderr)
        sys.exit(3)
    rect = _get_element_rect(sid, elem_id, args.url)
    if not rect or "x" not in rect:
        print(f"Error: element {elem_id} has no rect (off-screen?).", file=sys.stderr)
        sys.exit(4)
    cx = int(rect["x"] + rect["width"] / 2)
    cy = int(rect["y"] + rect["height"] / 2)
    _do_tap(sid, cx, cy, args.url)
    print(f"Tapped {args.by}={args.value!r} at center ({cx},{cy}) "
          f"[rect=({rect['x']},{rect['y']},{rect['width']},{rect['height']})]")


def _alert_text(sid, url_base):
    """Return alert text if present, else empty string.

    WDA returns 404 on some builds when no alert is present, so we probe
    directly and swallow 404 as 'no alert'.
    """
    base = url_base or WDA_URL
    req = urllib.request.Request(f"{base}/session/{sid}/alert/text")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
        val = data.get("value")
        return val if isinstance(val, str) else ""
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return ""
        return ""
    except Exception:
        return ""


def cmd_alert_safe_tap(args):
    """Tap only if no system alert is present — else report the alert and exit non-zero.

    Guards against the common pitfall of tapping under an iOS system alert
    (ATT/permission/etc.), which absorbs all touches and wastes screenshots.
    """
    sid = get_session_id(args.url)
    text = _alert_text(sid, args.url)
    if text:
        print(f"System alert detected: {text!r}. Refusing to tap.\n"
              f"Use 'wda-cli.py alert --action accept|dismiss [--button-label LABEL]' first.",
              file=sys.stderr)
        sys.exit(2)
    x, y = int(args.x), int(args.y)
    if getattr(args, 'pixel', False):
        x, y = pixel_to_logical(args.x, args.y, args.url)
    _do_tap(sid, x, y, args.url)
    print(f"Tapped ({x}, {y}) [no alert]")


def cmd_alert(args):
    """Inspect or dismiss a system alert (ATT, permissions, etc.)."""
    sid = get_session_id(args.url)
    action = args.action or "text"
    if action == "text":
        text = _alert_text(sid, args.url)
        print(text if text else "(no alert)")
    elif action == "buttons":
        resp = wda_request(f"/session/{sid}/wda/alert/buttons", url_base=args.url)
        print(json.dumps(resp.get("value", []), ensure_ascii=False, indent=2))
    elif action in ("accept", "dismiss"):
        body = {}
        if args.button_label:
            body["name"] = args.button_label
        wda_request(f"/session/{sid}/alert/{action}", method="POST",
                    body=body or None, url_base=args.url)
        print(f"Alert {action}ed" + (f" (button={args.button_label!r})" if args.button_label else ""))
    else:
        print(f"Unknown action: {action}", file=sys.stderr)
        sys.exit(1)


def cmd_scroll_to_top(args):
    """Scroll back to top. Tries status-bar tap first, falls back to swipe up × N.

    iOS 'tap status bar to scroll to top' is unreliable on many Apps (custom
    nav bars intercept the gesture). This helper tries it once, then falls
    back to repeated swipes which is the robust default.
    """
    sid = get_session_id(args.url)
    # Best-effort status bar tap (cheap, may or may not work)
    try:
        _do_tap(sid, 200, 10, args.url)
    except SystemExit:
        pass
    # Default: multiple swipes from screen center downward to scroll content up-to-top
    win = wda_request(f"/session/{sid}/window/size", url_base=args.url).get("value", {})
    w = win.get("width", 390)
    h = win.get("height", 844)
    cx = w // 2
    y_top = int(h * 0.2)
    y_bot = int(h * 0.8)
    for i in range(args.max_swipes):
        actions = {
            "actions": [{
                "type": "pointer",
                "id": "finger1",
                "parameters": {"pointerType": "touch"},
                "actions": [
                    {"type": "pointerMove", "duration": 0, "x": cx, "y": y_top},
                    {"type": "pointerDown", "button": 0},
                    {"type": "pointerMove", "duration": 250, "x": cx, "y": y_bot},
                    {"type": "pointerUp", "button": 0},
                ]
            }]
        }
        wda_request(f"/session/{sid}/actions", method="POST",
                    body=actions, url_base=args.url)
    print(f"scroll-to-top: status-bar tap + {args.max_swipes} swipe(s)")


def cmd_swipe(args):
    sid = get_session_id(args.url)
    x1, y1 = int(args.x1), int(args.y1)
    x2, y2 = int(args.x2), int(args.y2)
    if getattr(args, 'pixel', False):
        x1, y1 = pixel_to_logical(args.x1, args.y1, args.url)
        x2, y2 = pixel_to_logical(args.x2, args.y2, args.url)
        scale = get_scale_factor(args.url)
        print(f"pixel→logical: ÷ {scale}x → ({x1},{y1})→({x2},{y2})")
    # W3C Actions API (WDA 11.x+)
    dur_ms = int(args.duration * 1000)
    actions = {
        "actions": [{
            "type": "pointer",
            "id": "finger1",
            "parameters": {"pointerType": "touch"},
            "actions": [
                {"type": "pointerMove", "duration": 0, "x": x1, "y": y1},
                {"type": "pointerDown", "button": 0},
                {"type": "pointerMove", "duration": dur_ms, "x": x2, "y": y2},
                {"type": "pointerUp", "button": 0},
            ]
        }]
    }
    wda_request(f"/session/{sid}/actions", method="POST",
                body=actions, url_base=args.url)
    print(f"Swiped ({x1},{y1}) → ({x2},{y2})")


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
        print(f"Saved: {args.save} ({len(content)} bytes, {content.count(chr(10))+1} lines)")
    else:
        # Warn: stdout dump floods LLM context. Prefer --save + grep/head.
        size = len(content)
        if size > 4000:
            print(f"Warning: element tree is {size} bytes — this will bloat LLM context.\n"
                  f"Prefer: wda-cli.py source --format {fmt} --save /tmp/wda-tree{('.xml' if fmt=='xml' else '.json')}\n"
                  f"Then grep / head the file. Printing anyway below:",
                  file=sys.stderr)
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

    p_tap = sub.add_parser("tap", help="Tap at coordinates (raw — prefer tap-element)")
    p_tap.add_argument("x", type=float)
    p_tap.add_argument("y", type=float)
    p_tap.add_argument("--pixel", action="store_true",
                       help="Treat x,y as pixel coords; auto ÷ scale → logical points")

    p_tape = sub.add_parser("tap-element",
                            help="Tap on an element found by accessibility_id / name / label / xpath / predicate (PREFERRED — prevents naked-coord tap)")
    p_tape.add_argument("--by", required=True,
                        choices=list(_LOCATOR_STRATEGIES.keys()),
                        help="Locator strategy")
    p_tape.add_argument("--value", required=True,
                        help="Locator value (e.g. 'Back' for name, '//XCUIElementTypeButton[@name=\"Back\"]' for xpath)")
    p_tape.add_argument("--ignore-alert", action="store_true",
                        help="Skip pre-tap alert check (default: fail fast if alert present)")

    p_ast = sub.add_parser("alert-safe-tap",
                           help="Tap at coords ONLY if no system alert is present")
    p_ast.add_argument("x", type=float)
    p_ast.add_argument("y", type=float)
    p_ast.add_argument("--pixel", action="store_true")

    p_alert = sub.add_parser("alert", help="Inspect or dismiss a system alert")
    p_alert.add_argument("--action",
                         choices=["text", "buttons", "accept", "dismiss"],
                         default="text")
    p_alert.add_argument("--button-label",
                         help="Specific button label to click (for accept/dismiss)")

    p_stt = sub.add_parser("scroll-to-top",
                           help="Scroll to top via status-bar tap → fallback to swipe×N")
    p_stt.add_argument("--max-swipes", type=int, default=6,
                       help="Number of swipe-down gestures as fallback (default: 6)")

    p_swipe = sub.add_parser("swipe", help="Swipe gesture")
    p_swipe.add_argument("x1", type=float)
    p_swipe.add_argument("y1", type=float)
    p_swipe.add_argument("x2", type=float)
    p_swipe.add_argument("y2", type=float)
    p_swipe.add_argument("--duration", type=float, default=0.5)
    p_swipe.add_argument("--pixel", action="store_true",
                         help="Treat coords as pixel; auto ÷ scale → logical points")

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
        "tap-element": cmd_tap_element,
        "alert-safe-tap": cmd_alert_safe_tap,
        "alert": cmd_alert,
        "scroll-to-top": cmd_scroll_to_top,
        "swipe": cmd_swipe, "launch": cmd_launch,
        "source": cmd_source, "apps": cmd_apps,
    }
    cmds[args.command](args)


if __name__ == "__main__":
    main()
