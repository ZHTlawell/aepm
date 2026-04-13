#!/usr/bin/env bash
# ae doctor — check environment readiness

ae_doctor() {
    local all_ok=true
    local role="${1:-all}"

    # 确保 Homebrew 在 PATH 中（macOS arm64）
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
    fi

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

    # ── Skill Dependencies ──
    if [[ "$role" == "all" ]]; then
        for _role in pm go dev; do
            local _skill_dir="$AE_HOME/$_role/.claude/skills"
            if [[ -d "$_skill_dir" ]]; then
                _check_skill_dependencies "$_role" && true
            fi
        done
    else
        local _skill_dir="$AE_HOME/$role/.claude/skills"
        if [[ -d "$_skill_dir" ]]; then
            _check_skill_dependencies "$role" && true
        fi
    fi

    # ── User Overrides ──
    local overrides_dir="$PWD/.claude/overrides"
    if [[ -d "$overrides_dir" ]]; then
        local override_count
        override_count=$(find "$overrides_dir" -name "*.md" ! -name "README.md" | wc -l | tr -d ' ')
        if [[ "$override_count" -gt 0 ]]; then
            printf "\n${BOLD}User Overrides${NC}\n"
            echo "──────────────────"
            find "$overrides_dir" -name "*.md" ! -name "README.md" -exec basename {} \; | while read f; do
                printf "  %s %s\n" "📝" "$f"
            done
            echo ""
        fi
    fi

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

# ── Skill Dependency Checker ──
# Parse SKILL.md frontmatter dependencies and verify each one
_check_skill_dependencies() {
    local role="$1"
    local skill_dir="$AE_HOME/$role/.claude/skills"
    local header_printed=false
    local any_fail=false

    # Collect all SKILL.md files
    local skill_files=()
    while IFS= read -r -d '' f; do
        skill_files+=("$f")
    done < <(find "$skill_dir" -maxdepth 2 -name SKILL.md -print0 2>/dev/null | sort -z)

    [[ ${#skill_files[@]} -eq 0 ]] && return 0

    for skill_file in "${skill_files[@]}"; do
        # Extract skill name from path: .../skills/<name>/SKILL.md
        local skill_name
        skill_name=$(basename "$(dirname "$skill_file")")

        # Use Python to parse YAML frontmatter and extract dependencies as JSON
        local deps_json
        deps_json=$(python3 -c "
import sys, json, re

try:
    with open(sys.argv[1], 'r') as f:
        content = f.read()
except Exception:
    print('{}')
    sys.exit(0)

# Extract YAML frontmatter between --- markers
m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
if not m:
    print('{}')
    sys.exit(0)

fm_text = m.group(1)

# Try PyYAML first, fall back to manual parsing
deps = {}
try:
    import yaml
    fm = yaml.safe_load(fm_text)
    if isinstance(fm, dict) and 'dependencies' in fm:
        deps = fm['dependencies']
        if not isinstance(deps, dict):
            deps = {}
except ImportError:
    # Manual parsing for simple YAML structure
    in_deps = False
    current_key = None
    for line in fm_text.split('\n'):
        stripped = line.strip()
        if stripped == '' or stripped.startswith('#'):
            continue
        # Top-level key
        if not line.startswith(' ') and not line.startswith('\t'):
            if stripped == 'dependencies:':
                in_deps = True
                continue
            elif in_deps:
                break  # Left dependencies block
            continue
        if not in_deps:
            continue
        # Second-level key (mcp:, cli:, api_keys:, scripts:)
        indent = len(line) - len(line.lstrip())
        if indent <= 4 and stripped.endswith(':') and not stripped.startswith('-'):
            current_key = stripped[:-1].strip()
            deps[current_key] = []
            continue
        # List items
        if current_key and stripped.startswith('-'):
            val = stripped[1:].strip()
            # Handle name: / verify: dict items for cli
            if current_key == 'cli' and val.startswith('name:'):
                # Start a new dict entry
                entry = {'name': val.split(':', 1)[1].strip().strip('\"').strip(\"'\")}
                deps[current_key].append(entry)
            elif current_key == 'cli' and isinstance(deps[current_key], list) and len(deps[current_key]) > 0 and isinstance(deps[current_key][-1], dict):
                # This might be a simple string item
                deps[current_key].append(val.strip('\"').strip(\"'\"))
            else:
                deps[current_key].append(val.strip('\"').strip(\"'\"))
            continue
        # Indented key-value under a list item (e.g., verify:)
        if current_key == 'cli' and 'verify:' in stripped:
            if deps[current_key] and isinstance(deps[current_key][-1], dict):
                verify_val = stripped.split('verify:', 1)[1].strip().strip('\"').strip(\"'\")
                deps[current_key][-1]['verify'] = verify_val
except Exception:
    deps = {}

print(json.dumps(deps))
" "$skill_file" 2>/dev/null) || deps_json="{}"

        # Skip if no dependencies
        [[ "$deps_json" == "{}" ]] && continue

        # Print section header once
        if ! $header_printed; then
            echo -e "${BOLD}Skill Dependencies ($role)${NC}"
            echo -e "──────────────────"
            header_printed=true
        fi

        echo -e "  ${BOLD}${skill_name}${NC}:"

        # Parse and check each dependency type using Python
        eval "$(python3 -c "
import json, sys, os, subprocess, shlex

deps = json.loads(sys.argv[1])
role = sys.argv[2]
ae_home = os.environ.get('AE_HOME', os.path.expanduser('~/.ae'))

lines = []

# --- MCP dependencies ---
for item in deps.get('mcp', []):
    name = item if isinstance(item, str) else item.get('name', str(item))
    lines.append(('mcp', name, '', ''))

# --- CLI dependencies ---
for item in deps.get('cli', []):
    if isinstance(item, dict):
        name = item.get('name', '')
        verify = item.get('verify', '')
    else:
        name = str(item)
        verify = name + ' --version'
    lines.append(('cli', name, verify, ''))

# --- API key dependencies ---
for item in deps.get('api_keys', []):
    name = item if isinstance(item, str) else str(item)
    lines.append(('api_key', name, '', ''))

# --- Script dependencies ---
for item in deps.get('scripts', []):
    name = item if isinstance(item, str) else str(item)
    lines.append(('script', name, '', ''))

# Output as shell commands
for dtype, name, verify, _ in lines:
    # Escape for shell
    name_esc = name.replace(\"'\", \"'\\\"'\\\"'\")
    verify_esc = verify.replace(\"'\", \"'\\\"'\\\"'\")
    print(f\"_check_dep '{dtype}' '{name_esc}' '{verify_esc}' '{role}'\")
" "$deps_json" "$role" 2>/dev/null)"

    done

    if $header_printed; then
        echo ""
    fi

    if $any_fail; then
        all_ok=false
    fi
}

# Check a single dependency item
# Usage: _check_dep <type> <name> <verify_cmd> <role>
_check_dep() {
    local dtype="$1"
    local name="$2"
    local verify_cmd="$3"
    local role="$4"

    case "$dtype" in
        mcp)
            # Check if MCP server is configured in ~/.claude.json or ~/.claude/settings.json
            local mcp_found=false
            for cfg in "$HOME/.claude.json" "$HOME/.claude/settings.json"; do
                if [[ -f "$cfg" ]]; then
                    if python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
servers = d.get('mcpServers', {})
sys.exit(0 if sys.argv[2] in servers else 1)
" "$cfg" "$name" 2>/dev/null; then
                        mcp_found=true
                        break
                    fi
                fi
            done
            if $mcp_found; then
                printf "    ${GREEN}✅${NC} MCP: %s\n" "$name"
            else
                printf "    ${RED}❌${NC} MCP: %s — not configured in ~/.claude.json\n" "$name"
                any_fail=true
            fi
            ;;
        cli)
            local result
            result=$(eval "$verify_cmd" 2>&1) || result=""
            if [[ -n "$result" ]]; then
                printf "    ${GREEN}✅${NC} CLI: %s (%s)\n" "$name" "$verify_cmd"
            else
                printf "    ${RED}❌${NC} CLI: %s (%s) — not found\n" "$name" "$verify_cmd"
                any_fail=true
            fi
            ;;
        api_key)
            # Check environment variable and credentials files
            local key_found=false
            if [[ -n "${!name:-}" ]]; then
                key_found=true
            else
                for cred_file in "$HOME/.config/ae/credentials.env" "$HOME/.config/ae-pm/credentials.env"; do
                    if [[ -f "$cred_file" ]] && grep -q "^${name}=" "$cred_file" 2>/dev/null; then
                        key_found=true
                        break
                    fi
                done
            fi
            if $key_found; then
                printf "    ${GREEN}✅${NC} API Key: %s\n" "$name"
            else
                printf "    ${RED}❌${NC} API Key: %s — not set\n" "$name"
                any_fail=true
            fi
            ;;
        script)
            local script_path="$AE_HOME/$role/scripts/$name"
            if [[ -f "$script_path" ]]; then
                printf "    ${GREEN}✅${NC} Script: %s\n" "$name"
            else
                printf "    ${RED}❌${NC} Script: %s — not found in ~/.ae/%s/scripts/\n" "$name" "$role"
                any_fail=true
            fi
            ;;
    esac
}
