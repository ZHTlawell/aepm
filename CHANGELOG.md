# Changelog

## v0.14.1 (2026-04-02) — 飞书集成

### 新增能力
- **飞书消息与会议 skill** — `/ae-lark-feishu`，支持搜索群聊、读取消息、搜索消息、下载图片/文件、读取私聊、发送消息、获取会议妙记/逐字稿、读取飞书文档 `#IHXG1V`
  - 前置条件：需安装 `lark-cli` 并完成飞书认证
  - 支持 8 项核心操作：群聊搜索、消息读取、消息搜索、图片下载、私聊读取、消息发送、会议妙记、文档读取

## v0.14.0 (2026-04-01) — Skill 命名规范化 + 目录格式

### 重要变更
- **所有 skill 文件统一加 `ae-` 前缀** — 与用户自建 skills 区分，输入 `/ae` 即可筛选出所有 ae-platform 提供的能力 `#IHWMM0`
  - `/demo-to-speckit` → `/ae-demo-to-speckit`
  - `/verify-app` → `/ae-verify-app`
  - `/submit-bug` → `/ae-submit-bug`
  - `/file-bugs` → `/ae-file-bugs`
  - `/submit-requirement` → `/ae-submit-requirement`
  - `/demo-to-figma` → `/ae-demo-to-figma`
  - `/image-decopyrighter` → `/ae-image-decopyrighter`
- **Skill 改用 folder/SKILL.md 格式** — 单文件 `.md` 在 Claude Code 的 `/` 搜索中不可见，改为 `ae-<name>/SKILL.md` 目录格式，附带 frontmatter description `#IHWNMY`
- **CLI 子命令不变** — `ae pm demo-to-speckit` 等 CLI 命令保持不变，内部自动映射到新文件名
- **CLAUDE.md / README 同步更新** — 所有文档中的 skill 引用已更新
- **link.sh 适配** — 软链接改为链接 skill 目录，`ae link pm .` 后 `/` 补全可见

## v0.13.0 (2026-03-31) — 交付完整性修复 + demo-to-figma 预处理管线

### 重大修复
- **PM 交付完整性修复** — ae-pm 之前只包含 skills 和文档，PM 拿到后无法使用任何 CLI 命令或预处理脚本 `#IHUYQ4`
  - build.sh 改造：构建 PM 包时自动打包 **完整 CLI**（ae 命令 + 9 个 lib 模块）和 **所有工具脚本**
  - ae-pm 从 10 个文件扩充到 26 个文件，PM 拿到后可完成全部自助安装和使用

### 新增能力
- **demo-to-figma 预处理管线** — 5 个脚本将确定性提取工作脚本化，LLM 只需读取 JSON `#IHUYQ4`
  - `demo-to-figma-prepare.sh` — 编排器，一键运行以下 4 个脚本
  - `discover-pages.sh` → pages.json（HTML + JS 路由扫描，过滤 action handler 噪音）
  - `extract-tokens.sh` → tokens.json（CSS :root 变量 → 分类 tokens，颜色自动转 rgb01）
  - `extract-images.sh` → images.json + *.b64（5 种图片引用模式 + 可选 base64 编码）
  - `extract-svgs.sh` → svgs.json（内联 SVG content 提取）
- **demo-to-figma skill 更新** — Step 1-2 改为调用预处理脚本，颜色直接用 tokens.json 的 rgb01

### 改进
- **setup.sh 新增 AI 工具链检查**（Step 2）— 检测 Claude Code 安装状态 + Figma MCP 连接状态，交互式引导安装
- **doctor.sh 新增 4 项检查** — Claude Code / Figma MCP / 预处理脚本就绪 / ae CLI 就绪
- **install.sh 改用 Gitee 源** — 从 GitHub 改为 Gitee，国内访问更稳定，错误提示人话化

### Figma MCP 调研结论
- `createImageAsync(url)` 在 MCP 沙箱中被明确禁用
- `generate_figma_design` 可截取简单页面（含图片），但复杂页面会 crash
- 最佳实践：**图片用色块占位 + SVG 图标通过 `createNodeFromSvg()` 完美还原**，设计师后续替换图片

## v0.12.0 (2026-03-31) — demo-to-figma skill + 图层组织规范

### 新增能力
- **`/demo-to-figma` skill** — PM demo 原型自动转 Figma 设计稿，供设计师精修 `#IHUYQ4`
- **demo-to-figma Agent Team 分工** — 页面拆分多 agent 并行处理，提升转换效率
- **CLI 工具脚本** — `figma-load-images.sh`（批量图片加载）+ `capture-demo-screenshots.sh`（自动截图）

### 改进
- **demo-to-figma 图层规范** — 嵌入 Figma 图层组织规范，解决设计师反馈的图层结构不规范问题 `#IHUYQ4`
  - 命名规范：斜杠分层命名（Card/Cover、Card/Content），禁止默认名
  - 语义分组：相关元素必须用父 Frame 包裹（Cover+Tag → CoverArea），禁止平级堆叠
  - Auto Layout 尺寸模式决策表（HUG/FILL/FIXED 何时使用）
  - Card 标准结构模板（Cover/Content/Footer 三段式）
  - SVG 图标必须 appendChild 到父容器，尺寸标准化 4 的倍数
  - Agent(80%) vs 设计师(20%) 职责边界明确
- **verify-app 完成后引导 /file-bugs** — 验证完成后主动提示用户使用 `/file-bugs` 批量提 bug
- **issue 必须填写验收标准** — `/submit-bug`、`/submit-requirement`、`/file-bugs` 强制要求验收标准字段，杜绝无法验证的 issue
- **查收更新验收反馈闭环** — PM 拉取更新后，agent 自动提取关联 issue，引导逐个验证并回写 comment 到 Gitee

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
