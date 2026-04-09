#!/usr/bin/env bash
# ae manifest — generate and display manifest.yml (capability registry)

ae_manifest() {
    local subcmd="${1:-}"
    local role="${2:-}"

    case "$subcmd" in
        generate)
            [[ -z "$role" ]] && err "用法: ae manifest generate <role>" && return 1
            local script="$(dirname "$AE_CLI_DIR")/scripts/generate-manifest.sh"
            if [[ ! -f "$script" ]]; then
                # Fallback: try resolving from AE_HOME
                script="$AE_HOME/$role/scripts/generate-manifest.sh"
            fi
            if [[ ! -f "$script" ]]; then
                err "generate-manifest.sh 未找到"
                return 1
            fi
            bash "$script" "$role" "$AE_HOME/$role/manifest.yml"
            ok "manifest.yml 已生成: $AE_HOME/$role/manifest.yml"
            ;;
        show)
            [[ -z "$role" ]] && err "用法: ae manifest show <role>" && return 1
            local manifest="$AE_HOME/$role/manifest.yml"
            if [[ ! -f "$manifest" ]]; then
                err "manifest.yml 不存在，运行: ae manifest generate $role"
                return 1
            fi
            cat "$manifest"
            ;;
        *)
            err "用法: ae manifest <generate|show> <role>"
            return 1
            ;;
    esac
}
