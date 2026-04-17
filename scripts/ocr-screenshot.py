#!/usr/bin/env python3
"""OCR a screenshot using Apple Vision framework.

Usage:
    # OCR a local image file
    python3 ocr-screenshot.py /path/to/screenshot.png

    # OCR the current WDA screenshot (grab + OCR in one step)
    python3 ocr-screenshot.py --wda

    # Output as JSON (for programmatic use)
    python3 ocr-screenshot.py --wda --json

    # Save WDA screenshot to file before OCR
    python3 ocr-screenshot.py --wda --save /tmp/screenshot.png

    # Output logical point coordinates (auto-detect scale from WDA)
    python3 ocr-screenshot.py --wda --logical

    # Specify scale factor manually (default: auto-detect, fallback @3x)
    python3 ocr-screenshot.py /path/to/screenshot.png --logical --scale 3

    # Multi-session parallel: each session exports its own WDA_URL
    export WDA_URL=http://localhost:8101
    python3 ocr-screenshot.py --wda

    # Or explicit flag (overrides $WDA_URL)
    python3 ocr-screenshot.py --wda --wda-url http://localhost:8101

Requires: pyobjc-framework-Vision, pyobjc-framework-Quartz
    pip3 install pyobjc-framework-Vision pyobjc-framework-Quartz
"""

import sys
import argparse
import json
import base64
import tempfile
import os
import urllib.request


# Read from $WDA_URL env var if set, else default to 8100.
DEFAULT_WDA_URL = os.environ.get("WDA_URL", "http://localhost:8100")


def fetch_wda_screenshot(save_path=None, max_retries=3, wda_url=DEFAULT_WDA_URL):
    """Fetch screenshot from WDA API, return temp file path.

    WDA /screenshot on real devices intermittently returns black screens
    (~40KB for a 1178x2556 image). Real screenshots are typically >100KB.
    This function retries until a non-black screenshot is obtained.
    """
    url = f"{wda_url}/screenshot"
    MIN_VALID_SIZE = 80_000  # black screen ~40KB, real content >100KB

    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                data = json.loads(resp.read())
            img_bytes = base64.b64decode(data["value"])
        except Exception as e:
            if attempt == max_retries:
                print(f"Error: WDA screenshot failed after {max_retries} attempts — {e}", file=sys.stderr)
                print(f"Is WDA running? Check: curl -s {wda_url}/status", file=sys.stderr)
                sys.exit(1)
            import time; time.sleep(1)
            continue

        if len(img_bytes) >= MIN_VALID_SIZE:
            break

        if attempt < max_retries:
            print(f"Screenshot attempt {attempt}: {len(img_bytes)} bytes (likely black screen), retrying...", file=sys.stderr)
            import time; time.sleep(2)
        else:
            print(f"Warning: screenshot may be black ({len(img_bytes)} bytes) after {max_retries} attempts", file=sys.stderr)

    if save_path:
        with open(save_path, "wb") as f:
            f.write(img_bytes)

    # Write to temp file for OCR
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    tmp.write(img_bytes)
    tmp.close()
    return tmp.name


def get_wda_scale_factor(wda_url=DEFAULT_WDA_URL):
    """Detect scale factor from WDA window size vs screenshot resolution."""
    try:
        with urllib.request.urlopen(f"{wda_url}/screenshot", timeout=5) as resp:
            data = json.loads(resp.read())
        img_bytes = base64.b64decode(data["value"])
        # Get pixel dimensions from PNG header (width at bytes 16-19)
        pixel_w = int.from_bytes(img_bytes[16:20], 'big')

        # Get logical window size from WDA
        with urllib.request.urlopen(f"{wda_url}/window/size", timeout=5) as resp:
            win = json.loads(resp.read())
        logical_w = win.get("value", {}).get("width", 0)

        if logical_w > 0:
            return round(pixel_w / logical_w)
    except Exception:
        pass
    return 3  # default @3x for modern iPhones


