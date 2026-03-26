# AE PM Agent

> 让 PM 通过 vibe coding 产出可直接上线的产品原型。

## 这是什么

AE PM Agent 是一套 **AI 编程助手的指令和能力包**，安装后你的 AI 编码工具（Claude Code / Codex / Cursor 等）就具备了产品经理专属的工作流支持。

它解决的核心问题是：**PM 用 vibe coding 做出的 demo 原型，往往因为技术选型不规范，导致后续无法高效转化为可上线的成品。**

AE PM Agent 通过两个机制解决这个问题：

1. **技术选型约束** — 在 vibe coding 阶段就确保 demo 符合工程规范（如必须用 SwiftUI Native，禁止 WebView 包装）
2. **标准化工作流 (Skills)** — 把 demo→成品的每一步都做成可复用的能力

## 核心流程

```
PM vibe coding demo 原型（在约束下）
        │
        ▼
  /demo-to-speckit    ← 自动提取标准规格书
        │
        ▼
  Speckit (6 模块)    ← 产品定位/场景/架构/设计/数据/API
        │
        ▼
  Dev Agent 生成成品   ← 调用 ae-dev 生成 iOS + 后端
        │
        ▼
  /verify-app          ← E2E 对比 demo vs 成品，自动归因差异
        │
        ▼
  可上线的产品
```

## 各步骤操作说明

### Step 1: Vibe Coding Demo

用 AI 编码工具（Antigravity / Claude Code / Cursor）做出 demo 原型。ae-pm 的技术选型约束会确保 demo 符合工程规范。

### Step 2: Demo → Speckit

在 demo 项目中执行：

```bash
# 在 Claude Code 中
/demo-to-speckit
```

产出 `speckit/` 目录，包含 6 个标准模块文件。

### Step 3: Speckit → 成品（调用 ae-dev）

**这一步需要切换到 Dev Agent 的工作环境。** 具体做法：

```bash
# 1. 创建成品项目目录
mkdir -p ~/Projects/ShoeLens-prod
cd ~/Projects/ShoeLens-prod

# 2. 链接 ae-dev（如未链接过）
ae link dev .
# 或手动：
#   mkdir -p .claude/skills
#   ln -sf ~/.ae/dev/.claude/skills/* .claude/skills/
#   echo '请同时遵守 ~/.ae/dev/CLAUDE.md 中的技术选型和生成流程。' >> CLAUDE.md

# 3. 打开 Claude Code，告诉它 speckit 位置
claude
# 然后说：从 ~/Projects/ShoeLens/speckit/ 生成项目
```

或者用 `ae` CLI 一步完成：

```bash
ae dev speckit-receive ~/Projects/ShoeLens/speckit/
```

Dev Agent 会自动执行：验证 speckit → 生成 OpenAPI 契约 → 生成 Spring Boot 后端 → 生成 SwiftUI iOS → 编译验证。

### Step 4: 验证

回到 demo 项目，E2E 对比：

```bash
/verify-app
```

## 已有能力

| Skill | 命令 | 说明 |
|-------|------|------|
| Demo 转 Speckit | `/demo-to-speckit` | 从 demo 源码自动提取 6 模块标准规格书 |
| App 差异验证 | `/verify-app` | E2E 对比两个 app 的功能差异，自动归因到提取/生成/约束环节 |
| 提交需求 | `/submit-requirement` | 向 AE Team 提交新能力需求（必须是可复用机制） |
| 提交 Bug | `/submit-bug` 或 `ae pm submit-bug` | 提交 bug 报告到 ae-pm repo |
| 批量提 Bug | `/file-bugs` 或 `ae pm file-bugs` | 从 verify 报告自动生成 issue 并批量提交 |
| 查收更新 | 直接告诉 agent | 查看 CHANGELOG 了解最新版本更新 |

## 技术选型约束

安装后，你的 AI 编码工具在 vibe coding 时会遵守以下约束：

**iOS 前端**
- 必须使用 SwiftUI Native（禁止 WebView hybrid）
- 所有可交互元素必须有 `accessibilityIdentifier`
- 单文件不超过 500 行

**后端**
- Spring Boot 3.x + MyBatis + Flyway
- 多模块 Gradle 工程

