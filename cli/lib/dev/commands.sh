#!/usr/bin/env bash
# ae dev — Dev subcommands (delegates to Claude Code with skills)

ae_dev() {
    if [[ $# -eq 0 ]]; then
        _dev_usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        speckit-receive)  _dev_run_skill "ae-speckit-receive" "$@" ;;
        ios-build)        _dev_run_skill "ae-ios-build-verify" "$@" ;;
        ios-test)         _dev_run_skill "ae-ios-ui-test" "$@" ;;
        backend-build)    _dev_run_skill "ae-backend-build-verify" "$@" ;;
        help|--help|-h)   _dev_usage ;;
        *)
            err "未知 Dev 命令: $cmd"
            _dev_usage
            exit 1
            ;;
    esac
}

_dev_usage() {
    cat <<EOF
${BOLD}ae dev${NC} — Dev 工作流命令

${BOLD}USAGE${NC}
    ae dev <command> [args...]

${BOLD}COMMANDS${NC}
    speckit-receive <speckit_dir>   从 speckit 生成 iOS + 后端项目
    ios-build <project_dir>        iOS 编译验证（xcodebuild loop）
    ios-test <app_path>            iOS UI 自动化测试（AXe + simctl）
    backend-build <project_dir>    后端编译+启动验证（gradle + bootRun + smoke test）

${BOLD}EXAMPLES${NC}
    ae dev speckit-receive ./speckit/ShoeLens
    ae dev ios-build ./ShoeLens-iOS
    ae dev ios-test ./build/ShoeLens.app
    ae dev backend-build ./ShoeLens-backend
EOF
}

_dev_run_skill() {
    local skill_name="$1"
    shift

    local skill_file="$AE_HOME/dev/.claude/skills/${skill_name}/SKILL.md"

    # Check ae-dev is installed
    if [[ ! -d "$AE_HOME/dev" ]]; then
        err "ae-dev 未安装。运行 ${BOLD}ae install${NC} 先安装。"
        exit 1
    fi

    # Check skill exists
    if [[ ! -f "$skill_file" ]]; then
        err "Skill 不存在: $skill_name"
        echo "可用的 Dev skills:"
        for d in "$AE_HOME/dev/.claude/skills/"*/; do
            [[ -f "$d/SKILL.md" ]] && echo "  - $(basename "$d")"
        done
        exit 1
    fi

    # Check if Claude Code is available
    if command -v claude &>/dev/null; then
        info "通过 Claude Code 执行 /${skill_name}..."
        echo ""

        local prompt="请执行 /${skill_name} skill"
        if [[ $# -gt 0 ]]; then
            prompt="$prompt，目标: $*"
        fi

        claude --print "$prompt"
    else
        warn "Claude Code 未安装，显示 skill 内容供手动执行:"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$skill_file"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        info "将上述流程粘贴到你的 AI 编码工具中执行。"
    fi
}
