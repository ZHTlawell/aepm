#!/bin/bash
# extract-svgs.sh
# 从 Demo 源码中提取内联 SVG 图标，输出 JSON 清单
#
# 用法: ./scripts/extract-svgs.sh <demo_dir> [output_file]
#   demo_dir    - Demo 项目目录
#   output_file - 输出 JSON 路径（默认 stdout）
#
# 提取策略:
#   1. JS 文件中的 SVG 字符串常量（`<svg ...>...</svg>`）
#   2. HTML 文件中的内联 SVG
#   3. 独立 SVG 文件引用
#
# 输出 JSON 结构:
#   {
#     "svg_count": 5,
#     "inline_svgs": [ { "id": "icon-home", "source": "app.js", "content": "<svg...>" } ],
#     "svg_files": [ { "src": "icons/home.svg", "exists": true } ]
#   }
#
# 示例:
#   ./scripts/extract-svgs.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www

set -euo pipefail

DEMO_DIR="${1:?用法: $0 <demo_dir> [output_file]}"
OUTPUT="${2:-}"

# ── 查找源文件 ────────────────────────────────────────────
SRC_FILES=$(find "$DEMO_DIR" \( -name '*.html' -o -name '*.js' -o -name '*.jsx' -o -name '*.tsx' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)

# ── 提取内联 SVG ─────────────────────────────────────────
# 用 awk 提取完整的 <svg ...>...</svg> 块，处理跨行情况
extract_inline_svgs() {
  [ -z "$SRC_FILES" ] && return

  awk '
  BEGIN { idx = 0; collecting = 0; svg = "" }

  # 单行 SVG
  /<svg[^>]*>.*<\/svg>/ && !collecting {
    match($0, /<svg[^>]*>.*<\/svg>/)
    content = substr($0, RSTART, RLENGTH)
    idx++
    # 尝试提取 id 或 class 作为名称
    name = "svg_" idx
    if (match(content, /class="[^"]*"/)) {
      tmp = substr(content, RSTART+7, RLENGTH-8)
      gsub(/[[:space:]]/, "-", tmp)
      name = tmp
    }
    # JSON 转义 content
    gsub(/\\/, "\\\\", content)
    gsub(/"/, "\\\"", content)
    gsub(/\t/, " ", content)
    printf "%s\t%s\t%s\n", name, FILENAME, content
    next
  }

  # 多行 SVG 开始
  /<svg[^>]*>/ && !collecting {
    collecting = 1
    svg = ""
    line_start = FNR
  }

  collecting {
    svg = svg $0 " "
  }

  # 多行 SVG 结束
  collecting && /<\/svg>/ {
    collecting = 0
    idx++
    content = svg
    name = "svg_" idx
    if (match(content, /class="[^"]*"/)) {
      tmp = substr(content, RSTART+7, RLENGTH-8)
      gsub(/[[:space:]]/, "-", tmp)
      name = tmp
    }
    gsub(/\\/, "\\\\", content)
    gsub(/"/, "\\\"", content)
    gsub(/\t/, " ", content)
    # 压缩多余空格
    gsub(/[[:space:]]+/, " ", content)
    printf "%s\t%s\t%s\n", name, FILENAME, content
  }
  ' $SRC_FILES 2>/dev/null || true
}

# ── 提取 SVG 文件引用 ────────────────────────────────────
extract_svg_file_refs() {
  [ -z "$SRC_FILES" ] && return

  {
    # src="xxx.svg"
    grep -hoE 'src="[^"]*\.svg"' $SRC_FILES 2>/dev/null | sed -E 's/src="(.*)"/\1/' || true
    grep -hoE "src='[^']*\.svg'" $SRC_FILES 2>/dev/null | sed -E "s/src='(.*)'/\1/" || true

    # url('xxx.svg') in CSS
    local css_files
    css_files=$(find "$DEMO_DIR" -name '*.css' -not -path '*/node_modules/*' 2>/dev/null || true)
    if [ -n "$css_files" ]; then
      grep -hoE "url\(['\"]?[^)]*\.svg['\"]?\)" $css_files 2>/dev/null | \
        sed -E "s/url\(['\"]?([^)'\"]*)['\"]?\)/\1/" || true
    fi
  } | sort -u
}

# ── 查找独立 SVG 文件 ────────────────────────────────────
find_svg_files() {
  find "$DEMO_DIR" -name '*.svg' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | \
    while IFS= read -r f; do
      # 输出相对路径
      echo "${f#$DEMO_DIR/}"
    done | sort
}

# ── 构建 JSON ────────────────────────────────────────────
INLINE_SVGS=$(extract_inline_svgs)
SVG_REFS=$(extract_svg_file_refs)
SVG_FILES=$(find_svg_files)

# 内联 SVG JSON
inline_json=""
inline_count=0
if [ -n "$INLINE_SVGS" ]; then
  while IFS=$'\t' read -r name source content; do
    [ -z "$name" ] && continue
    source_basename=$(basename "$source")
    [ $inline_count -gt 0 ] && inline_json="${inline_json},"
    inline_json="${inline_json}
    { \"id\": \"${name}\", \"source\": \"${source_basename}\", \"content\": \"${content}\" }"
    inline_count=$((inline_count + 1))
  done <<< "$INLINE_SVGS"
fi

# SVG 文件 JSON
files_json=""
files_count=0

# 合并引用和实际文件
all_svgs=""
[ -n "$SVG_REFS" ] && all_svgs="$SVG_REFS"
[ -n "$SVG_FILES" ] && all_svgs="${all_svgs}"$'\n'"${SVG_FILES}"
all_svgs=$(echo "$all_svgs" | sort -u)

if [ -n "$all_svgs" ]; then
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in http://*|https://*|data:*) continue ;; esac

    exists="false"
    abs="$DEMO_DIR/$ref"
    [ -f "$abs" ] && exists="true"

    [ $files_count -gt 0 ] && files_json="${files_json},"
    files_json="${files_json}
    { \"src\": \"${ref}\", \"exists\": ${exists} }"
    files_count=$((files_count + 1))
  done <<< "$all_svgs"
fi

total=$((inline_count + files_count))

RESULT=$(cat <<ENDJSON
{
  "svg_count": ${total},
  "inline_count": ${inline_count},
  "file_count": ${files_count},
  "inline_svgs": [${inline_json}
  ],
  "svg_files": [${files_json}
  ]
}
ENDJSON
)

if [ -n "$OUTPUT" ]; then
  echo "$RESULT" > "$OUTPUT"
  echo "svgs 已输出到: $OUTPUT" >&2
else
  echo "$RESULT"
fi
