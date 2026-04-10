#!/usr/bin/env bash
# ae setup — one-command full environment setup

ae_setup() {
    local role="${1:-go}"
    local skip_ios=false
    local skip_backend=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            go|pm|dev|all) role="$1"; shift ;;
            --skip-ios)     skip_ios=true; shift ;;
            --skip-backend) skip_backend=true; shift ;;
            --help|-h)
                cat <<EOF
${BOLD}ae setup${NC} — 一键完成环境搭建

${BOLD}USAGE${NC}
    ae setup [role] [options]

${BOLD}ROLES${NC}
    go       全员通用环境（默认）
    pm       PM 环境
    dev      Dev 环境
    all      Go + PM + Dev 全装

${BOLD}OPTIONS${NC}
    --skip-ios       跳过 iOS 依赖（Xcode/AXe）
    --skip-backend   跳过后端依赖（Java/Gradle）

${BOLD}STEPS${NC}
    1. 安装核心依赖（git/python3）
    2. 克隆 ae-pm / ae-dev 仓库
    3. 配置 Gitee Token（交互式）
    4. 安装开发依赖（iOS/后端）
    5. 环境健康检查
    6. 入驻确认（自动发 comment 验证配置）

${BOLD}EXAMPLES${NC}
    ae setup                  # PM 环境一键搭建
    ae setup both             # PM + Dev 全装
    ae setup pm --skip-ios    # PM 环境，跳过 iOS 依赖
EOF
                return 0
                ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${BOLD}AE 环境一键搭建${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  角色: ${BOLD}$role${NC}"
    echo ""

    local total_steps=7
    local step=0

    # ── Step 1: Core deps ─────────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] 核心依赖${NC}"

    _setup_check_or_install "git"     "brew install git"
    _setup_check_or_install "python3" "brew install python3"
    _setup_check_or_install "curl"    ""  # curl is always present on macOS
    echo ""

    # ── Step 2: AI 工具链 ─────────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] AI 工具链（Claude Code + Figma MCP）${NC}"

    # Claude Code
    if command -v claude &>/dev/null; then
        ok "  Claude Code: $(claude --version 2>/dev/null || echo '已安装')"
    else
        warn "  Claude Code 未安装"
        echo "    安装方法: npm install -g @anthropic-ai/claude-code"
        echo "    或参考: https://docs.anthropic.com/en/docs/claude-code"
        if command -v npm &>/dev/null; then
            read -p "    是否现在安装 Claude Code？(y/N) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                npm install -g @anthropic-ai/claude-code && ok "  Claude Code 安装成功" || warn "  安装失败，请手动安装"
            fi
        fi
    fi

    # Playwright MCP（go/pm/all 均需要：ae-web-browse + ae-testflight-publish）
    if command -v claude &>/dev/null; then
        if claude mcp list 2>/dev/null | grep -qi "playwright"; then
            ok "  Playwright MCP: 已连接"
        else
            warn "  Playwright MCP 未连接"
            echo "    连接方法: claude mcp add playwright -s user -- npx @playwright/mcp@latest --browser chrome --user-data-dir ~/.config/playwright-profile"
            read -p "    是否现在连接 Playwright MCP？(y/N) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                claude mcp add playwright -s user -- npx @playwright/mcp@latest --browser chrome --user-data-dir ~/.config/playwright-profile \
                    && ok "  Playwright MCP 连接成功（使用系统 Chrome + 持久化 profile）" \
                    || warn "  连接失败，请手动执行上述命令"
            fi
        fi
    else
        warn "  跳过 Playwright MCP 检查（需先安装 Claude Code）"
    fi

    # Figma MCP（仅 PM 角色需要）
    if [[ "$role" == "pm" || "$role" == "all" ]]; then
        if command -v claude &>/dev/null; then
            if claude mcp list 2>/dev/null | grep -qi "figma"; then
                ok "  Figma MCP: 已连接"
            else
                warn "  Figma MCP 未连接"
                echo "    连接方法: claude mcp add --transport http figma https://mcp.figma.com/mcp"
                read -p "    是否现在连接 Figma MCP？(y/N) " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    claude mcp add --transport http figma https://mcp.figma.com/mcp && ok "  Figma MCP 连接成功（首次使用时会弹出 OAuth 认证）" || warn "  连接失败，请手动执行上述命令"
                fi
            fi
        else
            warn "  跳过 Figma MCP 检查（需先安装 Claude Code）"
        fi
    fi
    echo ""

    # ── Step 3: AE 仓库 ────────────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] AE 仓库${NC}"

    if [[ "$role" == "go" || "$role" == "all" ]]; then
        _setup_clone_or_pull "ae-go" "https://gitee.com/turningsyn/ae-go.git" "$AE_HOME/go"
    fi

    if [[ "$role" == "pm" || "$role" == "all" ]]; then
        _setup_clone_or_pull "ae-pm" "https://gitee.com/turningsyn/ae-pm.git" "$AE_HOME/pm"
    fi

    if [[ "$role" == "dev" || "$role" == "all" ]]; then
        _setup_clone_or_pull "ae-dev" "https://gitee.com/turningsyn/ae-dev.git" "$AE_HOME/dev"
        # speckit-examples (optional, don't fail on error)
        _setup_clone_or_pull "ae-speckit-examples" "https://github.com/ligenjian001-ai/ae-speckit-examples.git" "$AE_HOME/speckit-examples" || true
    fi
    echo ""

    # ── Step 3: Credentials ───────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] Gitee Token 配置${NC}"

    _setup_credentials
    echo ""

    # ── Step 4: Dev deps ──────────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] 开发依赖${NC}"

    if [[ "$role" == "dev" || "$role" == "all" ]]; then
        if ! $skip_ios; then
            _setup_ios_deps
        else
            warn "  跳过 iOS 依赖（--skip-ios）"
        fi
        if ! $skip_backend; then
            _setup_backend_deps
        else
            warn "  跳过后端依赖（--skip-backend）"
        fi
    else
        ok "  $role 角色无需开发依赖"
    fi
    echo ""

    # ── Step 5: Health check ──────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] 环境检查${NC}"

    source_lib "doctor"
    ae_doctor "$role" 2>/dev/null || true
    echo ""

    # ── Step 6: Onboarding ────────────────────────────────────────

    step=$((step + 1))
    echo -e "${BOLD}[$step/$total_steps] 入驻确认${NC}"

    _setup_onboarding
    echo ""

    # ── Done ──────────────────────────────────────────────────────

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ok "环境搭建完成！"
    echo ""
    echo "  下一步："
    echo "    1. 进入你的项目目录"
    echo "    2. 运行 ${BOLD}ae link $role .${NC} 启用 AE 能力"
    echo "    3. 打开 AI 编码工具，开始工作"
    echo ""
}

