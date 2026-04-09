#!/usr/bin/env bash
set -euo pipefail

# ae-cli installer — curl -sSL <url> | sh
# Installs ae CLI by cloning the first available role package, then symlinking.
#
# Architecture: each role package (ae-pm, ae-go, ae-dev) bundles the full CLI
# at <role>/cli/ae. We clone one role and symlink ~/.ae/bin/ae to its CLI.
# After `ae install`, all roles are cloned and the symlink is refreshed.

AE_HOME="${AE_HOME:-$HOME/.ae}"
AE_BIN="$AE_HOME/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ae-install]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ae-install]${NC} $*"; }
err()   { echo -e "${RED}[ae-install]${NC} $*" >&2; }

echo ""
echo -e "${BOLD}AE CLI Installer${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Migrate from legacy ~/.ae/cli/ clone (v0.24.0 and earlier)
if [[ -d "$AE_HOME/cli/.git" ]]; then
    info "清理旧版 CLI clone (~/.ae/cli/)..."
    rm -rf "$AE_HOME/cli"
fi

# 2. Clone a role package if none exists yet
#    Priority: pm > go > dev (pm has the most complete skill set)
_clone_role() {
    local name="$1" url="$2" dir="$3"
    if [[ -d "$dir/.git" ]]; then
        return 0
    fi
    info "安装 $name..."
    git clone "$url" "$dir" 2>/dev/null || return 1
}

role_cloned=false
for pair in \
    "ae-pm|https://gitee.com/turningsyn/ae-pm.git|$AE_HOME/pm" \
    "ae-go|https://gitee.com/turningsyn/ae-go.git|$AE_HOME/go" \
    "ae-dev|https://gitee.com/turningsyn/ae-dev.git|$AE_HOME/dev"; do
    IFS='|' read -r name url dir <<< "$pair"
    if [[ -d "$dir/.git" ]] || _clone_role "$name" "$url" "$dir"; then
        role_cloned=true
        break
    fi
done

if ! $role_cloned; then
    err "无法克隆任何 role 仓库。可能的原因："
    echo "  1. 网络问题 — 请检查网络连接"
    echo "  2. 没有权限 — 请联系管理员获取 Gitee 仓库访问权限"
    echo ""
    echo "  手动安装:"
    echo "    git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm"
    exit 1
fi

# 3. Create bin/ symlink — find first available role with cli/ae
mkdir -p "$AE_BIN"
linked=false
for role in pm go dev; do
    local_ae="$AE_HOME/$role/cli/ae"
    if [[ -f "$local_ae" ]]; then
        chmod +x "$local_ae"
        ln -sf "$local_ae" "$AE_BIN/ae"
        info "ae 命令已链接到 $local_ae"
        linked=true
        break
    fi
done

if ! $linked; then
    warn "未找到 cli/ae，请运行 ae install 安装完整环境"
fi

# 4. Add to PATH if needed
_add_to_path() {
    local shell_rc="$1"
    local path_line='export PATH="$HOME/.ae/bin:$PATH"'

    if [[ -f "$shell_rc" ]] && grep -q '.ae/bin' "$shell_rc" 2>/dev/null; then
        return
    fi

    echo "" >> "$shell_rc"
    echo "# AE CLI" >> "$shell_rc"
    echo "$path_line" >> "$shell_rc"
    info "已添加 PATH 到 $shell_rc"
}

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    _add_to_path "$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
    _add_to_path "$HOME/.bashrc"
    [[ -f "$HOME/.bash_profile" ]] && _add_to_path "$HOME/.bash_profile"
fi

# 5. Make available in current session
export PATH="$AE_BIN:$PATH"

echo ""
info "安装完成！"
echo ""
echo "  下一步:"
echo "    1. 重启终端 或 运行: export PATH=\"\$HOME/.ae/bin:\$PATH\""
echo "    2. ae install    — 安装所有依赖"
echo "    3. ae doctor     — 检查环境"
echo ""
echo -e "  文档: ${BOLD}ae help${NC}"
echo ""
