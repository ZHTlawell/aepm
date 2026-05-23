#!/usr/bin/env bash
# ae qa - QA onboarding and test workflow commands

ae_qa() {
    if [[ $# -eq 0 ]]; then
        _qa_usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        product-init)      _qa_run_skill "ae-qa-product-init" "$@" ;;
        start)             _qa_run_skill "ae-qa-start" "$@" ;;
        intake-check)      _qa_run_skill "ae-qa-intake-check" "$@" ;;
        onboard)           _qa_run_skill "ae-qa-onboard-project" "$@" ;;
        consistency-check) _qa_run_skill "ae-qa-consistency-check" "$@" ;;
        risk-scan)         _qa_run_skill "ae-qa-risk-scan" "$@" ;;
        generate-cases)    _qa_run_skill "ae-qa-generate-cases" "$@" ;;
        change-impact)     _qa_run_skill "ae-qa-change-impact" "$@" ;;
        file-bugs)         _qa_run_skill "ae-qa-file-bugs" "$@" ;;
        release-check)     _qa_run_skill "ae-qa-release-check" "$@" ;;
        new-module-test)   _qa_run_skill "ae-qa-new-module-test" "$@" ;;
        help|--help|-h)    _qa_usage ;;
        *)
            err "未知 QA 命令: $cmd"
            _qa_usage
            exit 1
            ;;
    esac
}

_qa_usage() {
    cat <<EOF
${BOLD}ae qa${NC} - QA 项目入驻与测试工作流

${BOLD}USAGE${NC}
    ae qa <command> [args...]

${BOLD}COMMANDS${NC}
    product-init <dir>      初始化一个产品专属 QA Agent
    start <dir>              新项目 QA 入驻总入口
    intake-check <dir>       检查项目测试入驻资料完整性
    onboard <dir>            生成产品理解包和 QA Memory
    consistency-check <dir>  检查 PRD / API / DB / 用例 / Bug / 自动化冲突
    risk-scan <dir>          生成风险地图和测试优先级
    generate-cases <dir>     生成分级测试用例
    change-impact <target>   根据 diff / 需求 / 版本说明分析回归范围
    file-bugs <report>       结构化整理并提交缺陷
    release-check <dir>      发布前 Go / No-Go 质量门禁
    new-module-test <target> 新模块测试任务规划

${BOLD}EXAMPLES${NC}
    ae qa product-init ./my-product
    ae qa start ./qa-onboarding-input
    ae qa intake-check ./qa-onboarding-input
    ae qa onboard .
    ae qa risk-scan .
    ae qa generate-cases .
    ae qa change-impact "git diff main...HEAD"
    ae qa release-check .
    ae qa new-module-test ./docs/new-module-prd.md
EOF
}

_qa_find_skill_file() {
    local skill_name="$1"
    local repo_root
    repo_root="$(cd "$(dirname "$AE_CLI_DIR")" && pwd)"

    local candidates=(
        "$AE_HOME/qa/.claude/skills/${skill_name}/SKILL.md"
        "$AE_HOME/qa/.agents/skills/${skill_name}/SKILL.md"
        "$AE_HOME/pm/.claude/skills/${skill_name}/SKILL.md"
        "$AE_HOME/pm/.agents/skills/${skill_name}/SKILL.md"
        "$repo_root/.agents/skills/${skill_name}/SKILL.md"
    )

    local c
    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            echo "$c"
            return 0
        fi
    done

    return 1
}

_qa_run_skill() {
    local skill_name="$1"
    shift

    local skill_file
    if ! skill_file="$(_qa_find_skill_file "$skill_name")"; then
        err "Skill 不存在: $skill_name"
        echo "请确认 ae-qa 已安装，或当前仓库包含 .agents/skills/${skill_name}/SKILL.md"
        exit 1
    fi

    if command -v claude &>/dev/null; then
        info "通过 Claude Code 执行 /${skill_name}..."
        echo ""
        local prompt="请执行 /${skill_name} skill"
        if [[ $# -gt 0 ]]; then
            prompt="$prompt，目标：$*"
        fi
        claude --print "$prompt"
    else
        warn "Claude Code 未安装，显示 skill 内容供手动执行"
        echo ""
        cat "$skill_file"
    fi
}
