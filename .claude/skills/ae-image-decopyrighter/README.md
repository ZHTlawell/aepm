# ae-image-decopyrighter

> 填补 0.1 产品从 demo 走向发布时的图片版权合规 gap，将有版权风险的占位素材一键替换为 AI 生成的可商用替代。

## 问题陈述

PM 在 vibe coding 阶段大量使用网络图片作为 demo 占位素材（Unsplash、Google 搜图、竞品截图），但发布上架时面临版权风险：

1. **版权追溯风险** — 网络图片即使标注"免费"，实际版权状态复杂（CC 协议限制、来源不可追溯），一旦被追诉赔偿金额高
2. **人工替换低效** — PM 需要逐张去图库找替代素材，匹配原图的语义（运动场景→运动场景），耗时且容易遗漏
3. **语义偏移** — 随意替换可能导致图片含义变化（原图是跑步卡片，替换后变成瑜伽卡片），影响产品一致性

## 解决方案

两步 AI 管线：**Gemini 2.5 Flash Vision 提取语义 → Imagen 4.0 重绘生成**。

核心机制：
- **语义提取 + 版权清洗** — Gemini Vision 读取原图，输出纯描述性 prompt（去除品牌、logo、人名等版权元素）
- **多后端生成** — 默认 Gemini/Imagen 4.0（免费），可选 Together AI（Flux，$0.003/张）和 DALL-E 3（$0.04/张，最高质量）
- **批量处理** — 支持一次处理多张图片，自动命名 `*_decopyrighted.png`
- **元数据追踪** — 每张生成图附带 `.meta.json`，记录原图路径、生成 prompt、后端、时间戳，便于审计

工具脚本 `image_decopyrighter.py` 封装了完整管线，skill 调用脚本即可，不需要 PM 理解底层 API。

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 语义提取用 VLM | Gemini 2.5 Flash Vision | 免费、速度快、中文理解好，且与生成后端同一个 API Key | Claude Vision — 需要额外 API Key，且 Gemini Flash 对图片描述的细节更丰富 |
| 默认生成后端 | Gemini/Imagen 4.0 | 免费层 50 张/天，0.1 产品阶段足够。全程只需一个 GEMINI_API_KEY | DALL-E 3 — 质量最好但 $0.04/张，批量处理成本高 |
| 多后端可切换 | gemini / together / dalle | 不同场景需求不同：免费验证用 gemini，高质量发布用 dalle，性价比用 together | 只支持一个后端 — 无法适应不同阶段和预算 |
| 两步管线 vs 端到端 | describe → generate 分离 | PM 可以在中间审核/修改 prompt，避免语义偏移。也方便 debug：prompt 不对改 prompt，图不好改后端 | 端到端（图片直接进图片出）— 不可控，出错时无法定位是理解问题还是生成问题 |
| HTTP 用 curl 不用 requests | subprocess curl | macOS 系统 Python 的 SSL 证书链经常有问题（urllib3 报 CERTIFICATE_VERIFY_FAILED），curl 走系统证书链更稳定 | requests/urllib3 — macOS 用户高概率遇到 SSL 错误 |
| 输出文件命名 | `{原名}_decopyrighted.{ext}` | 保持与原文件的对应关系，方便在项目中直接替换 | 随机命名 — 无法追溯来源 |

## 已放弃方案

### 方案 A: 在线图库搜索替代
- **是什么：** 通过 Unsplash/Pexels API 搜索语义相近的免费图片作为替代
- **为什么放弃：** 图库搜索结果与原图语义匹配度低（搜"运动卡片"返回的是运动照片，不是卡片 UI），且免费图库的版权状态并非绝对安全（有被撤销授权的案例）

### 方案 B: 图片风格迁移（Style Transfer）
- **是什么：** 保持原图构图，只改变视觉风格（如变成水彩/油画），规避版权
- **为什么放弃：** 风格迁移保留了原图的构图和布局，法律上仍可能被认定为"实质性相似"。AI 重新生成的图片与原图无像素级关联，版权风险更低

### 方案 C: Claude Vision 做语义提取
- **是什么：** 用 Claude 的 Vision 能力替代 Gemini Flash 做图片语义提取
- **为什么放弃：** 需要额外的 Anthropic API Key。PM 已经配了 GEMINI_API_KEY（ae-pm 基础配置之一），用 Gemini 做提取 + 生成全程只需一个 key，降低配置门槛

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| 语义提取 | Google Gemini 2.5 Flash Vision API | 图片→文本描述 | 版权元素清洗 prompt 工程（去除品牌/logo/人名） |
| 图片生成（默认） | Google Imagen 4.0 API | 文本→图片 | 与语义提取共用 API Key，PM 零配置 |
| 图片生成（备选） | Together AI Flux / OpenAI DALL-E 3 | 文本→图片 | 多后端切换封装，统一 CLI 接口 |
| CLI 工具 | 自建 image_decopyrighter.py | 100% 自建 | 两步管线封装、批量处理、元数据追踪 |

## FAQ

**Q: AI 生成的图片就没有版权问题了吗？**
A: AI 生成图片的版权状态在法律上仍有争议，但与直接使用他人版权图片相比，风险显著降低：(1) 没有明确的版权持有人可以追诉；(2) 与原图无像素级关联，无法被举证为复制。建议正式上线前仍做人工审核。

**Q: 免费层 50 张/天够用吗？**
A: 一个 0.1 产品通常有 5-15 张占位图，50 张/天绰绰有余。如果需要批量处理多个产品，可以分天执行，或切换到 Together AI（$0.003/张，几乎无上限）。

**Q: 生成的图和原图"长得太不一样"怎么办？**
A: 用 `describe` 命令单独提取 prompt，手动补充细节描述后再 `generate`。也可以指定风格（`--style illustration`）使输出更接近预期。图片去版权的核心原则是"保留含义，改变表现"，视觉差异是有意为之。

**Q: DALL-E 3 被内容策略拒绝了怎么办？**
A: DALL-E 3 对人物、暴力、品牌相关内容有严格限制。遇到拒绝时：(1) 修改 prompt 去除敏感元素；(2) 换 Gemini 或 Together 后端，它们的内容限制更宽松。

## 生命周期

- **填补的 gap：** PM vibe coding 阶段使用的网络占位图无法合规发布，人工逐张替换低效且容易语义偏移
- **什么会让它过时：** 当主流 AI 编码工具（Cursor、Claude Code）内置"生成可商用占位图"能力，或当版权安全的 AI 图库（如 Shutterstock AI）足够便宜且搜索精度足够高，PM 可以直接从图库获取素材而无需"去版权化"

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-03-26 | 首版。Claude Vision 提取语义 → DALL-E 3 生成，支持单张/批量 (#IHQQOZ) |
| v2.0 | 2026-04-07 | 重构。语义提取迁移到 Gemini 2.5 Flash Vision，默认生成后端改为 Imagen 4.0（免费），全程只需 GEMINI_API_KEY。新增 Together AI 后端。HTTP 层从 requests 改为 curl 规避 macOS SSL 问题 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：确认输入 → 查看原图 → 执行去版权化 → 验证结果 → 输出报告 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、生命周期 |
| cli/lib/pm/image_decopyrighter.py | 工具脚本：两步管线封装（describe + generate），支持 auto/batch/describe/generate 四种模式 |
