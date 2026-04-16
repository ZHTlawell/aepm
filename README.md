# AE PM Agent

> 让 PM 通过 vibe coding 产出可直接上架的 iOS App。

## 这是什么

AE PM Agent 是一套 **AI 编程助手的指令和能力包**，安装后你的 AI 编码工具（Claude Code / Codex / Cursor 等）就具备了产品经理专属的工作流支持。

它解决的核心问题是：**PM 用 vibe coding 做出的 demo 原型，与真正能上架 App Store 之间存在大量工程化环节。** AE PM Agent 把从 demo 到上架的完整路径拆成 8 个 Phase，每个 Phase 对应一组 Skill，走完即可提审。

## 端到端流水线

```
Phase 0  Vibe Coding Demo ─── PM 用 AI 工具产出 demo（受技术选型约束）
   │
Phase 1  Demo → Speckit ───── 提取标准规格书 / 逆向已上架 App
   │
Phase 2  Speckit → 成品 ───── ae-dev 生成 iOS + 后端，E2E 对比验证
   │
Phase 3  发布准备 ──────────── 预检 + 埋点 + 支付 + Onboarding + Paywall
   │
Phase 4  TestFlight 分发 ──── 签名 → Archive → Upload → 测试组
   │
Phase 5  验证 & 修复 ──────── 真机验证 + 埋点验证 + 购买验证 + Bug 修复
   │
Phase 6  App Store 提审 ──── 审核自检 + ASC 配置 + Submit  ← 🆕 建设中
   │
Phase 7  运营迭代 ──────────── 去版权化 + 原型转 Figma + A/B 测试
```

## 各 Phase 详细说明

### Phase 0: Vibe Coding Demo

用 AI 编码工具（Antigravity / Claude Code / Cursor）做出 demo 原型。ae-pm 的技术选型约束会确保 demo 符合工程规范。

**输出：** 可运行的 demo 项目

### Phase 1: Demo → Speckit

| Skill | 说明 |
|-------|------|
| `/ae-demo-to-speckit` | 从 demo 源码自动提取 6 模块标准规格书 |
| `/ae-app-to-speckit` | 从已上架 App 逆向提取 speckit（需 iPhone + USB + WDA） |

```bash
/ae-demo-to-speckit
```

**输出：** `speckit/` 目录（产品定位/场景/架构/设计/数据/API）

### Phase 2: Speckit → 成品

**这一步需要切换到 ae-dev 环境。**

```bash
# 方式一：ae CLI（推荐）
ae dev speckit-receive ~/Projects/MyApp/speckit/

# 方式二：手动
cd ~/Projects/MyApp-prod && ae link dev . && claude
```

Dev Agent 自动执行：验证 speckit → 生成 OpenAPI 契约 → 生成 Spring Boot 后端 → 生成 SwiftUI iOS → 编译验证。

验证阶段：

| Skill | 说明 |
|-------|------|
| `/ae-verify-app` | E2E 对比 demo vs 成品，自动归因差异 |
| `/ae-file-bugs` | 从 verify 报告批量生成 issue 并提交 |

**输出：** 功能完整的 iOS + 后端项目

### Phase 3: 发布准备 (Publish-Ready)

| Skill | 说明 |
|-------|------|
| `/ae-preflight` | 预检扫描 — API Key 泄漏/Icon/Privacy/签名/资源尺寸 |
| `/ae-analytics-setup` | Firebase Analytics + Adjust SDK 双轨埋点 |
| `/ae-superwall-setup` | Superwall 支付集成（账号 + ASC 订阅 + SDK + StoreKit 2） |
| `/ae-onboarding-design` | 生成 Onboarding 幻灯片（HTML/CSS/JS，Superwall/WebView） |
| `/ae-paywall-design` | 生成 Paywall 付费墙（HTML 或 Native StoreKit 2） |

```bash
/ae-preflight          # 先扫描，修完所有 blocker
/ae-analytics-setup    # 接埋点
/ae-superwall-setup    # 接支付
```

**输出：** 代码满足上架标准

### Phase 4: TestFlight 分发

| Skill | 说明 |
|-------|------|
| `/ae-testflight-publish` | 签名 → Archive → Upload → TestFlight 测试组分发 |

```bash
/ae-testflight-publish
```

真机自动化环境（如需要）通过 ae-go 提供：`/ae-mobile-setup` + `/ae-mobile-agent`

**输出：** TestFlight 可测 Build

