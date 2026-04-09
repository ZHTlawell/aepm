#!/usr/bin/env bash
# ae pm — PM subcommands (delegates to Claude Code with skills)

ae_pm() {
    if [[ $# -eq 0 ]]; then
        _pm_usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        demo-to-speckit)    _pm_run_skill "ae-demo-to-speckit" "$@" ;;
        verify-app)         _pm_run_skill "ae-verify-app" "$@" ;;
        submit-requirement) _pm_run_skill "ae-submit-requirement" "$@" ;;
        submit-bug)         _pm_submit_bug "$@" ;;
        comment-issue)      _pm_comment_issue "$@" ;;
        file-bugs)          _pm_file_bugs "$@" ;;
        validate-speckit)   _pm_validate_speckit "$@" ;;
        image-decopyright)  _pm_image_decopyright "$@" ;;
        help|--help|-h)     _pm_usage ;;
        *)
            err "未知 PM 命令: $cmd"
            _pm_usage
            exit 1
            ;;
    esac
}

_pm_usage() {
    cat <<EOF
${BOLD}ae pm${NC} — PM 工作流命令

${BOLD}USAGE${NC}
    ae pm <command> [args...]

${BOLD}COMMANDS${NC}
    demo-to-speckit <demo_dir>     从 demo 源码提取标准 speckit（6 模块）
    verify-app <demo> <prod>       E2E 对比 demo vs 成品，自动归因差异
    submit-requirement             向 AE Team 提交可复用能力需求
    submit-bug <title> [body]      向 AE Team 提交 bug 报告（支持 --screenshot）
    comment-issue <id> <body>      给已有 issue 追加评论（支持 --screenshot）
    file-bugs <diff-report.json>   从 verify-app 报告批量提交 bug
    validate-speckit <speckit_dir> 校验 speckit 格式是否符合 schema
    image-decopyright <img...>     图片去版权化 — AI 重绘生成可商用替代图片

${BOLD}EXAMPLES${NC}
    ae pm demo-to-speckit ./ShoeLens
    ae pm verify-app ./ShoeLens-demo ./ShoeLens-prod
    ae pm submit-requirement
    ae pm submit-bug "底部 Tab 栏出现双层重叠" --screenshot ~/Desktop/bug.png
    ae pm comment-issue IHXXXX "补充截图" --screenshot ~/Desktop/demo.png
    ae pm file-bugs verify/reports/diff-iter1.json
    ae pm image-decopyright ./assets/hero.png
    ae pm image-decopyright ./assets/*.png --output ./assets/safe/
EOF
}

# ── Gitee API helper (via ae-git.py) ─────────────────────────────

_pm_ae_git() {
    local ae_git="$(dirname "$AE_CLI_DIR")/scripts/ae-git.py"
    if [[ ! -f "$ae_git" ]]; then
        err "ae-git.py 未找到"
        exit 1
    fi
    python3 "$ae_git" "$@"
}

# _pm_gitee_create_issue <repo> <title> <body>
# Creates issue via ae-git.py and prints the result URL.
_pm_gitee_create_issue() {
    local repo="$1" title="$2" body="$3"

    info "正在提交 issue 到 ${BOLD}${repo}${NC} ..."

    local response
    response=$(_pm_ae_git issues create --repo "$repo" --title "$title" --body "$body" 2>&1) || {
        err "Issue 创建失败"
        echo "$response"
        exit 1
    }

    local html_url
    html_url=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null || true)

    if [[ -n "$html_url" ]]; then
        ok "Issue 创建成功！"
        echo ""
        echo "  $html_url"
        echo ""
    else
        err "Issue 创建失败，API 返回:"
        echo "$response"
        exit 1
    fi
}

# _pm_gitee_upload_image <image_path> [repo]
# Uploads a local image to Gitee repo under _attachments/, prints download URL.
_pm_gitee_upload_image() {
    local image_path="$1"
    local repo="${2:-ae-pm}"

    if [[ ! -f "$image_path" ]]; then
        err "文件不存在: $image_path"
        return 1
    fi

    local response
    response=$(_pm_ae_git upload-image --repo "$repo" --file "$image_path" 2>&1) || {
        err "图片上传失败"
        echo "$response" >&2
        return 1
    }

    local download_url
    download_url=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('download_url',''))" 2>/dev/null || true)

    if [[ -n "$download_url" ]]; then
        echo "$download_url"
    else
        err "图片上传失败，API 返回:"
        echo "$response" >&2
        return 1
    fi
}

# _pm_gitee_add_comment <repo> <issue_number> <body>
# Posts a comment on an existing issue.
_pm_gitee_add_comment() {
    local repo="$1" issue_number="$2" body="$3"

    info "正在评论 ${BOLD}${repo}#${issue_number}${NC} ..."

    local response
    response=$(_pm_ae_git issues comment --repo "$repo" --number "$issue_number" --body "$body" 2>&1) || {
        err "评论失败"
        echo "$response"
        exit 1
    }

    local comment_id
    comment_id=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

    if [[ -n "$comment_id" ]]; then
        ok "评论成功！"
        echo ""
        echo "  https://e.gitee.com/turningsyn/issues/list?issue=${issue_number}"
        echo ""
    else
        err "评论失败，API 返回:"
        echo "$response"
        exit 1
    fi
}

# _pm_clipboard_to_file — macOS: extract clipboard image to temp file, print path
_pm_clipboard_to_file() {
    local tmp="/tmp/ae-clipboard-$(date +%s).png"
    if osascript -e '
        set png_data to the clipboard as «class PNGf»
        set f to open for access POSIX file "'"$tmp"'" with write permission
        write png_data to f
        close access f
    ' 2>/dev/null; then
        echo "$tmp"
    else
        return 1
    fi
}

# _pm_upload_screenshots <repo> <screenshots...>
# Uploads images, prints markdown image section to stdout.
# Progress messages go to stderr so they don't pollute the captured output.
_pm_upload_screenshots() {
    local repo="$1"; shift
    local img_section=$'\n\n## 截图\n'
    local any_ok=0

    for img in "$@"; do
        info "上传截图: $(basename "$img") ..." >&2
        local url
        url=$(_pm_gitee_upload_image "$img" "$repo")
        if [[ $? -eq 0 && -n "$url" ]]; then
            local name=$(basename "$img")
            img_section+=$'\n'"![${name}](${url})"$'\n'
            ok "截图上传成功" >&2
            any_ok=1
        else
            warn "截图上传失败: $img，跳过" >&2
        fi
    done

    if [[ $any_ok -eq 1 ]]; then
        echo "$img_section"
    fi
}

# ── comment-issue ────────────────────────────────────────────────

_pm_comment_issue() {
    local issue_id="" body="" repo="ae-pm" screenshots=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)          repo="$2"; shift 2 ;;
            --screenshot|-s) screenshots+=("$2"); shift 2 ;;
            --clipboard)
                local tmp
                tmp=$(_pm_clipboard_to_file)
                if [[ $? -eq 0 ]]; then
                    screenshots+=("$tmp")
                    info "已从剪贴板提取截图"
                else
                    err "剪贴板中没有图片"
                    exit 1
                fi
                shift
                ;;
            --help|-h)
                cat <<EOF
${BOLD}ae pm comment-issue${NC} — 给已有 issue 追加评论

${BOLD}USAGE${NC}
    ae pm comment-issue <issue_id> <body> [--screenshot <image>]...
    ae pm comment-issue <issue_id> --screenshot <image>

${BOLD}ARGS${NC}
    issue_id    Issue 编号（如 IHXXXX）
    body        评论内容（支持 markdown，仅有截图时可省略）

${BOLD}OPTIONS${NC}
    --repo          目标仓库（默认 ae-pm，可选 ae-dev）
    --screenshot,-s 附带截图（可多次指定）
    --clipboard     从剪贴板提取截图（仅 macOS）

${BOLD}EXAMPLES${NC}
    ae pm comment-issue IHXXXX "已修复，请验收"
    ae pm comment-issue IHXXXX "补充截图" --screenshot ~/Desktop/bug.png
    ae pm comment-issue IHXXXX -s demo.png -s prod.png
    ae pm comment-issue IHXXXX --clipboard
EOF
                return 0
                ;;
            *)
                if [[ -z "$issue_id" ]]; then
                    issue_id="$1"
                elif [[ -z "$body" ]]; then
                    body="$1"
                else
                    err "参数过多。用法: ae pm comment-issue <issue_id> <body>"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$issue_id" ]]; then
        err "请指定 issue 编号"
        echo "用法: ae pm comment-issue <issue_id> <body> [--screenshot ...]"
        exit 1
    fi

    if [[ -z "$body" && ${#screenshots[@]} -eq 0 ]]; then
        err "评论内容和截图不能都为空"
        exit 1
    fi

    # Upload screenshots and append to body
    if [[ ${#screenshots[@]} -gt 0 ]]; then
        local img_md
        img_md=$(_pm_upload_screenshots "$repo" "${screenshots[@]}")
        body="${body}${img_md}"
    fi

    _pm_gitee_add_comment "$repo" "$issue_id" "$body"
}

# ── submit-bug ────────────────────────────────────────────────────

_pm_submit_bug() {
    local title="" body="" repo="ae-pm" screenshots=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)        repo="$2"; shift 2 ;;
            --screenshot|-s) screenshots+=("$2"); shift 2 ;;
            --clipboard)
                local tmp
                tmp=$(_pm_clipboard_to_file)
                if [[ $? -eq 0 ]]; then
                    screenshots+=("$tmp")
                    info "已从剪贴板提取截图"
                else
                    err "剪贴板中没有图片"
                    exit 1
                fi
                shift
                ;;
            --help|-h)
                cat <<EOF
${BOLD}ae pm submit-bug${NC} — 提交 bug 报告到 AE Team

${BOLD}USAGE${NC}
    ae pm submit-bug <title> [body] [--screenshot <image>]...
    ae pm submit-bug --repo <repo> <title> [body]

${BOLD}ARGS${NC}
    title    Bug 标题（自动添加 [BUG] 前缀）
    body     Bug 描述（可选，支持 markdown）

${BOLD}OPTIONS${NC}
    --repo          目标仓库（默认 ae-pm，可选 ae-dev）
    --screenshot,-s 附带截图（可多次指定）
    --clipboard     从剪贴板提取截图（仅 macOS）

${BOLD}EXAMPLES${NC}
    ae pm submit-bug "底部 Tab 栏出现双层重叠"
    ae pm submit-bug "UI 颜色不对" --screenshot ~/Desktop/bug.png
    ae pm submit-bug "布局错位" -s demo.png -s prod.png
    ae pm submit-bug --repo ae-dev "编译报错" --clipboard
EOF
                return 0
                ;;
            *)
                if [[ -z "$title" ]]; then
                    title="$1"
                elif [[ -z "$body" ]]; then
                    body="$1"
                else
                    err "参数过多。用法: ae pm submit-bug <title> [body]"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Interactive fallback if no title
    if [[ -z "$title" ]]; then
        echo -n "Bug 标题: "
        read -r title
        if [[ -z "$title" ]]; then
            err "标题不能为空"
            exit 1
        fi
        echo "Bug 描述（输入完按 Ctrl+D 结束，直接回车跳过）:"
        body=$(cat 2>/dev/null || true)
    fi

    # Add [BUG] prefix if not present — skip if already has a known prefix
    if [[ "$title" != \[BUG\]* && "$title" != \[GEN-BUG\]* && "$title" != \[SPECKIT-GAP\]* && "$title" != \[CONSTRAINT-GAP\]* && "$title" != \[DEMO-BUG\]* ]]; then
        title="[BUG] $title"
    fi

    # Upload screenshots and append to body
    if [[ ${#screenshots[@]} -gt 0 ]]; then
        local img_md
        img_md=$(_pm_upload_screenshots "$repo" "${screenshots[@]}")
        body="${body}${img_md}"
    fi

    _pm_gitee_create_issue "$repo" "$title" "$body"
}

# ── file-bugs ─────────────────────────────────────────────────────

_pm_file_bugs() {
    local report_file="" repo="ae-pm"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)   repo="$2"; shift 2 ;;
            --help|-h)
                cat <<EOF
${BOLD}ae pm file-bugs${NC} — 从 verify-app diff report 批量提交 bug

${BOLD}USAGE${NC}
    ae pm file-bugs <diff-report.json> [--repo <repo>]

${BOLD}ARGS${NC}
    diff-report.json    verify-app 生成的 diff report 文件

${BOLD}OPTIONS${NC}
    --repo   目标仓库（默认 ae-pm）

${BOLD}EXAMPLES${NC}
    ae pm file-bugs verify/reports/diff-iter1.json
    ae pm file-bugs diff-report.json --repo ae-dev
EOF
                return 0
                ;;
            *)
                report_file="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$report_file" ]]; then
        err "请指定 diff report 文件路径"
        echo "用法: ae pm file-bugs <diff-report.json>"
        exit 1
    fi

    if [[ ! -f "$report_file" ]]; then
        err "文件不存在: $report_file"
        exit 1
    fi

    # Parse report and generate issue list
    local bug_list
    bug_list=$(python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    report = json.load(f)

# Map attribution to prefix
PREFIX_MAP = {
    'extraction': '[SPECKIT-GAP]',
    'generation': '[GEN-BUG]',
    'constraint': '[CONSTRAINT-GAP]',
}

# Map attribution to Chinese
ATTR_CN = {
    'extraction': 'speckit 提取遗漏',
    'generation': '成品生成偏差',
    'constraint': '约束缺失',
    'unknown': '待归因',
}

bugs = []
for case in report.get('cases', []):
    status = case.get('status', '')
    if status not in ('different', 'missing_in_prod'):
        continue

    attribution = case.get('attribution', '')
    prefix = PREFIX_MAP.get(attribution, '[BUG]')
    case_id = case.get('id', 'unknown')
    # Prefer description (human-readable) over detail (technical note)
    desc = case.get('description', '')
    detail = case.get('detail', '')
    # If no description, derive a short title from case_id
    if not desc:
        desc = case_id.replace('_', ' ').title()
    level = case.get('level', '')
    source = case.get('source', '')
    attr_cn = ATTR_CN.get(attribution, '待归因')

    bugs.append({
        'case_id': case_id,
        'prefix': prefix,
        'desc': desc,
        'detail': detail,
        'status': status,
        'attribution': attribution or 'unknown',
        'attribution_cn': attr_cn,
        'level': level,
        'source': source,
    })

# Output as JSON for bash to parse
print(json.dumps({'bugs': bugs, 'total': len(bugs), 'iteration': report.get('iteration', '?')}))
" "$report_file")

    local total
    total=$(echo "$bug_list" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")

    if [[ "$total" -eq 0 ]]; then
        ok "没有需要提交的 bug（全部 pass）"
        return 0
    fi

    # Display bug list
    info "从 ${BOLD}$(basename "$report_file")${NC} 中发现 ${BOLD}${total}${NC} 个需要提交的 bug："
    echo ""

    echo "$bug_list" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for i, bug in enumerate(data['bugs'], 1):
    status_label = '差异' if bug['status'] == 'different' else '缺失'
    print(f\"  {i}. {bug['prefix']} {bug['desc']} ({bug['case_id']}, {status_label})\")
    if bug['detail']:
        # Show first 80 chars of detail as context
        short = bug['detail'][:80] + ('...' if len(bug['detail']) > 80 else '')
        print(f\"     \u2514\u2500 {short}\")
"
    echo ""

    # Ask for confirmation
    echo -n "提交哪些？（all=全部 / 1,3,5=指定编号 / n=取消）: "
    read -r selection

    if [[ -z "$selection" || "$selection" == "n" || "$selection" == "N" ]]; then
        warn "已取消"
        return 0
    fi

    # Determine which indices to submit
    local indices
    if [[ "$selection" == "all" || "$selection" == "a" ]]; then
        indices=$(seq 0 $((total - 1)))
    else
        # Convert 1-based user input to 0-based indices
        indices=$(echo "$selection" | tr ',' '\n' | while read -r n; do echo $((n - 1)); done)
    fi

    # Submit each bug
    local submitted=0
    for idx in $indices; do
        local title body
        read -r title body < <(echo "$bug_list" | python3 -c "
import json, sys
data = json.load(sys.stdin)
idx = int(sys.argv[1])
if idx < 0 or idx >= len(data['bugs']):
    print(' ')
    sys.exit(0)
bug = data['bugs'][idx]

title = f\"{bug['prefix']} {bug['desc']}\"

status_cn = '与 demo 有差异' if bug['status'] == 'different' else '成品中缺失'

body_parts = [
    '## 描述',
    f\"{bug['desc']} — {status_cn}\",
    '',
]
if bug['detail']:
    body_parts += ['## 详情', bug['detail'], '']

body_parts += [
    '## 归因',
    f\"- **阶段**: {bug['attribution_cn']}（{bug['attribution']}）\",
    f\"- **验证级别**: {bug['level']}\",
    f\"- **来源**: {bug['source']}\",
    '',
    '## 验证信息',
    f\"- **Case ID**: {bug['case_id']}\",
    f\"- **Diff Report**: {sys.argv[2]}\",
    f\"- **迭代轮次**: iter{data['iteration']}\",
]
body = chr(10).join(body_parts)

# Tab-separated output
print(f'{title}\t{body}')
" "$idx" "$report_file")

        if [[ -z "$title" || "$title" == " " ]]; then
            continue
        fi

        _pm_gitee_create_issue "$repo" "$title" "$body"
        submitted=$((submitted + 1))
    done

    echo ""
    ok "已提交 ${BOLD}${submitted}${NC} 个 bug"
}

# ── validate-speckit ──────────────────────────────────────────────

_pm_validate_speckit() {
    local speckit_dir="" json_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)    json_flag="--json"; shift ;;
            --help|-h)
                cat <<EOF
${BOLD}ae pm validate-speckit${NC} — 校验 speckit 格式

${BOLD}USAGE${NC}
    ae pm validate-speckit <speckit_dir> [--json]

${BOLD}EXAMPLES${NC}
    ae pm validate-speckit ./speckit
    ae pm validate-speckit ./speckit --json
EOF
                return 0
                ;;
            *) speckit_dir="$1"; shift ;;
        esac
    done

    if [[ -z "$speckit_dir" ]]; then
        err "请指定 speckit 目录"
        echo "用法: ae pm validate-speckit <speckit_dir>"
        exit 1
    fi

    # Find validator script
    local validator=""
    local candidates=(
        "$AE_CLI_DIR/../verify/engine/speckit_validator.py"
        "$AE_HOME/cli/verify/engine/speckit_validator.py"
        "$(dirname "$AE_CLI_DIR")/verify/engine/speckit_validator.py"
    )
    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            validator="$c"
            break
        fi
    done

    if [[ -z "$validator" ]]; then
        err "speckit_validator.py 未找到"
        exit 1
    fi

    python3 "$validator" "$speckit_dir" $json_flag
}

# ── image-decopyright ─────────────────────────────────────────

_pm_image_decopyright() {
    local images=() output_dir="" style="" size="1024x1024" mode="auto" backend="gemini"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output|-o)   output_dir="$2"; shift 2 ;;
            --style|-s)    style="$2"; shift 2 ;;
            --size)        size="$2"; shift 2 ;;
            --backend|-b)  backend="$2"; shift 2 ;;
            --describe)    mode="describe"; shift ;;
            --help|-h)
                cat <<EOF
${BOLD}ae pm image-decopyright${NC} — 图片去版权化（AI 重绘生成可商用替代）

${BOLD}USAGE${NC}
    ae pm image-decopyright <image...> [options]

${BOLD}OPTIONS${NC}
    --output, -o <dir>      输出目录（默认同源文件目录）
    --style, -s <style>     风格提示（illustration, flat design, watercolor...）
    --size <WxH>            尺寸（1024x1024 | 1792x1024 | 1024x1792）
    --backend, -b <name>    生成后端: gemini（免费默认）| together（\$0.003/张）| dalle（\$0.04/张）
    --describe              仅输出语义描述 prompt，不生成图片

${BOLD}EXAMPLES${NC}
    ae pm image-decopyright hero.png                          # 免费方案
    ae pm image-decopyright hero.png --backend dalle          # 高质量付费
    ae pm image-decopyright *.png --output ./safe/ --style illustration
    ae pm image-decopyright card.jpg --describe

${BOLD}ENVIRONMENT${NC}
    GEMINI_API_KEY       默认后端（describe + 生成，只需这一个）
    TOGETHER_API_KEY     together 后端（\$0.003/张）
    OPENAI_API_KEY       dalle 后端（\$0.04/张）
EOF
                return 0
                ;;
            *)
                images+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#images[@]} -eq 0 ]]; then
        err "请指定至少一张图片"
        echo "用法: ae pm image-decopyright <image...>"
        exit 1
    fi

    # Load credentials if available
    for cred in "$HOME/.config/ae/credentials.env" "$HOME/.config/ae-pm/credentials.env" "$HOME/.config/agentrunzo/credentials.env"; do
        [[ -f "$cred" ]] && source "$cred"
    done

    # Check API keys
    if [[ "$backend" == "gemini" && -z "${GEMINI_API_KEY:-}" ]]; then
        err "GEMINI_API_KEY 未配置。请设置："
        echo "  echo 'GEMINI_API_KEY=...' >> ~/.config/ae/credentials.env"
        exit 1
    fi
    if [[ "$backend" == "together" && -z "${TOGETHER_API_KEY:-}" ]]; then
        err "TOGETHER_API_KEY 未配置"
        exit 1
    fi
    if [[ "$backend" == "dalle" && -z "${OPENAI_API_KEY:-}" ]]; then
        err "OPENAI_API_KEY 未配置"
        exit 1
    fi

    # Find the script
    local script=""
    local candidates=(
        "$AE_CLI_DIR/lib/image_decopyrighter.py"
        "$AE_HOME/cli/lib/image_decopyrighter.py"
        "$(dirname "$AE_CLI_DIR")/lib/image_decopyrighter.py"
    )
    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            script="$c"
            break
        fi
    done

    if [[ -z "$script" ]]; then
        err "image_decopyrighter.py 未找到"
        exit 1
    fi

    local cmd_args=()

    if [[ "$mode" == "describe" ]]; then
        # Describe only — single image
        cmd_args=(describe "${images[0]}")
        [[ -n "$style" ]] && cmd_args+=(--style "$style")
    elif [[ ${#images[@]} -eq 1 ]]; then
        # Single image — auto mode
        cmd_args=(auto "${images[0]}" --backend "$backend")
        [[ -n "$output_dir" ]] && cmd_args+=(--output "$output_dir")
        [[ -n "$style" ]] && cmd_args+=(--style "$style")
        cmd_args+=(--size "$size")
    else
        # Multiple images — batch mode
        cmd_args=(batch "${images[@]}" --backend "$backend")
        [[ -n "$output_dir" ]] && cmd_args+=(--output "$output_dir")
        [[ -n "$style" ]] && cmd_args+=(--style "$style")
        cmd_args+=(--size "$size")
    fi

    local backend_label="Gemini/Imagen 4.0 (免费)"
    [[ "$backend" == "together" ]] && backend_label="Together/Flux ($0.003/张)"
    [[ "$backend" == "dalle" ]] && backend_label="DALL-E 3 ($0.04/张)"
    info "执行图片去版权化 [${backend_label}]..."
    python3 "$script" "${cmd_args[@]}"
}

# ── Skill runner ──────────────────────────────────────────────────

_pm_run_skill() {
    local skill_name="$1"
    shift

    local skill_file="$AE_HOME/pm/.claude/skills/${skill_name}/SKILL.md"

    # Check ae-pm is installed
    if [[ ! -d "$AE_HOME/pm" ]]; then
        err "ae-pm 未安装。运行 ${BOLD}ae install${NC} 先安装。"
        exit 1
    fi

    # Check skill exists
    if [[ ! -f "$skill_file" ]]; then
        err "Skill 不存在: $skill_name"
        echo "可用的 PM skills:"
        for d in "$AE_HOME/pm/.claude/skills/"*/; do
            [[ -f "$d/SKILL.md" ]] && echo "  - $(basename "$d")"
        done
        exit 1
    fi

    # Check if Claude Code is available
    if command -v claude &>/dev/null; then
        info "通过 Claude Code 执行 /${skill_name}..."
        echo ""

        # Build prompt with skill context and arguments
        local prompt="请执行 /${skill_name} skill"
        if [[ $# -gt 0 ]]; then
            prompt="$prompt，目标: $*"
        fi

        claude --print "$prompt"
    else
        # Fallback: show skill content for manual execution
        warn "Claude Code 未安装，显示 skill 内容供手动执行:"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$skill_file"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        info "将上述流程粘贴到你的 AI 编码工具中执行。"
    fi
}
