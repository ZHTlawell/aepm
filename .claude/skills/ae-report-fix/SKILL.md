---
name: ae-report-fix
description: "修复回流 — 用户/agent 在本地解决问题后，结构化回流修复方案给 AE Team"
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

# Skill: 修复回流 (report-fix)

> **ROLE**: 把用户/agent 在本地成功解决的问题，结构化为 AE Team 可直接 review + 合并的修复方案。用户是最好的 skill 构建者——调试成功时上下文最完整，总结成本最低。

## 与 submit-bug / submit-requirement 的关系

```
遇到问题
  ├── 解决了（全部或部分，含 workaround）→ /ae-report-fix
  ├── 没解决 → /ae-submit-bug
  └── 不是问题，是新需求 → /ae-submit-requirement
```

**核心判断：只要动手解决了，不管是根因修复还是 workaround，都走 report-fix。** 没解决才走 submit-bug。不需要纠结"这算 bug 还是 fix"——AE Team 拿到结构化的修复方案，比拿到一个问题描述有价值得多。

**Workaround 也要回流：** 用户加了个 retry 绕过了超时、手动改了个配置避开了报错——这些都是修复。即使不是根因，AE Team 也能从中判断问题的真正原因。

**只对当前项目有效的修复也要回流：** 说明 skill 的适配性不够广，AE Team 需要知道哪些场景没覆盖到。在「影响范围」字段标注即可。

## 触发条件

以下任一情况时触发：

1. 用户或 agent 刚解决了一个 skill/工具/配置问题（包括 workaround）
2. Agent 自主修复了一个问题后，主动建议回流
3. 用户说"帮我提交这个修复"、"把这个 fix 反馈给 AE Team"
4. 执行其他 `/ae-*` skill 过程中发现并修复了问题
5. 用户描述之前（可能在其他对话中）解决过的问题，希望回流

**主动触发规则：** 当 agent 在执行任务时自行解决了以下类型的问题，**应主动建议用户回流**（不需要用户先提出）：

- MCP 工具配置调整（如加参数、换命令）
- settings.json / settings.local.json 权限补充
- project.yml / Info.plist 必填项发现
- 环境配置修复（如路径、依赖版本）
- Skill 流程中的步骤缺失或顺序错误
- Skill 描述与实际行为不一致（适配性问题）

建议方式（融入对话，不要生硬）：
> "这个问题我们刚解决了，其他用户可能也会遇到。要不要把修复方案回流给 AE Team？我帮你整理。"

## 执行流程

### Step 1: 采集修复信息

从当前对话上下文中提取，尽量不让用户重复描述。逐项确认：

**1a. 修复标题** — 一句话概括（agent 拟，用户确认）

**1b. 修复前** — 遇到了什么问题？表现是什么？
> 从对话记录中提取，用户确认即可。

**1c. 修复后** — 怎么解决的？现在的状态是什么？
> 从对话记录中提取实际执行的命令或配置变更。

**1d. 关联 issue（可选）** — 如果这个问题有对应的已有 issue，记录编号。没有就留空。

**信息提取策略：**
- 当前对话中刚解决的问题 → 从对话上下文自动提取，只让用户确认，不让用户重新描述
- 用户描述之前解决过的问题 → 正常对话采集，逐项引导用户补充

### Step 2: 格式化

```markdown
## 修复方案

**标题：** {title}

### 修复前（问题）
{before — 问题描述 + 具体表现}

### 修复后（方案）
{after — 具体做了什么，包含命令/配置/代码变更}

### 验证结果
{当前对话中实际验证通过的证据，如命令输出、截图等}

### 影响范围
{这个修复对其他项目/用户是否通用，还是仅限特定场景}

### 用户清理提示
{AE Team 合并此修复后，用户本地需要做什么清理？如"可移除手动添加的 MCP 配置 xxx，skill 已内置"。如果无需清理写"无需清理，更新后自动生效"}

---
> 由用户 agent 通过 `/ae-report-fix` 自动生成
```

### Step 3: 用户确认

将格式化后的修复方案展示给用户确认。用户可修改或补充。

### Step 4: 提交

**情况 A：有关联 issue** — 作为 comment 追加到已有 issue：

```bash
ae git issues comment --repo <目标仓库> --number <issue_number> --body "<格式化内容>"
```

**情况 B：无关联 issue** — 创建新 issue：

```bash
ae git issues create --repo <目标仓库> --title "[FIX-REPORT] {title}" --body "<格式化内容>"
```

目标仓库：读取 AE 角色 CLAUDE.md（`~/.ae/go/CLAUDE.md` 或 `~/.ae/pm/CLAUDE.md`，**不是当前 workspace 的 CLAUDE.md**）中的「Issue 路由」表。

### Step 5: 提交后确认

```bash
ae git issues list --repo <目标仓库> --state open --pretty
```

确认 issue/comment 创建成功，向用户展示：
> "修复方案已提交（#XXXX），AE Team 会 review 后合并到 skill 默认配置。感谢回流！"

## 硬规则

1. **提交前必须让用户确认内容** — 和 submit-bug 一样，不跳过确认
2. **从对话上下文自动提取，不让用户重新描述** — 用户刚解决完问题，上下文都在，agent 应该能自动整理
3. **提交前必须查重** — 检查是否已有相同/相似的 fix report
4. **提交后必须验证** — 确认 issue/comment 存在
5. **验证结果段必填** — 没有验证过的修复不允许提交（避免把未验证的"理论修复"推给 AE Team）
6. **不碰本地 skill 文件** — 这个 skill 只做记录和提交，不直接修改 `~/.ae/` 下的 skill 源码

## Anti-Patterns

- 修复没验证就提交 → 必须有当前对话中的验证证据
- 让用户从头描述问题 → 应该从对话上下文自动提取
- 提交后不验证 → 必须 list 确认存在
- 直接修改本地 skill 文件 → 只做 report，AE Team 负责合并

## Troubleshooting

| 问题 | 解决 |
|------|------|
| 用户说不清修复了什么 | 回顾对话记录，帮用户整理 |
| 不确定该提到哪个仓库 | 读 `~/.ae/<role>/CLAUDE.md` 的 Issue 路由表 |
| 修复涉及多个问题 | 每个问题单独一条 fix report |
| 用户说"不用提交了" | 尊重用户选择，不强制 |
