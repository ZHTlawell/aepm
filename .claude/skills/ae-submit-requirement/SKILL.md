---
description: "向 AE Team 提交可复用能力需求"
---

# Skill: 提交需求 (submit-requirement)

## 触发条件

当用户提出功能需求、希望 agent 具备新能力、或描述一个希望自动化的工作流程时触发。

## 核心原则

**每个需求必须是一个可复用机制（Reusable Mechanism）**，而非一次性任务。

一个合格的需求应满足：
1. **可被 agent 感知** — 需求实现后，agent 能通过 skill 或指令自动执行
2. **可被同角色复用** — 其他 PM 遇到同类场景时，也能直接使用这个能力
3. **可被验证** — 有明确的输入输出和验证标准

### 不合格需求示例

> "帮我把这个 demo 转成正式项目" — 这是一次性任务，不是机制

### 合格需求示例

> "希望 PM agent 具备将 vibe coding demo 原型转化为 speckit 的能力，以便任何 PM 都能将 demo 标准化" — 这是可复用机制

## 执行流程

### Step 1: 理解用户意图

与用户对话，厘清：
- 用户想解决什么问题？
- 这个能力的使用场景是什么？
- 谁会复用这个能力？（同角色的其他人）

### Step 2: 引导为可复用机制

如果用户描述的是一次性任务，引导转化：

> "我理解你想完成 X。如果我们把这个做成一个通用能力，以后任何 PM 遇到类似场景都能用。我来帮你梳理成一个标准需求？"

### Step 3: 填写需求模板

```markdown
## 需求名称
<!-- 简明描述这个能力，如：Demo 原型转 Speckit -->

## 使用场景
<!-- 什么情况下会用到这个能力 -->

## 输入
<!-- agent 执行这个能力需要什么输入 -->

## 输出
<!-- agent 执行完后产出什么 -->

## 验证标准（必填）
<!-- 如何判断这个能力执行成功？必须是可执行的具体步骤，不接受"能正常工作"之类的模糊描述 -->
1. ...

## 复用说明
<!-- 谁会复用？在什么场景下复用？ -->
```

### Step 4: 用户确认

将填写好的需求展示给用户，确认无误后提交。

### Step 5: 提交到 ae-pm

```bash
source ~/.config/ae-pm/credentials.env
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null

curl -s -X POST "https://gitee.com/api/v5/repos/turningsyn/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "'"$GITEE_TOKEN"'",
    "repo": "ae-pm",
    "title": "[FEAT] 需求名称",
    "body": "需求正文（按上方模板填写）"
  }'
```

### Step 6: 确认提交成功

向用户展示 issue 链接，并说明：

> "需求已提交到 ae-pm，AE 团队会评估并排期。能力开发完成后会通过 CHANGELOG 发布更新，届时你可以通过查收更新来获取新能力。"

## 重要规则

- **验证标准必填且必须具体** — 不接受"能正常使用"之类的模糊描述。必须是可执行的验证步骤，如"运行 /xxx 后能生成 xxx 文件，文件包含 xxx 字段"。如果用户没提供，主动追问："这个能力做好后，你会怎么验证它是可用的？"
