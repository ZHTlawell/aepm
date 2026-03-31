#!/bin/bash
# extract-images.sh
# 从 Demo 源码中提取图片引用，检查本地文件存在性，输出清单 JSON
# 可选：下载/压缩为 Figma 可用的 base64 编码文件
#
# 用法:
#   ./scripts/extract-images.sh <demo_dir> [output_dir]
#   demo_dir   - Demo 项目目录
#   output_dir - 可选，指定后下载图片并 base64 编码到该目录
#
# 输出:
#   stdout → images.json（图片清单）
#   output_dir/ → 每张图片的 .b64 文件 + manifest.json
#
# 示例:
#   ./scripts/extract-images.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www
#   ./scripts/extract-images.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www /tmp/figma-images

set -euo pipefail

DEMO_DIR="${1:?用法: $0 <demo_dir> [output_dir]}"
OUTPUT_DIR="${2:-}"

# ── 从源码提取图片引用 ────────────────────────────────────
# 搜索 HTML/JS/CSS 中的图片路径
extract_image_refs() {
  local files
  files=$(find "$DEMO_DIR" \( -name '*.html' -o -name '*.js' -o -name '*.css' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)

  [ -z "$files" ] && return

  {
    # 模式 1: src="xxx.png/jpg/webp/gif"
    grep -hoE 'src="[^"]*\.(png|jpg|jpeg|webp|gif|svg)"' $files 2>/dev/null | \
      sed -E 's/src="(.*)"/\1/' || true

    # 模式 2: src='xxx.png/jpg/webp/gif'
    grep -hoE "src='[^']*\.(png|jpg|jpeg|webp|gif|svg)'" $files 2>/dev/null | \
      sed -E "s/src='(.*)'/\1/" || true

    # 模式 3: url('xxx') 或 url("xxx") 在 CSS 中
    grep -hoE "url\(['\"]?[^)]*\.(png|jpg|jpeg|webp|gif)['\"]?\)" $files 2>/dev/null | \
      sed -E "s/url\(['\"]?([^)'\"]*)['\"]?\)/\1/" || true

    # 模式 4: img: 'xxx.png' (JS data objects)
    grep -hoE "img:[[:space:]]*'[^']*\.(png|jpg|jpeg|webp|gif)'" $files 2>/dev/null | \
      sed -E "s/img:[[:space:]]*'(.*)'/\1/" || true

    # 模式 5: background-image: url(xxx)
    grep -hoE "background-image:[[:space:]]*url\(['\"]?[^)]*['\"]?\)" $files 2>/dev/null | \
      sed -E "s/.*url\(['\"]?([^)'\"]*)['\"]?\)/\1/" || true
  } | sort -u
}

# ── 解析引用并构建清单 ────────────────────────────────────
REFS=$(extract_image_refs)

if [ -z "$REFS" ]; then
  echo '{ "image_count": 0, "images": [] }'
  exit 0
fi

# 构建 JSON
count=0
images_json=""

while IFS= read -r ref; do
  [ -z "$ref" ] && continue

  # 跳过外部 URL（http/https）和 data URI
  case "$ref" in
    http://*|https://*|data:*) continue ;;
  esac

  # 跳过 SVG 文件（由 extract-svgs.sh 处理）
  case "$ref" in
    *.svg) continue ;;
  esac

  # 解析为绝对路径
  abs_path="$DEMO_DIR/$ref"
  exists="false"
  if [ -f "$abs_path" ]; then
    exists="true"
  fi

  # 提取文件名和用途推断
  filename=$(basename "$ref")
  dirname=$(dirname "$ref")

  [ $count -gt 0 ] && images_json="${images_json},"
  images_json="${images_json}
    { \"src\": \"${ref}\", \"exists\": ${exists}, \"filename\": \"${filename}\" }"
  count=$((count + 1))
done <<< "$REFS"

# 输出清单 JSON
echo "{
  \"image_count\": ${count},
  \"images\": [${images_json}
  ]
}"

# ── 可选：下载+压缩+base64 ────────────────────────────────
if [ -n "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
  echo "" >&2
  echo "=== 图片预处理 ===" >&2

  SIZE=140
  QUALITY=65
  MAX_B64=6000
  idx=0
  manifest=""

  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      http://*|https://*|data:*|*.svg) continue ;;
    esac

    abs_path="$DEMO_DIR/$ref"
    [ ! -f "$abs_path" ] && continue

    idx=$((idx + 1))
    out_name="img_$(printf '%03d' $idx)"
    out_jpg="$OUTPUT_DIR/${out_name}.jpg"
    out_b64="$OUTPUT_DIR/${out_name}.b64"

    # 压缩为小尺寸 JPEG
    sips -z $SIZE $SIZE --setProperty format jpeg --setProperty formatOptions $QUALITY \
      "$abs_path" --out "$out_jpg" >/dev/null 2>&1

    # Base64 编码
    b64=$(base64 -i "$out_jpg" | tr -d '\n')
    b64_len=${#b64}

    # 如果太大，进一步压缩
    if [ "$b64_len" -gt "$MAX_B64" ]; then
      sips -z 100 100 --setProperty format jpeg --setProperty formatOptions 50 \
        "$abs_path" --out "$out_jpg" >/dev/null 2>&1
      b64=$(base64 -i "$out_jpg" | tr -d '\n')
      b64_len=${#b64}
    fi

    echo "$b64" > "$out_b64"
    echo "  [${idx}] ${ref} → ${out_name}.b64 (${b64_len} chars)" >&2

    [ $idx -gt 1 ] && manifest="${manifest},"
    manifest="${manifest}
    { \"idx\": ${idx}, \"src\": \"${ref}\", \"b64_file\": \"${out_name}.b64\", \"b64_len\": ${b64_len} }"
  done <<< "$REFS"

  # 写 manifest
  echo "{
  \"count\": ${idx},
  \"images\": [${manifest}
  ]
}" > "$OUTPUT_DIR/manifest.json"

  echo "" >&2
  echo "=== 预处理完成: ${idx} 张图片 → $OUTPUT_DIR/ ===" >&2
fi
