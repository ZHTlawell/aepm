#!/bin/bash
# demo-to-figma-prepare.sh
# Demo→Figma 预处理管线：在 LLM 介入前完成所有确定性工作
#
# 用法: ./scripts/demo-to-figma-prepare.sh <demo_dir> [output_dir]
#   demo_dir   - Demo 项目目录
#   output_dir - 输出目录（默认 /tmp/figma-prepare）
#
# 输出目录结构:
#   output_dir/
#   ├── pages.json      — 页面清单（名称、入口、render 函数）
#   ├── tokens.json     — Design tokens（颜色 rgb01、圆角、字体、效果）
#   ├── images.json     — 图片引用清单（路径、是否存在）
#   ├── svgs.json       — SVG 图标清单（内联 content + 文件引用）
#   ├── images/         — 图片 base64 编码文件（可选，加 --with-b64）
#   │   ├── img_001.b64
#   │   ├── img_002.b64
#   │   └── manifest.json
#   └── summary.json    — 汇总摘要
#
# 选项:
#   --with-b64  同时下载压缩图片并 base64 编码（耗时较长）
#
# 示例:
#   ./scripts/demo-to-figma-prepare.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www
#   ./scripts/demo-to-figma-prepare.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www /tmp/shoelens-prep --with-b64

set -euo pipefail

# ── 参数解析 ──────────────────────────────────────────────
DEMO_DIR=""
OUTPUT_DIR=""
WITH_B64=0

for arg in "$@"; do
  case "$arg" in
    --with-b64) WITH_B64=1 ;;
    *)
      if [ -z "$DEMO_DIR" ]; then
        DEMO_DIR="$arg"
      elif [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$arg"
      fi
      ;;
  esac
done

DEMO_DIR="${DEMO_DIR:?用法: $0 <demo_dir> [output_dir] [--with-b64]}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/figma-prepare}"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════════════════╗"
echo "║   Demo → Figma 预处理管线                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Demo:   $DEMO_DIR"
echo "  Output: $OUTPUT_DIR"
echo "  Base64: $([ $WITH_B64 -eq 1 ] && echo '是' || echo '否（加 --with-b64 启用）')"
echo ""

mkdir -p "$OUTPUT_DIR"

# ── Step 1: 页面发现 ─────────────────────────────────────
echo "━━━ [1/4] 页面发现 ━━━"
"$SCRIPT_DIR/discover-pages.sh" "$DEMO_DIR" "$OUTPUT_DIR/pages.json"
page_count=$(grep -o '"page_count"' "$OUTPUT_DIR/pages.json" | wc -l | tr -d ' ')
# 从 JSON 提取 page_count 值
page_count=$(sed -n 's/.*"page_count": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/pages.json")
echo "  ✓ 发现 ${page_count} 个页面 → pages.json"
echo ""

# ── Step 2: Design Token 提取 ────────────────────────────
echo "━━━ [2/4] Design Token 提取 ━━━"
"$SCRIPT_DIR/extract-tokens.sh" "$DEMO_DIR" "$OUTPUT_DIR/tokens.json"
# 统计各类 token 数量
color_count=$(grep -c '"rgb01"' "$OUTPUT_DIR/tokens.json" 2>/dev/null || echo "0")
radius_count=$(grep -c '"radius-' "$OUTPUT_DIR/tokens.json" 2>/dev/null || echo "0")
echo "  ✓ ${color_count} 个颜色 + ${radius_count} 个圆角 → tokens.json"
echo ""

# ── Step 3: 图片提取 ─────────────────────────────────────
echo "━━━ [3/4] 图片引用提取 ━━━"
if [ $WITH_B64 -eq 1 ]; then
  "$SCRIPT_DIR/extract-images.sh" "$DEMO_DIR" "$OUTPUT_DIR/images" > "$OUTPUT_DIR/images.json"
else
  "$SCRIPT_DIR/extract-images.sh" "$DEMO_DIR" > "$OUTPUT_DIR/images.json"
fi
image_count=$(sed -n 's/.*"image_count": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/images.json")
echo "  ✓ ${image_count} 张图片 → images.json"
echo ""

# ── Step 4: SVG 提取 ─────────────────────────────────────
echo "━━━ [4/4] SVG 图标提取 ━━━"
"$SCRIPT_DIR/extract-svgs.sh" "$DEMO_DIR" "$OUTPUT_DIR/svgs.json"
svg_count=$(sed -n 's/.*"svg_count": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/svgs.json")
inline_count=$(sed -n 's/.*"inline_count": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/svgs.json")
file_count=$(sed -n 's/.*"file_count": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/svgs.json")
echo "  ✓ ${svg_count} 个 SVG（${inline_count} 内联 + ${file_count} 文件）→ svgs.json"
echo ""

# ── 生成汇总 ─────────────────────────────────────────────
canvas_w=$(sed -n 's/.*"width": *\([0-9]*\).*/\1/p' "$OUTPUT_DIR/tokens.json" | head -1)
project_type=$(sed -n 's/.*"type": *"\([^"]*\)".*/\1/p' "$OUTPUT_DIR/tokens.json" | head -1)

cat > "$OUTPUT_DIR/summary.json" <<ENDJSON
{
  "project_type": "${project_type}",
  "demo_dir": "${DEMO_DIR}",
  "canvas": { "width": ${canvas_w:-430}, "height": 932 },
  "page_count": ${page_count:-0},
  "color_count": ${color_count:-0},
  "radius_count": ${radius_count:-0},
  "image_count": ${image_count:-0},
  "svg_count": ${svg_count:-0},
  "files": {
    "pages": "pages.json",
    "tokens": "tokens.json",
    "images": "images.json",
    "svgs": "svgs.json"
  }
}
ENDJSON

echo "╔══════════════════════════════════════════════════╗"
echo "║   预处理完成                                     ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  类型:  ${project_type:-web}                     "
echo "║  画布:  ${canvas_w:-430}×932                     "
echo "║  页面:  ${page_count:-0} 个                      "
echo "║  颜色:  ${color_count:-0} 个 (含 rgb01 转换)     "
echo "║  圆角:  ${radius_count:-0} 个                    "
echo "║  图片:  ${image_count:-0} 张                     "
echo "║  SVG:   ${svg_count:-0} 个                       "
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "输出目录: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.json
echo ""
echo "LLM 可直接读取以上 JSON 文件，专注于结构映射和节点生成。"
