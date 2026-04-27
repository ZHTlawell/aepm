---
name: ae-submit-bug
description: "提交 bug 报告到 Gitee — 含查重、验证标准、提交后确认"
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

# Skill: 提交 Bug (submit-bug)

> **ROLE**: 把用户遇到的问题转化为高质量的 issue。高质量 = AE Team 拿到 issue 后能直接复现、知道修好的标准是什么、不需要再追问。

## 触发条件

当用户报告 bug、描述异常行为、或说"帮我提一个 bug"时触发。

## 执行流程

### Step 1: 收集 bug 信息

与用户对话，逐项厘清（已知项跳过，不要一次问完）：

**1a. 问题描述** — 发生了什么？涉及什么产品/工具/项目？

**1b. 具体化** — 如果描述笼统（"用不了"、"有问题"），追问：
> "能具体说说是哪个环节出了问题吗？比如点了什么按钮、看到了什么错误？"

**1c. 截图（如有）** — UI 问题询问截图。无截图标注 `无截图，需人工复现`。

**1d. 复现步骤** — 必须有可执行的步骤，不是描述性文字。

**1e. 验证标准（必须）** — 追问用户：
> "修好之后应该是什么样的？怎么确认修好了？"

如果用户说不清，agent 根据问题描述草拟验证标准让用户确认。

### Step 1.5: 目标仓库路由检测

收集完信息后、查重前，先确定**默认推荐的目标仓库**。读当前 workspace 的 git remote：

```bash
git remote get-url origin 2>/dev/null
```

按以下规则推荐 target repo（最终以用户确认为准）：

| git remote 模式 | 默认推荐 target | 关键词覆盖（推荐改 `ae-pm`） |
|----------------|----------------|-----------------------------|
| `gitee.com/<org>/product-*` | 当前 product repo（例 `product-reflow`） | bug 描述含 `/ae-*` slash command、`ae git`、`ae-speckit-to-app`、`ae-analytics-integrate`、`ae-paywall-integrate` 等 AE 工具关键词 |
| `gitee.com/<org>/ae-pm` 或 `ae-go` 或 `ae-dev` 或 `ae-platform` | 当前 AE 仓库 | 无（AE 仓 = AE 仓） |
| 不在 gitee 上 / 无 origin / 无法识别 | 读 `~/.ae/<role>/CLAUDE.md` 的「Issue 路由」表（默认 `ae-pm` / `ae-go`） | 同上 |

向用户展示判断结果并请确认：
> "检测到当前 workspace 在 `<repo>` 下，初判这是 {产品 bug / AE 工具 bug}，建议提到 `<推荐 repo>`。要改提到别的仓库吗？"

**用户确认后**进入 Step 2，后续 Step 2/Step 5/Step 6 的「目标仓库」均使用此处确定的 target repo。

### Step 2: 查重（幂等保护）

提交前搜索是否已有相似 issue（目标仓库 = Step 1.5 确定的 target repo）：

```bash
ae git issues list --repo <目标仓库> --state open --pretty
```

扫描返回的 issue 列表，检查标题或描述是否与当前 bug 相似。

- **找到相似 issue** → 告诉用户："已有一个类似的 issue #XXXX，要在上面补充评论还是新开一个？"
- **没有相似 issue** → 继续

### Step 3: 格式化

```markdown
## 描述
<!-- 一句话说清问题 -->

## 具体表现
1. ...
2. ...

## 复现步骤
1. ...
2. ...

## 期望行为
<!-- 修好后应该是什么样 -->

## 验证标准
<!-- AE Team 修完后怎么验证 -->
1. 执行 `<具体命令>`，预期输出 `<具体结果>`
2. ...
```

标题格式：`[BUG] 产品名 — 问题简述`

### Step 4: 用户确认

将标题和正文展示给用户确认。**验证标准段为空不允许提交。**

### Step 5: 提交

目标仓库 = Step 1.5 经用户确认的 target repo（不要重新读 CLAUDE.md 推断）。

```bash
ae git issues create --repo <目标仓库> --title "[BUG] 标题" --body "正文"
```

### Step 6: 提交后验证

确认 issue 创建成功：

```bash
ae git issues list --repo <目标仓库> --state open --pretty
```

在列表中找到刚创建的 issue，向用户展示链接：
> "Bug 已提交（#XXXX），AE Team 会跟进处理。"

如果列表中找不到，告知用户提交可能失败，建议重试。

## 硬规则

1. **提交前必须让用户确认内容**
2. **验证标准必填** — 空验证标准不允许提交
3. **提交前必须查重** — 不查重就提 = 制造噪音
4. **提交后必须验证** — 不验证就说"已提交" = 可能骗了用户
5. **笼统描述必须追问具体化**
6. **多个 bug 逐个提交，每个一个 issue**
7. **目标仓库必须经用户确认** — Step 1.5 给出推荐后必须由用户确认，禁止 agent 自行决定 target repo

## Anti-Patterns

- ❌ 用户说"有 bug"就直接提 → 必须先收集具体信息 + 验证标准
- ❌ 不查重直接创建 → 先 `ae git issues list` 搜索相似 issue
- ❌ 验证标准写"功能正常" → 必须是可执行的具体命令 + 预期输出
- ❌ 提交后不验证就说"已提交" → 必须 list 确认 issue 存在
- ❌ 在 product repo workspace 下默认提到 `ae-pm` → 必须先看 git remote，产品 bug 应进 product repo
- ❌ 在 product repo workspace 下报 `/ae-speckit-to-app` 报错却提到 product repo → AE 工具关键词应覆盖默认，推荐 `ae-pm`
- ❌ 跳过 Step 1.5 直接读 `~/.ae/<role>/CLAUDE.md` → 仅在 git remote 不可识别时才回退到 CLAUDE.md 路由表

## Troubleshooting

| 问题 | 解决 |
|------|------|
| `ae git issues create` 报 401 | Gitee Token 过期，检查 `~/.config/ae/credentials.env` |
| 提交后 list 找不到 | API 延迟，等 5 秒重试；或检查目标仓库是否正确 |
| 用户不知道怎么写验证标准 | 根据问题描述帮用户草拟，让用户确认 |
| 找到相似 issue 但用户坚持新开 | 尊重用户选择，在新 issue body 中引用相似 issue 编号 |
