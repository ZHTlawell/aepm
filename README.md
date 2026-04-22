# AE PM Agent

> 让 PM 通过 vibe coding 产出可直接上架的 iOS App。

## 这是什么

AE PM Agent 是一套 **AI 编程助手的指令和能力包**，安装后你的 AI 编码工具（Claude Code / Codex / Cursor 等）就具备了产品经理专属的工作流支持。

它解决的核心问题是：**PM 用 vibe coding 做出的 demo 原型，与真正能上架 App Store 之间存在大量工程化环节。**

设计原则是 **skill = 人类可确认中间品之间的变换**：整条流水线被拆成 4 个人类可审阅的中间品（M0→M3），每个 skill 负责把一个中间品变成下一个。PM 在每个中间品处可以停下来检查，确认无误再推进下一段。

## 中间品流水线

```
M0  Idea ─────────────────────── 产品想法 / demo 雏形 / 参考 App
 │
 │  [M0 → M1] PM 工具箱（集合）
 │
M1  Speckit ────────────────────  6 模块标准规格书（产品/场景/架构/设计/数据/API）
 │
 │  [M1 → M2] ae-speckit-to-app（核心段）
 │
M2  本地可用程序 ───────────────── Route B 代码骨架 + E2E 跑通
 │
 │  [M2 → M3] 发布段
 │
M3  TestFlight ──────────────── 可测 Build 已分发
```

一次通过率（first-pass yield）是核心度量：每段 skill 都尽量做到"一次跑完即成"，失败时通过 `/ae-report-fix` 回流修复经验。

## 各段 skill 详解

### M0 → M1：PM 工具箱（集合）

把"想法/参考 App/demo"变成规范化的 Speckit。依据起点不同，选择合适的入口：

| Skill | 说明 | 触发命令 |
|-------|------|---------|
| `/ae-app-to-speckit` | 从已上架 App 逆向提取 speckit（iPhone + USB + WDA） | `/ae-app-to-speckit` |
| `/ae-demo-to-speckit` | 从 demo 源码自动提取 6 模块 Speckit | `/ae-demo-to-speckit` |
| `/ae-onboarding-design` | 生成 Onboarding 幻灯片规格（HTML/CSS/JS） | `/ae-onboarding-design` |
| `/ae-paywall-design` | 生成 Paywall 付费墙规格（HTML 或 Native StoreKit 2） | `/ae-paywall-design` |
| `/ae-speckit-brainstorm` 🆕 | 从零开始与 PM 对话共创 Speckit（无 demo / 无参考 App） | `/ae-speckit-brainstorm` |

**输出：** `speckit/` 目录，人类可审阅。

### M1 → M2：ae-speckit-to-app（核心段）

| Skill | 说明 | 触发命令 |
|-------|------|---------|
| `/ae-speckit-to-app` 🆕 | Route B 约束 + 代码模板包，从 Speckit 生成本地可用程序 | `/ae-speckit-to-app` |

这是 PM 产品线最核心、技术约束最密集的一段。skill 本身是**薄 harness**，只做约束透传 + 模板装配 + precheck，具体构建由外部 harness（ae-dev / Claude Code / Codex）驱动。预检已融入这个 skill 内部（不再独立 `/ae-preflight`）。

**输出：** 可在模拟器/真机本地运行的 iOS 工程（含后端）。

### M2 → M3：发布段

| Skill | 说明 | 触发命令 | 标记 |
|-------|------|---------|------|
| `/ae-app-to-testflight` | 签名 → Archive → Upload → TestFlight 分发（原 `ae-testflight-publish` 改名） | `/ae-app-to-testflight` | — |
| `/ae-analytics-integrate` | Firebase Analytics + Adjust SDK 双轨埋点（原 `ae-analytics-setup` 改名） | `/ae-analytics-integrate` | optional |

**输出：** TestFlight 可测 Build。

## Utility Skills

下列 skill 不在主线 M0→M3 流水线上，但在日常 PM 工作中按需触发。源码仍保留在 `skills/pm/` 下。

| Skill | 一句话定位 |
|-------|-----------|
| `/ae-verify-app` | E2E 对比 demo vs 成品，自动归因差异 |
| `/ae-file-bugs` | 从 verify 报告批量生成 issue 并提交 |
| `/ae-demo-to-figma` | 将 demo 原型导入 Figma 设计稿 |
| `/ae-image-decopyrighter` | 图片 AI 重绘去版权化（Gemini Imagen 4.0） |
| `/ae-prod-to-local` | 将线上项目转为本地可编译运行的配置 |

## 路线：Route B

PM 产品线路线定调为 **Route B**（Route A 不再维护）：

- **工程形态：** CocoaPods 依赖管理（不用 SPM），多 target Xcode 工程
- **SDK 栈：** BCStoreKit（支付）+ BCSensor（埋点）+ BCAdjust（归因）+ BCNetwork（网络）
- **构建流程：** Work Chain 12 步（从环境预检到 Archive 的固定流水线）
- **约束位置：** `/ae-speckit-to-app` skill 内置所有 Route B 约束 + 代码模板，harness 只负责透传

