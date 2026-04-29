# ae-demo-to-figma

> 填补"PM demo 原型与设计师 Figma 稿之间的人工翻译成本"的 gap，让 demo 代码自动转为设计师可直接编辑的 Figma 原生图层。

## 问题陈述

PM 用 vibe coding 生成 demo 后，设计师需要在 Figma 中从零重建 UI 才能开始精修。这个"代码到 Figma"的翻译过程纯粹是重复劳动：

1. 设计师看着 demo 截图，手动在 Figma 中搭建图层结构 -- 耗时数小时
2. 颜色、字体、间距等 design token 需要从代码中人工提取 -- 容易出错
3. 图层命名和分组不规范，后续修改效率低
4. 翻译过程中信息丢失（组件层级、布局关系等）

核心痛点：demo 代码中已经包含了完整的 UI 信息（颜色、布局、组件结构），但需要人工"翻译"成 Figma 图层，这个过程完全可以自动化。

## 解决方案

读取 demo 源码，通过 Figma MCP（Plugin API）程序化创建原生 Figma 节点，输出设计师可直接编辑的设计稿：

1. **预处理管线** -- 5 个 bash 脚本将确定性提取工作前置完成（页面发现、design token 提取、图片/SVG 引用提取），LLM 只需读取 JSON 结果
2. **逐页构建** -- LLM 读源码理解 UI 结构，通过 `use_figma` Plugin API 代码创建 Figma 节点，遵循严格的图层组织规范
3. **自验证循环** -- 每构建完一个页面，截取 Demo + Figma 对比截图，Vision 分析差距，按严重度修复
4. **Agent Team 分工** -- 主 Agent 负责 Vision 分析和布局修复，独立子 Agent 负责图片加载和 SVG 替换（避免长对话中 base64 损坏）

核心机制：
- **预处理管线** -- 确定性工作（正则提取）交给脚本，LLM 专注于需要理解力的工作（组件结构、布局决策）
- **图层组织规范** -- 语义化命名 + 语义分组 + Auto Layout 尺寸模式决策表，确保设计师可高效编辑
- **80/20 职责边界** -- Agent 完成 80% 结构工作（图层 + 命名 + Auto Layout + 颜色字体），设计师完成 20% 精修（组件化 + 替换图片 + 交互原型）

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 通过 Plugin API 而非 generate_figma_design | `use_figma` 逐节点创建 | generate_figma_design 对复杂页面会 crash，且无法控制图层结构 | generate_figma_design 一次生成（不稳定） |
| 图片用占位色块 | 深灰色 Rectangle + 语义化命名 | Figma Plugin API 沙箱中 `createImageAsync(url)` 被禁用，`fetch`/`atob` 不存在 | 直接加载图片 URL（不可行） |
| base64 图片通过独立子 Agent 加载 | Agent 工具委托 | 长对话中 base64 字符串在传递过程中损坏，子 Agent 拥有独立短上下文 | 主 Agent 直接加载（base64 损坏） |
| 预处理管线脚本化 | 5 个 bash 脚本 | 正则提取是确定性工作，脚本执行速度快且结果稳定，LLM 不需要反复解析 CSS | LLM 直接读 CSS 提取 token（慢且不稳定） |
| 颜色转 rgb01 格式 | extract-tokens.sh 自动转换 | Figma API 需要 0-1 范围的 RGB 值，提前转换避免 LLM 手动计算出错 | LLM 运行时转换（容易算错） |
| 每次 use_figma 不超过 200 行 | 分多次调用 | 单次代码过长会报错；且出错时影响范围可控 | 整页一次性生成（不可行） |
| 先创建父节点再 appendChild | 严格构建顺序 | Figma API 限制：`layoutSizingHorizontal = "FILL"` 只能在 appendChild 到 auto-layout 父节点后设置 | 先设属性再 appendChild（API 报错） |
| 字体统一用 Inter | Figma 默认可用字体 | 避免字体加载失败；设计师后续统一替换为品牌字体 | 匹配原始字体（可能不可用） |
| 逐页完成而非多页并行 | 一个页面验证达标后再开始下一个 | 多页并行时错误累积难以排查 | 所有页面同时构建 |

## 已放弃方案

### 方案 A: generate_figma_design 一次生成
- **是什么：** 使用 Figma MCP 的 `generate_figma_design` API 将截图直接转为 Figma 设计
- **为什么放弃：** 调研发现可截取简单页面但复杂页面 crash。且无法控制图层命名和分组结构，设计师拿到的是扁平图层

### 方案 B: createImageAsync 加载远程图片
- **是什么：** 通过 Figma Plugin API 的 `createImageAsync(url)` 直接从 URL 加载图片
- **为什么放弃：** Figma MCP 沙箱中该 API 被明确禁用。`fetch` 和 `atob` 也不存在。只能通过 base64 编码方案曲线加载

