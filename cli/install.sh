#!/usr/bin/env bash
set -euo pipefail

# ae-cli installer — curl -sSL <url> | sh
# Installs ae CLI to ~/.ae/cli/ and adds to PATH

AE_HOME="${AE_HOME:-$HOME/.ae}"
AE_CLI_DIR="$AE_HOME/cli"
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

# 1. Clone or update ae-platform (for cli/)
if [[ -d "$AE_CLI_DIR/.git" ]]; then
    info "ae-cli 已存在，更新中..."
    (cd "$AE_CLI_DIR" && git pull origin master 2>/dev/null) || true
else
    info "安装 ae-cli..."
    mkdir -p "$AE_HOME"

    # Clone ae-pm from Gitee (CLI is bundled inside ae-pm)
    git clone --depth 1 https://gitee.com/turningsyn/ae-pm.git "$AE_CLI_DIR" 2>/dev/null || {
        err "克隆失败。可能的原因："
        echo "  1. 网络问题 — 请检查网络连接"
        echo "  2. 没有权限 — 请联系管理员获取 Gitee 仓库访问权限"
        echo ""
        echo "  手动安装:"
        echo "    git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/cli"
        exit 1
    }
fi

# 2. Create bin/ symlink
mkdir -p "$AE_BIN"

# CLI lives at cli/ae inside the ae-pm repo
local_ae="$AE_CLI_DIR/cli/ae"
if [[ -f "$local_ae" ]]; then
    chmod +x "$local_ae"
    ln -sf "$local_ae" "$AE_BIN/ae"
else
    warn "ae 命令未找到，请确认 ae-pm 仓库包含 cli/ 目录"
fi

# 3. Add to PATH if needed
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

# 4. Make available in current session
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
