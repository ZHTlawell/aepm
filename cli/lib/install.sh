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

    # ae-go
    _install_clone_or_pull "ae-go" "https://gitee.com/turningsyn/ae-go.git" "$AE_HOME/go"
    _register_global_skills "go"

    # ae-pm
    _install_clone_or_pull "ae-pm" "https://gitee.com/turningsyn/ae-pm.git" "$AE_HOME/pm"
    _register_global_skills "pm"

    # ae-dev
    _install_clone_or_pull "ae-dev" "https://gitee.com/turningsyn/ae-dev.git" "$AE_HOME/dev"
    _register_global_skills "dev"

    # ae-speckit-examples (optional)
    _install_clone_or_pull "ae-speckit-examples" "https://github.com/ligenjian001-ai/ae-speckit-examples.git" "$AE_HOME/speckit-examples" || true

    # Register auto-update hook
    _register_update_hook
}

_install_clone_or_pull() {
    local name="$1"
    local url="$2"
    local dir="$3"

    if [[ -d "$dir/.git" ]]; then
        ok "$name 已安装，更新中..."
        (cd "$dir" && git pull 2>/dev/null) || warn "$name 更新失败（可能无网络）"
    else
        info "克隆 $name..."
        git clone "$url" "$dir" 2>/dev/null || {
            warn "$name 克隆失败。请确认网络和权限。"
        }
    fi
}

# Register ~/.ae/<role>/.claude/skills in Claude Code global settings so
# skills are available in every workspace without per-project ae link.
# Also merges all skill permissions into global allow list so users never
# see permission approval popups for ae skills.
_register_global_skills() {
    local role="$1"
    local skills_dir="$AE_HOME/$role/.claude/skills"

    # Only register if the skills directory exists
    [[ -d "$skills_dir" ]] || return 0

    local settings_file="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"

    local result
    result=$(python3 - "$skills_dir" "$settings_file" <<'PYEOF'
import sys, os, json, re

skills_dir, settings_file = sys.argv[1], sys.argv[2]

settings = {}
if os.path.isfile(settings_file):
    try:
        with open(settings_file) as f:
            settings = json.load(f)
    except:
        pass

perms = settings.setdefault("permissions", {})
changed = False

# 1. Register additionalDirectories
dirs = perms.setdefault("additionalDirectories", [])
if skills_dir not in dirs:
    dirs.append(skills_dir)
    changed = True

# 2. Extract permissions from all SKILL.md frontmatter and merge into allow list
allow = perms.setdefault("allow", [])
added_perms = 0
if os.path.isdir(skills_dir):
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        with open(skill_md) as f:
            content = f.read()
        m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
        if not m:
            continue
        fm = m.group(1)
        in_allow = False
        for line in fm.splitlines():
            if re.match(r'\s+allow:\s*$', line):
                in_allow = True
                continue
            if in_allow:
                pm = re.match(r'\s+-\s+"(.+)"', line)
                if pm:
                    perm = pm.group(1)
                    if perm not in allow:
                        allow.append(perm)
                        added_perms += 1
                elif line.strip() and not line.strip().startswith('-') and not line.strip().startswith('#'):
                    in_allow = False

if added_perms > 0:
    changed = True

if changed:
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")

print(f"{added_perms}")
PYEOF
    ) || return 0

    if [[ "$result" != "0" ]]; then
        ok "  合并了 ${result} 条 skill 权限到全局 settings.json"
    fi
}

# Copy ae-update-check.sh to stable location and register SessionStart hook
# in Claude Code global settings, so updates are checked automatically.
_register_update_hook() {
    # Find the update-check script from any installed role
    local script_src=""
    for role in pm go dev; do
        local candidate="$AE_HOME/$role/scripts/ae-update-check.sh"
        if [[ -f "$candidate" ]]; then
            script_src="$candidate"
            break
        fi
    done

    if [[ -z "$script_src" ]]; then
        return 0
    fi

    # Copy script to stable location
    local target="$HOME/.config/ae/update-check.sh"
    mkdir -p "$HOME/.config/ae"
    cp "$script_src" "$target"
    chmod +x "$target"

    # Register hook in ~/.claude/settings.json
    local settings_file="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"

    local result
    result=$(python3 - "$target" "$settings_file" <<'PYEOF'
import sys, os, json

script_path, settings_file = sys.argv[1], sys.argv[2]

settings = {}
if os.path.isfile(settings_file):
    try:
        with open(settings_file) as f:
            settings = json.load(f)
    except:
        pass

hooks = settings.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [])

# Check if already registered
command = f"bash {script_path}"
already = False
for entry in session_hooks:
    for h in entry.get("hooks", []):
        if h.get("command") == command:
            already = True
            break
    if already:
        break

if not already:
    session_hooks.append({
        "hooks": [{
            "type": "command",
            "command": command,
            "timeout": 15
        }]
    })
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("registered")
else:
    print("exists")
PYEOF
    ) || return 0

    if [[ "$result" == "registered" ]]; then
        ok "  已注册自动更新检查 hook (SessionStart)"
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

    local cred_dir="$HOME/.config/ae"
    local cred_file="$cred_dir/credentials.env"

    # Check new path or legacy path
    if [[ -f "$cred_file" ]] || [[ -f "$HOME/.config/ae-pm/credentials.env" ]]; then
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