### 方案 C: LLM 直接解析 CSS 提取 token
- **是什么：** 不用预处理脚本，LLM 直接读取 CSS 文件提取颜色/字体/间距
- **为什么放弃：** v0.13.0 引入预处理管线后效果显著提升。正则提取是确定性工作，脚本做更快更准；LLM 解析 CSS 时容易遗漏变量、计算 rgb 值出错

### 方案 D: 单 Agent 全流程执行
- **是什么：** 主 Agent 完成所有工作包括图片 base64 加载
- **为什么放弃：** 实战中发现长对话（20+ 轮后）base64 字符串在传递过程中会被截断或损坏，导致图片显示为色块。独立子 Agent 拥有短上下文，base64 传递完整无损

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Figma MCP | Figma 官方 | Figma Plugin API 桥接（whoami / create_file / use_figma / get_screenshot） | 无修改 |
| demo-to-figma-prepare.sh | 自研 | 无 | 预处理编排器 |
| discover-pages.sh | 自研 | 无 | HTML + JS 路由扫描 -> pages.json |
| extract-tokens.sh | 自研 | 无 | CSS :root 变量 -> 分类 tokens（颜色含 rgb01） |
| extract-images.sh | 自研 | 无 | 5 种图片引用模式提取 + 可选 base64 编码 |
| extract-svgs.sh | 自研 | 无 | 内联 SVG content + SVG 文件引用提取 |
| capture-demo-screenshots.sh | 自研 | 无 | Demo 页面截图（供自验证对比） |
| figma-load-images.sh | 自研 | 无 | 批量图片加载 |

## FAQ

**Q: 需要什么样的 Figma 账号？**
A: 需要 Figma Pro 或以上计划的 Full 席位。View-only 和 Dev Mode 席位不支持通过 API 写入。

**Q: 生成的设计稿还原度如何？**
A: 布局结构、颜色、字体、间距的还原度较高（经过自验证循环修复）。图片为占位色块，需设计师替换。无交互原型。

**Q: 支持哪些类型的 demo？**
A: 主要支持 HTML/CSS/JS Web SPA。iOS Xcode 项目也支持（读取 SwiftUI 代码理解 UI 结构）。

**Q: 为什么图片是灰色色块？**
A: Figma Plugin API 沙箱限制导致无法直接从 URL 加载图片。可通过 base64 编码方案加载部分图片，但受限于单次调用大小限制，复杂页面仍需设计师手动替换。

**Q: 生成后设计师需要做什么？**
A: 20% 精修工作：将重复元素转为组件和变体、创建共享样式和变量、替换图片占位符、添加原型交互流程、光学间距微调、响应式变体。

## 生命周期

- **填补的 gap：** demo 代码到 Figma 设计稿之间的人工翻译成本
- **什么会让它过时：** 如果 Figma 官方推出"从代码生成设计稿"功能（如 Dev Mode 的反向操作），或者 vibe coding 工具本身集成 Figma 输出。另外如果 Figma Plugin API 开放 `createImageAsync` 和 `fetch`，图片加载的复杂度会大幅降低

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.12.0 | 2026-03-31 | 首版。基础逐页构建 + Agent Team 分工 + 图层组织规范（命名/分组/Auto Layout） |
| v0.13.0 | 2026-03-31 | 预处理管线（5 个脚本）：页面发现 + token 提取 + 图片引用 + SVG 提取。Figma MCP 调研结论：createImageAsync 被禁用 |
| v0.14.0 | 2026-04-01 | 重命名 demo-to-figma -> ae-demo-to-figma，改为 folder/SKILL.md 格式 |

## 文件清单

| 文件 | 用途 |
|------|------|
| `SKILL.md` | Agent 操作指南（Step 1-6 完整流程 + 图层规范 + Agent Team 分工 + 故障排查） |
| `scripts/demo-to-figma-prepare.sh` | 预处理编排器（串联下面 4 个脚本） |
| `scripts/discover-pages.sh` | HTML + JS 路由扫描 -> pages.json |
| `scripts/extract-tokens.sh` | CSS :root 变量 -> tokens.json（颜色自动转 rgb01） |
| `scripts/extract-images.sh` | 图片引用提取 -> images.json + 可选 .b64 文件 |
| `scripts/extract-svgs.sh` | SVG 内容提取 -> svgs.json |
| `scripts/capture-demo-screenshots.sh` | Demo 页面自动截图（供 Step 5 自验证对比） |
| `scripts/figma-load-images.sh` | 批量图片加载到 Figma |
