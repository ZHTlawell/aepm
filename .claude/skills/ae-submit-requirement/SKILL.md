---
name: ae-submit-requirement
description: "向 AE Team 提交能力需求"
---

# Skill: 提交需求 (submit-requirement)

## 触发条件

当用户提出功能需求、希望 agent 具备新能力、或描述一个希望自动化的工作流程时触发。

## 核心原则

**收集用户的真实诉求，转化为 AE Team 可理解的需求描述。** 不需要用户懂技术，只需要说清"想让 AI 帮我做什么"。

## 执行流程

### Step 1: 理解用户意图

与用户对话，了解：
- 你想解决什么问题？
- 现在是怎么做的？（手动流程）
- 你希望 AI 帮你做到什么程度？

### Step 2: 整理需求

将用户的描述整理为结构化格式：

```markdown
## 需求描述
<!-- 用户想要什么能力 -->

## 使用场景
<!-- 什么时候会用到 -->

## 当前做法
<!-- 现在是怎么手动完成的 -->

## 期望效果
<!-- AI 帮忙后应该是什么样的 -->

## 验证标准
<!-- 如何判断这个能力做好了？至少一条可执行的验证步骤 -->
1. ...
```

### Step 3: 用户确认

将整理好的标题和正文展示给用户确认。

标题格式：`[FEAT] 能力简述`

### Step 4: 提交

**确定目标仓库：** 读取已安装的 AE 角色 CLAUDE.md（路径为 `~/.ae/go/.claude/CLAUDE.md` 或 `~/.ae/pm/.claude/CLAUDE.md`，**不是当前 workspace 的 CLAUDE.md**）中的「Issue 路由」表，获取目标仓库名。

```bash
source ~/.config/ae/credentials.env 2>/dev/null || source ~/.config/ae-pm/credentials.env 2>/dev/null
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null

curl -s -X POST "https://gitee.com/api/v5/repos/turningsyn/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "'"$GITEE_TOKEN"'",
    "repo": "<目标仓库>",
    "title": "[FEAT] 需求标题",
    "body": "需求正文"
  }'
```

### Step 5: 确认结果

向用户展示 issue 链接：
> "需求已提交，AE Team 会评估并排期。做好后会通知你更新。"

## 重要规则

- **提交前必须让用户确认内容**
- **验证标准必填** — 如果用户没提供，主动追问
- 多个需求分开提交，每个一个 issue
