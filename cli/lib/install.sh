#!/usr/bin/env bash
# ae install — install all dependencies

ae_install() {
    local component="${1:-all}"

    info "AE 依赖安装..."
    echo ""

    case "$component" in
        all)
            _install_core
            _install_repos
            _install_ios_deps
            _install_backend_deps
            _setup_credentials
            ;;
        core)    _install_core ;;
        repos)   _install_repos ;;
        ios)     _install_ios_deps ;;
        backend) _install_backend_deps ;;
        creds)   _setup_credentials ;;
        *)
            err "未知组件: $component"
            echo "可选: all, core, repos, ios, backend, creds"
            exit 1
            ;;
    esac

    echo ""
    ok "安装完成。运行 ${BOLD}ae doctor${NC} 检查环境。"
}

_install_core() {
    echo -e "${BOLD}[1/5] 核心工具${NC}"

    # Homebrew
    if ! command -v brew &>/dev/null; then
        info "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        ok "Homebrew 已安装"
    fi

    # Python 3
    if ! command -v python3 &>/dev/null; then
        info "安装 Python 3..."
        brew install python3
    else
        ok "Python 3 已安装"
    fi

    # Git
    if ! command -v git &>/dev/null; then
        info "安装 Git..."
        brew install git
    else
        ok "Git 已安装"
    fi
}

_install_repos() {
    echo -e "${BOLD}[2/5] AE 仓库${NC}"

    mkdir -p "$AE_HOME"

    # ae-pm
    if [[ -d "$AE_HOME/pm/.git" ]]; then
        ok "ae-pm 已安装，更新中..."
        (cd "$AE_HOME/pm" && git pull origin main 2>/dev/null) || warn "ae-pm 更新失败（可能无网络）"
    else
        info "克隆 ae-pm..."
        git clone https://gitee.com/turningsyn/ae-pm.git "$AE_HOME/pm" 2>/dev/null || {
            err "ae-pm 克隆失败。请确认网络和 Gitee 权限。"
        }
    fi

    # ae-dev
    if [[ -d "$AE_HOME/dev/.git" ]]; then
        ok "ae-dev 已安装，更新中..."
        (cd "$AE_HOME/dev" && git pull origin main 2>/dev/null) || warn "ae-dev 更新失败"
    else
        info "克隆 ae-dev..."
        git clone https://gitee.com/turningsyn/ae-dev.git "$AE_HOME/dev" 2>/dev/null || {
            err "ae-dev 克隆失败。请确认网络和 Gitee 权限。"
        }
    fi

    # ae-speckit-examples
    if [[ -d "$AE_HOME/speckit-examples/.git" ]]; then
        ok "ae-speckit-examples 已安装，更新中..."
        (cd "$AE_HOME/speckit-examples" && git pull origin main 2>/dev/null) || warn "ae-speckit-examples 更新失败"
    else
        info "克隆 ae-speckit-examples..."
        git clone https://github.com/ligenjian001-ai/ae-speckit-examples.git "$AE_HOME/speckit-examples" 2>/dev/null || {
            warn "ae-speckit-examples 克隆失败（可选组件，不影响核心功能）"
        }
    fi
}

_install_ios_deps() {
    echo -e "${BOLD}[3/5] iOS 开发依赖${NC}"

    # Xcode check (can't auto-install)
    if ! command -v xcodebuild &>/dev/null; then
        warn "Xcode 未安装。请从 App Store 安装 Xcode，然后运行:"
        echo "      xcode-select --install"
        echo "      sudo xcodebuild -license accept"
    else
        ok "Xcode $(xcodebuild -version 2>/dev/null | head -1)"
    fi

    # AXe CLI
    if ! command -v axe &>/dev/null; then
        info "安装 AXe CLI（iOS 自动化测试工具）..."
        brew tap cameroncooke/axe 2>/dev/null && brew install axe 2>/dev/null || {
            warn "AXe 安装失败。手动安装: brew tap cameroncooke/axe && brew install axe"
        }
    else
        ok "AXe CLI 已安装"
    fi
}

_install_backend_deps() {
    echo -e "${BOLD}[4/5] 后端开发依赖${NC}"

    # Java 17
    if ! java -version 2>&1 | grep -q '"17\|"21'; then
        info "安装 Java 17..."
        brew install openjdk@17 2>/dev/null || {
            warn "Java 17 安装失败。手动安装: brew install openjdk@17"
        }
        # Symlink for system Java
        if [[ -d "$(brew --prefix)/opt/openjdk@17" ]]; then
            sudo ln -sfn "$(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-17.jdk 2>/dev/null || true
        fi
    else
        ok "Java $(java -version 2>&1 | head -1)"
    fi

    # Gradle
    if ! command -v gradle &>/dev/null; then
        info "安装 Gradle..."
        brew install gradle 2>/dev/null || {
            warn "Gradle 安装失败。手动安装: brew install gradle"
        }
    else
        ok "Gradle 已安装"
    fi
}

_setup_credentials() {
    echo -e "${BOLD}[5/5] 凭证配置${NC}"

    local cred_dir="$HOME/.config/ae-pm"
    local cred_file="$cred_dir/credentials.env"

    if [[ -f "$cred_file" ]]; then
        ok "Gitee credentials 已配置"
        return
    fi

    warn "Gitee credentials 未配置"
    echo ""
    echo "  请输入你的 Gitee Personal Access Token"
    echo "  生成地址: https://gitee.com/profile/personal_access_tokens"
    echo "  需要权限: issues, repo"
    echo ""

    read -rp "  Gitee Token (留空跳过): " token

    if [[ -n "$token" ]]; then
        mkdir -p "$cred_dir"
        echo "GITEE_TOKEN=$token" > "$cred_file"
        chmod 600 "$cred_file"
        ok "Token 已保存到 $cred_file"
    else
        warn "跳过。之后手动配置:"
        echo "      mkdir -p $cred_dir"
        echo "      echo 'GITEE_TOKEN=你的token' > $cred_file"
        echo "      chmod 600 $cred_file"
    fi
}