关联 issue：[#II8UYE](https://gitee.com/turningsyn/ae-pm/issues/II8UYE) / [#II8RAE](https://gitee.com/turningsyn/ae-pm/issues/II8RAE) / [#IJC8D4](https://gitee.com/turningsyn/ae-platform/issues/IJC8D4)

## 核心原则

1. **Skill = 人类可确认中间品之间的变换** — 每段 skill 有明确输入输出中间品（M0/M1/M2/M3），PM 可在中间品处停检。
2. **Harness 薄，透传约束** — skill 本身不重复造轮子，把 Route B 约束和代码模板打包交给外部 harness（ae-dev / Claude Code）执行。
3. **一次通过率为核心度量** — 每段 skill 的目标都是 first-pass yield，失败即通过 `/ae-report-fix` 回流修复。

## 快速开始

### 前置要求

- AI 编码工具（Claude Code / Codex / Cursor / Antigravity 任选）
- Gitee 账号（[注册地址](https://gitee.com)）

### 一键搭建（推荐）

```bash
# 1. 克隆 ae-pm 并运行安装脚本（首次安装）
git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
bash ~/.ae/pm/cli/install.sh

# 2. 一键搭建环境（安装依赖 + 配置 Token + 入驻确认）
ae setup
```

> 首次 `git clone` 需要你已在本机配置好 Gitee 企业版 git 凭证（`git config user.name/email` + 通过 SSH key 或 token 有 turningsyn 组织的读取权限）。如果 clone 报 403，联系 AE Team 开通权限。

`bash install.sh` 会把 ae CLI 软链到 `~/.ae/bin/ae`，并尝试克隆 ae-go / ae-dev（已有则跳过）。

`ae setup` 会自动完成：
- 交互式配置 Gitee Token（引导你生成并验证）
- 环境健康检查
- 自动完成入驻确认

### 第一次使用（最小命令序列）

```bash
# 1. 在项目目录中启用
cd 你的项目目录
ae link pm .

# 2. 打开 AI 编码工具（Claude Code / Codex / Cursor）
# 然后根据起点选择入口 skill：

# 起点是 demo 源码：
/ae-demo-to-speckit
# 起点是已上架 App：
/ae-app-to-speckit
# 起点只是想法：
/ae-speckit-brainstorm

# 3. Speckit 生成后，构建本地可用程序
/ae-speckit-to-app

# 4. 发布到 TestFlight
/ae-app-to-testflight
```

### 更新（一次更新，所有项目生效）

```bash
ae update
```

通过软链接挂载的 skills 自动更新，无需逐项目操作。

### 手动搭建

如果 `ae setup` 不适用，可以手动操作：

<details>
<summary>展开手动步骤</summary>

**Step 1: 全局安装**

```bash
mkdir -p ~/.ae
git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
```

**Step 2: 配置 Token**

```bash
mkdir -p ~/.config/ae
cat > ~/.config/ae/credentials.env << 'EOF'
GITEE_TOKEN=你的gitee_access_token
EOF
chmod 600 ~/.config/ae/credentials.env
```

Token 生成地址：https://gitee.com/profile/personal_access_tokens（需要 `issues` 和 `projects` 权限）

**Step 3: 在项目中启用**

```bash
cd 你的项目目录
ae link pm .
```

**Step 4: 验证**

```bash
ae doctor
```

</details>

### 项目结构示意

```
~/.ae/                          ← 全局安装（只有一份）
├── pm/                         ← ae-pm
│   ├── CLAUDE.md
│   ├── .claude/skills/
│   │   ├── ae-speckit-brainstorm/SKILL.md
│   │   ├── ae-speckit-to-app/SKILL.md
│   │   ├── ae-app-to-testflight/SKILL.md
│   │   └── ...
│   ├── README.md
│   └── CHANGELOG.md
└── dev/                        ← ae-dev（开发者用）

~/Projects/YourApp/             ← 你的项目（任意多个）
├── .claude/skills/             ← 软链接到 ~/.ae/pm/.claude/skills/
├── CLAUDE.md
└── ...
```

## 移出主线（另议）

下列能力从本次 M0→M3 主线中移出，源码保留供参考，但需求和路线另议：

- **`/ae-app-review-check`** — App Store 审核自检（M3 之后另议）
- **`/ae-asc-submit`** — ASC 元数据提交审核（M3 之后另议）
- **`/ae-prod-data-feedback-report`** — 产品数据反馈报告（Stage 5 另议）
- **`/ae-preflight`** — 已融入 `/ae-speckit-to-app` 内部 precheck，不再独立触发；目录暂保留供参考。

**已废弃：** `/ae-superwall-setup`（Route A 遗产，已删除目录）。

## 反馈与贡献

### 遇到问题？

在 Claude Code 中使用 `/ae-submit-bug`，或告诉 agent：

> "帮我提一个 bug：[描述你的问题]"

或直接用 CLI：

```bash
ae pm submit-bug "问题标题" "问题描述"
```

### 想要新能力？

使用 `/ae-submit-requirement`。**每个需求必须是可复用机制**，而非一次性任务。

### Meta skill

- `/ae-skill-creator` — 造 skill 的 skill，标准化 skill 构建流程（六段标准 + 审计模式）

## 关联 Issue

- [#IJC8D4](https://gitee.com/turningsyn/ae-platform/issues/IJC8D4) — PM 产品线结构性重写
- [#II8UYE](https://gitee.com/turningsyn/ae-pm/issues/II8UYE) — Route B 路线定调
- [#II8RAE](https://gitee.com/turningsyn/ae-pm/issues/II8RAE) — 埋点与支付整合

## 版本历史

查看 [CHANGELOG.md](CHANGELOG.md) 了解完整更新记录。

当前版本：**v0.50.2**

## 由谁维护

AE Team（Agent Engineering Team）。代码变更仅通过 AE Team 发布，PM 通过 issue 和需求 skill 参与贡献。
