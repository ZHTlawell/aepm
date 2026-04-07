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

    # Update ae-cli itself if installed from ae-platform
    if [[ -d "$AE_HOME/cli/.git" ]]; then
        _update_repo "ae-cli" "$AE_HOME/cli" ""
    fi

    # Re-register update hook (picks up latest script version)
    source_lib "install"
    _register_update_hook

    # Clear update cache since we just updated
    rm -f "$HOME/.config/ae/.update-available"

    echo ""
    if $any_updated; then
        ok "更新完成。所有通过软链接挂载的项目自动生效。"
    else
        ok "所有组件已是最新。"
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
