# Changelog

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