**数据层**
- 数据不得硬编码在 UI 代码中
- Mock API 必须遵循标准 REST 契约

## 快速开始

### 前置要求

- AI 编码工具（Claude Code / Codex / Cursor / Antigravity 任选）
- Gitee 账号 + access token（[生成地址](https://gitee.com/profile/personal_access_tokens)，需要 `issues` 和 `repo` 权限）

### Step 1: 全局安装（只需一次）

ae-pm 安装到 `~/.ae/pm/`，所有项目共享同一份：

```bash
mkdir -p ~/.ae
git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
```

### Step 2: 配置 Token（只需一次）

```bash
mkdir -p ~/.config/ae-pm
cat > ~/.config/ae-pm/credentials.env << 'EOF'
GITEE_TOKEN=你的gitee_access_token
EOF
chmod 600 ~/.config/ae-pm/credentials.env
```

### Step 3: 在你的项目中启用

在你需要使用 ae-pm 能力的项目中，运行以下命令接入：

**Claude Code**

```bash
cd 你的项目目录

# 1. 链接 skills（推荐，更新自动生效）
mkdir -p .claude/skills
ln -sf ~/.ae/pm/.claude/skills/* .claude/skills/

# 2. 在你的 CLAUDE.md 中引用 ae-pm 约束（加在末尾）
echo '' >> CLAUDE.md
echo '## AE PM 约束' >> CLAUDE.md
echo '请同时遵守 ~/.ae/pm/CLAUDE.md 中的技术选型约束和工作流。' >> CLAUDE.md
```

**Codex / Cursor / Antigravity**

将 `~/.ae/pm/CLAUDE.md` 中的约束部分拷贝到你的工具对应配置中（`AGENTS.md` / `.cursorrules` / 项目设定）。

### Step 4: 验证

启动 AI 编码工具后，说：

> "帮我完成 ae-pm 入驻确认"

### 更新（一次更新，所有项目生效）

```bash
cd ~/.ae/pm && git pull origin main
```

通过软链接挂载的 skills 自动更新，无需逐项目操作。

### 项目结构示意

```
~/.ae/                          ← 全局安装（只有一份）
├── pm/                         ← ae-pm
│   ├── CLAUDE.md
│   ├── .claude/skills/
│   │   ├── demo-to-speckit.md
│   │   ├── verify-app.md
│   │   ├── submit-requirement.md
│   │   └── submit-bug.md
│   ├── README.md
│   └── CHANGELOG.md
└── dev/                        ← ae-dev（开发者用）
    ├── CLAUDE.md
    └── .claude/skills/

~/Projects/ShoeLens/            ← 你的项目（任意多个）
├── .claude/skills/             ← 软链接到 ~/.ae/pm/.claude/skills/
├── CLAUDE.md                   ← 你的项目指令 + ae-pm 引用
├── ShoeLens/
└── ...

~/Projects/AnotherApp/          ← 另一个项目
├── .claude/skills/             ← 同样软链接
├── CLAUDE.md
└── ...
```

## 反馈与贡献

### 遇到问题？

**方式一：通过 agent（推荐）**

在 Claude Code 中使用 `/submit-bug` skill，或告诉 agent：

> "帮我提一个 bug：[描述你的问题]"

Agent 会引导你描述问题，然后通过 `ae` CLI 自动提交到 Gitee。

**方式二：直接用 CLI**

```bash
ae pm submit-bug "问题标题" "问题描述"
```

### 想要新能力？

使用 `/submit-requirement` skill。注意：**每个需求必须是可复用机制**，而非一次性任务。

例如：
- 合格："希望 PM agent 能自动生成 API 文档" — 所有 PM 都能复用
- 不合格："帮我把这个项目部署上线" — 一次性任务

### 获取更新

```bash
cd ae-pm
git pull origin main
```

或告诉 agent "查收更新"，它会对比本地和远端版本。

## 版本历史

查看 [CHANGELOG.md](CHANGELOG.md) 了解完整更新记录。

当前版本：**v0.8.0**

## 由谁维护

AE Team（Agent Engineering Team）。代码变更仅通过 AE Team 发布，PM 通过 issue 和需求 skill 参与贡献。
