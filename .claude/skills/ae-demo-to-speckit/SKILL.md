---
description: "从 demo 源码自动提取 6 模块标准规格书 (Speckit)"
dependencies:
  mcp: []
  cli: []
  api_keys: []
  scripts: []
---

# Skill: Demo 原型转 Speckit (demo-to-speckit)

## 触发条件

当 PM 使用 vibe coding 工具（Antigravity 等）生成了产品 demo 原型后，需要将其转化为结构化 speckit，以便后续用 dev agent 生成高质量成品项目时触发。

## 核心原则

**Speckit 是整条 demo→成品 流水线的关键衔接件。** 提取质量直接决定成品质量。遗漏任何功能都会导致成品缺失该功能，最终在 E2E 验证中被发现。

## 参照示例

在提取前，先参考 `gitee.com/turningsyn/ae-speckit-examples` 中的已验证示例（如 ShoeLens），了解每个模块的预期格式、深度和质量标准。

## 输入

- **demo 项目目录**：PM 的 vibe coding 产出（iOS Xcode 项目或独立前端项目）
- **iOS 模拟器**（可选）：用于运行 demo 截图辅助提取

## Context Manifest

代码只告诉你 WHAT exists，不告诉你 WHY。提取前必须系统性搜集 4 类上下文：

| 上下文类型 | 发现规则 | 用途 | 降级策略 |
|-----------|---------|------|---------|
| **codebase** | demo 项目目录（用户提供） | 所有 6 模块的主要提取来源 | 无降级，缺失则终止 |
| **product_doc** | 搜索项目根目录及上一级: `README.md`, `PRD.md`, `endgoal.*`, `docs/`, `*.prd` | 模块 01 定位、模块 02 场景的补充 | 仅从代码推断，标注 `[inferred]` |
| **design_asset** | 搜索 `assets/`, `design/`, `*.figma`, `tokens.*`；代码中的颜色/字体常量 | 模块 04 设计规范的精确值 | 从 CSS/SwiftUI 代码提取，标注 `[extracted]` |
| **strategic_context** | 搜索 `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/`, 项目级指令文件 | 了解项目特殊约束和优先级 | 使用 ae-platform 默认约束 |

### 来源置信度标注

提取的每个字段标注来源，让下游（Dev agent、验证）知道信息的可靠程度：

| 置信度 | 含义 | 标注方式 |
|--------|------|---------|
| `confirmed` | 直接从代码或文档中找到明确定义 | 无标注（默认） |
| `extracted` | 从代码结构推断，未有文档确认 | 字段后标注 `[extracted]` |
| `inferred` | 无直接证据，从上下文推断 | 字段后标注 `[inferred]` |
| `missing` | 无法提取，需 PM 补充 | 字段后标注 `[NEEDS INPUT]` |

## 输出

6 个标准模块的 markdown 文件 + 1 个上下文追溯文件，写入 `speckit/` 目录：

| 模块 | 文件 | 内容 |
|------|------|------|
| 01 | `01-project-positioning.md` | 产品名、定位、目标用户、商业模式、边界（做什么/不做什么）|
| 02 | `02-user-scenarios.md` | 所有用户流程（叙事式）、页面清单、导航图、Toast 消息 |
| 03 | `03-tech-architecture.md` | 技术选型、文件结构、状态管理、数据流、持久化 |
| 04 | `04-design-spec.md` | 色彩系统、字体、间距、圆角、特效、组件库 |
| 05 | `05-data-model.md` | 数据 schema、字段定义、关系、数据量级 |
| 06 | `06-api-spec.md` | 已集成 API、Mock 实现、AI Prompt、未来 API 规划 |
| -- | `00-context-manifest.md` | 上下文来源追溯（非标准模块，供追溯用） |

## 执行流程

### Step 0: 约束合规预检

开始提取前，读取 `content/constraints/` 下所有约束文件的 Detection Rules（`before:demo-to-speckit` 阶段），逐条执行：

- iOS 约束: ios-001（SwiftUI Native）、ios-002（无 WebView）、ios-003（accessibilityIdentifier）、ios-004（权限声明）、ios-005（文件行数）
- 数据约束: data-001（数据未硬编码在 UI）

将违规项汇总告知 PM：
- **block 级违规**（如 WebView 包装为主 UI）→ 建议 PM 先修复再提取
- **warn 级违规**（如个别缺少 accessibilityIdentifier）→ 记录并继续

### Step 1: 识别项目类型

读取项目根目录，判断技术栈：

| 特征 | 项目类型 |
|------|---------|
| `*.xcodeproj` + `*.swift` | iOS Native (SwiftUI) |
| `*.xcodeproj` + `www/` + `*.html` | iOS WebView Hybrid |
| `package.json` + React/Vue/Next | Web SPA |
| `build.gradle` + Spring Boot | Java Backend |

### Step 1.5: 搜集上下文

按 Context Manifest 声明，系统性搜集 4 类上下文：

1. 扫描项目目录和父目录，按发现规则定位所有上下文源
2. 对找到的每个上下文源，记录: `{type, path, found: true/false}`
3. 对未找到的上下文类型，执行降级策略
4. 将上下文清单写入 `speckit/00-context-manifest.md`

`00-context-manifest.md` 格式：

```markdown
# Context Manifest

| 类型 | 路径 | 状态 |
|------|------|------|
| codebase | ./ShoeLens/ | found |
| product_doc | ./README.md | found |
| product_doc | ./endgoal.md | not_found → fallback: inferred from code |
| design_asset | 代码内 Color/Font 常量 | extracted |
| strategic_context | ./CLAUDE.md | not_found → fallback: ae-platform defaults |
```

