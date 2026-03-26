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

## 已有能力

| Skill | 命令 | 说明 |
|-------|------|------|
| Demo 转 Speckit | `/demo-to-speckit` | 从 demo 源码自动提取 6 模块标准规格书 |
| App 差异验证 | `/verify-app` | E2E 对比两个 app 的功能差异，自动归因到提取/生成/约束环节 |
| 提交需求 | `/submit-requirement` | 向 AE Team 提交新能力需求（必须是可复用机制） |
| Issue 反馈 | 直接告诉 agent | 提交 bug 或使用疑问到 ae-pm repo |
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

- AI 编码工具（Claude Code / Codex / Cursor 任选其一）
- Gitee 账号 + access token（[生成地址](https://gitee.com/profile/personal_access_tokens)，需要 `issues` 和 `repo` 权限）

### 安装

```bash
git clone https://gitee.com/turningsyn/ae-pm.git
cd ae-pm
```

### 配置 Token

```bash
mkdir -p ~/.config/ae-pm
cat > ~/.config/ae-pm/credentials.env << 'EOF'
GITEE_TOKEN=你的gitee_access_token
EOF
chmod 600 ~/.config/ae-pm/credentials.env
```

### 使用

根据你的 AI 编码工具：

| 工具 | 操作 |
|------|------|
| **Claude Code** | 在 ae-pm 目录下运行 `claude`，或将 `CLAUDE.md` + `.claude/` 目录拷贝到你的项目 |
| **Codex** | 将 `CLAUDE.md` 内容合并到你的项目 `AGENTS.md` 中 |
| **Cursor** | 将约束部分拷贝到 `.cursorrules` |

### 验证

启动 AI 编码工具后，说：

> "帮我完成入驻确认"

Agent 会在 Gitee issue 下方发 comment，确认你的配置成功。

## 反馈与贡献

### 遇到问题？

告诉你的 agent：

> "帮我提一个 bug：[描述你的问题]"

Agent 会自动格式化并提交到 ae-pm repo 的 issue 列表。

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

当前版本：**v0.3.0**

## 由谁维护

AE Team（Agent Engineering Team）。代码变更仅通过 AE Team 发布，PM 通过 issue 和需求 skill 参与贡献。
