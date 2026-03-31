# Changelog

## v0.12.0 (2026-03-30) — Demo → Figma 自动转换

### 新增能力
- **Demo 转 Figma 设计稿** (`/demo-to-figma`) — PM vibe coding 出 demo 后，自动将 HTML/CSS/JS 项目转为可编辑的 Figma 设计稿，供设计师精修 `#IHRKLX`
  - 自动扫描项目页面、从 CSS 变量提取 design tokens（色彩/字体/间距/圆角）
  - 用 Figma MCP `use_figma` 逐页程序化构建 Figma 节点（auto-layout + 语义化图层命名）
  - 内置 Vision 自验证循环：截图对比 → 差距分析（7 类差距 × 3 级严重度）→ 自动修复 → 再验证
  - 真实图片加载：bash 下载 → base64 编码 → Plugin API `figma.createImage()` 填充
  - 纯 JS base64 解码器模板（兼容 Plugin API 沙箱，无 fetch/atob）
  - 8 条故障排查 + 7 条规则（含「图片加载必须委托独立 Agent」「Frame 默认高度 100px 陷阱」等）

### 新增脚本
- **`capture-demo-screenshots.sh`** — Playwright 自动截取 demo 各页面截图，供 `/demo-to-figma` 自验证对比使用

### 验证结果
- ShoeLens 4 个主要页面（Home/Category/Collection/Profile）全部成功转换
- 5 轮验证-修复迭代，修复 15+ 个问题
- Figma 文件可直接打开编辑：https://www.figma.com/design/Cg2gGDD9aH4Rjs1iUgDWhD

### 关键技术发现
- `generate_figma_design`（浏览器截屏）图片密集页面超时 → `use_figma`（程序化创建）无此问题
- Plugin API 沙箱无 `fetch`/`atob` → 外部下载 + 自带 base64 解码器
- 长对话 base64 传递会损坏 → 图片加载必须委托独立 Agent

## v0.11.0 (2026-03-26) — 图片去版权化工具

### 新增能力
- **图片去版权化** (`/image-decopyrighter`, `ae pm image-decopyright`) — 将有版权风险的图片通过 AI 重绘生成可商用替代图片 `#IHQQOZ`
  - Claude Vision 提取图片语义 → 图片生成 API 重绘 → 输出可商用替代
  - 默认使用 Google Imagen 4.0（免费层 50 张/天），支持切换 Together AI / DALL-E 3
  - 支持单张、批量处理，可指定风格（illustration, watercolor 等）和尺寸
  - 配置 `GEMINI_API_KEY` 即可使用

## v0.10.0 (2026-03-26) — Backlog 推进（validator + 数据发现 + 后端验证）

### 新增能力
- **Speckit Schema Validator** (`ae pm validate-speckit`) — 校验 speckit 目录是否符合 schema 标准，支持 JSON 输出，同义词 fuzzy match（解决章节名不完全一致的问题） `#IHQJFK`
- **后端编译验证 skill** (`/backend-build-verify`, `ae dev backend-build`) — 补齐后端验证链：gradle build → bootRun → smoke test，与 iOS 的 build/test 对等 `#IHQJFJ`

### 改进
- **demo-to-speckit 数据源发现** (Step 1.8) — 新增 CSV/JSON/SQLite/Plist/CoreData 文件扫描步骤，确保模块 05/06 完整描述数据层，避免成品遗漏真实数据源 `#IHQQC3`
- **Tab 双层重叠 bug 转 ae-dev** — 归因为 [GEN-BUG]，已转至 ae-dev#IHQR39 跟进 `#IHQQC8`

## v0.9.0 (2026-03-26) — 一键搭建 + 自动提 bug

### 新增能力
- **`ae setup` 命令** — 一键完成环境搭建：安装依赖 → 克隆仓库 → 配置 Token（交互式 + 自动验证）→ 环境检查 → 入驻确认
  - Token 配置改为必填（不再允许跳过），输入后立即验证有效性
  - 入驻确认自动完成（通过 API 发 comment），不再需要让 agent 代劳
  - 支持角色选择：`ae setup pm` / `ae setup dev` / `ae setup both`
- **`/file-bugs` skill + `ae pm file-bugs` CLI** — 从 verify-app diff report 自动生成 issue 草稿，PM 确认后批量提交

### 修正
- **doctor token 检查** — 修复 subshell 导致 token 无效时不影响最终检查结果的问题
- **curl 超时** — doctor 和 setup 的 API 调用统一加 `--max-time 10`

### 改进
- **README 快速开始重写** — 从 6 步手动操作简化为 `ae setup` + `ae link pm .` 两步

## v0.8.0 (2026-03-26) — verify-app → 自动提 bug

### 新增能力
- **`/file-bugs` skill** — 读取 verify-app 的 diff report，自动生成 issue 草稿（含归因前缀、验证级别、case ID），PM 确认后批量提交
- **`ae pm file-bugs` CLI 命令** — 解析 diff-report.json，交互式选择后批量调用 Gitee API 提交

### 改进
- **`/submit-bug` 前缀兼容** — 支持 `[GEN-BUG]`、`[SPECKIT-GAP]`、`[CONSTRAINT-GAP]`、`[DEMO-BUG]` 前缀，不再强制覆盖为 `[BUG]`

### 设计意图
PM 跑完 `/verify-app` 后说"提 bug"，agent 自动从 diff report 生成所有 issue，PM 只需确认。**PM 不做流程 QA。**

## v0.7.0 (2026-03-26) — Bug 反馈质量升级

