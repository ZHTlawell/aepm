#!/usr/bin/env python3
"""Auto-mask PII in screenshots using Apple Vision OCR.

Usage:
    # Mask all screenshots in a directory using PII config from exploration-state.json
    python3 privacy-mask.py speckit/screenshots/ --pii-config speckit/exploration-state.json

    # Mask with inline PII keywords
    python3 privacy-mask.py speckit/screenshots/ --pii '李根剑,根剑,lgj'

    # Dry run — show what would be masked without modifying files
    python3 privacy-mask.py speckit/screenshots/ --pii '李根剑' --dry-run

    # Also mask fixed regions (e.g., top-right avatar on all pages)
    python3 privacy-mask.py speckit/screenshots/ --pii-config pii.json --avatar-region 330,44,60,60

Requires: pyobjc-framework-Vision, pyobjc-framework-Quartz, Pillow
    pip3 install pyobjc-framework-Vision pyobjc-framework-Quartz Pillow
"""

import sys
import argparse
import json
import os
import re

def ocr_image(image_path):
    """Run Apple Vision OCR, return list of {text, bbox{x,y,width,height}}."""
    import Vision
    import Quartz
    from Foundation import NSURL

    url = NSURL.fileURLWithPath_(image_path)
    source = Quartz.CGImageSourceCreateWithURL(url, None)
    if source is None:
        return [], 0, 0

    cg_image = Quartz.CGImageSourceCreateImageAtIndex(source, 0, None)
    img_width = Quartz.CGImageGetWidth(cg_image)
    img_height = Quartz.CGImageGetHeight(cg_image)

    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    request.setRecognitionLanguages_(["zh-Hans", "zh-Hant", "en"])
    request.setUsesLanguageCorrection_(True)

    handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
    success, error = handler.performRequests_error_([request], None)
    if not success:
        return [], img_width, img_height

    results = []
    for obs in request.results():
        candidate = obs.topCandidates_(1)[0]
        text = candidate.string()
        box = obs.boundingBox()
        x = int(box.origin.x * img_width)
        y = int((1 - box.origin.y - box.size.height) * img_height)
        w = int(box.size.width * img_width)
        h = int(box.size.height * img_height)
        results.append({
            "text": text,
            "bbox": {"x": x, "y": y, "width": w, "height": h},
        })

    return results, img_width, img_height


def load_pii_patterns(pii_config_path=None, pii_inline=None):
    """Load PII keywords from config file or inline string."""
    keywords = []

    if pii_config_path and os.path.exists(pii_config_path):
        with open(pii_config_path) as f:
            data = json.load(f)

        pii = data.get("pii_patterns", {})
        for key in ("name", "name_variants", "device_names", "ids", "emails", "phones"):
            val = pii.get(key)
            if isinstance(val, str):
                keywords.append(val)
            elif isinstance(val, list):
                keywords.extend(val)

    if pii_inline:
        keywords.extend(k.strip() for k in pii_inline.split(",") if k.strip())

    # Deduplicate, sort by length descending (match longer patterns first)
    seen = set()
    unique = []
    for k in keywords:
        if k.lower() not in seen:
            seen.add(k.lower())
            unique.append(k)
    unique.sort(key=len, reverse=True)
    return unique