# ── Helpers ───────────────────────────────────────────────────────

_setup_check_or_install() {
    local cmd="$1"
    local install_cmd="$2"

    if command -v "$cmd" &>/dev/null; then
        ok "  $cmd 已安装"
    elif [[ -n "$install_cmd" ]]; then
        info "  安装 $cmd..."
        eval "$install_cmd" 2>/dev/null || {
            err "  $cmd 安装失败"
            return 1
        }
        ok "  $cmd 安装完成"
    else
        ok "  $cmd 已安装"
    fi
}

_setup_clone_or_pull() {
    local name="$1"
    local url="$2"
    local dir="$3"

    mkdir -p "$(dirname "$dir")"

    if [[ -d "$dir/.git" ]]; then
        ok "  $name 已存在，更新中..."
        (cd "$dir" && git pull origin main 2>/dev/null) || warn "  $name 更新失败（不影响使用）"
    else
        info "  克隆 $name..."
        git clone "$url" "$dir" 2>/dev/null || {
            err "  $name 克隆失败。请确认网络连接。"
            return 1
        }
        ok "  $name 克隆完成"
    fi
}

_setup_credentials() {
    local cred_dir="$HOME/.config/ae"
    local cred_file="$cred_dir/credentials.env"

    # Check new path first, then fallback to legacy
    local existing_cred=""
    for f in "$cred_file" "$HOME/.config/ae-pm/credentials.env"; do
        [[ -f "$f" ]] && existing_cred="$f" && break
    done

    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"

    if [[ -n "$existing_cred" ]]; then
        # Validate existing token
        source "$existing_cred"
        if [[ -n "${GITEE_TOKEN:-}" ]]; then
            local resp
            resp=$(python3 "$ae_git" --token "$GITEE_TOKEN" auth validate 2>/dev/null) || resp=""
            local valid
            valid=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('valid',False))" 2>/dev/null) || valid="False"

            if [[ "$valid" == "True" ]]; then
                ok "  Gitee Token 已配置且有效"
                return 0
            else
                warn "  已有 Token 无效，需要重新配置"
            fi
        fi
    fi

    echo ""
    echo "  需要配置 Gitee Personal Access Token。"
    echo ""
    echo "  步骤："
    echo "    1. 打开 https://gitee.com/profile/personal_access_tokens"
    echo "    2. 创建新 Token，勾选 ${BOLD}issues${NC} 和 ${BOLD}projects${NC} 权限"
    echo "    3. 复制 Token 粘贴到下方"
    echo ""

    local token=""
    while [[ -z "$token" ]]; do
        read -rp "  Gitee Token: " token
        if [[ -z "$token" ]]; then
            warn "  Token 不能为空。如需跳过，按 Ctrl+C 退出。"
        fi
    done

    # Validate before saving
    local resp
    resp=$(python3 "$ae_git" --token "$token" auth validate 2>/dev/null) || resp=""
    local valid
    valid=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('valid',False))" 2>/dev/null) || valid="False"

    if [[ "$valid" != "True" ]]; then
        err "  Token 验证失败。请检查 Token 是否正确。"
        echo "  你可以稍后运行 ${BOLD}ae setup${NC} 重新配置。"
        return 1
    fi

    # Save
    mkdir -p "$cred_dir"
    echo "GITEE_TOKEN=$token" > "$cred_file"
    chmod 600 "$cred_file"
    ok "  Token 验证通过，已保存"

    # Export for subsequent steps
    export GITEE_TOKEN="$token"
}