def ocr_image(image_path, output_json=False, logical=False, scale=None):
    """Run Apple Vision OCR on an image file."""
    try:
        import Vision
        import Quartz
        from Foundation import NSURL
    except ImportError:
        print("Error: pyobjc-framework-Vision not installed.", file=sys.stderr)
        print("Run: pip3 install pyobjc-framework-Vision pyobjc-framework-Quartz", file=sys.stderr)
        sys.exit(1)

    url = NSURL.fileURLWithPath_(image_path)
    source = Quartz.CGImageSourceCreateWithURL(url, None)
    if source is None:
        print(f"Error: cannot open image {image_path}", file=sys.stderr)
        sys.exit(1)

    cg_image = Quartz.CGImageSourceCreateImageAtIndex(source, 0, None)
    img_width = Quartz.CGImageGetWidth(cg_image)
    img_height = Quartz.CGImageGetHeight(cg_image)

    # Configure OCR
    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    request.setRecognitionLanguages_(["zh-Hans", "zh-Hant", "en"])
    request.setUsesLanguageCorrection_(True)

    handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
    success, error = handler.performRequests_error_([request], None)

    if not success:
        print(f"Error: OCR failed — {error}", file=sys.stderr)
        sys.exit(1)

    # Determine coordinate divisor for logical mode
    divisor = 1
    if logical:
        divisor = scale if scale else 3
        coord_label = f"logical @{divisor}x"
    else:
        coord_label = "pixel"

    results = []
    for obs in request.results():
        candidate = obs.topCandidates_(1)[0]
        text = candidate.string()
        confidence = candidate.confidence()

        # Convert normalized bounding box to pixel coordinates
        # Vision uses bottom-left origin, convert to top-left
        box = obs.boundingBox()
        x = int(box.origin.x * img_width) // divisor
        y = int((1 - box.origin.y - box.size.height) * img_height) // divisor
        w = int(box.size.width * img_width) // divisor
        h = int(box.size.height * img_height) // divisor

        results.append({
            "text": text,
            "confidence": round(confidence, 3),
            "bbox": {"x": x, "y": y, "width": w, "height": h},
            "center": {"x": x + w // 2, "y": y + h // 2},
        })

    out_w = img_width // divisor
    out_h = img_height // divisor

    if output_json:
        output = {
            "image_size": {"width": img_width, "height": img_height},
            "text_count": len(results),
            "texts": results,
        }
        if logical:
            output["coordinate_mode"] = "logical"
            output["scale_factor"] = divisor
            output["logical_size"] = {"width": out_w, "height": out_h}
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        size_info = f"{img_width}x{img_height}"
        if logical:
            size_info += f" → {out_w}x{out_h} ({coord_label})"
        print(f"Image: {size_info}, {len(results)} text regions\n")
        for r in results:
            conf = r["confidence"]
            marker = "✓" if conf >= 0.8 else "?" if conf >= 0.5 else "✗"
            print(f"  {marker} [{conf:.2f}] {r['text']}")
            print(f"          @ ({r['bbox']['x']},{r['bbox']['y']}) {r['bbox']['width']}x{r['bbox']['height']}")


def main():
    parser = argparse.ArgumentParser(description="OCR screenshot using Apple Vision")
    parser.add_argument("image", nargs="?", help="Path to image file")
    parser.add_argument("--wda", action="store_true",
                        help=f"Grab screenshot from WDA (default: {DEFAULT_WDA_URL})")
    parser.add_argument("--wda-url", default=DEFAULT_WDA_URL,
                        help="WDA base URL (default: $WDA_URL env var or http://localhost:8100)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--save", metavar="PATH", help="Save WDA screenshot to file")
    parser.add_argument("--logical", action="store_true",
                        help="Output logical point coordinates (auto-detect scale from WDA, fallback @3x)")
    parser.add_argument("--scale", type=int, metavar="N",
                        help="Scale factor for --logical (default: auto-detect)")
    args = parser.parse_args()

    if not args.image and not args.wda:
        parser.print_help()
        sys.exit(1)

    # Auto-detect scale factor from WDA if --logical without explicit --scale
    scale = args.scale
    if args.logical and not scale and args.wda:
        scale = get_wda_scale_factor(args.wda_url)

    if args.wda:
        image_path = fetch_wda_screenshot(save_path=args.save, wda_url=args.wda_url)
        cleanup = True
    else:
        image_path = args.image
        cleanup = False

    try:
        ocr_image(image_path, output_json=args.json, logical=args.logical, scale=scale)
    finally:
        if cleanup and os.path.exists(image_path):
            os.unlink(image_path)


if __name__ == "__main__":
    main()