### 重要变更
- **`/submit-bug` skill 重写** — 增加归因引导（5 个阶段前缀）、UI 截图要求、笼统描述拆分机制
  - 归因阶段：DEMO-BUG / SPECKIT-GAP / GEN-BUG / CONSTRAINT-GAP / BUG
  - UI 类 bug 必须附截图，否则标注 ⚠️ 需人工复现
  - 笼统描述（如"视觉差距大"）必须拆成 2-3 个可验证具体条目
- **批量提交规范** — 多个 bug 逐个独立提交，各自归因，禁止合并为一个 issue

## v0.6.0 (2026-03-26) — Bug 提交收归 CLI

### 新增能力
- **`/submit-bug` skill** — 引导 agent 收集 bug 信息后通过 `ae` CLI 自动提交到 Gitee，杜绝本地 issue 文件
- **`ae pm submit-bug` CLI 命令** — 直接调用 Gitee API 提交 bug 报告，支持 `--repo` 指定目标仓库

### 重要变更
- **Gitee API 调用收归 CLI** — CLAUDE.md 明确禁止 agent 创建本地 issue 文件或直接调用 curl/Gitee API，统一通过 `ae` CLI 完成
- **`_pm_gitee_create_issue()` 通用函数** — CLI 内部抽出 Gitee issue 创建的通用函数，后续 `submit-requirement` 可复用
- **curl 加固** — 增加 `--max-time 30` 超时防止代理未清除时挂死，token 通过 `os.environ` 安全传递

### 修正
- 修复 agent 按 README 提 bug 时 fallback 为创建本地 markdown 文件的问题

## v0.5.0 (2026-03-26) — Pipeline v0.2

### 机制升级（4 项同步升级）

- **Context Manifest (P0)** — `/demo-to-speckit` 新增 4 类上下文发现机制（codebase / product_doc / design_asset / strategic_context）+ 来源置信度标注（confirmed / extracted / inferred / missing）
- **Constraint Detection (P1)** — 约束文件新增可执行 Detection Rules，在 pipeline 3 个阶段自动触发（before:demo-to-speckit / after:speckit-receive / before:verify-app）
- **Verify Level System (P1)** — 测试用例分为 structural / behavioral / functional 三级，coverage 升级为三维报告
- **Speckit Schema (P2)** — 新增 `content/speckit-schema.yaml` 定义 6 模块格式标准（required_sections + quality_indicators）

### 改进

- `/demo-to-speckit` 新增 Step 0（约束合规预检）和 Step 1.5（上下文搜集），输出增加 `00-context-manifest.md`
- `/verify-app` 新增 Step 1.5（约束合规预检），输出增加 `constraint_violations` 和 `coverage_by_level`
- `/speckit-receive` Step 1 升级为 schema-based 深度验证，新增 Step 5.5 约束合规检查
- 约束文件 `content/constraints/{ios,backend,data}.md` 各增加 Detection Rules 节（共 16 条规则）

## v0.4.0 (2026-03-26)

### 重要变更
- **PM → Dev 衔接说明** — README 和 CLAUDE.md 新增完整的操作步骤：PM 生成 speckit 后如何调用 ae-dev 生成成品
  - 方式一：`ae dev speckit-receive <speckit_dir>`（推荐）
  - 方式二：手动创建项目 → `ae link dev .` → 打开 Claude Code 指定 speckit 路径

### 修正
- **能力清单更新** — CLAUDE.md "当前能力"表补全了 `/demo-to-speckit` 和 `/verify-app`，删除了已过时的"规划中的能力"段落（这些能力早已可用）

## v0.3.0 (2026-03-26)

### 重要变更
- **愿景声明** — CLAUDE.md 开头新增愿景与定位，明确反馈机制：凡与愿景有偏差的情况都应反馈给 AE Team
- **README 重写** — 从纯安装指引升级为完整产品介绍（理念、全链路、能力清单、反馈方式）

### 新增能力
- **iOS 编译验证 skill** (`/ios-build-verify`) — xcodebuild 编译 + 自动修复 loop
- **iOS UI 测试 skill** (`/ios-ui-test`) — AXe + simctl 自动化测试（Native/WebView 双模式）
- **Speckit 接收生成 skill** (`/speckit-receive`) — 从 speckit 生成 iOS + 后端项目

### 改进
- 跨平台说明：README 中增加 Claude Code / Codex / Cursor 三种工具的使用方式

## v0.2.0 (2026-03-26)

### 新增能力
- **App 差异比对验证 skill** (`/verify-app`) — E2E 对比 demo vs 成品，自动归因差异到 speckit 提取 / 代码生成 / 约束缺失

### 新增约束
- **技术选型约束** — CLAUDE.md 新增 iOS/后端/数据层技术约束，确保 PM vibe coding 产出符合后续流程要求
  - iOS: 必须 SwiftUI Native，禁止 WebView hybrid
  - 后端: Spring Boot 3.x + MyBatis + Flyway
  - 数据: 禁止硬编码，Mock 遵循 REST 契约

### 基础设施
- E2E verify 框架: 测试用例格式 (YAML) + 执行引擎 + baseline 报告格式 (JSON)
- ShoeLens 验证用例: 25 个 test cases，baseline coverage 72%

## v0.1.0 (2026-03-25)

首版发布。

### 新增能力
- **Issue 反馈提交** — 通过 Gitee API 向 ae-pm repo 提交 bug / 功能需求 / 使用疑问
- **查收更新** — 读取 CHANGELOG.md 了解最新版本更新内容
- **提需求 skill** — 标准化的需求提交流程，确保需求是可复用机制（reusable mechanism）

### 基础设施
- CLAUDE.md 核心指令
- README.md 安装指引
- 入驻确认流程（通过 comment 验证配置）
