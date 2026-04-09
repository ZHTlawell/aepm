# ae-demo-to-speckit

> 填补"demo 原型到成品代码之间缺乏结构化衔接件"的 gap，让 PM 的 vibe coding 产出可以被 dev agent 精确消费。

## 问题陈述

PM 用 vibe coding 工具（Antigravity 等）生成了产品 demo 原型，但 demo 代码不能直接用于生产：结构混乱、缺少架构设计、数据硬编码、Mock API 无法替换。需要 dev agent 重新生成成品项目。

问题是：dev agent 需要明确的输入规格。直接给一堆 demo 代码，dev agent 不知道哪些是产品意图、哪些是实现妥协。

没有这个 skill 之前：
1. PM 口头描述功能给 dev，信息丢失严重
2. PM 写 PRD 文档但格式不统一，dev agent 无法结构化消费
3. 直接交 demo 代码，dev 需要人工逆向理解产品意图，效率低且容易遗漏

痛点核心：demo 代码只告诉你 WHAT exists，不告诉你 WHY。遗漏任何功能都会导致成品缺失该功能，最终在 E2E 验证中暴露。

## 解决方案

自动读取 demo 项目全部源码，提取 6 个标准模块的结构化规格书（speckit），作为 dev agent 的精确输入：

1. **上下文搜集** -- 系统性发现 4 类上下文（代码、产品文档、设计资产、战略约束），每个字段标注来源置信度
2. **全量源码读取** -- 必须读完所有源码文件，不能只看部分
3. **6 模块提取** -- 项目定位、用户场景、技术架构、设计规范、数据模型、API 规范
4. **自检校验** -- 功能自检 + Schema 质量校验 + 置信度检查

核心机制：
- **Context Manifest** -- 追溯每个提取字段的来源（confirmed / extracted / inferred / missing），让下游知道信息可靠程度
- **数据源发现** -- 主动扫描项目中的 CSV/JSON/SQLite 等数据文件，确保成品不丢失真实数据
- **约束合规预检** -- 提取前检测 demo 是否违反技术选型约束（如 WebView、缺少 accessibilityIdentifier），提前暴露问题

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 6 模块标准格式 | 固定 01-06 模块 | dev agent 需要结构化输入，自由格式无法程序化消费 | PRD 自由文档（dev agent 无法解析） |
| 置信度标注 | 4 级标注（confirmed/extracted/inferred/missing） | 下游需要知道信息可靠程度，inferred 的字段需要 PM 确认 | 不标注（下游无法判断准确性） |
| 必须读完全部源码 | 不允许抽样 | 遗漏一个文件可能丢失整个功能模块 | 智能抽样（风险太高） |
| 数据源发现前置 | Step 1.8 独立步骤 | 成品遗漏真实数据源（只用 mock）是最常见的质量问题 | 在 Module 05 提取时顺带扫描（容易遗忘） |
| Context Manifest 独立文件 | 00-context-manifest.md | 追溯需要独立于 speckit 模块，供调试和审计 | 嵌在各模块注释中（不可汇总） |
| 约束合规预检在提取前 | Step 0 | block 级违规应在提取前暴露，避免做无用功 | 提取后再检查（浪费时间） |

## 已放弃方案

### 方案 A: 自由格式 PRD 文档
- **是什么：** 让 agent 生成传统 PRD 文档（自由文本 + 截图）
- **为什么放弃：** dev agent 无法结构化消费。每个项目的 PRD 格式不同，dev agent 需要重新理解结构。标准 6 模块格式让 dev agent 可以直接定位所需信息

### 方案 B: 只提取核心模块
- **是什么：** 只提取 Module 01（定位）和 Module 02（场景），其余 PM 手写
- **为什么放弃：** Module 03-06 的技术细节是成品质量的关键。设计规范遗漏导致 UI 不一致，数据模型遗漏导致数据丢失，API 遗漏导致功能不可用

### 方案 C: 不做置信度标注
- **是什么：** 所有提取结果一视同仁，不区分来源
- **为什么放弃：** v0.5.0 引入 Context Manifest 时发现，不标注置信度会导致 dev agent 把推断当事实实现，PM Review 时无法快速定位需要确认的字段

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| speckit-schema.yaml | 自研 | 无 | 6 模块格式标准（required_sections + quality_indicators） |
| speckit_validator.py | 自研 | 无 | Schema 校验引擎（同义词 fuzzy match） |
| ae-speckit-examples | 自研（Gitee） | 无 | 已验证的 speckit 样例（ShoeLens 等），供提取时参照 |

此 skill 无外部依赖，纯 LLM 能力（读代码 + 提取结构化信息）。

## FAQ

**Q: 提取一个项目大概需要多长时间？**
A: 取决于项目规模。小型 demo（10 个文件）约 5-10 分钟，中型项目（50+ 文件）约 15-30 分钟。主要时间花在全量源码读取上。

**Q: 提取的 speckit 准确率如何验证？**
A: 通过 /ae-verify-app 对 demo 运行 baseline 测试，自动提取的 test cases coverage 应 >= 90%。

**Q: 如果 demo 没有 README 或产品文档怎么办？**
A: Context Manifest 的降级策略会启动 -- 从代码推断产品定位和用户场景，标注为 `[inferred]`。PM 需要在 Review 阶段确认或修正。

**Q: 支持哪些技术栈的 demo？**
A: iOS Native (SwiftUI)、iOS WebView Hybrid、Web SPA (React/Vue/Next)、Java Backend (Spring Boot)。通过项目根目录特征文件自动识别。

**Q: speckit 生成后下一步是什么？**
A: 进入 dev agent 生成成品：`ae dev speckit-receive <speckit_dir>`。或者先通过 /ae-demo-to-figma 生成设计稿供设计师精修。

## 生命周期

- **填补的 gap：** PM demo 与 dev agent 之间缺乏结构化衔接件
- **什么会让它过时：** 如果 vibe coding 工具本身能输出结构化规格书（即 demo 代码和产品规格同步生成），则提取步骤不再需要。但目前所有 vibe coding 工具的输出都是非结构化的代码

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.1.0 | 2026-03-25 | 首版随 ae-pm 一起发布，基础 6 模块提取 |
| v0.5.0 | 2026-03-26 | Context Manifest + 4 级置信度标注 + 约束合规预检 |
| v0.10.0 | 2026-03-26 | 数据源发现（Step 1.8）-- CSV/JSON/SQLite/Plist/CoreData 扫描 |
| v0.14.0 | 2026-04-01 | 重命名 demo-to-speckit -> ae-demo-to-speckit，改为 folder/SKILL.md 格式 |

## 文件清单

| 文件 | 用途 |
|------|------|
| `SKILL.md` | Agent 操作指南（Step 0-5 完整流程 + 模块提取规则 + 自检清单） |
| `content/speckit-schema.yaml` | 6 模块格式标准定义（required_sections + quality_indicators） |
| `verify/engine/speckit_validator.py` | Schema 校验引擎 |
