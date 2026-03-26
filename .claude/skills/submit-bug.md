# Skill: 提交 Bug (submit-bug)

## 触发条件

当用户报告 bug、描述异常行为、或说"帮我提一个 bug"时触发。

## 执行流程

### Step 1: 收集 bug 信息

与用户对话，厘清：
- **问题描述** — 发生了什么？
- **复现步骤** — 怎么触发的？
- **期望行为** — 你期望发生什么？
- **环境信息** — 操作系统、ae-pm 版本等（可选）

### Step 2: 格式化

将收集到的信息整理为 markdown 格式：

```markdown
## 描述
<!-- 问题描述 -->

## 复现步骤
1. ...
2. ...

## 期望行为
<!-- 期望行为 -->

## 环境信息
- 操作系统:
- ae-pm 版本:
```

### Step 3: 用户确认

将格式化后的标题和正文展示给用户确认。

### Step 4: 通过 CLI 提交

**必须通过 `ae` CLI 提交，不要直接调用 API 或创建本地文件。**

```bash
ae pm submit-bug "bug 标题" "bug 正文（markdown 格式）"
```

如果 bug 属于 ae-dev 而非 ae-pm：

```bash
ae pm submit-bug --repo ae-dev "bug 标题" "bug 正文"
```

### Step 5: 确认结果

CLI 会输出 issue 链接。将链接展示给用户，并说明：

> "Bug 已提交，AE Team 会跟进处理。你可以在上面的链接中查看进展。"

## 重要规则

- **禁止创建本地 issue 文件** — 所有 bug 必须通过 `ae pm submit-bug` CLI 命令提交到 Gitee
- **禁止直接调用 curl/Gitee API** — 统一走 CLI
- 提交前必须让用户确认内容
