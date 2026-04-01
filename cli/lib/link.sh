#!/usr/bin/env bash
# ae link — enable ae-pm or ae-dev in a project

ae_link() {
    if [[ $# -lt 1 ]]; then
        cat <<EOF
${BOLD}ae link${NC} — 在项目中启用 ae-pm 或 ae-dev

${BOLD}USAGE${NC}
    ae link <role> [project_dir]

${BOLD}ROLES${NC}
    pm      启用 PM 工作流（skills + 约束）
    dev     启用 Dev 工作流（skills + 约束）
    both    同时启用 pm + dev

${BOLD}EXAMPLES${NC}
    ae link pm .              # 在当前目录启用 ae-pm
    ae link dev ./MyProject   # 在 MyProject 启用 ae-dev
    ae link both .            # 同时启用
EOF
        exit 0
    fi

    local role="$1"
    local project_dir="${2:-.}"
    project_dir="$(cd "$project_dir" && pwd)"

    case "$role" in
        pm)   _link_role "pm" "$project_dir" ;;
        dev)  _link_role "dev" "$project_dir" ;;
        both)
            _link_role "pm" "$project_dir"
            _link_role "dev" "$project_dir"
            ;;
        *)
            err "未知角色: $role (可选: pm, dev, both)"
            exit 1
            ;;
    esac

    echo ""
    ok "完成！启动你的 AI 编码工具即可使用 AE 能力。"
}

_link_role() {
    local role="$1"
    local project_dir="$2"
    local ae_role_dir="$AE_HOME/$role"

    if [[ ! -d "$ae_role_dir" ]]; then
        err "ae-$role 未安装 ($ae_role_dir)。运行 ${BOLD}ae install${NC} 先安装。"
        exit 1
    fi

    info "在 $project_dir 启用 ae-$role..."

    # 1. Link skills
    local skills_dir="$project_dir/.claude/skills"
    mkdir -p "$skills_dir"

    local linked=0
    for skill_dir in "$ae_role_dir/.claude/skills/"*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local name
        name=$(basename "$skill_dir")
        if [[ -L "$skills_dir/$name" ]]; then
            # Already linked, skip
            continue
        elif [[ -d "$skills_dir/$name" ]]; then
            warn "  $name 已存在（非软链接），跳过"
            continue
        fi
        ln -sf "$skill_dir" "$skills_dir/$name"
        ((linked++))
    done
    ok "  链接了 $linked 个 skills"

    # 2. Add reference to CLAUDE.md if not already present
    local claude_md="$project_dir/CLAUDE.md"
    local marker="~/.ae/$role/CLAUDE.md"

    if [[ -f "$claude_md" ]] && grep -q "$marker" "$claude_md" 2>/dev/null; then
        ok "  CLAUDE.md 已包含 ae-$role 引用"
    else
        echo "" >> "$claude_md"
        echo "## AE $(echo "$role" | tr '[:lower:]' '[:upper:]') 约束" >> "$claude_md"
        echo "请同时遵守 $marker 中的技术选型约束和工作流。" >> "$claude_md"
        ok "  已在 CLAUDE.md 中添加 ae-$role 引用"
    fi
}
