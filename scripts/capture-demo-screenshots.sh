#!/bin/bash
# capture-demo-screenshots.sh
# 自动截取 Demo 项目各页面截图，供 /demo-to-figma 自验证使用
#
# 用法: ./scripts/capture-demo-screenshots.sh <demo_dir> <output_dir> [pages...]
#   demo_dir  - Demo 项目的 www 目录（包含 HTML 文件）
#   output_dir - 截图输出目录
#   pages     - 可选，要截图的页面名称列表（默认自动发现所有 .html）
#
# 依赖: npx playwright (playwright CLI)
#
# 示例:
#   ./scripts/capture-demo-screenshots.sh \
#     ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www \
#     /tmp/demo-screenshots \
#     home category collection profile

set -e

DEMO_DIR="${1:?用法: $0 <demo_dir> <output_dir> [pages...]}"
OUTPUT_DIR="${2:?用法: $0 <demo_dir> <output_dir> [pages...]}"
shift 2
PAGES=("$@")

# 如果没有指定页面，自动发现所有 .html 文件（排除 index.html）
if [ ${#PAGES[@]} -eq 0 ]; then
  for f in "$DEMO_DIR"/*.html; do
    name=$(basename "$f" .html)
    if [ "$name" != "index" ]; then
      PAGES+=("$name")
    fi
  done
fi

echo "=== Demo 截图工具 ==="
echo "Demo 目录: $DEMO_DIR"
echo "输出目录: $OUTPUT_DIR"
echo "页面列表: ${PAGES[*]}"
echo ""

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 寻找一个可用端口
PORT=18765
while lsof -ti:$PORT >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done

# 启动本地服务器
echo "[1/3] 启动本地服务器 (端口 $PORT)..."
cd "$DEMO_DIR"
npx http-server -p $PORT -s &
SERVER_PID=$!
sleep 2

# 截图
echo "[2/3] 截取页面截图..."
for page in "${PAGES[@]}"; do
  echo "  截取: ${page}.html -> demo-${page}.png"
  npx playwright screenshot \
    --viewport-size="430,932" \
    --color-scheme=dark \
    --full-page \
    "http://localhost:${PORT}/${page}.html" \
    "${OUTPUT_DIR}/demo-${page}.png" 2>/dev/null
done

# 停止服务器
echo "[3/3] 停止服务器..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "=== 截图完成 ==="
ls -la "$OUTPUT_DIR"/demo-*.png
echo ""
echo "截图已保存到: $OUTPUT_DIR"
