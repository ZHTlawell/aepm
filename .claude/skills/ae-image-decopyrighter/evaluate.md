# ae-image-decopyrighter 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-image-decopyrighter

## Test Stories

### Story 1: 单张图片基础去版权化
- **Prompt**: "帮我把这张图片去版权化：assets/hero-banner.png"
- **Expect**: Skill 确认输入图片路径，用 Read 工具查看原图并向用户描述内容，调用 `image_decopyrighter.py auto` 生成新图片，用 Read 查看生成结果并对比原图（语义一致、视觉差异、品牌清除），最终输出包含原图/新图对照表和输出路径的报告。
- **Max Time**: 120s

### Story 2: 指定风格和后端的批量处理
- **Prompt**: "把 marketing/ 目录下的 3 张产品图都去版权化，用插画风格，后端用 together"
- **Expect**: Skill 识别批量处理需求，使用 `batch` 命令配合 `--style illustration --backend together` 参数处理多张图片，每张图片都进行语义一致性验证，输出包含所有图片对照的完整报告和输出目录。
- **Max Time**: 180s

### Story 3: 图片路径不存在或 API Key 未配置
- **Prompt**: "去版权化这张图：/tmp/not-exist.png"
- **Expect**: Skill 检测到图片路径不存在时，明确告知用户文件不存在并请求提供正确路径。若 GEMINI_API_KEY 未配置，应提示用户配置方法（写入 `~/.config/ae/credentials.env`），不应直接报错崩溃。
- **Max Time**: 30s

### Story 4: 生成质量验证——语义一致性与视觉差异
- **Prompt**: "帮我去版权化 assets/shoe-product.png，这是一张运动鞋产品图，要保持运动鞋的主题"
- **Expect**: Skill 在 Step 2 查看原图时准确识别出运动鞋主题，Step 3 生成后在 Step 4 进行四项检查（语义一致、视觉差异、品牌清除、质量可用），如果生成结果语义偏差大应主动建议用 `describe` 分步执行或调整风格重试，最终报告中包含版权安全提示。
- **Max Time**: 120s

### Story 5: 分步执行与手动修改 prompt
- **Prompt**: "先帮我提取 assets/card.png 的语义描述，我看看 prompt 再决定要不要修改"
- **Expect**: Skill 识别用户要求分步执行，调用 `describe` 命令提取语义 prompt 并展示给用户，等待用户确认或修改后再调用 `generate` 生成图片。整个流程体现与用户的交互协作，不应一步直接执行 `auto` 命令。
- **Max Time**: 90s

## 最近一次评估
（待执行）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
（待执行）

## 瓶颈分析
（待执行）

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
