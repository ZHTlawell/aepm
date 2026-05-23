#!/usr/bin/env bash
# ae link - enable AE skills in a project

ae_link() {
    if [[ $# -lt 1 ]]; then
        cat <<EOF
${BOLD}ae link${NC} - 在项目中启用 AE 能力

${BOLD}USAGE${NC}
    ae link <role> [project_dir]

${BOLD}ROLES${NC}
    qa      启用 QA 测试入驻与测试工作流
    go      启用通用能力（兼容）
    pm      启用旧版 PM 能力（兼容）
    dev     启用 Dev 能力（兼容）
    all     同时启用 qa + go + pm + dev

${BOLD}EXAMPLES${NC}
    ae link qa .
    ae link all ./MyProject
EOF
        exit 0
    fi

    local role="$1"
    local project_dir="${2:-.}"
    project_dir="$(cd "$project_dir" && pwd)"

    case "$role" in
        qa|go|pm|dev) _link_role "$role" "$project_dir" ;;
        all)
            _link_role "qa" "$project_dir"
            _link_role "go" "$project_dir"
            _link_role "pm" "$project_dir"
            _link_role "dev" "$project_dir"
            ;;
        *)
            err "未知角色: $role (可选: qa, go, pm, dev, all)"
            exit 1
            ;;
    esac

    echo ""
    ok "完成。启动你的 AI 编程工具即可使用 AE 能力。"
}
_role_dir_candidates() {
    local role="$1"
    local repo_root
    repo_root="$(cd "$(dirname "$AE_CLI_DIR")" && pwd)"
    echo "$AE_HOME/$role"
    if [[ "$role" == "qa" ]]; then
        echo "$repo_root"
        echo "$AE_HOME/pm"
    fi
}

_find_role_dir() {
    local role="$1"
    local d
    while IFS= read -r d; do
        [[ -d "$d/.agents/skills" || -d "$d/.claude/skills" ]] && {
            echo "$d"
            return 0
        }
    done < <(_role_dir_candidates "$role")
    return 1
}

_sync_skill_symlinks() {
    local role="$1"
    local role_dir="$2"
    local project_dir="$3"
    local skills_dir="$project_dir/.claude/skills"
    mkdir -p "$skills_dir"

    local source_dir=""
    if [[ -d "$role_dir/.agents/skills" ]]; then
        source_dir="$role_dir/.agents/skills"
    elif [[ -d "$role_dir/.claude/skills" ]]; then
        source_dir="$role_dir/.claude/skills"
    else
        echo "0 0 0"
        return 0
    fi

    local linked=0 skipped=0 repaired=0
    local skill_dir name
    for skill_dir in "$source_dir"/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        name="$(basename "$skill_dir")"
        if [[ "$role" == "qa" && "$name" != ae-qa-* ]]; then
            continue
        fi

        if [[ -L "$skills_dir/$name" && ! -e "$skills_dir/$name" ]]; then
            rm -f "$skills_dir/$name"
            ln -sf "$skill_dir" "$skills_dir/$name"
            ((repaired++))
            continue
        fi

        if [[ -L "$skills_dir/$name" || -d "$skills_dir/$name" ]]; then
            ((skipped++))
            continue
        fi

        ln -sf "$skill_dir" "$skills_dir/$name"
        ((linked++))
    done

    echo "$linked $skipped $repaired"
}

_track_linked_project() {
    local role="$1"
    local project_dir="$2"
    local registry="$AE_HOME/.linked-projects"
    mkdir -p "$AE_HOME"
    local entry="$role	$project_dir"
    if [[ -f "$registry" ]] && grep -qxF "$entry" "$registry" 2>/dev/null; then
        return 0
    fi
    echo "$entry" >> "$registry"
}

_setup_overrides_dir() {
    local project_dir="$1"
    local overrides_dir="$project_dir/.claude/overrides"
    mkdir -p "$overrides_dir"
    if [[ ! -f "$overrides_dir/README.md" ]]; then
        cat > "$overrides_dir/README.md" <<'EOF'
# AE Overrides

本目录中的 `.md` 文件会作为项目级规则被读取，用于覆盖 AE 默认行为。
`ae update` 不会修改本目录。
EOF
    fi
}

_link_role() {
    local role="$1"
    local project_dir="$2"
    local role_dir

    if ! role_dir="$(_find_role_dir "$role")"; then
        warn "ae-$role 未安装或没有 skills，跳过。"
        return 0
    fi

    info "在 $project_dir 启用 ae-$role..."

    local result linked skipped repaired
    result="$(_sync_skill_symlinks "$role" "$role_dir" "$project_dir")"
    linked="$(echo "$result" | cut -d' ' -f1)"
    skipped="$(echo "$result" | cut -d' ' -f2)"
    repaired="$(echo "$result" | cut -d' ' -f3)"
    ok "  链接 ${linked} 个 skills，跳过 ${skipped} 个已存在，修复 ${repaired} 个失效链接"

    _track_linked_project "$role" "$project_dir"
    _setup_overrides_dir "$project_dir"

    local claude_md="$project_dir/CLAUDE.md"
    local marker="AE $(echo "$role" | tr '[:lower:]' '[:upper:]') Agent"
    if [[ ! -f "$claude_md" ]] || ! grep -q "$marker" "$claude_md" 2>/dev/null; then
        {
            echo ""
            echo "## $marker"
            echo "请遵守已链接的 ae-$role skills 和项目级 .claude/overrides/ 规则。"
        } >> "$claude_md"
        ok "  已在 CLAUDE.md 中添加 ae-$role 引用"
    fi
}
