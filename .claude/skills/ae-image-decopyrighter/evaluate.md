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
- **日期**: 2026-04-13
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 34.7s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 单张图片基础去版权化 | 1/5 | 34.6s | 输出为空，无法判断执行情况 | 未产生任何可见输出，可能静默失败；未展示 Read 原图、调用 auto、验证结果等任何预期步骤 |
| 指定风格和后端的批量处理 | 3/5 | 44.1s | 测试环境缺少素材 | 正确识别 marketing/ 不存在并列出目录内容，友好引导用户提供路径；但未检查 together API key 可用性 |
| 图片路径不存在或 API Key 未配置 | 3/5 | 15.0s | 仅覆盖一半测试意图 | 文件不存在的检测和提示清晰准确；但未主动检查 GEMINI_API_KEY 配置状态和提示配置方法，漏掉了预期行为的另一半 |
| 生成质量验证 | 0/5 | 55.7s | 陷入循环，达到 max turns | 触发 max turns (10) 限制后崩溃退出；疑似在文件不存在时反复重试而非优雅退出，暴露了缺乏循环保护的问题 |
| 分步执行与手动修改 prompt | 3/5 | 24.3s | 测试环境缺少素材 | 正确检测文件不存在并引导用户；但无法验证 describe 分步流程是否能正确执行——核心能力未被测试到 |

## 瓶颈分析
- **测试环境缺少素材是最大盲区**：5 个 story 中没有一个成功执行到核心的图片处理流程（describe → generate → verify），所有测试本质上只验证了错误处理路径。建议在测试环境中预置真实测试图片（assets/hero-banner.png、assets/shoe-product.png、assets/card.png、marketing/*.png），否则无法评估 skill 的实际能力。
- **缺乏 max turns 保护机制**：Story 4 陷入 10 轮循环后崩溃，说明 skill 在遇到持续性障碍时没有 early exit 策略。应在检测到文件不存在或 API 调用连续失败时，至多重试 1 次就向用户报告并停止。
- **API Key 检查缺失**：SKILL.md 明确将 GEMINI_API_KEY 列为前置条件并定义了 smoke_test，但实际执行时 skill 没有在 Step 1 前主动验证 key 是否就绪。建议在流程最前端加入 credential check gate。

## 结论
当前 skill 的错误处理路径基本可用（文件不存在时能友好提示），但核心的图片去版权化能力因测试环境缺少素材而完全未被验证，加上 Story 1 静默无输出和 Story 4 循环崩溃暴露了鲁棒性问题——**建议优先补全测试素材后重新评估，同时修复 max turns 保护和 API key 前置检查**。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | 1/5 (20%) | 34.7s |
