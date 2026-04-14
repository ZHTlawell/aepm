#!/usr/bin/env bash
set -euo pipefail

# ae-eval.sh — Skill 评估框架
# 在远程 Mac Mini 上通过 claude -p 执行 skill 测试
#
# Usage:
#   bash scripts/ae-eval.sh <role> <skill-name>        # 测试单个 skill
#   bash scripts/ae-eval.sh <role> --all                # 批量测试所有 skill
#   bash scripts/ae-eval.sh <role> <skill> --dry-run    # 只生成 stories 不执行
#   bash scripts/ae-eval.sh <role> <skill> --generate   # 重新生成 stories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Mac Mini SSH 配置
SSH_HOST="testing@127.0.0.1"
SSH_PORT=6000
SSH_KEY="$HOME/.ssh/id_ed25519_macmini"
SSH_OPTS="-o Port=$SSH_PORT -o IdentityFile=$SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[ae-eval]${NC} $*"; }
ok()    { echo -e "${GREEN}[ae-eval]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ae-eval]${NC} $*"; }
err()   { echo -e "${RED}[ae-eval]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: bash scripts/ae-eval.sh <role> <skill|--all> [options]

Arguments:
  role        pm | dev | go
  skill       skill 名称 (如 ae-web-browse) 或 --all

Options:
  --dry-run   只生成 stories，不执行
  --generate  强制重新生成 stories（覆盖 evaluate.md 中已有的）

Examples:
  bash scripts/ae-eval.sh go ae-panel-discussion
  bash scripts/ae-eval.sh pm --all
  bash scripts/ae-eval.sh go ae-web-browse --dry-run
EOF
}

# --- 参数解析 ---
if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

ROLE="$1"
TARGET="$2"
DRY_RUN=false
FORCE_GENERATE=false
JUDGE_ONLY=false

shift 2
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --generate) FORCE_GENERATE=true ;;
        --judge-only) JUDGE_ONLY=true ;;
        *) err "未知参数: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$ROLE" != "pm" && "$ROLE" != "dev" && "$ROLE" != "go" ]]; then
    err "无效角色: $ROLE"
    exit 1
fi

# --- 检查 Mac Mini 连通性 ---
check_connection() {
    if ! ssh $SSH_OPTS $SSH_HOST "echo ok" >/dev/null 2>&1; then
        err "无法连接 Mac Mini。请确认 frpc 在运行: frpc -c /tmp/frpc-macmini.toml &"
        exit 1
    fi
    ok "Mac Mini 连接正常"
}

# --- 解析 skill 实际路径（支持 role 专属和共享 skill）---
resolve_skill_dir() {
    local skill_name="$1"
    if [[ -f "$REPO_ROOT/skills/$ROLE/$skill_name/SKILL.md" ]]; then
        echo "$REPO_ROOT/skills/$ROLE/$skill_name"
    elif [[ -f "$REPO_ROOT/skills/$skill_name/SKILL.md" ]]; then
        echo "$REPO_ROOT/skills/$skill_name"
    else
        echo ""
    fi
}

