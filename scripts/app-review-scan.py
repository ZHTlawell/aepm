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
    rubric_dimension: str | None = None  # D1..D6 | None
    rubric_score_on_pass: int = 3
    rubric_score_on_warn: int = 2
    rubric_score_on_fail: int = 0
    rubric_weight: int = 1
    source_file: str = ""


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
        rubric = entry.get("rubric") or {}
        rdim = rubric.get("dimension")  # D1..D6 | None
        r_pass = int(rubric.get("score_on_pass", 3)) if rdim else 3
        r_warn = int(rubric.get("score_on_warn", 2)) if rdim else 2
        r_fail = int(rubric.get("score_on_fail", 0)) if rdim else 0
        r_weight = int(rubric.get("weight", 1)) if rdim else 1
        source_file = entry.get("_source_file", "")

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
                rubric_dimension=rdim,
                rubric_score_on_pass=r_pass,
                rubric_score_on_warn=r_warn,
                rubric_score_on_fail=r_fail,
                rubric_weight=r_weight,
                source_file=source_file,
            ))
    return results


def compute_rubric_scores(results: list[CheckResult]) -> dict:
    """Aggregate per-dimension scores from check results.

    Returns: {
        "scores": {"D1": 3, "D2": None, ...},   # None = N/A
        "tier": "T1" | "T0" | "BELOW_T0",
        "total": int,
        "dims_with_score": int,
        "details": {"D1": {"checks": [...], "earned": int, "cap": int}, ...}
    }
    """
    DIMS = ["D1", "D2", "D3", "D4", "D5", "D6"]
    by_dim: dict[str, list[CheckResult]] = {d: [] for d in DIMS}
    for r in results:
        if r.rubric_dimension in DIMS:
            by_dim[r.rubric_dimension].append(r)

    scores: dict[str, int | None] = {}
    details: dict[str, dict] = {}

    for dim in DIMS:
        checks = by_dim[dim]
        if not checks:
            scores[dim] = None
            details[dim] = {"checks": [], "earned": 0, "cap": 0, "note": "N/A — 该维度无 kb 条目触发"}
            continue

        # Aggregate per source_file (entry-level rubric: each kb entry contributes once)
        # If any check in an entry FAILed → entry is FAIL. Else if any WARN → WARN. Else PASS.
        by_entry: dict[str, list[CheckResult]] = {}
        for c in checks:
            by_entry.setdefault(c.source_file, []).append(c)

        earned = 0
        cap = 0
        entry_results = []
        for entry_file, entry_checks in by_entry.items():
            statuses = {c.status for c in entry_checks}
            ec = entry_checks[0]  # rubric is entry-level, all share same scores
            cap += ec.rubric_score_on_pass * ec.rubric_weight
            if "fail" in statuses:
                e_status = "fail"
                points = ec.rubric_score_on_fail * ec.rubric_weight
            elif "warn" in statuses:
                e_status = "warn"
                points = ec.rubric_score_on_warn * ec.rubric_weight
            elif statuses == {"skip"}:
                # All checks skipped (e.g., conditional gates not met) → exclude this entry
                cap -= ec.rubric_score_on_pass * ec.rubric_weight
                e_status = "skip"
                points = 0
            else:
                e_status = "pass"
                points = ec.rubric_score_on_pass * ec.rubric_weight
            earned += points
            entry_results.append({
                "file": Path(entry_file).name if entry_file else "?",
                "guideline": entry_checks[0].guideline,
                "status": e_status,
                "points": points,
            })

        if cap == 0:
            scores[dim] = None
            details[dim] = {"checks": entry_results, "earned": 0, "cap": 0, "note": "N/A — 所有相关条目都未触发"}
        else:
            normalized = round(earned / cap * 3)
            scores[dim] = max(0, min(3, normalized))
            details[dim] = {"checks": entry_results, "earned": earned, "cap": cap}

    non_na = [s for s in scores.values() if s is not None]
    total = sum(non_na)
    dims_with_score = len(non_na)
    has_zero = any(s == 0 for s in non_na)

    # Tier judgment
    d1 = scores.get("D1")
    d2 = scores.get("D2")
    if (d1 is not None and d1 < 2) or (d2 is not None and d2 < 2):
        tier = "BELOW_T0"
    elif has_zero:
        tier = "BELOW_T0"
    elif total < 12 or dims_with_score < 2:
        tier = "BELOW_T0"
    elif total >= 16 and dims_with_score >= 4:
        tier = "T1"
    else:
        tier = "T0"

    return {
        "scores": scores,
        "tier": tier,
        "total": total,
        "dims_with_score": dims_with_score,
        "details": details,
    }


