# Skill: Demo 原型转 Speckit (demo-to-speckit)

## 触发条件

当 PM 使用 vibe coding 工具（Antigravity 等）生成了产品 demo 原型后，需要将其转化为结构化 speckit，以便后续用 dev agent 生成高质量成品项目时触发。

## 核心原则

**Speckit 是整条 demo→成品 流水线的关键衔接件。** 提取质量直接决定成品质量。遗漏任何功能都会导致成品缺失该功能，最终在 E2E 验证中被发现。

## 输入

- **demo 项目目录**：PM 的 vibe coding 产出（iOS Xcode 项目或独立前端项目）
- **iOS 模拟器**（可选）：用于运行 demo 截图辅助提取

## 输出

6 个标准模块的 markdown 文件，写入 `speckit/` 目录：

| 模块 | 文件 | 内容 |
|------|------|------|
| 01 | `01-project-positioning.md` | 产品名、定位、目标用户、商业模式、边界（做什么/不做什么）|
| 02 | `02-user-scenarios.md` | 所有用户流程（叙事式）、页面清单、导航图、Toast 消息 |
| 03 | `03-tech-architecture.md` | 技术选型、文件结构、状态管理、数据流、持久化 |
| 04 | `04-design-spec.md` | 色彩系统、字体、间距、圆角、特效、组件库 |
| 05 | `05-data-model.md` | 数据 schema、字段定义、关系、数据量级 |
| 06 | `06-api-spec.md` | 已集成 API、Mock 实现、AI Prompt、未来 API 规划 |

## 执行流程

### Step 1: 识别项目类型

读取项目根目录，判断技术栈：

| 特征 | 项目类型 |
|------|---------|
| `*.xcodeproj` + `*.swift` | iOS Native (SwiftUI) |
| `*.xcodeproj` + `www/` + `*.html` | iOS WebView Hybrid |
| `package.json` + React/Vue/Next | Web SPA |
| `build.gradle` + Spring Boot | Java Backend |

### Step 2: 读取全部源码

**必须读完所有源码文件**，不能只看部分。具体策略：

- JS/Swift 文件：完整读取（分 chunk 如果超过 2000 行）
- CSS 文件：重点读取变量定义和组件样式
- 数据文件：读取 schema（前 50 行）+ 数据量统计
- 配置文件：完整读取

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

**模块 06 — API 规范**
- 找到所有 fetch/XMLHttpRequest/API 调用
- 找到所有 mock 实现
- 找到 AI prompt 模板（如有）
- 推断未来需要的真实 API

### Step 4: 运行 demo 补充验证（可选）

如果有 iOS 模拟器：
1. 构建并安装 demo app
2. 逐 tab 截图
3. 用截图补充/验证 Step 3 提取的页面清单

### Step 5: 输出并自检

生成 speckit 后，自检清单：
- [ ] 所有 tab 都有对应描述
- [ ] 所有 Toast 消息都已列出
- [ ] 所有导航路径都已覆盖
- [ ] CSS 变量完整提取
- [ ] 数据 schema 字段无遗漏
- [ ] API/Mock 全部列出

## 验证标准

通过 `/verify-app` 对 demo 运行 baseline 测试：
- 从自动 speckit 提取的 test cases coverage ≥ 90%（与手工 speckit 对比）
- 无功能点遗漏（遗漏 = verify 能通过但 speckit 没描述的功能）

## 复用说明

所有 PM 在完成 demo 原型后都需要此能力。这是 demo→成品流水线的第一步。
