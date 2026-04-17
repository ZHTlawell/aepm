#!/usr/bin/env python3
"""Save WDA screenshot + element tree XML in one call.

Usage:
    # Save screenshot + element tree
    python3 screenshot-save.py screenshots/2a-F01-scan-entry

    # Only screenshot, no element tree
    python3 screenshot-save.py screenshots/2a-F01-scan-entry --no-xml

    # Skip notification dismiss (not recommended)
    python3 screenshot-save.py screenshots/test --no-dismiss

    # Custom WDA URL (explicit flag — overrides $WDA_URL env var)
    python3 screenshot-save.py screenshots/test --wda-url http://localhost:8200

    # Or set env var (multi-session parallel: each session its own port)
    export WDA_URL=http://localhost:8101
    python3 screenshot-save.py screenshots/test

Output:
    screenshots/2a-F01-scan-entry.png   — screenshot image
    screenshots/2a-F01-scan-entry.xml   — WDA element tree (unless --no-xml)

Exit codes:
    0 — success
    1 — WDA not reachable or black screen after retries
"""

import sys
import argparse
import json
import base64
import os
import urllib.request
import urllib.error


# Read from $WDA_URL env var if set, else default to 8100.
DEFAULT_WDA_URL = os.environ.get("WDA_URL", "http://localhost:8100")


def _wda_request(path, method="GET", body=None, wda_url=DEFAULT_WDA_URL):
    """Make a WDA HTTP request, return parsed JSON or None on failure."""
    full_url = f"{wda_url}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        full_url, data=data, method=method,
        headers={"Content-Type": "application/json"} if data else {},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception:
        return None


def _get_session_id(wda_url=DEFAULT_WDA_URL):
    """Get existing WDA session ID or create one."""
    data = _wda_request("/status", wda_url=wda_url)
    if not data:
        return ""
    sid = data.get("sessionId") or ""
    if not sid:
        val = data.get("value", {})
        sid = val.get("sessionId", "") if isinstance(val, dict) else ""
    if sid:
        return sid
    resp = _wda_request("/session", method="POST",
                        body={"capabilities": {}}, wda_url=wda_url)
    return (resp or {}).get("sessionId", "")


def dismiss_notifications(wda_url=DEFAULT_WDA_URL):
    """Dismiss system alerts and notification banners before taking a screenshot.

    1. Try WDA alert dismiss API (handles UIAlertController dialogs)
    2. Swipe up from top to dismiss any notification banner
    """
    sid = _get_session_id(wda_url)
    if not sid:
        return

    # Step 1: Dismiss any system alert (e.g., permission dialogs)
    _wda_request(f"/session/{sid}/alert/dismiss", method="POST",
                 body={}, wda_url=wda_url)

    # Step 2: Swipe down-to-up on the notification banner area (top ~80 logical pts)
    # This dismisses iOS notification banners that slide in from the top
    import time
    actions = {
        "actions": [{
            "type": "pointer",
            "id": "finger1",
            "parameters": {"pointerType": "touch"},
            "actions": [
                {"type": "pointerMove", "duration": 0, "x": 200, "y": 30},
                {"type": "pointerDown", "button": 0},
                {"type": "pointerMove", "duration": 200, "x": 200, "y": 0},
                {"type": "pointerUp", "button": 0},
            ]
        }]
    }
    _wda_request(f"/session/{sid}/actions", method="POST",
                 body=actions, wda_url=wda_url)
    time.sleep(0.5)  # Wait for animation to complete


def save_screenshot(base_path, wda_url=DEFAULT_WDA_URL, max_retries=3):
    """Fetch and save WDA screenshot with black screen retry."""
    url = f"{wda_url}/screenshot"
    MIN_VALID_SIZE = 80_000

    png_path = f"{base_path}.png"
    os.makedirs(os.path.dirname(png_path) or ".", exist_ok=True)

    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                data = json.loads(resp.read())
            img_bytes = base64.b64decode(data["value"])
        except Exception as e:
            if attempt == max_retries:
                print(f"Error: WDA screenshot failed after {max_retries} attempts — {e}", file=sys.stderr)
                return None
            import time; time.sleep(1)
            continue

        if len(img_bytes) >= MIN_VALID_SIZE:
            with open(png_path, "wb") as f:
                f.write(img_bytes)
            return png_path

        if attempt < max_retries:
            print(f"Attempt {attempt}: {len(img_bytes)} bytes (likely black screen), retrying...", file=sys.stderr)
            import time; time.sleep(2)

    # Last attempt might still be black, save anyway with warning
    print(f"Warning: screenshot may be black ({len(img_bytes)} bytes)", file=sys.stderr)
    with open(png_path, "wb") as f:
        f.write(img_bytes)
    return png_path


def save_element_tree(base_path, wda_url=DEFAULT_WDA_URL):
    """Fetch and save WDA element tree as XML."""
    xml_path = f"{base_path}.xml"
    url = f"{wda_url}/source?format=xml"

    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            data = json.loads(resp.read())
        xml_content = data.get("value", "")
        if xml_content:
            with open(xml_path, "w", encoding="utf-8") as f:
                f.write(xml_content)
            return xml_path
    except Exception as e:
        print(f"Warning: element tree fetch failed — {e}", file=sys.stderr)

    return None


def main():
    parser = argparse.ArgumentParser(description="Save WDA screenshot + element tree")
    parser.add_argument("base_path", help="Output base path (without extension), e.g. screenshots/2a-F01-scan")
    parser.add_argument("--no-xml", action="store_true", help="Skip element tree XML")
    parser.add_argument("--no-dismiss", action="store_true",
                        help="Skip auto-dismiss of notifications/alerts before screenshot")
    parser.add_argument("--wda-url", default=DEFAULT_WDA_URL,
                        help="WDA base URL (default: $WDA_URL env var or http://localhost:8100)")
    args = parser.parse_args()

    # Dismiss notifications/alerts before screenshot (default: on)
    if not args.no_dismiss:
        dismiss_notifications(args.wda_url)

    # Save screenshot
    png_path = save_screenshot(args.base_path, args.wda_url)
    if png_path is None:
        print("Failed to save screenshot", file=sys.stderr)
        sys.exit(1)
    print(f"Screenshot: {png_path}")

    # Save element tree
    if not args.no_xml:
        xml_path = save_element_tree(args.base_path, args.wda_url)
        if xml_path:
            print(f"XML:        {xml_path}")
        else:
            print("XML:        (skipped — fetch failed)", file=sys.stderr)

    # Output JSON for programmatic use
    result = {"png": png_path}
    if not args.no_xml:
        result["xml"] = xml_path
    # Print to stderr so stdout stays clean for piping
    print(json.dumps(result), file=sys.stderr)


if __name__ == "__main__":
    main()