# --- 收集要测试的 skill 列表 ---
collect_skills() {
    local skills=()
    if [[ "$TARGET" == "--all" ]]; then
        # Role-specific skills
        while IFS= read -r d; do
            local name=$(basename "$d")
            if [[ -f "$d/SKILL.md" ]]; then
                skills+=("$name")
            fi
        done < <(find "$REPO_ROOT/skills/$ROLE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
        # Shared skills (directly under skills/)
        while IFS= read -r d; do
            local name=$(basename "$d")
            [[ "$name" == "pm" || "$name" == "go" || "$name" == "dev" ]] && continue
            if [[ -f "$d/SKILL.md" ]]; then
                skills+=("$name")
            fi
        done < <(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    else
        local resolved
        resolved=$(resolve_skill_dir "$TARGET")
        if [[ -z "$resolved" ]]; then
            err "Skill 不存在: skills/$ROLE/$TARGET/SKILL.md 或 skills/$TARGET/SKILL.md"
            exit 1
        fi
        skills+=("$TARGET")
    fi
    echo "${skills[@]}"
}

# --- 同步 skill 文件到 Mac Mini ---
sync_skill() {
    local skill_name="$1"
    local skill_dir
    skill_dir=$(resolve_skill_dir "$skill_name")
    local remote_dir="/tmp/ae-eval/$ROLE/$skill_name"

    ssh $SSH_OPTS $SSH_HOST "mkdir -p $remote_dir"
    scp -o Port=$SSH_PORT -o IdentityFile=$SSH_KEY -o IdentitiesOnly=yes \
        "$skill_dir/SKILL.md" "$SSH_HOST:$remote_dir/SKILL.md" 2>/dev/null

    # 同步 evaluate.md（如果存在）
    if [[ -f "$skill_dir/evaluate.md" ]]; then
        scp -o Port=$SSH_PORT -o IdentityFile=$SSH_KEY -o IdentitiesOnly=yes \
            "$skill_dir/evaluate.md" "$SSH_HOST:$remote_dir/evaluate.md" 2>/dev/null
    fi
}

# --- Phase 1: 生成 test stories ---
generate_stories() {
    local skill_name="$1"
    local remote_dir="/tmp/ae-eval/$ROLE/$skill_name"

    # 检查是否已有 stories（除非 --generate 强制重新生成）
    if [[ "$FORCE_GENERATE" == "false" ]]; then
        local has_stories
        has_stories=$(ssh $SSH_OPTS $SSH_HOST "grep -c '## Test Stories' $remote_dir/evaluate.md 2>/dev/null || echo 0")
        if [[ "$has_stories" -gt 0 ]]; then
            info "$skill_name: evaluate.md 已有 stories，跳过生成（用 --generate 强制重新生成）"
            return 0
        fi
    fi

    info "$skill_name: 生成 test stories..."

    ssh $SSH_OPTS $SSH_HOST "
eval \"\$(/opt/homebrew/bin/brew shellenv zsh)\"
cd $remote_dir

claude -p \"你是一个 skill 测试专家。阅读以下 SKILL.md，生成 5 个 test stories。

要求：
1. 覆盖 skill 的核心路径（happy path）
2. 包含 1-2 个边界/异常场景
3. 每个 story 包含: name, prompt（用户会说的话）, expect（期望行为描述）, max_time（秒）
4. prompt 必须是真实可执行的（不能引用不存在的 URL 或文件，除非 skill 本身会搜索）
5. 对于需要外部依赖（MCP/CLI）的 skill，stories 应包含一个'依赖检查'story

输出格式严格为以下 markdown，不要加任何其他内容：

## Test Stories

### Story 1: {name}
- **Prompt**: \\\"{用户 prompt}\\\"
- **Expect**: {期望行为，1-2 句话}
- **Max Time**: {秒数}s

### Story 2: {name}
...

---

SKILL.md 内容：
\$(cat SKILL.md)
\" --max-turns 1 > /tmp/ae-eval-stories-$skill_name.md 2>/dev/null

# 写入或更新 evaluate.md
if [[ -f evaluate.md ]]; then
    # 替换已有的 Test Stories 部分
    python3 -c \"
import re, sys
with open('evaluate.md', 'r') as f:
    content = f.read()
with open('/tmp/ae-eval-stories-$skill_name.md', 'r') as f:
    new_stories = f.read().strip()
if '## Test Stories' in content:
    content = re.sub(r'## Test Stories.*?(?=\\n## [^T]|\\Z)', new_stories + '\\n\\n', content, flags=re.DOTALL)
else:
    content = content.rstrip() + '\\n\\n' + new_stories + '\\n'
with open('evaluate.md', 'w') as f:
    f.write(content)
\"
else
    # 创建新的 evaluate.md
    cat > evaluate.md <<HEADER
# $skill_name 评估报告

## 基本信息
- **Role**: $ROLE
- **Skill**: $skill_name

HEADER
    cat /tmp/ae-eval-stories-$skill_name.md >> evaluate.md
    echo '' >> evaluate.md
fi
" 2>&1

    ok "$skill_name: stories 生成完成"
}

# --- Phase 2: 执行 stories ---
execute_stories() {
    local skill_name="$1"
    local remote_dir="/tmp/ae-eval/$ROLE/$skill_name"

    info "$skill_name: 执行 test stories..."

    ssh $SSH_OPTS $SSH_HOST "
eval \"\$(/opt/homebrew/bin/brew shellenv zsh)\"
cd $remote_dir

# 解析 stories 并逐个执行
python3 <<'PYEOF'
import re, subprocess, json, time, os

with open('evaluate.md', 'r') as f:
    content = f.read()

# 解析 stories
pattern = r'### Story (\d+): (.+?)\n- \*\*Prompt\*\*: .(.+?).\n- \*\*Expect\*\*:(.*?)\n- \*\*Max Time\*\*: (\d+)s'
stories = re.findall(pattern, content, re.DOTALL)

if not stories:
    print('WARNING: 未找到可执行的 stories')
    exit(0)

results = []
for idx, name, prompt, expect, max_time in stories:
    max_time = int(max_time)
    print(f'  [{idx}/{len(stories)}] {name}...')

    start = time.time()
    try:
        result = subprocess.run(
            ['claude', '-p', prompt, '--max-turns', '10'],
            capture_output=True, text=True,
            timeout=max(max_time * 2, 120),  # 给 2 倍超时
            env={**os.environ, 'PATH': '/opt/homebrew/bin:' + os.environ.get('PATH', '')}
        )
        elapsed = time.time() - start
        output = result.stdout[:2000]  # 截断过长输出
        exit_code = result.returncode
    except subprocess.TimeoutExpired:
        elapsed = time.time() - start
        output = 'TIMEOUT'
        exit_code = -1

    results.append({
        'index': idx,
        'name': name,
        'prompt': prompt,
        'expect': expect,
        'max_time': max_time,
        'elapsed': round(elapsed, 1),
        'output': output,
        'exit_code': exit_code,
        'timeout': exit_code == -1
    })
    print(f'    → {elapsed:.1f}s (exit={exit_code})')

# 保存原始结果
with open('/tmp/ae-eval-results-${skill_name}.json', 'w') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print(f'执行完成: {len(results)} stories')
PYEOF
" 2>&1
}

# --- Phase 3: Judge ---
judge_results() {
    local skill_name="$1"
    local remote_dir="/tmp/ae-eval/$ROLE/$skill_name"

    info "$skill_name: LLM Judge 评估中..."

    ssh $SSH_OPTS $SSH_HOST "
eval \"\$(/opt/homebrew/bin/brew shellenv zsh)\"
cd $remote_dir

# 读取结果并让 LLM judge
python3 <<'PYEOF'
import json, subprocess, os, re
from datetime import datetime

with open('/tmp/ae-eval-results-${skill_name}.json', 'r') as f:
    results = json.load(f)

with open('SKILL.md', 'r') as f:
    skill_md = f.read()[:3000]  # 截断以控制 context

# 构建 judge prompt
judge_input = '''你是一个 skill 测试评审员。根据 SKILL.md 的定义和每个 test story 的实际输出，评分并分析。

## SKILL.md 摘要
{skill_md}

## 测试结果
'''.format(skill_md=skill_md)

for r in results:
    output_preview = r['output'][:800] if r['output'] else '(empty)'
    r_copy = dict(r)
    r_copy['output_preview'] = output_preview
    judge_input += '''
### Story {index}: {name}
- **Prompt**: \"{prompt}\"
- **期望**: {expect}
- **耗时**: {elapsed}s (上限 {max_time}s)
- **超时**: {timeout}
- **输出摘要**:
{output_preview}
'''.format(**r_copy)

judge_input += '''
## 请输出评估结果

严格按以下格式输出，不要加其他内容：

## 最近一次评估
- **日期**: {date}
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: X/Y (Z%)
- **平均耗时**: Xs

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| {{story name}} | X/5 | Xs | {{瓶颈分析或 —}} | {{备注或 —}} |

## 瓶颈分析
- 列出主要瓶颈和优化建议（2-3 条）

## 结论
一句话总结 skill 当前质量和建议优先级。
'''.format(date=datetime.now().strftime('%Y-%m-%d'))

# 调用 judge
result = subprocess.run(
    ['claude', '-p', judge_input, '--max-turns', '1'],
    capture_output=True, text=True, timeout=120,
    env={**os.environ, 'PATH': '/opt/homebrew/bin:' + os.environ.get('PATH', '')}
)
judge_output = result.stdout.strip()

# 更新 evaluate.md
with open('evaluate.md', 'r') as f:
    content = f.read()

# 提取历史基线（如果有）
baseline_match = re.search(r'## 历史基线\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
baseline = baseline_match.group(0) if baseline_match else ''

# 从 judge 输出提取通过率和耗时，加入历史
new_pass = re.search(r'总体通过率\*?\*?: (.+?)$', judge_output, re.MULTILINE)
new_time = re.search(r'平均耗时\*?\*?: (.+?)$', judge_output, re.MULTILINE)
baseline_row = '| {date} | {pass_rate} | {avg_time} |'.format(
    date=datetime.now().strftime('%Y-%m-%d'),
    pass_rate=new_pass.group(1).strip() if new_pass else 'N/A',
    avg_time=new_time.group(1).strip() if new_time else 'N/A'
)

if baseline:
    baseline = baseline.rstrip() + '\n' + baseline_row + '\n'
else:
    baseline = '''## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
''' + baseline_row + '\n'

# 重组 evaluate.md: 基本信息 + stories + 评估结果 + 历史基线
stories_match = re.search(r'(## Test Stories.*?)(?=\n## [^T]|\Z)', content, re.DOTALL)
stories_section = stories_match.group(1).strip() if stories_match else ''

header_match = re.search(r'^(# .+?评估报告\n\n## 基本信息\n.*?)(?=\n## )', content, re.DOTALL)
header = header_match.group(1).strip() if header_match else '# ${skill_name} 评估报告\n\n## 基本信息\n- **Role**: ${ROLE}\n- **Skill**: ${skill_name}'

final = header + '\n\n' + stories_section + '\n\n' + judge_output + '\n\n' + baseline

with open('evaluate.md', 'w') as f:
    f.write(final)

print(judge_output)
PYEOF
" 2>&1
}

# --- 回收 evaluate.md ---
fetch_evaluate() {
    local skill_name="$1"
    local remote_dir="/tmp/ae-eval/$ROLE/$skill_name"
    local local_dir
    local_dir=$(resolve_skill_dir "$skill_name")

    scp -o Port=$SSH_PORT -o IdentityFile=$SSH_KEY -o IdentitiesOnly=yes \
        "$SSH_HOST:$remote_dir/evaluate.md" "$local_dir/evaluate.md" 2>/dev/null

    ok "$skill_name: evaluate.md 已写回 $local_dir/evaluate.md"
}

# ==================== 主流程 ====================

check_connection

SKILLS=($(collect_skills))
info "待测试: ${#SKILLS[@]} 个 skill (role=$ROLE)"

for skill in "${SKILLS[@]}"; do
    echo ""
    info "━━━ $skill ━━━"

    # 同步文件到 Mac Mini
    sync_skill "$skill"

    if [[ "$JUDGE_ONLY" == "true" ]]; then
        # 跳过生成和执行，直接用已有的 results JSON 跑 Judge
        sync_skill "$skill"
        judge_results "$skill"
        fetch_evaluate "$skill"
        continue
    fi

    # Phase 1: 生成 stories
    generate_stories "$skill"

    if [[ "$DRY_RUN" == "true" ]]; then
        fetch_evaluate "$skill"
        info "$skill: --dry-run 模式，跳过执行和评估"
        continue
    fi

    # Phase 2: 执行
    execute_stories "$skill"

    # Phase 3: Judge
    judge_results "$skill"

    # 回收结果
    fetch_evaluate "$skill"
done

echo ""
ok "━━━ 评估完成 ━━━"
