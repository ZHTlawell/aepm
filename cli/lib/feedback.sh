#!/usr/bin/env bash
# ae feedback — feedback collection management + upload

# Dedicated Gitee issue for collecting automated feedback
FEEDBACK_ISSUE_REPO="ae-platform"
FEEDBACK_ISSUE_NUMBER="II887G"

ae_feedback() {
    local cmd="${1:-}"

    case "$cmd" in
        ""|show)   _feedback_show ;;
        upload)    _feedback_upload ;;
        clear)     _feedback_clear ;;
        help|-h|--help)
            cat <<EOF
${BOLD}ae feedback${NC} — 使用反馈管理

${BOLD}USAGE${NC}
    ae feedback              查看待上传反馈
    ae feedback upload       立即上传（需确认）
    ae feedback clear        清除待上传反馈（不上传）

${BOLD}说明${NC}
    ae 会在使用过程中自动收集 skill 相关的错误信息（工具名、错误片段、版本号）。
    不收集对话内容或文件内容。反馈在 ae update 时提示上传，或通过此命令手动管理。
EOF
            ;;
        *)
            err "未知命令: ae feedback $cmd"
            echo "用法: ae feedback [show|upload|clear]"
            exit 1
            ;;
    esac
}

# Show pending feedback summary
_feedback_show() {
    local has_any=false

    for role in pm go dev; do
        local pending="$AE_HOME/$role/feedback/pending.jsonl"
        [[ -f "$pending" ]] || continue
        local count
        count=$(wc -l < "$pending" 2>/dev/null | tr -d ' ')
        [[ "$count" -gt 0 ]] || continue

        has_any=true
        echo -e "  ${BOLD}ae-${role}${NC}: ${count} 条反馈"

        # Show top entries grouped by tool_name
        python3 - "$pending" <<'PYEOF' 2>/dev/null || true
import json, sys
from collections import Counter

entries = []
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Group by summary (first 80 chars)
counter = Counter()
for e in entries:
    key = e.get("summary", "unknown")[:80]
    counter[key] += 1

for summary, count in counter.most_common(5):
    prefix = f"    ({count}x) " if count > 1 else "    "
    print(f"{prefix}{summary}")
PYEOF
        echo ""
    done

    if ! $has_any; then
        ok "没有待上传的反馈。"
    fi
}

# Upload pending feedback to Gitee issue
_feedback_upload() {
    # Collect all pending entries
    local all_entries=""
    local has_any=false

    for role in pm go dev; do
        local pending="$AE_HOME/$role/feedback/pending.jsonl"
        [[ -f "$pending" ]] || continue
        local count
        count=$(wc -l < "$pending" 2>/dev/null | tr -d ' ')
        [[ "$count" -gt 0 ]] || continue
        has_any=true
    done

    if ! $has_any; then
        ok "没有待上传的反馈。"
        return 0
    fi

    # Show summary first
    echo ""
    info "检测到使用反馈（自动收集，无敏感信息）:"
    echo ""
    _feedback_show

    # Ask for confirmation
    read -rp "  是否上传反馈给 AE Team？(y/n) " confirm
    echo ""

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "已跳过上传。反馈保留在本地，下次 ae update 时再次询问。"
        return 0
    fi

    # Build markdown comment body
    local body
    body=$(_feedback_build_markdown)

    if [[ -z "$body" ]]; then
        warn "未能生成反馈内容。"
        return 1
    fi

    # Post to Gitee via ae-git.py
    info "上传反馈到 Gitee..."

    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"
    if [[ ! -f "$ae_git" ]]; then
        err "ae-git.py 未找到"
        return 1
    fi

    local response
    response=$(python3 "$ae_git" issues comment \
        --repo "$FEEDBACK_ISSUE_REPO" \
        --number "$FEEDBACK_ISSUE_NUMBER" \
        --body "$body" 2>&1) || {
        err "上传失败"
        echo "$response"
        warn "反馈保留在本地，下次再试。"
        return 1
    }

    local comment_id
    comment_id=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

    if [[ -n "$comment_id" ]]; then
        ok "反馈上传成功！"
        echo ""
        echo "  https://e.gitee.com/turningsyn/issues/list?issue=${FEEDBACK_ISSUE_NUMBER}"
        echo ""

        # Archive uploaded entries
        _feedback_archive
    else
        err "上传失败"
        echo "$response"
        warn "反馈保留在本地，下次再试。"
    fi
}

# Clear pending feedback without uploading
_feedback_clear() {
    local cleared=false
    for role in pm go dev; do
        local pending="$AE_HOME/$role/feedback/pending.jsonl"
        if [[ -f "$pending" ]]; then
            rm -f "$pending"
            cleared=true
        fi
    done

    if $cleared; then
        ok "待上传反馈已清除。"
    else
        ok "没有待清除的反馈。"
    fi
}

# Check for pending feedback and prompt upload (called from ae update)
_check_and_upload_feedback() {
    local has_any=false
    for role in pm go dev; do
        local pending="$AE_HOME/$role/feedback/pending.jsonl"
        [[ -f "$pending" ]] || continue
        local count
        count=$(wc -l < "$pending" 2>/dev/null | tr -d ' ')
        [[ "$count" -gt 0 ]] || continue
        has_any=true
        break
    done

    $has_any || return 0

    echo ""
    _feedback_upload
}

# ── Internal helpers ─────────────────────────────────────────────────

## _feedback_load_gitee_token — removed, auth now handled by ae-git.py

# Build a markdown comment body from all pending feedback
_feedback_build_markdown() {
    python3 - "$AE_HOME" <<'PYEOF'
import json, sys, os
from datetime import datetime

ae_home = sys.argv[1]
all_entries = {}

for role in ("pm", "go", "dev"):
    pending = os.path.join(ae_home, role, "feedback", "pending.jsonl")
    if not os.path.isfile(pending):
        continue
    entries = []
    with open(pending) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    if entries:
        all_entries[role] = entries

if not all_entries:
    sys.exit(0)

# Detect user identity (hostname)
import socket
hostname = socket.gethostname()

# Build markdown
lines = []
date_str = datetime.now().strftime("%Y-%m-%d")
lines.append(f"## 自动反馈 — {date_str}")
lines.append(f"")
lines.append(f"来源: `{hostname}`")
lines.append(f"")

for role, entries in sorted(all_entries.items()):
    version = entries[0].get("ae_version", "?") if entries else "?"
    lines.append(f"### ae-{role} {version}")
    lines.append(f"")
    lines.append(f"| 时间 | 工具 | 错误摘要 |")
    lines.append(f"|------|------|----------|")
    for e in entries:
        ts = e.get("ts", "?")
        try:
            t = datetime.fromisoformat(ts)
            ts_short = t.strftime("%m-%d %H:%M")
        except (ValueError, TypeError):
            ts_short = ts[:16]
        tool = e.get("tool_name", "?")
        summary = e.get("summary", "?")[:100].replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {ts_short} | {tool} | {summary} |")
    lines.append(f"")

print("\n".join(lines))
PYEOF
}

# Archive uploaded feedback
_feedback_archive() {
    local date_stamp
    date_stamp=$(date +%Y-%m-%d)

    for role in pm go dev; do
        local pending="$AE_HOME/$role/feedback/pending.jsonl"
        [[ -f "$pending" ]] || continue

        local archive_dir="$AE_HOME/$role/feedback/uploaded"
        mkdir -p "$archive_dir"
        mv "$pending" "$archive_dir/${date_stamp}.jsonl"
    done
}
