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
        product-init)      _qa_product_init "$@" ;;
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

_qa_product_init() {
    local product_dir="${1:-}"
    if [[ -z "$product_dir" || "$product_dir" == "--help" || "$product_dir" == "-h" ]]; then
        cat <<EOF
${BOLD}ae qa product-init${NC} - 初始化一个产品专属 QA Agent

${BOLD}USAGE${NC}
    ae qa product-init <product_dir>

${BOLD}WHAT IT CREATES${NC}
    <product_dir>/.qa-agent.yml
    <product_dir>/qa-onboarding-input/
    <product_dir>/qa/
    <product_dir>/.qa-memory/

${BOLD}NEXT${NC}
    下一步只做一件事：提供第一份产品资料。
    建议优先提供 PRD 或产品截图。
EOF
        return 0
    fi

    mkdir -p "$product_dir"
    product_dir="$(cd "$product_dir" && pwd)"

    local repo_root
    repo_root="$(cd "$(dirname "$AE_CLI_DIR")" && pwd)"

    if [[ ! -f "$product_dir/.qa-agent.yml" ]]; then
        if [[ -f "$repo_root/.qa-agent.example.yml" ]]; then
            cp "$repo_root/.qa-agent.example.yml" "$product_dir/.qa-agent.yml"
        else
            cat > "$product_dir/.qa-agent.yml" <<'EOF'
project:
  name: ""
  type: ""
  default_language: zh-CN
  product_agent_mode: false
  readiness_threshold: 85
output:
  directory: qa
  memory_directory: .qa-memory
issue_provider:
  type: manual
onboarding:
  minimum_score_to_continue: 40
  minimum_score_for_full_cases: 60
  minimum_score_for_product_agent_mode: 85
EOF
        fi
        ok "已创建 $product_dir/.qa-agent.yml"
    else
        ok "$product_dir/.qa-agent.yml 已存在，保留现有配置"
    fi

    mkdir -p \
        "$product_dir/qa-onboarding-input/02-product-screens" \
        "$product_dir/qa-onboarding-input/03-product-docs" \
        "$product_dir/qa-onboarding-input/04-api-docs" \
        "$product_dir/qa-onboarding-input/05-database-docs" \
        "$product_dir/qa-onboarding-input/06-test-cases" \
        "$product_dir/qa-onboarding-input/07-bug-history" \
        "$product_dir/qa-onboarding-input/08-test-reports" \
        "$product_dir/qa-onboarding-input/09-automation" \
        "$product_dir/qa" \
        "$product_dir/.qa-memory"

    [[ -f "$product_dir/qa-onboarding-input/00-project-structure.md" ]] || cat > "$product_dir/qa-onboarding-input/00-project-structure.md" <<'EOF'
# Project Structure

请补充产品源码/项目结构、启动方式、环境地址、账号角色、模块边界。
EOF

    [[ -f "$product_dir/qa-onboarding-input/01-product-overview.md" ]] || cat > "$product_dir/qa-onboarding-input/01-product-overview.md" <<'EOF'
# Product Overview

请补充产品名称、产品类型、目标用户、核心流程和一句话定位。
EOF

    [[ -f "$product_dir/qa-onboarding-input/README.md" ]] || cat > "$product_dir/qa-onboarding-input/README.md" <<'EOF'
# QA Onboarding Input

请把资料放入对应目录：

- 02-product-screens/: 产品图、页面截图、流程图
- 03-product-docs/: PRD、需求文档、验收标准
- 04-api-docs/: 接口文档、错误码、第三方依赖
- 05-database-docs/: 数据库、数据模型、状态流转
- 06-test-cases/: 已有测试用例
- 07-bug-history/: 历史 Bug、线上问题、回归热点
- 08-test-reports/: 历史测试报告、发布结论
- 09-automation/: 自动化脚本、执行说明、覆盖报告

也可以在对话中上传或粘贴资料，由 Agent 帮你归档。
EOF

    ok "已创建 QA 入驻目录结构"
    echo ""
    info "下一步只做一件事：请提供第一份产品资料，建议优先提供 PRD 或产品截图。"
    echo ""

    if command -v claude &>/dev/null; then
        _qa_run_skill "ae-qa-product-init" "$product_dir"
    else
        warn "Claude Code 未安装，已完成本地初始化。"
        info "请回到 AI 对话中提供第一份产品资料；Agent 会继续做资料归档和熟悉度判断。"
    fi
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