### Phase 5: 验证 & 修复

| 验证项 | 方法 |
|--------|------|
| 功能验证 | 真机安装 TestFlight Build，核心流程走通 |
| 埋点验证 | GA4 Realtime + Adjust Sandbox 确认数据到达 |
| 购买验证 | StoreKit Sandbox 购买流程完整 |
| Bug 修复 | `/ae-report-fix` 回流修复方案 |

**输出：** 全链路验证通过

### Phase 6: App Store 提审 `建设中`

| Skill | 说明 | 状态 |
|-------|------|------|
| `/ae-app-review-check` | 对照 Apple Review Guidelines + AI 审核规则自检 | 🔨 待建 |
| `/ae-asc-submit` | ASC 截图/描述/关键词/Privacy URL → Submit for Review | 🔨 待建 |

**输出：** 审核通过上线

### Phase 7: 运营迭代

| Skill | 说明 |
|-------|------|
| `/ae-image-decopyrighter` | 图片 AI 重绘去版权化（Gemini Imagen 4.0） |
| `/ae-demo-to-figma` | 将 demo 项目 UI 导入 Figma 设计稿 |

## 通用能力（不属于特定 Phase）

| Skill | 说明 |
|-------|------|
| `/ae-submit-bug` | 提交 bug 报告到 Gitee |
| `/ae-submit-requirement` | 提交可复用能力需求 |
| `/ae-report-fix` | 本地修复成功后回流方案给 AE Team |
| `/ae-lark-feishu` | 飞书消息搜索/读取/发送 + 会议妙记/逐字稿 |
| `/ae-prod-to-local` | 将线上项目转为本地可编译运行的配置 |
| `/ae-skill-creator` | 标准化 skill 构建流程（六段标准 + 审计模式） |
| 查收更新 | 直接告诉 agent，查看 CHANGELOG 了解最新版本 |

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
- Gitee 账号（[注册地址](https://gitee.com)）

### 一键搭建（推荐）

```bash
# 1. 安装 ae CLI（只需一次）
curl -sSL https://raw.githubusercontent.com/ligenjian001-ai/ae-platform/master/cli/install.sh | sh

# 2. 一键搭建环境（安装依赖 + 配置 Token + 入驻确认）
ae setup
```

`ae setup` 会自动完成：
- 克隆 ae-pm / ae-dev 仓库到 `~/.ae/`
- 交互式配置 Gitee Token（引导你生成并验证）
- 环境健康检查
- 自动完成入驻确认

```bash
# 3. 在你的项目中启用
cd 你的项目目录
ae link pm .
```

搞定！打开 AI 编码工具即可使用所有 AE PM 能力。

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

或手动链接：

```bash
mkdir -p .claude/skills
ln -sf ~/.ae/pm/.claude/skills/* .claude/skills/
echo '' >> CLAUDE.md
echo '## AE PM 约束' >> CLAUDE.md
echo '请同时遵守 ~/.ae/pm/CLAUDE.md 中的技术选型约束和工作流。' >> CLAUDE.md
```

**Step 4: 验证**

```bash
ae doctor
```

</details>

### 更新（一次更新，所有项目生效）

```bash
ae update
```

或手动：`cd ~/.ae/pm && git pull origin main`

通过软链接挂载的 skills 自动更新，无需逐项目操作。

### 项目结构示意

```
~/.ae/                          ← 全局安装（只有一份）
├── pm/                         ← ae-pm
│   ├── CLAUDE.md
│   ├── .claude/skills/
│   │   ├── ae-demo-to-speckit/SKILL.md
│   │   ├── ae-verify-app/SKILL.md
│   │   ├── ae-submit-requirement/SKILL.md
│   │   └── ae-submit-bug/SKILL.md
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

在 Claude Code 中使用 `/ae-submit-bug` skill，或告诉 agent：

> "帮我提一个 bug：[描述你的问题]"

Agent 会引导你描述问题，然后通过 `ae` CLI 自动提交到 Gitee。

**方式二：直接用 CLI**

```bash
ae pm submit-bug "问题标题" "问题描述"
```

### 想要新能力？

使用 `/ae-submit-requirement` skill。注意：**每个需求必须是可复用机制**，而非一次性任务。

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

当前版本：**v0.41.0**

## 由谁维护

AE Team（Agent Engineering Team）。代码变更仅通过 AE Team 发布，PM 通过 issue 和需求 skill 参与贡献。