def apply_mosaic(image, bbox, block_size=15):
    """Apply mosaic (pixelation) to a rectangular region."""
    x, y, w, h = bbox["x"], bbox["y"], bbox["width"], bbox["height"]

    # Add padding around the detected text region
    pad = max(5, int(h * 0.3))
    x1 = max(0, x - pad)
    y1 = max(0, y - pad)
    x2 = min(image.width, x + w + pad)
    y2 = min(image.height, y + h + pad)

    region = image.crop((x1, y1, x2, y2))
    rw, rh = region.size
    if rw <= 0 or rh <= 0:
        return

    # Pixelate: shrink then enlarge
    small = region.resize(
        (max(1, rw // block_size), max(1, rh // block_size)),
        resample=0  # NEAREST
    )
    mosaic = small.resize((rw, rh), resample=0)
    image.paste(mosaic, (x1, y1))


def text_matches_pii(text, pii_keywords):
    """Check if OCR text contains any PII keyword (case-insensitive)."""
    text_lower = text.lower()
    matched = []
    for kw in pii_keywords:
        if kw.lower() in text_lower:
            matched.append(kw)
    return matched


def parse_region(region_str):
    """Parse 'x,y,w,h' string into bbox dict."""
    parts = [int(x.strip()) for x in region_str.split(",")]
    if len(parts) != 4:
        raise ValueError(f"Region must be x,y,w,h — got: {region_str}")
    return {"x": parts[0], "y": parts[1], "width": parts[2], "height": parts[3]}


def process_screenshot(image_path, pii_keywords, fixed_regions=None, dry_run=False):
    """Process a single screenshot. Returns list of masked items."""
    from PIL import Image

    texts, img_w, img_h = ocr_image(image_path)
    if not texts and not fixed_regions:
        return []

    masked_items = []

    # Check each OCR text against PII keywords
    for t in texts:
        matches = text_matches_pii(t["text"], pii_keywords)
        if matches:
            masked_items.append({
                "text": t["text"],
                "matched_keywords": matches,
                "bbox": t["bbox"],
                "type": "pii_text",
            })

    # Add fixed regions
    if fixed_regions:
        for region in fixed_regions:
            masked_items.append({
                "text": "(fixed region)",
                "matched_keywords": [],
                "bbox": region,
                "type": "fixed_region",
            })

    if masked_items and not dry_run:
        image = Image.open(image_path)
        for item in masked_items:
            apply_mosaic(image, item["bbox"])
        image.save(image_path)

    return masked_items


def main():
    parser = argparse.ArgumentParser(
        description="Auto-mask PII in screenshots using Apple Vision OCR"
    )
    parser.add_argument("screenshot_dir", help="Directory containing screenshots (*.png)")
    parser.add_argument("--pii-config", metavar="PATH",
                        help="Path to exploration-state.json with pii_patterns field")
    parser.add_argument("--pii", metavar="KEYWORDS",
                        help="Comma-separated PII keywords (e.g., '李根剑,根剑,lgj')")
    parser.add_argument("--avatar-region", metavar="x,y,w,h", action="append",
                        help="Fixed region to always mask (pixel coords, repeatable)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be masked without modifying files")
    parser.add_argument("--json", action="store_true",
                        help="Output report as JSON")
    args = parser.parse_args()

    if not args.pii_config and not args.pii:
        parser.error("At least one of --pii-config or --pii is required")

    if not os.path.isdir(args.screenshot_dir):
        parser.error(f"Not a directory: {args.screenshot_dir}")

    # Load PII keywords
    pii_keywords = load_pii_patterns(args.pii_config, args.pii)
    if not pii_keywords:
        print("Warning: no PII keywords loaded", file=sys.stderr)

    # Parse fixed regions
    fixed_regions = []
    if args.avatar_region:
        for r in args.avatar_region:
            fixed_regions.append(parse_region(r))

    # Find all PNG files
    png_files = sorted(
        f for f in os.listdir(args.screenshot_dir)
        if f.lower().endswith(".png")
    )

    if not png_files:
        print(f"No PNG files found in {args.screenshot_dir}", file=sys.stderr)
        sys.exit(1)

    # Process each screenshot
    report = {
        "total_screenshots": len(png_files),
        "pii_keywords": pii_keywords,
        "screenshots_with_pii": 0,
        "total_masked_regions": 0,
        "details": [],
    }

    for png in png_files:
        path = os.path.join(args.screenshot_dir, png)
        masked_items = process_screenshot(path, pii_keywords, fixed_regions, args.dry_run)

        if masked_items:
            report["screenshots_with_pii"] += 1
            report["total_masked_regions"] += len(masked_items)
            report["details"].append({
                "file": png,
                "masked_count": len(masked_items),
                "items": [
                    {
                        "text": item["text"],
                        "matched": item["matched_keywords"],
                        "bbox": item["bbox"],
                        "type": item["type"],
                    }
                    for item in masked_items
                ],
            })

    # Output
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        mode = "DRY RUN" if args.dry_run else "MASKED"
        print(f"\n{'='*50}")
        print(f"Privacy Mask Report ({mode})")
        print(f"{'='*50}")
        print(f"PII keywords: {', '.join(pii_keywords)}")
        print(f"Screenshots scanned: {report['total_screenshots']}")
        print(f"Screenshots with PII: {report['screenshots_with_pii']}")
        print(f"Total regions masked: {report['total_masked_regions']}")

        if report["details"]:
            print(f"\nDetails:")
            for d in report["details"]:
                print(f"\n  {d['file']} ({d['masked_count']} regions):")
                for item in d["items"]:
                    if item["type"] == "fixed_region":
                        b = item["bbox"]
                        print(f"    [fixed] ({b['x']},{b['y']}) {b['width']}x{b['height']}")
                    else:
                        print(f"    \"{item['text']}\" → matched: {item['matched']}")
                        b = item["bbox"]
                        print(f"      @ ({b['x']},{b['y']}) {b['width']}x{b['height']}")
        else:
            print("\nNo PII detected in any screenshot. ✓")

        print()


if __name__ == "__main__":
    main()
