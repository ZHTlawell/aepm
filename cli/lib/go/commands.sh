#!/usr/bin/env bash
# ae go — Go (全员) subcommands

ae_go() {
    if [[ $# -eq 0 ]]; then
        _go_usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        submit-bug)         _go_submit_bug "$@" ;;
        submit-requirement) _go_submit_requirement "$@" ;;
        help|--help|-h)     _go_usage ;;
        *)
            err "未知 Go 命令: $cmd"
            _go_usage
            exit 1
            ;;
    esac
}

_go_usage() {
    cat <<EOF
${BOLD}ae go${NC} — 全员通用命令

${BOLD}USAGE${NC}
    ae go <command> [args...]

${BOLD}COMMANDS${NC}
    submit-bug <title> [body]      向 AE Team 提交 bug 报告
    submit-requirement             向 AE Team 提交能力需求

${BOLD}EXAMPLES${NC}
    ae go submit-bug "飞书搜索消息报错"
    ae go submit-requirement
EOF
}

# ── Gitee API helper ──────────────────────────────────────────────

_go_ae_git() {
    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"
    if [[ ! -f "$ae_git" ]]; then
        err "ae-git.py 未找到"
        exit 1
    fi
    python3 "$ae_git" "$@"
}

_go_submit_bug() {
    if [[ $# -lt 1 ]]; then
        err "用法: ae go submit-bug <标题> [正文]"
        exit 1
    fi

    local title="[BUG] $1"
    local body="${2:-}"

    info "正在提交 bug 到 ${BOLD}ae-go${NC} ..."
    local resp
    resp=$(_go_ae_git issues create --repo ae-go --title "$title" --body "$body" 2>&1) || {
        err "提交失败"
        echo "$resp"
        exit 1
    }
    local number
    number=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('number',''))" 2>/dev/null) || number=""
    ok "Issue 已创建: https://e.gitee.com/turningsyn/issues/list?issue=$number"
}

_go_submit_requirement() {
    if [[ $# -lt 1 ]]; then
        err "用法: ae go submit-requirement <标题> [正文]"
        exit 1
    fi

    local title="[FEAT] $1"
    local body="${2:-}"

    info "正在提交需求到 ${BOLD}ae-go${NC} ..."
    local resp
    resp=$(_go_ae_git issues create --repo ae-go --title "$title" --body "$body" 2>&1) || {
        err "提交失败"
        echo "$resp"
        exit 1
    }
    local number
    number=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('number',''))" 2>/dev/null) || number=""
    ok "Issue 已创建: https://e.gitee.com/turningsyn/issues/list?issue=$number"
}
