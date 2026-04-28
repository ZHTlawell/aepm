#!/usr/bin/env python3
"""Classify exploration entries before Phase 2a Level 2 fan-out.

Reads a JSON list of {id, label, tab} entries and writes an exploration plan
that tags each entry with one of:

    non_functional_doc → action=skip            (#IJG5HQ)
    media_likely       → action=enter_then_short_stop  (#IJG519)
    functional         → action=explore         (default)

The skill's subagent reads the plan and branches per-entry instead of running
the same "tap → screenshot → return" loop on every sub_entry. This keeps token
budget on real product features and avoids 10-minute audio playback waits.

The classifier is keyword-based on purpose: results are hints, not assertions.
The subagent has authority to override at runtime (e.g. detect-media-player
returns false → degrade enter_then_short_stop to explore).

Usage:
    python3 classify-entries.py --in raw-entries.json --out exploration-plan.json

Input schema (raw-entries.json):
    {"entries": [{"id": "F01", "label": "About", "tab": "Settings"}, ...]}

Output schema (exploration-plan.json):
    {"entries": [{"id": "F01", "label": "About", "tab": "Settings",
                  "tag": "non_functional_doc", "action_hint": "skip",
                  "matched": "About"}, ...],
     "summary": {"non_functional_doc": N, "media_likely": M,
                 "functional": K, "total": T}}
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Optional


# Keywords are matched against the label, normalised (lowercased + collapsed
# whitespace/punctuation). Two match modes:
#   - PHRASES: multi-word, substring (regex \b for English). "Privacy Policy"
#       matches "Privacy Policy" / "App Privacy Policy" alike.
#   - BARE: single short word, requires whole-label exact match (after
#       normalisation). "About" matches a label of just "About" but NOT
#       "About Sleep Quality" — the former is a doc page, the latter a feature.
#
# Across categories, non_functional_doc beats media_likely (a "Privacy" entry
# is a doc page even if some media keyword overlaps).

NON_FUNCTIONAL_PHRASES = [
    # English
    "privacy policy", "terms of use", "terms of service",
    "open source licenses", "open source license",
    "send feedback", "rate us", "rate app", "rate the app", "leave a review",
    "help center", "contact us", "about us",
    # Chinese
    "用户服务协议", "服务条款", "用户协议", "隐私政策", "隐私协议",
    "帮助与支持", "帮助中心", "常见问题", "意见反馈",
    "评价我们", "给我们打分", "5星好评", "5 星好评", "去评分",
    "法律声明", "第三方组件", "开源许可", "开源协议",
    "关于我们", "联系我们",
]

NON_FUNCTIONAL_BARE = [
    # English (whole-label only — these match standalone, never as prefix
    # of a feature name like "About Sleep Quality" or "Helper Bot")
    "privacy", "terms", "help", "support", "feedback",
    "about", "legal", "copyright", "licenses", "eula", "faq",
    "acknowledgements", "contact",
    # Chinese
    "关于", "帮助", "反馈", "版权", "评分", "鸣谢", "致谢",
]

MEDIA_PHRASES = [
    # English
    "sleep story", "sleep music", "sleep sounds", "guided meditation",
    "podcast episode",
    # Chinese
    "睡眠故事", "助眠故事", "助眠音乐", "睡前故事",
    "引导冥想", "播客单集",
]

MEDIA_BARE = [
    # English (whole-label only — drops bare "sleep" / "story" which would
    # mis-tag "Sleep Tracker" / "Story Mode" features)
    "meditation", "mindfulness", "podcast", "episode",
    "audio", "video", "song", "track", "lesson",
    # Chinese
    "助眠", "冥想", "正念", "播客", "单集", "音频", "视频", "曲目", "故事",
]


_HAS_CJK = re.compile(r"[一-鿿]")
# Normalisation for whole-label match: lowercase + strip outer whitespace +
# collapse internal whitespace + strip common decoration chars (>, →, ›, …)
_DECORATION_RE = re.compile(r"[›»→……>»]+")
_WS_RE = re.compile(r"\s+")


def _normalise_label(s: str) -> str:
    s = s.strip().lower()
    s = _DECORATION_RE.sub("", s)
    s = _WS_RE.sub(" ", s)
    return s.strip()


def _phrase_pattern(keyword: str) -> re.Pattern:
    kw = keyword.strip().lower()
    if _HAS_CJK.search(kw):
        return re.compile(re.escape(kw))
    return re.compile(r"\b" + re.escape(kw) + r"\b")


_NON_FUNC_PHRASE_PATTERNS = [(kw, _phrase_pattern(kw)) for kw in NON_FUNCTIONAL_PHRASES]
_MEDIA_PHRASE_PATTERNS = [(kw, _phrase_pattern(kw)) for kw in MEDIA_PHRASES]
_NON_FUNC_BARE_SET = {_normalise_label(kw) for kw in NON_FUNCTIONAL_BARE}
_MEDIA_BARE_SET = {_normalise_label(kw) for kw in MEDIA_BARE}


def _haystack(entry: dict) -> str:
    return (entry.get("label") or entry.get("title") or "").lower()


def _first_phrase_match(text: str, patterns) -> Optional[str]:
    for kw, pat in patterns:
        if pat.search(text):
            return kw
    return None


def classify_entry(entry: dict) -> dict:
    label_raw = entry.get("label") or entry.get("title") or ""
    text = label_raw.lower()
    norm_label = _normalise_label(label_raw)

    if not text:
        return {**entry, "tag": "functional", "action_hint": "explore", "matched": None}

    # 1) non_functional phrases (substring) — highest precedence
    matched = _first_phrase_match(text, _NON_FUNC_PHRASE_PATTERNS)
    if matched:
        return {**entry, "tag": "non_functional_doc", "action_hint": "skip", "matched": matched}

    # 2) non_functional bare (whole-label only)
    if norm_label in _NON_FUNC_BARE_SET:
        return {**entry, "tag": "non_functional_doc", "action_hint": "skip", "matched": norm_label}

    # 3) media phrases (substring)
    matched = _first_phrase_match(text, _MEDIA_PHRASE_PATTERNS)
    if matched:
        return {**entry, "tag": "media_likely",
                "action_hint": "enter_then_short_stop", "matched": matched}

    # 4) media bare (whole-label only)
    if norm_label in _MEDIA_BARE_SET:
        return {**entry, "tag": "media_likely",
                "action_hint": "enter_then_short_stop", "matched": norm_label}

    return {**entry, "tag": "functional", "action_hint": "explore", "matched": None}


def classify_all(entries: list) -> dict:
    classified = [classify_entry(e) for e in entries]
    summary = {"non_functional_doc": 0, "media_likely": 0, "functional": 0,
               "total": len(classified)}
    for c in classified:
        summary[c["tag"]] = summary.get(c["tag"], 0) + 1
    return {"entries": classified, "summary": summary}


def main():
    parser = argparse.ArgumentParser(
        description="Classify exploration entries (#IJG519 / #IJG5HQ).")
    parser.add_argument("--in", dest="input", required=True,
                        help="Path to raw-entries.json")
    parser.add_argument("--out", dest="output", required=True,
                        help="Path to write exploration-plan.json")
    parser.add_argument("--quiet", action="store_true",
                        help="Don't print summary to stderr")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        raw = json.load(f)

    entries = raw.get("entries", raw if isinstance(raw, list) else [])
    if not isinstance(entries, list):
        print(f"error: input.entries must be a list (got {type(entries).__name__})",
              file=sys.stderr)
        sys.exit(1)

    plan = classify_all(entries)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    if not args.quiet:
        s = plan["summary"]
        print(
            f"classified {s['total']} entries → "
            f"non_functional_doc={s['non_functional_doc']}, "
            f"media_likely={s['media_likely']}, "
            f"functional={s['functional']}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
