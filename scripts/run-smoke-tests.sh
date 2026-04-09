#!/usr/bin/env bash
set -euo pipefail

# run-smoke-tests.sh — run smoke tests declared in SKILL.md frontmatter
# Usage: bash scripts/run-smoke-tests.sh <role>
#
# Scans skills/<role>/*/ and skills/*/ (shared) SKILL.md files,
# extracts smoke_test blocks from frontmatter, and executes them.
# Exit non-zero if any test fails.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[smoke-test]${NC} $*"; }
ok()    { echo -e "${GREEN}[smoke-test]${NC} $*"; }
warn()  { echo -e "${YELLOW}[smoke-test]${NC} $*"; }
err()   { echo -e "${RED}[smoke-test]${NC} $*" >&2; }

usage() {
    echo "Usage: bash scripts/run-smoke-tests.sh <role>"
    echo "  role: pm | dev | go"
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

ROLE="$1"

# Validate role
if [[ "$ROLE" != "pm" && "$ROLE" != "dev" && "$ROLE" != "go" ]]; then
    err "无效角色: $ROLE (支持: pm, dev, go)"
    exit 1
fi

# Collect SKILL.md paths: role-specific + shared (top-level skills/*/SKILL.md)
SKILL_FILES=()

# Role-specific skills
while IFS= read -r f; do
    SKILL_FILES+=("$f")
done < <(find "$REPO_ROOT/skills/$ROLE" -maxdepth 2 -name SKILL.md 2>/dev/null | sort)

# Shared skills (skills/*/SKILL.md, NOT skills/<role>/*)
for d in "$REPO_ROOT"/skills/*/; do
    local_name=$(basename "$d")
    # Skip role directories
    if [[ "$local_name" == "pm" || "$local_name" == "dev" || "$local_name" == "go" ]]; then
        continue
    fi
    if [[ -f "$d/SKILL.md" ]]; then
        SKILL_FILES+=("$d/SKILL.md")
    fi
done

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    warn "未找到任何 SKILL.md (role=$ROLE)"
    echo "SUMMARY: 0 passed, 0 failed, 0 skipped"
    exit 0
fi

# Extract smoke tests from SKILL.md frontmatter via Python,
# then run them in shell
SMOKE_TESTS_JSON=$(python3 -c "
import sys, os, re, json

skill_paths_str = sys.argv[1]
skill_paths = skill_paths_str.split('|') if skill_paths_str else []

# Try to use PyYAML, fall back to manual parsing
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

def parse_frontmatter(filepath):
    \"\"\"Extract YAML frontmatter from a SKILL.md file.\"\"\"
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        return None

    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if not m:
        return None

    fm_text = m.group(1)

    if HAS_YAML:
        try:
            return yaml.safe_load(fm_text)
        except Exception:
            pass

    # Manual fallback: parse smoke_test block
    result = {}
    in_smoke = False
    smoke = {}

    for line in fm_text.split('\n'):
        stripped = line.strip()
        if stripped == '' or stripped.startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0:
            if stripped.startswith('smoke_test:'):
                rest = stripped[len('smoke_test:'):].strip()
                if rest:
                    # Inline format: smoke_test: {command: ..., expected_exit: 0, description: ...}
                    # Try to parse as simple inline
                    if rest.startswith('{') and rest.endswith('}'):
                        inner = rest[1:-1]
                        for pair in inner.split(','):
                            if ':' in pair:
                                k, v = pair.split(':', 1)
                                k = k.strip().strip('\"').strip(\"'\")
                                v = v.strip().strip('\"').strip(\"'\")
                                try:
                                    v = int(v)
                                except ValueError:
                                    pass
                                smoke[k] = v
                    result['smoke_test'] = smoke
                    in_smoke = False
                else:
                    in_smoke = True
                    result['smoke_test'] = smoke
                continue
            elif stripped.startswith('name:'):
                result['name'] = stripped.split(':', 1)[1].strip().strip('\"').strip(\"'\")
                in_smoke = False
                continue
            else:
                in_smoke = False
                continue

        if in_smoke and indent > 0:
            if ':' in stripped:
                k, v = stripped.split(':', 1)
                k = k.strip()
                v = v.strip().strip('\"').strip(\"'\")
                try:
                    v = int(v)
                except ValueError:
                    pass
                smoke[k] = v

    return result

def skill_name_from_path(filepath):
    return os.path.basename(os.path.dirname(filepath))

results = []
for path in skill_paths:
    path = path.strip()
    if not path:
        continue
    fm = parse_frontmatter(path)
    if fm is None:
        sname = skill_name_from_path(path)
        results.append({'name': sname, 'smoke_test': None})
        continue

    sname = fm.get('name', skill_name_from_path(path))
    smoke = fm.get('smoke_test', None)
    if smoke and isinstance(smoke, dict) and 'command' in smoke:
        results.append({
            'name': sname,
            'smoke_test': {
                'command': smoke.get('command', ''),
                'expected_exit': int(smoke.get('expected_exit', 0)),
                'description': smoke.get('description', '')
            }
        })
    else:
        results.append({'name': sname, 'smoke_test': None})

print(json.dumps(results))
" "$(IFS='|'; echo "${SKILL_FILES[*]}")")

# Run the smoke tests
PASSED=0
FAILED=0
SKIPPED=0
HAS_FAILURE=false

while IFS= read -r entry; do
    NAME=$(echo "$entry" | python3 -c "import sys, json; e=json.load(sys.stdin); print(e['name'])")
    HAS_TEST=$(echo "$entry" | python3 -c "import sys, json; e=json.load(sys.stdin); print('yes' if e['smoke_test'] else 'no')")

    if [[ "$HAS_TEST" == "no" ]]; then
        SKIPPED=$((SKIPPED + 1))
        echo -e "  ${YELLOW}⏭${NC}  $NAME — 无冒烟测试定义"
        continue
    fi

    COMMAND=$(echo "$entry" | python3 -c "import sys, json; e=json.load(sys.stdin); print(e['smoke_test']['command'])")
    EXPECTED_EXIT=$(echo "$entry" | python3 -c "import sys, json; e=json.load(sys.stdin); print(e['smoke_test']['expected_exit'])")
    DESC=$(echo "$entry" | python3 -c "import sys, json; e=json.load(sys.stdin); print(e['smoke_test']['description'])")

    # Run the command with a 5-second timeout
    ACTUAL_EXIT=0
    if ! timeout 5 bash -c "$COMMAND" >/dev/null 2>&1; then
        ACTUAL_EXIT=$?
    fi

    if [[ "$ACTUAL_EXIT" -eq "$EXPECTED_EXIT" ]]; then
        PASSED=$((PASSED + 1))
        echo -e "  ${GREEN}✅${NC}  $NAME — $DESC"
    else
        FAILED=$((FAILED + 1))
        HAS_FAILURE=true
        echo -e "  ${RED}❌${NC}  $NAME — $DESC (exit=$ACTUAL_EXIT, expected=$EXPECTED_EXIT)"
        echo -e "      FAILED: $COMMAND"
    fi

done < <(echo "$SMOKE_TESTS_JSON" | python3 -c "
import sys, json
tests = json.load(sys.stdin)
for t in tests:
    print(json.dumps(t))
")

echo ""
TOTAL=$((PASSED + FAILED + SKIPPED))
info "SUMMARY: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped (共 ${TOTAL} skills)"

if [[ "$HAS_FAILURE" == "true" ]]; then
    exit 1
fi
