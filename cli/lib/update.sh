#!/usr/bin/env bash
# ae update — pull latest ae-pm, ae-dev, ae-speckit-examples

ae_update() {
    info "更新 AE 组件..."
    echo ""

    local any_updated=false

    _update_repo "ae-go"              "$AE_HOME/go"
    _update_repo "ae-pm"              "$AE_HOME/pm"
    _update_repo "ae-dev"             "$AE_HOME/dev"
    _update_repo "ae-speckit-examples" "$AE_HOME/speckit-examples"

    # Update ae-cli itself if installed from ae-platform
    if [[ -d "$AE_HOME/cli/.git" ]]; then
        _update_repo "ae-cli" "$AE_HOME/cli"
    fi

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

    if [[ ! -d "$dir/.git" ]]; then
        warn "$name 未安装 ($dir)，跳过"
        return
    fi

    local before after
    before=$(cd "$dir" && git rev-parse HEAD 2>/dev/null)

    info "更新 $name..."
    if (cd "$dir" && git pull origin main 2>/dev/null); then
        after=$(cd "$dir" && git rev-parse HEAD 2>/dev/null)
        if [[ "$before" != "$after" ]]; then
            ok "$name 已更新 (${before:0:7} → ${after:0:7})"
            any_updated=true

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
