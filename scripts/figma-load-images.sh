#!/bin/bash
# figma-load-images.sh
# 将本地图片批量加载到 Figma 节点（生成可直接粘贴到 use_figma 的 JS 代码）
#
# 用法:
#   ./scripts/figma-load-images.sh <mapping_file> [output_dir]
#
# mapping_file 格式（每行一条，tab 分隔）:
#   /path/to/image.png	2:20
#   /path/to/image2.png	2:25
#
# 输出: output_dir 下生成 batch_1.js, batch_2.js, ... 每个文件可直接作为 use_figma 的 code 参数
#
# 约束:
#   - 图片统一 resize 到 140x140 JPEG q65（base64 ≈ 5-6K chars，Plugin API 安全上限）
#   - 每批最多 2 张图（避免 use_figma code 参数过长）

set -e

MAPPING="${1:?用法: $0 <mapping_file> [output_dir]}"
OUTDIR="${2:-/tmp/figma-image-batches}"
TMPDIR="/tmp/figma-img-prep"
SIZE=140
QUALITY=65
BATCH_SIZE=2
MAX_B64=6000

mkdir -p "$OUTDIR" "$TMPDIR"

# base64 解码器（Plugin API 无 atob，需内联）
DECODER='function decodeBase64(str) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
  let output = [];
  let i = 0;
  str = str.replace(/[^A-Za-z0-9\\+\\/\\=]/g, "");
  while (i < str.length) {
    const e1 = chars.indexOf(str.charAt(i++));
    const e2 = chars.indexOf(str.charAt(i++));
    const e3 = chars.indexOf(str.charAt(i++));
    const e4 = chars.indexOf(str.charAt(i++));
    output.push((e1 << 2) | (e2 >> 4));
    if (e3 !== 64) output.push(((e2 & 15) << 4) | (e3 >> 2));
    if (e4 !== 64) output.push(((e3 & 3) << 6) | e4);
  }
  return new Uint8Array(output);
}'

echo "=== Figma Image Loader ==="
echo "Mapping: $MAPPING"
echo "Output:  $OUTDIR"
echo ""

# Step 1: 预处理所有图片
IMAGES=()
NODES=()
B64S=()
IDX=0

while IFS=$'\t' read -r img_path node_id; do
  [ -z "$img_path" ] && continue
  [[ "$img_path" == \#* ]] && continue

  IDX=$((IDX + 1))
  OUT_JPG="$TMPDIR/img_${IDX}.jpg"

  # Resize + JPEG 压缩
  sips -z $SIZE $SIZE --setProperty format jpeg --setProperty formatOptions $QUALITY \
    "$img_path" --out "$OUT_JPG" >/dev/null 2>&1

  # Base64 编码
  B64=$(base64 -i "$OUT_JPG" | tr -d '\n')
  B64_LEN=${#B64}

  if [ "$B64_LEN" -gt "$MAX_B64" ]; then
    echo "WARNING: $img_path → ${B64_LEN} chars (> ${MAX_B64}), 尝试降低质量..."
    sips -z 120 120 --setProperty format jpeg --setProperty formatOptions 50 \
      "$img_path" --out "$OUT_JPG" >/dev/null 2>&1
    B64=$(base64 -i "$OUT_JPG" | tr -d '\n')
    B64_LEN=${#B64}
  fi

  echo "  [$IDX] $(basename "$img_path") → node $node_id (${B64_LEN} chars)"

  IMAGES+=("$img_path")
  NODES+=("$node_id")
  B64S+=("$B64")
done < "$MAPPING"

TOTAL=${#IMAGES[@]}
echo ""
echo "共 $TOTAL 张图片，分 $(( (TOTAL + BATCH_SIZE - 1) / BATCH_SIZE )) 批"
echo ""

# Step 2: 生成批次 JS 文件
BATCH_NUM=0
for ((i=0; i<TOTAL; i+=BATCH_SIZE)); do
  BATCH_NUM=$((BATCH_NUM + 1))
  JS_FILE="$OUTDIR/batch_${BATCH_NUM}.js"

  {
    echo "$DECODER"
    echo ""

    # 本批次的图片
    COUNT=0
    for ((j=i; j<i+BATCH_SIZE && j<TOTAL; j++)); do
      COUNT=$((COUNT + 1))
      echo "const B${COUNT} = \"${B64S[$j]}\";"
    done
    echo ""

    # 创建 Image 对象
    for ((k=1; k<=COUNT; k++)); do
      echo "const img${k} = figma.createImage(decodeBase64(B${k}));"
    done
    echo ""

    # 获取节点并赋值
    K=0
    for ((j=i; j<i+BATCH_SIZE && j<TOTAL; j++)); do
      K=$((K + 1))
      echo "const n${K} = figma.getNodeById(\"${NODES[$j]}\");"
      echo "if (n${K}) n${K}.fills = [{ type: \"IMAGE\", imageHash: img${K}.hash, scaleMode: \"FILL\" }];"
    done
    echo ""

    # 返回结果
    RETURN_PARTS=""
    for ((k=1; k<=COUNT; k++)); do
      [ -n "$RETURN_PARTS" ] && RETURN_PARTS="${RETURN_PARTS} + \", \" + "
      RETURN_PARTS="${RETURN_PARTS}\"${NODES[$((i+k-1))]}=\" + img${k}.hash.substring(0,8)"
    done
    echo "return ${RETURN_PARTS};"

  } > "$JS_FILE"

  echo "  batch_${BATCH_NUM}.js → nodes: ${NODES[@]:$i:$BATCH_SIZE}"
done

echo ""
echo "=== 完成 ==="
echo "生成了 $BATCH_NUM 个批次文件在 $OUTDIR/"
echo ""
echo "使用方式："
echo "  对每个 batch_N.js，调用 mcp__figma__use_figma:"
echo "    fileKey: <your_file_key>"
echo "    code: <paste batch_N.js content>"
echo "    description: \"Load images batch N\""
