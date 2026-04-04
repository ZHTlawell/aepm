#!/usr/bin/env python3
"""Save WDA screenshot + element tree XML in one call.

Usage:
    # Save screenshot + element tree
    python3 screenshot-save.py screenshots/2a-F01-scan-entry

    # Only screenshot, no element tree
    python3 screenshot-save.py screenshots/2a-F01-scan-entry --no-xml

    # Custom WDA URL
    python3 screenshot-save.py screenshots/test --wda-url http://localhost:8200

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


def save_screenshot(base_path, wda_url="http://localhost:8100", max_retries=3):
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


def save_element_tree(base_path, wda_url="http://localhost:8100"):
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
    parser.add_argument("--wda-url", default="http://localhost:8100", help="WDA base URL")
    args = parser.parse_args()

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
