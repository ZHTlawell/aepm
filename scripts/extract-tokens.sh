#!/bin/bash
# extract-tokens.sh
# 从 Web SPA 的 CSS 中提取 design tokens，输出结构化 JSON
#
# 用法: ./scripts/extract-tokens.sh <demo_dir> [output_file]
#   demo_dir    - Demo 项目目录（包含 CSS 文件）
#   output_file - 输出 JSON 路径（默认 stdout）
#
# 输出 JSON 结构:
#   {
#     "type": "web",
#     "colors": { "bg-primary": { "raw": "#000000", "rgb01": [0.00, 0.00, 0.00] } },
#     "radius": { "sm": "10px" },
#     "fonts":  { "primary": "..." },
#     "effects": { "shadow-card": "..." },
#     "canvas": { "width": 430, "height": 932 }
#   }
#
# 示例:
#   ./scripts/extract-tokens.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www
#   ./scripts/extract-tokens.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www /tmp/tokens.json

set -euo pipefail

DEMO_DIR="${1:?用法: $0 <demo_dir> [output_file]}"
OUTPUT="${2:-}"

# ── 查找 CSS 文件 ──────────────────────────────────────────
CSS_FILES=$(find "$DEMO_DIR" -name '*.css' -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)
if [ -z "$CSS_FILES" ]; then
  echo "ERROR: 未找到 CSS 文件: $DEMO_DIR" >&2
  exit 1
fi

# ── 用 awk 一次性提取 :root 变量并分类输出 JSON ───────────────
# awk 脚本：解析 :root 块，提取 --var: value，按类别分组，输出 JSON
OUTPUT_JSON=$(cat $CSS_FILES | awk '
BEGIN {
  in_root = 0
  depth = 0
  nc = 0; nr = 0; nf = 0; ne = 0; no = 0
  canvas_w = 430
}

# 检测 :root {
/:root/ && /{/ {
  in_root = 1
  depth = 1
  next
}

in_root {
  # 跟踪花括号深度
  for (i = 1; i <= length($0); i++) {
    c = substr($0, i, 1)
    if (c == "{") depth++
    if (c == "}") depth--
  }
  if (depth <= 0) { in_root = 0; next }

  # 匹配 --var-name: value;
  if ($0 ~ /--[a-zA-Z][a-zA-Z0-9_-]*[[:space:]]*:/) {
    # 提取变量名
    line = $0
    sub(/^[[:space:]]*/, "", line)
    idx = index(line, ":")
    varname = substr(line, 1, idx - 1)
    sub(/[[:space:]]*$/, "", varname)

    # 提取值
    value = substr(line, idx + 1)
    sub(/^[[:space:]]*/, "", value)
    sub(/;[[:space:]]*$/, "", value)
    sub(/[[:space:]]*$/, "", value)

    # 跳过 var() 别名
    if (value ~ /^var\(/) next

    # 去掉 -- 前缀
    key = varname
    sub(/^--/, "", key)

    # 颜色转换函数
    rgb01 = ""
    if (value ~ /^#[0-9a-fA-F]+$/) {
      hex = value
      sub(/^#/, "", hex)
      if (length(hex) == 3) {
        hex = substr(hex,1,1) substr(hex,1,1) substr(hex,2,1) substr(hex,2,1) substr(hex,3,1) substr(hex,3,1)
      }
      # 手动 hex → decimal
      r = hex2dec(substr(hex, 1, 2))
      g = hex2dec(substr(hex, 3, 2))
      b = hex2dec(substr(hex, 5, 2))
      rgb01 = sprintf("%.2f, %.2f, %.2f", r/255, g/255, b/255)
    } else if (value ~ /^rgba?\(/) {
      # 提取数字：去掉非数字/逗号/点字符，按逗号分割
      tmp = value
      gsub(/[^0-9.,]/, "", tmp)
      n = split(tmp, nums, ",")
      if (n >= 3) {
        r = nums[1]+0; g = nums[2]+0; b = nums[3]+0
        if (n >= 4 && nums[4]+0 > 0) {
          rgb01 = sprintf("%.2f, %.2f, %.2f, %s", r/255, g/255, b/255, nums[4])
        } else {
          rgb01 = sprintf("%.2f, %.2f, %.2f", r/255, g/255, b/255)
        }
      }
    }

    # 转义 value 中的双引号和反斜杠
    gsub(/\\/, "\\\\", value)
    gsub(/"/, "\\\"", value)

    # 分类
    if (key ~ /^(bg-|text-|accent-|separator|gradient-)/) {
      nc++
      if (rgb01 != "") {
        colors[nc] = sprintf("    \"%s\": { \"raw\": \"%s\", \"rgb01\": [%s] }", key, value, rgb01)
      } else {
        colors[nc] = sprintf("    \"%s\": { \"raw\": \"%s\" }", key, value)
      }
    } else if (key ~ /^radius/) {
      nr++
      radius[nr] = sprintf("    \"%s\": \"%s\"", key, value)
    } else if (key ~ /^font/) {
      nf++
      fonts[nf] = sprintf("    \"%s\": \"%s\"", key, value)
    } else if (key ~ /^(shadow-|glass-|transition)/) {
      ne++
      effects[ne] = sprintf("    \"%s\": \"%s\"", key, value)
    } else {
      no++
      others[no] = sprintf("    \"%s\": \"%s\"", key, value)
    }
  }
}

# 提取画布宽度
# 只取第一个 max-width（通常在 #app 或 body 中定义画布宽度）
!canvas_found && /max-width:[[:space:]]*[0-9]+px/ {
  tmp = $0
  sub(/.*max-width:[[:space:]]*/, "", tmp)
  sub(/px.*/, "", tmp)
  if (tmp+0 >= 320) { canvas_w = tmp+0; canvas_found = 1 }
}

function hex2dec(h,  result, i, c, v) {
  result = 0
  h = tolower(h)
  for (i = 1; i <= length(h); i++) {
    c = substr(h, i, 1)
    if (c >= "0" && c <= "9") v = c + 0
    else if (c == "a") v = 10
    else if (c == "b") v = 11
    else if (c == "c") v = 12
    else if (c == "d") v = 13
    else if (c == "e") v = 14
    else if (c == "f") v = 15
    else v = 0
    result = result * 16 + v
  }
  return result
}

function print_section(arr, n,  i) {
  for (i = 1; i <= n; i++) {
    printf "%s", arr[i]
    if (i < n) printf ","
    printf "\n"
  }
}

END {
  print "{"
  print "  \"type\": \"web\","

  print "  \"colors\": {"
  print_section(colors, nc)
  print "  },"

  print "  \"radius\": {"
  print_section(radius, nr)
  print "  },"

  print "  \"fonts\": {"
  print_section(fonts, nf)
  print "  },"

  print "  \"effects\": {"
  print_section(effects, ne)
  print "  },"

  print "  \"others\": {"
  print_section(others, no)
  print "  },"

  printf "  \"canvas\": { \"width\": %d, \"height\": 932 }\n", canvas_w
  print "}"
}
')

if [ -n "$OUTPUT" ]; then
  echo "$OUTPUT_JSON" > "$OUTPUT"
  echo "tokens 已输出到: $OUTPUT" >&2
else
  echo "$OUTPUT_JSON"
fi
