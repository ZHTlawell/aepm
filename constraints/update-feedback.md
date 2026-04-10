# 查收更新

## 被告知有更新时

当用户说"ae-pm 更新了"、"有更新"、"拉一下最新"等类似表述时，直接执行：

```bash
cd ~/.ae/pm && git pull origin main
```

然后读取 CHANGELOG.md 的最新版本条目，向用户汇报更新了什么内容。

> **注意：** 日常更新已由上方「版本更新检查」的 SessionStart hook 自动完成（每次新对话自动检查 + pull）。用户无需主动关注版本变化。

## 更新后反馈（关键）

拉取更新并汇报 CHANGELOG 内容后，**必须执行以下反馈引导流程**：

**Step 1: 提取关联 issue**

从本次更新的 CHANGELOG 条目中提取所有 issue 编号（格式 `#IHQXXX`）。

**Step 2: 展示待验证列表**

向用户展示：

```
本次更新关联了以下 issue，请逐个验证：

1. #IHQXXX — [功能描述]（试一下 /xxx 或 ae pm xxx）
2. #IHQXXY — [功能描述]（检查 xxx 是否符合预期）
...

请试用后告诉我哪些 OK、哪些有问题。
```

对每个 issue，根据 CHANGELOG 描述给出**具体的验证建议**（运行什么命令、试用哪个 skill、检查什么效果）。

**Step 3: 收集反馈并回写 issue**

用户验证后：

- **验证通过** — 在对应 issue 上发 comment 确认：
  ```bash
  ae git issues comment --repo {repo} --number {number} --body "**[用户名] 验收确认：** 已在 v{version} 中验证通过，功能符合预期。请 AE Team 关闭此 issue。"
  ```
- **验证有问题** — 在对应 issue 上发 comment 说明问题，不要关闭：
  ```bash
  ae git issues comment --repo {repo} --number {number} --body "**[用户名] 验收反馈：** 在 v{version} 中验证未通过。

问题描述：{用户描述的问题}"
  ```

**Step 4: 汇总**

全部验证完成后，展示汇总：

```
验证汇总：
- ✅ #IHQXXX — 已确认，等 AE Team 关闭
- ❌ #IHQXXY — 已反馈问题，等 AE Team 修复
- ⏭️ #IHQXXZ — 暂未验证（用户跳过）
```

**注意：** 如果 CHANGELOG 条目没有关联 issue 编号，提醒用户："这条更新没有关联 issue，无法追踪验收。建议反馈给 AE Team 要求 CHANGELOG 条目带上 issue 链接。"

## 本地 workaround 清理

当 CHANGELOG 条目标注了「用户清理提示」（通常来自 `/ae-report-fix` 回流的修复），**必须在验证通过后提醒用户清理本地 workaround**：

> 这次更新已内置了 {功能描述}。如果你之前手动配置过 {具体配置}，现在可以移除了——skill 已内置该配置。

**为什么要清理：** 本地 workaround 和官方修复同时存在不会报错，但会造成：
- 配置冗余，用户不知道哪个在生效
- 后续官方修复升级时，本地的旧配置可能和新版本不兼容
