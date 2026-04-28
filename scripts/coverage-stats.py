#!/usr/bin/env python3
"""Parse feature-checklist.md and output coverage statistics.

Usage:
    # Human-readable output
    python3 coverage-stats.py speckit/feature-checklist.md

    # JSON output (for programmatic use)
    python3 coverage-stats.py speckit/feature-checklist.md --json

    # Check if coverage meets threshold (exit code 1 if not)
    python3 coverage-stats.py speckit/feature-checklist.md --check --core-min 80 --in-app-min 60

Exit codes:
    0 — success (or coverage meets thresholds)
    1 — coverage below thresholds (with --check)
    2 — file not found or parse error
"""

import sys
import argparse
import json
import re

# Status emoji → category mapping
STATUS_MAP = {
    "⬜": "pending",
    "✅": "captured",
    "🔄": "e2e",
    "⛔": "paywall",
    "🔒": "login_required",
}


def parse_checklist(filepath):
    """Parse feature-checklist.md table rows into feature list."""
    try:
        with open(filepath, encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: {filepath} not found", file=sys.stderr)
        sys.exit(2)

    features = []
    in_table = False

    for line in lines:
        line = line.strip()

        # Detect table start (header row with ID column)
        if re.match(r'\|.*ID.*\|.*功能.*\|', line, re.IGNORECASE):
            in_table = True
            continue

        # Skip separator line
        if in_table and re.match(r'\|[-\s|:]+\|$', line):
            continue

        # Parse data row
        if in_table and line.startswith("|"):
            cells = [c.strip() for c in line.split("|")]
            # Remove empty first/last from split
            cells = [c for c in cells if c != ""]

            if len(cells) < 5:
                continue

            feature_id = cells[0]
            name = cells[1]
            source = cells[2] if len(cells) > 2 else ""
            priority = cells[3] if len(cells) > 3 else ""
            status_cell = cells[4] if len(cells) > 4 else "⬜"
            screenshot = cells[5] if len(cells) > 5 else ""
            notes = cells[6] if len(cells) > 6 else ""

            # Detect status from emoji
            status = "pending"
            for emoji, cat in STATUS_MAP.items():
                if emoji in status_cell:
                    status = cat
                    break

            features.append({
                "id": feature_id,
                "name": name,
                "source": source,
                "priority": priority.lower().strip(),
                "status": status,
                "screenshot": screenshot,
                "notes": notes,
            })

        elif in_table and not line.startswith("|"):
            in_table = False

    return features


def compute_stats(features):
    """Compute coverage statistics from parsed features.

    priority="non_functional" rows (about/privacy/terms/help/feedback static doc
    pages, see #IJG5HQ) are excluded from every denominator so PM doesn't see
    them as "uncovered". They are reported separately under `skipped`.
    """
    skipped_features = [f for f in features if f["priority"] == "non_functional"]
    features = [f for f in features if f["priority"] != "non_functional"]

    total = len(features)
    if total == 0 and not skipped_features:
        return {"total": 0, "error": "no features found"}

    by_status = {}
    for f in features:
        by_status[f["status"]] = by_status.get(f["status"], 0) + 1

    covered = by_status.get("captured", 0) + by_status.get("e2e", 0)
    core_features = [f for f in features if f["priority"] == "core"]
    core_total = len(core_features)
    core_covered = sum(1 for f in core_features if f["status"] in ("captured", "e2e"))

    app_store_features = [f for f in features if f["source"] in ("app_store", "")]
    app_store_total = len(app_store_features)
    app_store_covered = sum(1 for f in app_store_features if f["status"] in ("captured", "e2e"))

    in_app_features = [f for f in features if f["source"] == "in_app"]
    in_app_total = len(in_app_features)
    in_app_covered = sum(1 for f in in_app_features if f["status"] in ("captured", "e2e"))

    discovered_features = [f for f in features if f["source"] == "discovered"]
    discovered_total = len(discovered_features)
    discovered_covered = sum(1 for f in discovered_features if f["status"] in ("captured", "e2e"))

    def pct(n, d):
        return round(n / d * 100, 1) if d > 0 else 0

    return {
        "total": total,
        "by_status": {
            "pending": by_status.get("pending", 0),
            "captured": by_status.get("captured", 0),
            "e2e": by_status.get("e2e", 0),
            "paywall": by_status.get("paywall", 0),
            "login_required": by_status.get("login_required", 0),
        },
        "by_source": {
            "app_store": app_store_total,
            "in_app": in_app_total,
            "discovered": discovered_total,
        },
        "overall": {
            "covered": covered,
            "total": total,
            "pct": pct(covered, total),
        },
        "core": {
            "covered": core_covered,
            "total": core_total,
            "pct": pct(core_covered, core_total),
        },
        "app_store": {
            "covered": app_store_covered,
            "total": app_store_total,
            "pct": pct(app_store_covered, app_store_total),
        },
        "in_app": {
            "covered": in_app_covered,
            "total": in_app_total,
            "pct": pct(in_app_covered, in_app_total),
        },
        "discovered": {
            "covered": discovered_covered,
            "total": discovered_total,
            "pct": pct(discovered_covered, discovered_total),
        },
        "skipped": {
            "count": len(skipped_features),
            "items": [{"id": f["id"], "name": f["name"], "notes": f["notes"]}
                      for f in skipped_features],
        },
        "uncovered": [
            {"id": f["id"], "name": f["name"], "status": f["status"], "notes": f["notes"]}
            for f in features if f["status"] in ("pending",)
        ],
    }


def main():
    parser = argparse.ArgumentParser(description="Feature checklist coverage statistics")
    parser.add_argument("checklist", help="Path to feature-checklist.md")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--check", action="store_true", help="Check against thresholds (exit 1 if below)")
    parser.add_argument("--core-min", type=float, default=80, help="Min core coverage %% (default: 80)")
    parser.add_argument("--in-app-min", type=float, default=60, help="Min in-app coverage %% (default: 60)")
    args = parser.parse_args()

    features = parse_checklist(args.checklist)
    stats = compute_stats(features)

    if args.json:
        print(json.dumps(stats, ensure_ascii=False, indent=2))
    else:
        print(f"\n{'='*45}")
        print(f"Feature Coverage Report")
        print(f"{'='*45}")
        print(f"Total features: {stats['total']}")
        print()
        bs = stats["by_status"]
        print(f"  ⬜ Pending:        {bs['pending']}")
        print(f"  ✅ Captured:       {bs['captured']}")
        print(f"  🔄 E2E:            {bs['e2e']}")
        print(f"  ⛔ Paywall:        {bs['paywall']}")
        print(f"  🔒 Login required: {bs['login_required']}")
        print()
        src = stats["by_source"]
        print(f"  Sources: App Store={src['app_store']}, In-app={src['in_app']}, Discovered={src['discovered']}")
        print()
        o = stats["overall"]
        print(f"Overall coverage:    {o['covered']}/{o['total']} ({o['pct']}%)")
        c = stats["core"]
        print(f"Core coverage:       {c['covered']}/{c['total']} ({c['pct']}%)")
        a = stats["app_store"]
        print(f"App Store coverage:  {a['covered']}/{a['total']} ({a['pct']}%)")
        i = stats["in_app"]
        print(f"In-app coverage:     {i['covered']}/{i['total']} ({i['pct']}%)")
        d = stats["discovered"]
        if d["total"] > 0:
            print(f"Discovered coverage: {d['covered']}/{d['total']} ({d['pct']}%)")
        sk = stats.get("skipped", {})
        if sk.get("count", 0) > 0:
            print(f"Skipped (non_functional): {sk['count']} — excluded from denominators")

        if stats["uncovered"]:
            print(f"\nUncovered features ({len(stats['uncovered'])}):")
            for f in stats["uncovered"]:
                note = f" — {f['notes']}" if f["notes"] else ""
                print(f"  {f['id']} {f['name']}{note}")

        print()

    if args.check:
        passed = True
        core_pct = stats["core"]["pct"]
        in_app_pct = stats["in_app"]["pct"]

        if core_pct < args.core_min:
            print(f"FAIL: Core coverage {core_pct}% < {args.core_min}%", file=sys.stderr)
            passed = False
        if stats["in_app"]["total"] > 0 and in_app_pct < args.in_app_min:
            print(f"FAIL: In-app coverage {in_app_pct}% < {args.in_app_min}%", file=sys.stderr)
            passed = False

        if not passed:
            sys.exit(1)
        else:
            if not args.json:
                print("CHECK PASSED ✓")


if __name__ == "__main__":
    main()
