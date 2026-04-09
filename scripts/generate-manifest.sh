#!/usr/bin/env bash
set -euo pipefail

# generate-manifest.sh — generate manifest.yml for a given role
# Usage: bash scripts/generate-manifest.sh <role> [output_path]
#
# Scans skills/<role>/*/ and skills/*/ (shared) SKILL.md files,
# extracts frontmatter metadata, and produces a YAML capability registry.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

err() { echo -e "${RED}[generate-manifest]${NC} $*" >&2; }
ok()  { echo -e "${GREEN}[generate-manifest]${NC} $*" >&2; }

usage() {
    echo "Usage: bash scripts/generate-manifest.sh <role> [output_path]"
    echo "  role: pm | dev | go"
    echo "  output_path: optional file path (default: stdout)"
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

ROLE="$1"
OUTPUT="${2:-}"

# Validate role
if [[ "$ROLE" != "pm" && "$ROLE" != "dev" && "$ROLE" != "go" ]]; then
    err "无效角色: $ROLE (支持: pm, dev, go)"
    exit 1
fi

# Extract version from CHANGELOG.md
CHANGELOG="$REPO_ROOT/templates/$ROLE/CHANGELOG.md"
if [[ ! -f "$CHANGELOG" ]]; then
    err "CHANGELOG.md 不存在: $CHANGELOG"
    exit 1
fi

VERSION=$(grep -oE '## v[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" | head -1 | sed 's/## //')
if [[ -z "$VERSION" ]]; then
    err "无法从 CHANGELOG.md 提取版本号"
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
    err "未找到任何 SKILL.md (role=$ROLE)"
    exit 1
fi

# Generate manifest YAML via Python
MANIFEST=$(python3 -c "
import sys, os, json, re
from datetime import date

role = sys.argv[1]
version = sys.argv[2]
repo_root = sys.argv[3]
skill_paths_str = sys.argv[4]

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

    # Manual fallback parser
    result = {}
    deps = {}
    in_deps = False
    current_dep_key = None
    current_list_item = None

    for line in fm_text.split('\n'):
        stripped = line.strip()
        if stripped == '' or stripped.startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())

        # Top-level keys (indent 0)
        if indent == 0:
            if stripped == 'dependencies:':
                in_deps = True
                result['dependencies'] = deps
                current_dep_key = None
                continue
            elif in_deps:
                in_deps = False
                current_dep_key = None

            if ':' in stripped:
                key, val = stripped.split(':', 1)
                key = key.strip()
                val = val.strip().strip('\"').strip(\"'\")
                if val == 'true':
                    result[key] = True
                elif val == 'false':
                    result[key] = False
                elif val:
                    result[key] = val
            continue

        if in_deps:
            # Second-level dep keys (mcp:, cli:, api_keys:, scripts:)
            if indent <= 4 and stripped.endswith(':') and not stripped.startswith('-'):
                current_dep_key = stripped[:-1].strip()
                deps[current_dep_key] = []
                current_list_item = None
                continue
            if stripped == '[]':
                continue

            if current_dep_key is not None and stripped.startswith('-'):
                val = stripped[1:].strip()
                if 'name:' in val:
                    entry = {'name': val.split('name:', 1)[1].strip().strip('\"').strip(\"'\")}
                    deps[current_dep_key].append(entry)
                    current_list_item = entry
                else:
                    deps[current_dep_key].append(val.strip('\"').strip(\"'\"))
                    current_list_item = None
                continue

            # Indented key-value under a list item (e.g., verify:)
            if current_list_item is not None and isinstance(current_list_item, dict):
                if ':' in stripped:
                    k, v = stripped.split(':', 1)
                    current_list_item[k.strip()] = v.strip().strip('\"').strip(\"'\")
                continue

    return result

def skill_name_from_path(filepath):
    \"\"\"Extract skill name from path like skills/pm/ae-preflight/SKILL.md -> ae-preflight\"\"\"
    return os.path.basename(os.path.dirname(filepath))

# Build skills dict
skills = {}
for path in skill_paths:
    path = path.strip()
    if not path:
        continue
    fm = parse_frontmatter(path)
    if fm is None:
        # No frontmatter, still include with defaults
        sname = skill_name_from_path(path)
        skills[sname] = {
            'description': '',
            'type': 'internal',
            'deprecated': False,
            'dependencies': {'mcp': [], 'cli': [], 'api_keys': [], 'scripts': []}
        }
        continue

    sname = fm.get('name', skill_name_from_path(path))
    desc = fm.get('description', '')
    deprecated = fm.get('deprecated', False)
    deprecated_since = fm.get('deprecated_since', '')
    superseded_by = fm.get('superseded_by', '')
    deps = fm.get('dependencies', {})
    if not isinstance(deps, dict):
        deps = {}
    smoke_test = fm.get('smoke_test', None)

    entry = {
        'description': desc,
        'type': 'internal',
        'deprecated': bool(deprecated),
    }
    if smoke_test and isinstance(smoke_test, dict) and 'command' in smoke_test:
        entry['smoke_test'] = {
            'command': str(smoke_test.get('command', '')),
            'expected_exit': int(smoke_test.get('expected_exit', 0)),
            'description': str(smoke_test.get('description', '')),
        }
    if deprecated:
        if deprecated_since:
            entry['deprecated_since'] = str(deprecated_since)
        if superseded_by:
            entry['superseded_by'] = str(superseded_by)

    # Normalize dependencies
    norm_deps = {}
    for dep_type in ['mcp', 'cli', 'api_keys', 'scripts']:
        items = deps.get(dep_type, [])
        if not isinstance(items, list):
            items = []
        norm_deps[dep_type] = items

    entry['dependencies'] = norm_deps
    skills[sname] = entry

# Sort skills alphabetically
sorted_names = sorted(skills.keys())

# Generate YAML output (manual to avoid PyYAML dependency for output)
lines = []
lines.append('# Auto-generated by scripts/generate-manifest.sh')
lines.append('# Do not edit manually — regenerate with: bash scripts/generate-manifest.sh ' + role)
lines.append('name: ae-' + role)
lines.append('version: \"' + version + '\"')
lines.append('generated: \"' + date.today().isoformat() + '\"')
lines.append('')
lines.append('skills:')

for sname in sorted_names:
    entry = skills[sname]
    lines.append('  ' + sname + ':')

    # Description
    desc = entry.get('description', '')
    lines.append('    description: \"' + desc.replace('\"', '\\\\\"') + '\"')

    # Type
    lines.append('    type: ' + entry.get('type', 'internal'))

    # Deprecated
    dep_val = entry.get('deprecated', False)
    lines.append('    deprecated: ' + ('true' if dep_val else 'false'))

    if dep_val:
        if 'deprecated_since' in entry:
            lines.append('    deprecated_since: \"' + entry['deprecated_since'] + '\"')
        if 'superseded_by' in entry:
            lines.append('    superseded_by: \"' + entry['superseded_by'] + '\"')

    # Dependencies
    deps = entry.get('dependencies', {})
    lines.append('    dependencies:')

    for dep_type in ['mcp', 'cli', 'api_keys', 'scripts']:
        items = deps.get(dep_type, [])
        if not items:
            lines.append('      ' + dep_type + ': []')
        else:
            lines.append('      ' + dep_type + ':')
            for item in items:
                if isinstance(item, dict):
                    lines.append('        - name: ' + str(item.get('name', '')))
                    if 'verify' in item:
                        lines.append('          verify: \"' + str(item['verify']) + '\"')
                else:
                    lines.append('        - ' + str(item))

    # Smoke test (optional)
    smoke = entry.get('smoke_test')
    if smoke:
        lines.append('    smoke_test:')
        lines.append('      command: \"' + str(smoke.get('command', '')) + '\"')
        lines.append('      expected_exit: ' + str(smoke.get('expected_exit', 0)))
        lines.append('      description: \"' + str(smoke.get('description', '')) + '\"')

    lines.append('')

print('\n'.join(lines))
" "$ROLE" "$VERSION" "$REPO_ROOT" "$(IFS='|'; echo "${SKILL_FILES[*]}")")

# Output
if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    echo "$MANIFEST" > "$OUTPUT"
    ok "manifest.yml 已生成: $OUTPUT (role=$ROLE, version=$VERSION, skills=$(echo "$MANIFEST" | grep -c '    description:'))"
else
    echo "$MANIFEST"
fi
