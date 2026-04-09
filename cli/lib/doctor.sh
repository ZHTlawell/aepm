#!/usr/bin/env bash
# ae doctor — check environment readiness

ae_doctor() {
    local all_ok=true
    local role="${1:-all}"

    info "检查 AE 环境..."
    echo ""

    # ── Core ──
    echo -e "${BOLD}核心环境${NC}"
    _check "git"          "git --version"
    _check "python3"      "python3 --version"
    _check "curl"         "curl --version | head -1"
    _check "AE_HOME 目录" "test -d '$AE_HOME' && echo '$AE_HOME'"
    echo ""

    # ── ae-go ──
    if [[ "$role" == "all" || "$role" == "go" ]]; then
        echo -e "${BOLD}ae-go${NC}"
        _check "ae-go 已安装"      "test -f '$AE_HOME/go/CLAUDE.md' && echo '$AE_HOME/go/'"
        _check "Go skills"         "find '$AE_HOME/go/.claude/skills' -name SKILL.md 2>/dev/null | wc -l | tr -d ' '"
        _check "Gitee credentials" "(test -f '$HOME/.config/ae/credentials.env' || test -f '$HOME/.config/ae-pm/credentials.env') && echo '已配置'"
        _check_gitee_token
        echo ""
    fi

    # ── ae-pm ──
    if [[ "$role" == "all" || "$role" == "pm" ]]; then
        echo -e "${BOLD}ae-pm${NC}"
        _check "ae-pm 已安装"      "test -f '$AE_HOME/pm/CLAUDE.md' && echo '$AE_HOME/pm/'"
        _check "PM skills"         "find '$AE_HOME/pm/.claude/skills' -name SKILL.md 2>/dev/null | wc -l | tr -d ' '"
        _check "Gitee credentials" "(test -f '$HOME/.config/ae/credentials.env' || test -f '$HOME/.config/ae-pm/credentials.env') && echo '已配置'"
        _check_gitee_token
        echo ""
    fi

    # ── ae-dev ──
    if [[ "$role" == "all" || "$role" == "dev" ]]; then
        echo -e "${BOLD}ae-dev${NC}"
        _check "ae-dev 已安装"     "test -f '$AE_HOME/dev/CLAUDE.md' && echo '$AE_HOME/dev/'"
        _check "Dev skills"        "find '$AE_HOME/dev/.claude/skills' -name SKILL.md 2>/dev/null | wc -l | tr -d ' '"
        echo ""

        echo -e "${BOLD}iOS 开发环境${NC}"
        _check "Xcode"            "xcodebuild -version 2>/dev/null | head -1"
        _check "simctl"           "xcrun simctl list devices 2>/dev/null | head -1"
        _check "AXe CLI"          "which axe 2>/dev/null && axe --version 2>/dev/null || echo ''"
        echo ""

        echo -e "${BOLD}后端开发环境${NC}"
        _check "Java 17+"         "java -version 2>&1 | head -1"
        _check "Gradle"           "gradle --version 2>/dev/null | grep 'Gradle' | head -1"
        echo ""
    fi

    # ── AI Tool ──
    echo -e "${BOLD}AI 工具链${NC}"
    _check "Claude Code"   "claude --version 2>/dev/null"
    _check_any "或其他 AI 工具" \
        "codex --version 2>/dev/null" \
        "cursor --version 2>/dev/null"

    # Figma MCP（PM 需要，go 不需要）
    if [[ "$role" == "all" || "$role" == "pm" ]]; then
        if command -v claude &>/dev/null; then
            _check "Figma MCP" "claude mcp list 2>/dev/null | grep -qi figma && echo '已连接'"
        else
            printf "  ${YELLOW}△${NC} %-22s %s\n" "Figma MCP" "跳过（需先安装 Claude Code）"
        fi
    fi

    # Scripts（预处理脚本）
    if [[ "$role" == "all" || "$role" == "pm" ]]; then
        _check "预处理脚本" "test -f '$AE_HOME/pm/scripts/demo-to-figma-prepare.sh' && echo '已就绪 ($(ls \"$AE_HOME/pm/scripts/\"*.sh 2>/dev/null | wc -l | tr -d \" \") 个)'"
    fi

    # CLI
    _check "ae CLI" "test -f '$AE_HOME/pm/cli/ae' && echo '已就绪' || (test -f '$AE_HOME/dev/cli/ae' && echo '已就绪')"
    echo ""

    # ── Summary ──
    if $all_ok; then
        ok "环境就绪 ✓"
    else
        warn "部分依赖缺失，运行 ${BOLD}ae install${NC} 安装"
        return 1
    fi
}

_check() {
    local name="$1"
    local cmd="$2"
    local result
    result=$(eval "$cmd" 2>/dev/null) || result=""

    if [[ -n "$result" ]]; then
        printf "  ${GREEN}✓${NC} %-22s %s\n" "$name" "$result"
    else
        printf "  ${RED}✗${NC} %-22s %s\n" "$name" "未找到"
        all_ok=false
    fi
}

_check_any() {
    local name="$1"
    shift
    for cmd in "$@"; do
        local result
        result=$(eval "$cmd" 2>/dev/null) || result=""
        if [[ -n "$result" ]]; then
            printf "  ${GREEN}✓${NC} %-22s %s\n" "$name" "$result"
            return
        fi
    done
    printf "  ${YELLOW}△${NC} %-22s %s\n" "$name" "未检测到（至少需要一个 AI 编码工具）"
}

_check_gitee_token() {
    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"
    if [[ ! -f "$ae_git" ]]; then
        printf "  ${RED}✗${NC} %-22s %s\n" "Gitee Token" "ae-git.py 未找到"
        all_ok=false
        return
    fi

    # Save and restore proxy vars to avoid side effects on the bash process
    local _saved_http_proxy="${http_proxy:-}" _saved_https_proxy="${https_proxy:-}"

    local resp
    resp=$(python3 "$ae_git" auth validate 2>/dev/null) || resp=""

    # Restore proxy (ae-git.py clears proxy in its subprocess)
    [[ -n "$_saved_http_proxy" ]] && export http_proxy="$_saved_http_proxy"
    [[ -n "$_saved_https_proxy" ]] && export https_proxy="$_saved_https_proxy"

    local valid
    valid=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('valid',False))" 2>/dev/null) || valid="False"

    if [[ "$valid" == "True" ]]; then
        printf "  ${GREEN}✓${NC} %-22s %s\n" "Gitee Token" "有效"
    else
        printf "  ${RED}✗${NC} %-22s %s\n" "Gitee Token" "无效"
        all_ok=false
    fi
}