### Step 1.8: 数据源发现

扫描项目目录，定位所有数据源文件。**这一步的目的是确保模块 05/06 能完整描述数据层，避免成品使用 mock 数据而忽略真实数据源。**

**扫描规则：**

| 文件类型 | 匹配模式 | 处理方式 |
|---------|---------|---------|
| CSV | `*.csv` | 读取表头 + 前 5 行 + 统计行数 |
| JSON | `*.json`（排除 package.json/tsconfig 等配置） | 读取结构 + 统计记录数 |
| SQLite | `*.sqlite`, `*.db` | 列出所有表 + 各表记录数 |
| Plist | `*.plist`（排除 Info.plist） | 读取 key 列表 |
| CoreData | `*.xcdatamodeld` | 读取 entity 定义 |

**扫描位置（按优先级）：**
1. 项目根目录
2. `data/`, `assets/`, `resources/`, `mock/` 子目录
3. 项目同级目录（PM 可能把数据文件放在项目外）

**输出：** 将发现的数据源记录到 `00-context-manifest.md` 中，并在 Step 3 提取模块 05/06 时使用：

```markdown
| 类型 | 路径 | 记录数 | 字段摘要 |
|------|------|--------|---------|
| data_source | ./ShoeLens_Final_Database.csv | 2486 行 | brand, model, colorway, sku, price... |
| data_source | ./mock/shoes.json | 10 条 | id, name, brand, image_url |
```

**重要：** 如果发现了真实数据文件（行数 > 100 或文件名含 final/prod/real），必须在模块 05 中标注为主数据源，并在模块 06 中说明数据导入方式。忽略数据源会导致成品只使用 mock 数据。

### Step 2: 读取全部源码

**必须读完所有源码文件**，不能只看部分。具体策略：

- JS/Swift 文件：完整读取（分 chunk 如果超过 2000 行）
- CSS 文件：重点读取变量定义和组件样式
- 数据文件：读取 schema（前 50 行）+ 数据量统计（Step 1.8 已定位）
- 配置文件：完整读取
- **产品文档**（Step 1.5 找到的）：完整读取，提取产品定位、用户画像、商业决策
- **设计资产**（Step 1.5 找到的）：提取 token 定义（颜色、字体、间距精确值）

### Step 3: 提取各模块

**模块 01 — 项目定位**
- 从 onboarding UI 文案提取产品名和 tagline
- 从 paywall 代码提取商业模式和定价
- 从功能边界推断目标用户

**模块 02 — 用户场景**
- 追踪状态机：找到所有 state 变量和 navigate/goTo 函数
- 映射每个 tab 和 sub-view 的内容
- 找到所有 showToast 调用，列出所有 Toast 消息
- 画出完整导航图

**模块 03 — 技术架构**
- 列出技术选型表
- 画出文件结构树
- 描述状态管理模式
- 列出所有 localStorage/持久化 key

**模块 04 — 设计规范**
- 提取所有 CSS 变量（颜色、字体、间距）
- 识别组件模式（卡片、按钮、Tab bar 等）
- 记录特效（glassmorphism、shadow、gradient）

**模块 05 — 数据模型**
- 提取主要数据结构的 schema
- 统计数据量（记录数、文件大小）
- 识别品牌/分类等枚举值
- **数据源标注（关键）** — 将 Step 1.8 发现的数据文件写入此模块：
  - 真实数据源（CSV/DB）→ 标注为 `[PRIMARY DATA SOURCE]`，含文件路径、行数、字段列表
  - Mock 数据 → 标注为 `[MOCK]`，说明与真实数据的差异
  - 如果同时存在真实数据和 mock 数据，必须说明成品应使用哪个

**模块 06 — API 规范**
- 找到所有 fetch/XMLHttpRequest/API 调用
- 找到所有 mock 实现
- 找到 AI prompt 模板（如有）
- 推断未来需要的真实 API
- **数据导入方式** — 如果 Step 1.8 发现了真实数据文件，必须在此模块说明：
  - 成品启动时如何加载这些数据（导入 CSV → DB？直接读取 JSON？API 返回？）
  - 数据文件的位置和格式要求

### Step 4: 运行 demo 补充验证（可选）

如果有 iOS 模拟器：
1. 构建并安装 demo app
2. 逐 tab 截图
3. 用截图补充/验证 Step 3 提取的页面清单

### Step 5: 输出并自检

生成 speckit 后，执行两轮检查：

**功能自检清单：**
- [ ] 所有 tab 都有对应描述
- [ ] 所有 Toast 消息都已列出
- [ ] 所有导航路径都已覆盖
- [ ] CSS 变量完整提取
- [ ] 数据 schema 字段无遗漏
- [ ] API/Mock 全部列出
- [ ] `00-context-manifest.md` 已生成，列出所有上下文源

**Schema 质量校验：**

对照 `content/speckit-schema.yaml` 逐模块检查：
- 所有 `required_sections` 是否都有内容
- `quality_indicators` 是否满足（如 min_word_count, min_scenarios 等）
- 不满足的项目标注并告知 PM

**置信度检查：**
- `[inferred]` 标注的字段不超过总字段的 30%
- `[NEEDS INPUT]` 标注的字段汇总列出，提示 PM 补充

## 验证标准

通过 `/ae-verify-app` 对 demo 运行 baseline 测试：
- 从自动 speckit 提取的 test cases coverage ≥ 90%（与手工 speckit 对比）
- 无功能点遗漏（遗漏 = verify 能通过但 speckit 没描述的功能）

## 复用说明

所有 PM 在完成 demo 原型后都需要此能力。这是 demo→成品流水线的第一步。
