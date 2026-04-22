#!/usr/bin/env python3
"""Scan an iOS project against the ae-app-review-check kb.

Usage:
  python3 scripts/app-review-scan.py --project-dir /path/to/ios-project \
    [--kb-dir skills/pm/ae-app-review-check] \
    [--output json|markdown|both] \
    [--report-file review-check-report]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERR: pyyaml not installed. Run: pip3 install pyyaml", file=sys.stderr)
    sys.exit(2)


@dataclass
class CheckResult:
    check_id: str
    guideline: str
    chapter: str
    severity: str
    status: str  # pass | fail | warn | skip
    message: str
    evidence: str = ""
    case_refs: list[str] = field(default_factory=list)


def load_cases(cases_file: Path) -> dict[str, dict]:
    cases: dict[str, dict] = {}
    if not cases_file.exists():
        return cases
    with cases_file.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                c = json.loads(line)
                cases[c["id"]] = c
            except (json.JSONDecodeError, KeyError):
                continue
    return cases


def load_kb_entries(kb_root: Path) -> list[dict]:
    entries: list[dict] = []
    for yf in sorted(kb_root.rglob("*.yaml")):
        if yf.name == "SCHEMA.md":
            continue
        try:
            data = yaml.safe_load(yf.read_text())
            if isinstance(data, dict) and "guideline" in data and "auto_checks" in data:
                data["_source_file"] = str(yf)
                entries.append(data)
        except yaml.YAMLError as e:
            print(f"WARN: skip malformed {yf}: {e}", file=sys.stderr)
    return entries


def run_check(chk: dict, project_dir: Path) -> tuple[str, str]:
    """Execute one check. Returns (output, error)."""
    ctype = chk.get("type")
    if ctype == "grep":
        pattern = chk.get("pattern", "")
        include = chk.get("include", "*")
        cmd = [
            "grep", "-rEn", pattern,
            f"--include={include}",
            ".",
        ]
    elif ctype == "file_exists":
        path = chk.get("path", "")
        cmd = ["ls", path]
    elif ctype == "shell":
        cmd = ["bash", "-c", chk.get("command", "")]
    else:
        return "", f"unsupported check type: {ctype}"

    try:
        r = subprocess.run(
            cmd,
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return r.stdout.strip(), r.stderr.strip()
    except subprocess.TimeoutExpired:
        return "", "timeout (30s)"
    except Exception as e:  # noqa: BLE001
        return "", f"exec error: {e}"


def evaluate(chk: dict, out: str) -> tuple[str, str]:
    """Evaluate check output against expected. Returns (status, reason)."""
    expected = chk.get("expected")
    pattern = chk.get("match_pattern")

    if expected == "non_empty":
        return ("pass", "") if out else ("fail", "expected non-empty output")
    if expected == "empty":
        return ("pass", "") if not out else ("fail", f"expected empty, got: {out[:200]}")
    if expected == "match":
        if pattern and pattern in out:
            return ("pass", "")
        return ("fail", f"expected match for {pattern!r}")
    if expected == "no_match":
        if pattern and pattern in out:
            return ("fail", f"unexpected match for {pattern!r}: {out[:200]}")
        return ("pass", "")
    return ("skip", f"unknown expected: {expected}")


def scan(kb_root: Path, project_dir: Path) -> list[CheckResult]:
    entries = load_kb_entries(kb_root / "kb")
    results: list[CheckResult] = []

    for entry in entries:
        guideline = entry["guideline"]
        chapter = entry.get("chapter", "")
        default_sev = entry.get("severity", "medium")
        for chk in entry.get("auto_checks", []):
            cid = chk.get("id", "<unknown>")
            sev = chk.get("severity", default_sev)
            out, err = run_check(chk, project_dir)
            status, reason = evaluate(chk, out)

            if status == "fail":
                status_mapped = "fail" if sev == "high" else "warn"
                msg = chk.get("on_fail", reason)
                evidence = out[:500] if out else reason
            elif status == "pass":
                status_mapped = "pass"
                msg = "OK"
                evidence = ""
            else:
                status_mapped = "skip"
                msg = reason
                evidence = err or ""

            results.append(CheckResult(
                check_id=cid,
                guideline=guideline,
                chapter=chapter,
                severity=sev,
                status=status_mapped,
                message=msg,
                evidence=evidence,
                case_refs=chk.get("case_refs", []) or [],
            ))
    return results


def render_markdown(results: list[CheckResult], cases: dict[str, dict], project_dir: Path) -> str:
    fails = [r for r in results if r.status == "fail"]
    warns = [r for r in results if r.status == "warn"]
    passes = [r for r in results if r.status == "pass"]

    lines = []
    lines.append("═" * 63)
    lines.append(f"  APP REVIEW CHECK — {project_dir.name}")
    lines.append("  kb: ae-app-review-check")
    lines.append("═" * 63)
    lines.append("")
    lines.append(f"SUMMARY: {len(fails)} FAIL / {len(warns)} WARN / {len(passes)} PASS (total {len(results)} checks)")
    lines.append("")

    if fails:
        lines.append("FAIL (must fix, likely to be rejected):")
        for r in fails:
            lines.append(f"  ❌ [{r.guideline}] {r.check_id}")
            lines.append(f"     → {r.message}")
            if r.evidence:
                lines.append(f"     evidence: {r.evidence[:200]}")
            for cid in r.case_refs:
                case = cases.get(cid)
                if case:
                    lines.append(f"     case: {cid} — {case.get('source_url', '')}")
            lines.append("")

    if warns:
        lines.append("WARN (recommend fixing, raises rejection risk):")
        for r in warns:
            lines.append(f"  ⚠️  [{r.guideline}] {r.check_id}")
            lines.append(f"     → {r.message}")
            if r.evidence:
                lines.append(f"     evidence: {r.evidence[:200]}")
            for cid in r.case_refs:
                case = cases.get(cid)
                if case:
                    lines.append(f"     case: {cid} — {case.get('source_url', '')}")
            lines.append("")

    if passes:
        lines.append(f"PASS ({len(passes)}):")
        by_guideline: dict[str, list[str]] = {}
        for r in passes:
            by_guideline.setdefault(r.guideline, []).append(r.check_id)
        for g, ids in sorted(by_guideline.items()):
            lines.append(f"  ✅ [{g}] {len(ids)} check(s) passed")
        lines.append("")

    lines.append("NEXT STEPS:")
    if fails:
        lines.append(f"  1. Fix all {len(fails)} FAIL items")
        lines.append("  2. Re-run: python3 scripts/app-review-scan.py --project-dir <path>")
    elif warns:
        lines.append(f"  1. Review {len(warns)} WARN items")
        lines.append("  2. Address in ASC Review Notes if static fix not possible")
    else:
        lines.append("  All checks passed. Proceed to /ae-asc-submit.")
    lines.append("═" * 63)
    return "\n".join(lines)


def render_json(results: list[CheckResult]) -> str:
    return json.dumps([r.__dict__ for r in results], indent=2, ensure_ascii=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-dir", required=True, help="iOS project root")
    ap.add_argument("--kb-dir", default="skills/pm/ae-app-review-check")
    ap.add_argument("--output", choices=["json", "markdown", "both"], default="markdown")
    ap.add_argument("--report-file", default=None, help="Write report to file (without extension)")
    args = ap.parse_args()

    project_dir = Path(args.project_dir).resolve()
    kb_root = Path(args.kb_dir).resolve()

    if not project_dir.exists():
        print(f"ERR: project-dir not found: {project_dir}", file=sys.stderr)
        return 2
    if not (kb_root / "kb").exists():
        print(f"ERR: kb dir not found: {kb_root}/kb", file=sys.stderr)
        return 2

    cases = load_cases(kb_root / "cases" / "cases.jsonl")
    results = scan(kb_root, project_dir)

    md = render_markdown(results, cases, project_dir)
    j = render_json(results)

    if args.report_file:
        base = Path(args.report_file)
        if args.output in ("markdown", "both"):
            base.with_suffix(".md").write_text(md)
        if args.output in ("json", "both"):
            base.with_suffix(".json").write_text(j)
        print(f"Report written to {base}.{{md,json}}")
    else:
        if args.output in ("markdown", "both"):
            print(md)
        if args.output == "json":
            print(j)

    fails = sum(1 for r in results if r.status == "fail")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
