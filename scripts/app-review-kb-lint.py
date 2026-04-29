#!/usr/bin/env python3
"""Lint app-review-check kb: 校验 YAML 条目格式 + cases.jsonl 去重 + 引用完整性。

Usage:
  python3 scripts/app-review-kb-lint.py [--kb-dir skills/pm/ae-app-review-check]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERR: pyyaml not installed. Run: pip3 install pyyaml", file=sys.stderr)
    sys.exit(2)

REQUIRED_TOP = ["guideline", "chapter", "title", "severity", "official_text", "official_url", "triggers", "auto_checks"]
VALID_SEVERITY = {"high", "medium", "low"}
VALID_CHECK_TYPES = {"grep", "file_exists", "file_content_match", "shell"}
VALID_EXPECTED = {"non_empty", "empty", "match", "no_match"}
VALID_RUBRIC_DIMENSIONS = {"D1", "D2", "D3", "D4", "D5", "D6", None}


def lint_entry(path: Path) -> list[str]:
    errs: list[str] = []
    try:
        with path.open() as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        return [f"{path}: YAML parse error: {e}"]

    if not isinstance(data, dict):
        return [f"{path}: top level is not a dict"]

    for k in REQUIRED_TOP:
        if k not in data:
            errs.append(f"{path}: missing required field '{k}'")

    if data.get("severity") not in VALID_SEVERITY:
        errs.append(f"{path}: severity must be one of {VALID_SEVERITY}, got {data.get('severity')!r}")

    # rubric (optional)
    rubric = data.get("rubric")
    if rubric is not None:
        if not isinstance(rubric, dict):
            errs.append(f"{path}: rubric must be a dict if present")
        else:
            dim = rubric.get("dimension")
            if dim not in VALID_RUBRIC_DIMENSIONS:
                errs.append(f"{path}: rubric.dimension must be one of {VALID_RUBRIC_DIMENSIONS}, got {dim!r}")
            for k in ("score_on_pass", "score_on_warn", "score_on_fail"):
                v = rubric.get(k)
                if v is not None and not (isinstance(v, int) and 0 <= v <= 3):
                    errs.append(f"{path}: rubric.{k} must be int 0..3, got {v!r}")
            w = rubric.get("weight", 1)
            if not (isinstance(w, int) and w >= 1):
                errs.append(f"{path}: rubric.weight must be positive int, got {w!r}")

    checks = data.get("auto_checks", [])
    if not isinstance(checks, list) or not checks:
        errs.append(f"{path}: auto_checks must be a non-empty list")
    else:
        seen_ids: set[str] = set()
        for i, chk in enumerate(checks):
            prefix = f"{path} auto_checks[{i}]"
            if not isinstance(chk, dict):
                errs.append(f"{prefix}: must be a dict")
                continue
            for k in ("id", "type", "expected", "on_fail"):
                if k not in chk:
                    errs.append(f"{prefix}: missing '{k}'")
            if chk.get("type") not in VALID_CHECK_TYPES:
                errs.append(f"{prefix}: type must be one of {VALID_CHECK_TYPES}, got {chk.get('type')!r}")
            if chk.get("expected") not in VALID_EXPECTED:
                errs.append(f"{prefix}: expected must be one of {VALID_EXPECTED}, got {chk.get('expected')!r}")
            cid = chk.get("id")
            if cid in seen_ids:
                errs.append(f"{prefix}: duplicate check id {cid!r}")
            seen_ids.add(cid)
            ctype = chk.get("type")
            if ctype == "grep" and "pattern" not in chk:
                errs.append(f"{prefix}: grep check needs 'pattern'")
            elif ctype == "file_exists" and "path" not in chk:
                errs.append(f"{prefix}: file_exists check needs 'path'")
            elif ctype == "file_content_match" and ("path" not in chk or "pattern" not in chk):
                errs.append(f"{prefix}: file_content_match needs 'path' and 'pattern'")
            elif ctype == "shell" and "command" not in chk:
                errs.append(f"{prefix}: shell check needs 'command'")

    return errs


def lint_cases(cases_file: Path) -> list[str]:
    errs: list[str] = []
    if not cases_file.exists():
        return [f"{cases_file}: file missing"]
    seen_ids: set[str] = set()
    with cases_file.open() as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                errs.append(f"{cases_file}:{lineno}: JSON error: {e}")
                continue
            for k in ("id", "guideline", "source_url", "fix_summary", "recorded_at"):
                if k not in obj:
                    errs.append(f"{cases_file}:{lineno}: missing field {k!r}")
            cid = obj.get("id")
            if cid in seen_ids:
                errs.append(f"{cases_file}:{lineno}: duplicate case id {cid!r}")
            seen_ids.add(cid)
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb-dir", default="skills/pm/ae-app-review-check")
    args = ap.parse_args()

    kb_root = Path(args.kb_dir)
    entries_dir = kb_root / "kb"
    cases_file = kb_root / "cases" / "cases.jsonl"

    if not entries_dir.exists():
        print(f"ERR: kb dir not found: {entries_dir}", file=sys.stderr)
        return 2

    errs: list[str] = []
    yaml_files = sorted(entries_dir.rglob("*.yaml"))
    for yf in yaml_files:
        errs.extend(lint_entry(yf))

    errs.extend(lint_cases(cases_file))

    # referential integrity
    all_case_ids: set[str] = set()
    if cases_file.exists():
        with cases_file.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    all_case_ids.add(json.loads(line).get("id"))
                except json.JSONDecodeError:
                    pass
    for yf in yaml_files:
        try:
            data = yaml.safe_load(yf.read_text()) or {}
        except yaml.YAMLError:
            continue
        refs: set[str] = set(data.get("case_refs", []) or [])
        for chk in data.get("auto_checks", []) or []:
            refs.update(chk.get("case_refs", []) or [])
        missing = refs - all_case_ids
        if missing:
            errs.append(f"{yf}: case_refs not found in cases.jsonl: {sorted(missing)}")

    if errs:
        for e in errs:
            print("FAIL:", e)
        print(f"\n{len(errs)} lint error(s) in {len(yaml_files)} kb entries")
        return 1
    print(f"OK: {len(yaml_files)} kb entries lint clean, {len(all_case_ids)} cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
