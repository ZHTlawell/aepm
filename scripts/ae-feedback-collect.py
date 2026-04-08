#!/usr/bin/env python3
"""ae-feedback-collect.py — Claude Code PostToolUse hook

Silently captures ae-skill-related tool errors to ~/.ae/<role>/feedback/pending.jsonl.
Runs after every tool call; exits immediately (<50ms) when no error is detected.

Privacy: only records tool name, error snippet, skill context, and version.
Never captures conversation text or file contents.
"""

import sys
import os
import json
import hashlib
import time
from datetime import datetime, timezone

# ── Constants ────────────────────────────────────────────────────────

AE_HOME = os.environ.get("AE_HOME", os.path.expanduser("~/.ae"))
MAX_PENDING_SIZE = 500 * 1024  # 500KB cap
MAX_SNIPPET_LEN = 300
DEDUP_WINDOW_SEC = 86400  # 24h

# Error signal patterns (case-insensitive matching on tool output)
ERROR_PATTERNS = [
    "error:", "Error:", "ERROR",
    "exception", "Exception",
    "traceback", "Traceback",
    "failed", "Failed", "FAILED",
    "not found", "No such file",
    "permission denied", "Permission denied",
    "not installed",
    "timed out", "timeout", "Timeout",
    "command not found",
    "exit code",
    "fatal:", "Fatal:",
    "refused", "REFUSED",
    "429", "rate limit", "Rate limit",
    "500", "502", "503",
]

# Only capture feedback related to ae skills/scripts
AE_CONTEXT_MARKERS = [
    "ae-", "ae_",
    ".ae/", "/ae/",
    "ae update", "ae install", "ae doctor",
    "ae pm", "ae dev", "ae go",
    "wda-start", "wda-cli",
    "ocr-screenshot", "screenshot-save",
    "speckit", "SKILL.md",
]


def main():
    # Read hook input from stdin (Claude Code hook protocol)
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return
        data = json.loads(raw)
    except (json.JSONDecodeError, IOError):
        return

    # Extract tool result from hook payload
    tool_name = data.get("tool_name", "") or ""
    tool_result = data.get("tool_result", "") or ""
    if isinstance(tool_result, dict):
        tool_result = json.dumps(tool_result, ensure_ascii=False)
    tool_input = data.get("tool_input", "") or ""
    if isinstance(tool_input, dict):
        tool_input = json.dumps(tool_input, ensure_ascii=False)

    # Fast path: no error detected → exit immediately
    result_lower = tool_result.lower()
    has_error = False
    matched_pattern = ""
    for pattern in ERROR_PATTERNS:
        if pattern.lower() in result_lower:
            has_error = True
            matched_pattern = pattern
            break

    if not has_error:
        return

    # Check ae-context: is this error related to ae skills/scripts?
    combined_context = f"{tool_name} {tool_input} {tool_result}".lower()
    is_ae_related = any(marker.lower() in combined_context for marker in AE_CONTEXT_MARKERS)
    if not is_ae_related:
        return

    # Determine role from context
    role = _detect_role(combined_context)

    # Build feedback entry
    session_id = data.get("session_id", "unknown")
    error_snippet = _extract_snippet(tool_result, matched_pattern)
    ae_version = _get_ae_version(role)

    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "session_id": session_id[:12] if len(session_id) > 12 else session_id,
        "role": role,
        "signal": "tool_error",
        "tool_name": tool_name,
        "summary": error_snippet[:200],
        "error_snippet": error_snippet,
        "ae_version": ae_version,
    }

    # Dedup check + write
    feedback_dir = os.path.join(AE_HOME, role, "feedback")
    pending_file = os.path.join(feedback_dir, "pending.jsonl")

    # Size cap check
    if os.path.isfile(pending_file) and os.path.getsize(pending_file) >= MAX_PENDING_SIZE:
        return

    # Dedup: hash(session_id + tool_name + snippet[:100])
    dedup_key = hashlib.md5(
        f"{session_id}{tool_name}{error_snippet[:100]}".encode()
    ).hexdigest()[:12]

    if _is_duplicate(pending_file, dedup_key):
        return

    entry["dedup_key"] = dedup_key

    # Write
    os.makedirs(feedback_dir, exist_ok=True)
    try:
        with open(pending_file, "a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except IOError:
        pass


def _detect_role(context: str) -> str:
    """Detect which ae role is active from context clues."""
    if "ae-pm" in context or "/pm/" in context or "ae pm" in context:
        return "pm"
    if "ae-go" in context or "/go/" in context or "ae go" in context:
        return "go"
    if "ae-dev" in context or "/dev/" in context or "ae dev" in context:
        return "dev"
    # Fallback: check which role dirs exist
    for role in ("pm", "go", "dev"):
        if os.path.isdir(os.path.join(AE_HOME, role)):
            return role
    return "pm"


def _extract_snippet(tool_result: str, pattern: str) -> str:
    """Extract the most relevant error snippet around the matched pattern."""
    lower = tool_result.lower()
    idx = lower.find(pattern.lower())
    if idx == -1:
        return tool_result[:MAX_SNIPPET_LEN]

    # Take some context before and after the match
    start = max(0, idx - 50)
    end = min(len(tool_result), idx + MAX_SNIPPET_LEN)
    snippet = tool_result[start:end].strip()

    # Try to align to line boundaries
    lines = snippet.split("\n")
    relevant_lines = []
    for line in lines:
        if any(p.lower() in line.lower() for p in ERROR_PATTERNS):
            relevant_lines.append(line.strip())
    if relevant_lines:
        return "\n".join(relevant_lines[:5])
    return snippet[:MAX_SNIPPET_LEN]


def _get_ae_version(role: str) -> str:
    """Read version from CHANGELOG.md of the role."""
    changelog = os.path.join(AE_HOME, role, "CHANGELOG.md")
    if not os.path.isfile(changelog):
        return "unknown"
    try:
        with open(changelog) as f:
            for line in f:
                if line.startswith("## v"):
                    return line.strip().split()[1].rstrip()
                # Also match "## v0.21.0 (2026-04-08)" style
                import re
                m = re.search(r'v\d+\.\d+\.\d+', line)
                if m:
                    return m.group(0)
    except IOError:
        pass
    return "unknown"


def _is_duplicate(pending_file: str, dedup_key: str) -> bool:
    """Check if same dedup_key exists within the dedup window."""
    if not os.path.isfile(pending_file):
        return False
    cutoff = time.time() - DEDUP_WINDOW_SEC
    try:
        with open(pending_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("dedup_key") == dedup_key:
                    # Check if within dedup window
                    ts = entry.get("ts", "")
                    try:
                        entry_time = datetime.fromisoformat(ts).timestamp()
                        if entry_time > cutoff:
                            return True
                    except (ValueError, TypeError):
                        return True  # Can't parse time, assume recent
    except IOError:
        pass
    return False


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never crash — this is a hook, failures must be silent
        pass
    sys.exit(0)