DIM_LABELS = {
    "D1": "法务合规",
    "D2": "Privacy Manifest",
    "D3": "模板纯净度",
    "D4": "权限文案语义",
    "D5": "Free 路径完整度",
    "D6": "Paywall 漏斗合规",
}

TIER_BADGE = {
    "T1": "T1 ✅ 可投广基线",
    "T0": "T0 ⚠️ 理论可过审（不到投广线）",
    "BELOW_T0": "BELOW_T0 ❌ 不达上架最低线",
}


def render_rubric_section(rubric: dict) -> list[str]:
    """Render the Rubric scoring block at the top of the markdown report."""
    lines: list[str] = []
    lines.append("📊 RUBRIC 评分（RQ 打样模式 v0）")
    lines.append("─" * 63)
    badge = TIER_BADGE.get(rubric["tier"], rubric["tier"])
    lines.append(f"档位：{badge}")
    lines.append(f"总分：{rubric['total']}/18    有分维度：{rubric['dims_with_score']}/6")
    lines.append("")

    lines.append("| 维度 | 名称 | 得分 | 命中条目 |")
    lines.append("|------|------|------|---------|")
    for dim in ["D1", "D2", "D3", "D4", "D5", "D6"]:
        score = rubric["scores"].get(dim)
        label = DIM_LABELS[dim]
        details = rubric["details"][dim]
        if score is None:
            score_cell = "N/A"
            entries_cell = details.get("note", "")
        else:
            score_cell = f"{score}/3"
            entries = details["checks"]
            parts = []
            for e in entries:
                ico = {"pass": "✅", "warn": "⚠️", "fail": "❌", "skip": "⊘"}.get(e["status"], "?")
                parts.append(f"{ico} {e['guideline']}")
            entries_cell = " · ".join(parts) if parts else "—"
        lines.append(f"| {dim} | {label} | {score_cell} | {entries_cell} |")
    lines.append("")
    lines.append("档位定义：")
    lines.append("  - T0 = D1≥2 AND D2≥2 AND 总分≥12 AND 无任一维度=0")
    lines.append("  - T1 = T0 AND 总分≥16 AND 至少 4 维有分 AND 无任一维度=0")
    lines.append("  - T2 = T1 AND 数据闭环（v1 留空）")
    lines.append("")
    return lines


def render_markdown(results: list[CheckResult], cases: dict[str, dict], project_dir: Path, rubric: dict) -> str:
    fails = [r for r in results if r.status == "fail"]
    warns = [r for r in results if r.status == "warn"]
    passes = [r for r in results if r.status == "pass"]

    lines = []
    lines.append("═" * 63)
    lines.append(f"  APP REVIEW CHECK — {project_dir.name}")
    lines.append("  kb: ae-app-review-check")
    lines.append("═" * 63)
    lines.append("")
    lines.extend(render_rubric_section(rubric))
    lines.append("─" * 63)
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


def render_json(results: list[CheckResult], rubric: dict) -> str:
    return json.dumps(
        {
            "results": [r.__dict__ for r in results],
            "rubric": rubric,
        },
        indent=2,
        ensure_ascii=False,
    )


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
    rubric = compute_rubric_scores(results)

    md = render_markdown(results, cases, project_dir, rubric)
    j = render_json(results, rubric)

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
