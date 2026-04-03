#!/usr/bin/env bash
# ae link — enable ae-go / ae-pm / ae-dev in a project
#
# Shared skills (e.g., ae-lark-feishu) exist in every role's build.
# When linking multiple roles, duplicate skills are simply skipped (dedup).

ae_link() {
    if [[ $# -lt 1 ]]; then
        cat <<EOF
${BOLD}ae link${NC} — 在项目中启用 ae-go / ae-pm / ae-dev

${BOLD}USAGE${NC}
    ae link <role> [project_dir]

${BOLD}ROLES${NC}
    go      启用全员通用能力（飞书、issue 等）
    pm      启用 PM 工作流（skills + 约束）
    dev     启用 Dev 工作流（skills + 约束）
    all     同时启用 go + pm + dev

${BOLD}EXAMPLES${NC}
    ae link go .              # 在当前目录启用 ae-go
    ae link pm .              # 在当前目录启用 ae-pm
    ae link dev ./MyProject   # 在 MyProject 启用 ae-dev
    ae link all .             # 同时启用
EOF
        exit 0
    fi

    local role="$1"
    local project_dir="${2:-.}"
    project_dir="$(cd "$project_dir" && pwd)"

    case "$role" in
        go)   _link_role "go" "$project_dir" ;;
        pm)   _link_role "pm" "$project_dir" ;;
        dev)  _link_role "dev" "$project_dir" ;;
        all)
            _link_role "go" "$project_dir"
            _link_role "pm" "$project_dir"
            _link_role "dev" "$project_dir"
            ;;
        *)
            err "未知角色: $role (可选: go, pm, dev, all)"
            exit 1
            ;;
    esac

    echo ""
    ok "完成！启动你的 AI 编码工具即可使用 AE 能力。"
}

# Extract permissions.allow from all SKILL.md frontmatter and merge into
# the project's .claude/settings.local.json so users don't have to manually
# configure allow rules for each skill.
#
# SKILL.md frontmatter format:
#   ---
#   name: ae-app-to-speckit
#   permissions:
#     allow:
#       - "Bash(curl:*)"
#       - "mcp__mobile-mcp__*"
#   ---
#
# Template variable {workdir} is replaced with the actual project directory.
_merge_skill_permissions() {
    local project_dir="$1"
    local ae_role_dir="$2"
    local settings_file="$project_dir/.claude/settings.local.json"

    # Extract permissions from all SKILL.md frontmatter, merge into settings.local.json
    mkdir -p "$project_dir/.claude"
    local added
    added=$(python3 - "$ae_role_dir" "$project_dir" "$settings_file" <<'PYEOF'
import sys, os, yaml, json

ae_role_dir, project_dir, settings_file = sys.argv[1], sys.argv[2], sys.argv[3]
skills_dir = os.path.join(ae_role_dir, ".claude", "skills")

# 1. Collect permissions from all skills
new_perms = []
if os.path.isdir(skills_dir):
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        with open(skill_md) as f:
            content = f.read()
        parts = content.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except:
            continue
        if not isinstance(fm, dict):
            continue
        for p in (fm.get("permissions") or {}).get("allow") or []:
            p = p.replace("{workdir}", project_dir)
            if p not in new_perms:
                new_perms.append(p)

if not new_perms:
    print("0")
    sys.exit(0)

# 2. Merge into settings.local.json
settings = {}
if os.path.isfile(settings_file):
    try:
        with open(settings_file) as f:
            settings = json.load(f)
    except:
        pass

existing = settings.setdefault("permissions", {}).setdefault("allow", [])
added = 0
for p in new_perms:
    if p not in existing:
        existing.append(p)
        added += 1

if added > 0:
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")

print(added)
PYEOF
    ) || return 0

    if [[ "$added" != "0" ]]; then
        ok "  合并了 ${added} 条 skill 权限到 settings.local.json"
    fi
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

    # 1. Link skills (dedup: skip if already exists from any role)
    local skills_dir="$project_dir/.claude/skills"
    mkdir -p "$skills_dir"

    local linked=0
    local skipped=0
    for skill_dir in "$ae_role_dir/.claude/skills/"*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local name
        name=$(basename "$skill_dir")
        if [[ -L "$skills_dir/$name" || -d "$skills_dir/$name" ]]; then
            ((skipped++))
            continue
        fi
        ln -sf "$skill_dir" "$skills_dir/$name"
        ((linked++))
    done
    ok "  链接了 $linked 个 skills$(( skipped > 0 )) && echo -n "，跳过 $skipped 个已存在的" || true"

    # 2. Merge skill permissions into project settings.local.json
    _merge_skill_permissions "$project_dir" "$ae_role_dir"

    # 3. Add reference to CLAUDE.md if not already present
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