_setup_ios_deps() {
    if ! command -v xcodebuild &>/dev/null; then
        warn "  Xcode 未安装。请从 App Store 安装 Xcode，然后运行:"
        echo "        xcode-select --install"
        echo "        sudo xcodebuild -license accept"
    else
        ok "  Xcode $(xcodebuild -version 2>/dev/null | head -1)"
    fi

    if ! command -v axe &>/dev/null; then
        info "  安装 AXe CLI..."
        brew tap cameroncooke/axe 2>/dev/null && brew install axe 2>/dev/null || {
            warn "  AXe 安装失败。手动: brew tap cameroncooke/axe && brew install axe"
        }
    else
        ok "  AXe CLI 已安装"
    fi
}

_setup_backend_deps() {
    if ! java -version 2>&1 | grep -q '"17\|"21'; then
        info "  安装 Java 17..."
        brew install openjdk@17 2>/dev/null || {
            warn "  Java 17 安装失败。手动: brew install openjdk@17"
        }
        if [[ -d "$(brew --prefix 2>/dev/null)/opt/openjdk@17" ]]; then
            sudo ln -sfn "$(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk" \
                /Library/Java/JavaVirtualMachines/openjdk-17.jdk 2>/dev/null || true
        fi
    else
        ok "  Java $(java -version 2>&1 | head -1)"
    fi

    if ! command -v gradle &>/dev/null; then
        info "  安装 Gradle..."
        brew install gradle 2>/dev/null || warn "  Gradle 安装失败。手动: brew install gradle"
    else
        ok "  Gradle 已安装"
    fi
}

_setup_onboarding() {
    # Check prerequisites
    if [[ -z "${GITEE_TOKEN:-}" ]]; then
        for f in "$HOME/.config/ae/credentials.env" "$HOME/.config/ae-pm/credentials.env"; do
            if [[ -f "$f" ]]; then source "$f"; break; fi
        done
    fi

    if [[ -z "${GITEE_TOKEN:-}" ]]; then
        warn "  Token 未配置，跳过入驻确认"
        return 0
    fi

    # Get user name from Gitee API
    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"
    local user_info
    user_info=$(python3 "$ae_git" auth user 2>/dev/null) || user_info=""
    local user_name
    user_name=$(echo "$user_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name','') or d.get('login',''))" 2>/dev/null) || user_name=""

    if [[ -z "$user_name" ]]; then
        warn "  无法获取 Gitee 用户名，跳过入驻确认"
        return 0
    fi

    info "  以 ${BOLD}$user_name${NC} 身份完成入驻确认..."

    # Post comment to onboarding issue
    local resp
    resp=$(python3 "$ae_git" issues comment \
        --repo ae-pm --number IHQ4H7 \
        --body "**${user_name}** 已通过 ae setup 完成环境搭建 ✓" 2>/dev/null) || resp=""

    local comment_id
    comment_id=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

    if [[ -n "$comment_id" ]]; then
        ok "  入驻确认成功"
    else
        warn "  入驻确认失败（不影响使用，可稍后重试）"
    fi
}
