---
name: ae-submit-requirement
description: "向 AE Team 提交能力需求 — 含查重、验证标准、提交后确认"
dependencies:
  mcp: []
  cli:
    - name: ae
      verify: "ae --version"
  api_keys:
    - GITEE_TOKEN
  scripts: []
smoke_test:
  command: "ae --version"
  expected_exit: 0
  description: "ae CLI available"
---

# Skill: 提交需求 (submit-requirement)

> **ROLE**: 把用户的真实诉求转化为 AE Team 可直接评估和实现的需求。高质量需求 = 有场景、有验证标准、不重复。

## 触发条件

当用户提出功能需求、希望 agent 具备新能力、或描述一个希望自动化的工作流程时触发。

## 执行流程

### Step 1: 理解用户意图

与用户对话，了解（已知项跳过）：

**1a. 核心诉求** — 你想解决什么问题？

**1b. 当前做法** — 现在是怎么做的？（手动流程）

**1c. 自动化程度** — 你希望 AI 帮你做到什么程度？

**1d. 验证标准（必须）** — 追问用户：
> "做好之后怎么验证？能描述一个具体场景吗——你会说什么，期望看到什么结果？"

如果用户说不清，agent 根据诉求草拟 2-3 个验证场景让用户确认。

### Step 1.5: 目标仓库路由检测

收集完信息后、查重前，先确定**默认推荐的目标仓库**。读当前 workspace 的 git remote：

```bash
git remote get-url origin 2>/dev/null
```

按以下规则推荐 target repo（最终以用户确认为准）：

| git remote 模式 | 默认推荐 target | 关键词覆盖（推荐改 `ae-pm`） |
|----------------|----------------|-----------------------------|
| `gitee.com/<org>/product-*` | 当前 product repo（产品自身能力增强） | 需求描述含 `/ae-*` slash command、`ae git`、新 skill / 新 CLI / 中台能力等 AE 工具关键词 |
| `gitee.com/<org>/ae-pm` 或 `ae-go` 或 `ae-dev` 或 `ae-platform` | 当前 AE 仓库 | 无（AE 仓 = AE 仓） |
| 不在 gitee 上 / 无 origin / 无法识别 | 读 `~/.ae/<role>/CLAUDE.md` 的「Issue 路由」表（默认 `ae-pm` / `ae-go`） | 同上 |

向用户展示判断结果并请确认：
> "检测到当前 workspace 在 `<repo>` 下，初判这是 {产品自身需求 / AE 工具能力请求}，建议提到 `<推荐 repo>`。要改提到别的仓库吗？"

**用户确认后**进入 Step 2，后续 Step 2/Step 5/Step 6 的「目标仓库」均使用此处确定的 target repo。

### Step 2: 查重（幂等保护）

提交前搜索是否已有相似需求（目标仓库 = Step 1.5 确定的 target repo）：

```bash
ae git issues list --repo <目标仓库> --state open --pretty
```

- **找到相似 issue** → 告诉用户："已有一个类似的需求 #XXXX，要在上面补充还是新开？"
- **没有相似 issue** → 继续

### Step 3: 格式化

```markdown
## 需求描述
<!-- 用户想要什么能力 -->

## 使用场景
<!-- 什么时候会用到，越具体越好 -->

## 当前做法
<!-- 现在是怎么手动完成的 -->

## 期望效果
<!-- AI 帮忙后应该是什么样的 -->

## 验证标准
<!-- 怎么判断这个能力做好了？必须是可执行的场景 -->
1. 用户说"<具体的话>"，agent 做了 `<具体操作>`，输出 `<具体结果>`
2. ...
3. ...
```

标题格式：`[FEAT] 能力简述`

### Step 4: 用户确认

将标题和正文展示给用户确认。**验证标准段为空不允许提交。**

### Step 5: 提交

目标仓库 = Step 1.5 经用户确认的 target repo（不要重新读 CLAUDE.md 推断）。

```bash
ae git issues create --repo <目标仓库> --title "[FEAT] 需求标题" --body "需求正文"
```

### Step 6: 提交后验证

```bash
ae git issues list --repo <目标仓库> --state open --pretty
```

在列表中确认 issue 存在，向用户展示链接：
> "需求已提交（#XXXX），AE Team 会评估并排期。做好后会通知你更新。"

## 硬规则

1. **提交前必须让用户确认内容**
2. **验证标准必填** — 至少 2 个可执行的验证场景，空验证标准不允许提交
3. **提交前必须查重** — 避免重复需求
4. **提交后必须验证** — 确认 issue 创建成功
5. **多个需求分开提交，每个一个 issue**
6. **不要替用户做技术判断** — 收集诉求，不做方案设计
7. **目标仓库必须经用户确认** — Step 1.5 给出推荐后必须由用户确认，禁止 agent 自行决定 target repo

## Anti-Patterns

- ❌ 用户说"我想要 XX"就直接提 → 必须先理解场景 + 定义验证标准
- ❌ 不查重直接创建 → 先搜索相似需求
- ❌ 验证标准写"功能可用" → 必须是具体场景：用户说什么 → agent 做什么 → 输出什么
- ❌ 提交后不验证 → 必须 list 确认
- ❌ Agent 自己设计方案写在 issue 里 → issue 只描述需求和验证标准，方案由 AE Team 决定
- ❌ 在 product repo workspace 下产品功能需求默认提到 `ae-pm` → 必须先看 git remote，产品功能进 product repo
- ❌ "我想要 ae-pm 加个 skill 干 X" 提到 product repo → AE 工具关键词应覆盖默认，推荐 `ae-pm`

## Troubleshooting

| 问题 | 解决 |
|------|------|
| 用户不知道怎么描述验证标准 | 帮用户草拟 2-3 个场景："你会说 X，期望看到 Y" |
| 找到相似但不完全一样的需求 | 在已有 issue 上 comment 补充新场景 |
| 用户的需求跨多个 skill | 拆分为独立需求，每个聚焦一个能力 |
| 目标仓库不确定 | 默认当前角色的主仓库（ae-pm / ae-go） |
