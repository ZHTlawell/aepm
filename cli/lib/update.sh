#!/usr/bin/env bash
# ae update — pull latest ae-pm, ae-dev, ae-speckit-examples

ae_update() {
    info "更新 AE 组件..."
    echo ""

    local any_updated=false

    _update_repo "ae-go"              "$AE_HOME/go"              "go"
    _update_repo "ae-pm"              "$AE_HOME/pm"              "pm"
    _update_repo "ae-dev"             "$AE_HOME/dev"             "dev"
    _update_repo "ae-speckit-examples" "$AE_HOME/speckit-examples" ""

    # Migrate from legacy ~/.ae/cli/ clone (v0.24.0 and earlier)
    if [[ -d "$AE_HOME/cli/.git" ]]; then
        info "清理旧版 CLI clone (~/.ae/cli/)..."
        rm -rf "$AE_HOME/cli"
    fi

    # Refresh CLI symlink (point to latest role's CLI)
    source_lib "install"
    _refresh_cli_symlink

    # Re-register hooks (picks up latest script versions)
    _register_update_hook
    _register_feedback_hook

    # Clear update cache since we just updated
    rm -f "$HOME/.config/ae/.update-available"

    # Refresh skill symlinks in all linked projects
    # Always run — even without new versions, old projects may have missing symlinks
    _discover_untracked_projects
    _refresh_linked_projects

    # Check for pending feedback and offer to upload
    source_lib "feedback"
    _check_and_upload_feedback

    echo ""
    if $any_updated; then
        ok "更新完成。所有通过软链接挂载的项目自动生效。"
    else
        ok "所有组件已是最新。"
    fi
}

# Scan for projects that have ae-* skill symlinks pointing to ~/.ae/ but
# are not yet tracked in .linked-projects. This catches projects linked
# before the tracking feature was introduced (commit 65fb7f5).
_discover_untracked_projects() {
    local registry="$AE_HOME/.linked-projects"

    # Scan known project directories for .claude/skills/ae-* symlinks
    local search_dirs=("$HOME/Documents/git" "$HOME/git")
    for search_dir in "${search_dirs[@]}"; do
        [[ -d "$search_dir" ]] || continue

        for skills_dir in "$search_dir"/*/.claude/skills; do
            [[ -d "$skills_dir" ]] || continue
            local project_dir
            project_dir=$(dirname "$(dirname "$skills_dir")")

            # Skip ae-pm/ae-go/ae-dev build repos themselves
            case "$project_dir" in
                "$AE_HOME"/pm|"$AE_HOME"/go|"$AE_HOME"/dev) continue ;;
            esac

            # Check which roles this project has symlinks for
            for role in go pm dev; do
                local ae_skills="$AE_HOME/$role/.claude/skills"
                [[ -d "$ae_skills" ]] || continue

                # Look for any symlink pointing to this role's skills
                local has_role=false
                local link
                while IFS= read -r -d '' link; do
                    local target
                    target=$(readlink "$link" 2>/dev/null)
                    if [[ "$target" == "$ae_skills"/* ]]; then
                        has_role=true
                        break
                    fi
                done < <(find "$skills_dir" -maxdepth 1 -name 'ae-*' -type l -print0 2>/dev/null)

                if $has_role; then
                    local entry="$role	$project_dir"
                    if [[ -f "$registry" ]] && grep -qxF "$entry" "$registry" 2>/dev/null; then
                        continue  # already tracked
                    fi
                    echo "$entry" >> "$registry"
                    info "  自动发现已链接项目: ae-$role → $(basename "$project_dir")"
                fi
            done
        done
    done
}

# After ae update pulls new skills, refresh symlinks in all previously
# linked projects so new skills appear without manual re-linking.
_refresh_linked_projects() {
    local registry="$AE_HOME/.linked-projects"
    [[ -f "$registry" ]] || return 0

    source_lib "link"

    local total_new=0
    local total_repaired=0
    local stale_lines=()

    while IFS=$'\t' read -r role project_dir; do
        [[ -z "$role" || -z "$project_dir" ]] && continue

        # Prune stale entries (project no longer exists)
        if [[ ! -d "$project_dir/.claude/skills" ]]; then
            stale_lines+=("$role	$project_dir")
            continue
        fi

        local result
        result=$(_sync_skill_symlinks "$role" "$project_dir")
        local linked repaired
        linked=$(echo "$result" | cut -d' ' -f1)
        repaired=$(echo "$result" | cut -d' ' -f3)
        (( total_new += linked ))
        (( total_repaired += repaired ))
    done < "$registry"

    # Remove stale entries
    if (( ${#stale_lines[@]} > 0 )); then
        for stale in "${stale_lines[@]}"; do
            grep -vxF "$stale" "$registry" > "$registry.tmp" 2>/dev/null && mv "$registry.tmp" "$registry"
        done
    fi

    if (( total_new > 0 || total_repaired > 0 )); then
        local msg="  刷新已链接项目："
        (( total_new > 0 )) && msg="$msg 新增 $total_new 个 skill 链接"
        (( total_repaired > 0 )) && msg="$msg 修复 $total_repaired 个失效链接"
        ok "$msg"
    fi
}

_update_repo() {
    local name="$1"
    local dir="$2"
    local role="${3:-}"

    if [[ ! -d "$dir/.git" ]]; then
        warn "$name 未安装 ($dir)，跳过"
        return
    fi

    local before after branch
    before=$(cd "$dir" && git rev-parse HEAD 2>/dev/null)

    # Detect default branch (main or master)
    branch=$(cd "$dir" && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [[ -z "$branch" ]]; then
        for b in main master; do
            if (cd "$dir" && git show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null); then
                branch="$b"
                break
            fi
        done
    fi
    branch="${branch:-main}"

    # NOTE: User overrides live in project/.claude/overrides/ (not in ~/.ae/),
    # so git pull on ~/.ae/<role>/ does not affect them.
    info "更新 $name..."
    if (cd "$dir" && git pull origin "$branch" 2>/dev/null); then
        after=$(cd "$dir" && git rev-parse HEAD 2>/dev/null)
        if [[ "$before" != "$after" ]]; then
            ok "$name 已更新 (${before:0:7} → ${after:0:7})"
            any_updated=true

            # Re-register skills + permissions for new/updated skills
            if [[ -n "$role" ]]; then
                source_lib "install"
                _register_global_skills "$role"
            fi

            # Show changelog diff if available
            if [[ -f "$dir/CHANGELOG.md" ]]; then
                local changes
                changes=$(cd "$dir" && git log --oneline "$before..$after" -- CHANGELOG.md 2>/dev/null)
                if [[ -n "$changes" ]]; then
                    echo "    更新日志有变更，建议查看: $dir/CHANGELOG.md"
                fi
            fi
        else
            ok "$name 已是最新"
        fi
    else
        warn "$name 更新失败（可能无网络）"
    fi
}
