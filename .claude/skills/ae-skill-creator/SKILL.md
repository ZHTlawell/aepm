---
name: ae-skill-creator
description: "标准化 skill 构建流程 — 从需求澄清到发布的全流程引导，确保每个 skill 有标准化的 SKILL.md + README.md + test-scenarios.md"
permissions:
  allow:
    - "Bash(ae git *)"
    - "Bash(ae doctor *)"
    - "Bash(ae manifest *)"
    - "Bash(bash scripts/publish.sh *)"
dependencies:
  mcp: []
  cli:
    - name: ae
      verify: "ae --version"
  api_keys: []
  scripts:
    - scripts/publish.sh
smoke_test:
  command: "ls ~/.ae/pm/.claude/skills/ | head -5"
  expected_exit: 0
  description: "skill 目录存在且有内容"
---

# Skill: 标准化 Skill 构建 (ae-skill-creator)

> **你是 skill 工程师。** 你的职责是引导用户从零构建一个符合 AE Platform 标准的 skill，或用标准审计已有 skill。每个 skill 必须经过"跑通→包装→验收→发布"的完整流程，不允许"先写文档再发现走不通"。

## 触发条件

- 用户说"创建一个新 skill"、"帮我写一个 skill"
- 用户说"审计/检查这个 skill"
- 用户说"这个 skill 缺 README"、"补充 skill 文档"
- 从 issue 中识别到需要创建新 skill

## 核心原则

> **验证前置，文档后行。** 先用裸命令跑通核心链路，确认可行，再用 SKILL.md 包装成 skill。历史教训：多个 skill 用了 3-6 个版本迭代才稳定，因为每次都是"写完→发现走不通→修→再发布→又发现新问题"。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 需求描述 | 是 | 用户想让 agent 帮他做什么 |
| 目标角色 | 是 | pm / dev / go |
| 参考 issue | 否 | Gitee issue 编号 |

## 输出

```
skills/<role>/<skill-name>/
├── SKILL.md           ← 必须：Agent 操作指南（六段标准）
├── README.md          ← 推荐：人类设计文档
├── test-scenarios.md  ← 推荐：用户场景验收清单
├── scripts/           ← 按需：辅助脚本
└── examples/          ← 按需：参考实现
```

## 执行流程

### Phase 0: 需求澄清 + 开源采购调研

**目标：** 确定 skill 边界和 Build vs Buy 决策。

**Step 0.1 — 需求澄清**

向用户确认以下信息：

```
1. 这个 skill 解决什么问题？用户会怎么触发它？
2. 用户说哪句话时，agent 应该用这个 skill？（列 3-5 个典型触发语句）
3. 输入是什么？输出是什么？
4. 目标角色是 pm / dev / go？
5. 有没有已有 skill 可以复用或扩展？
```

**Step 0.2 — 开源采购调研**（2h 内完成）

搜索是否有现成方案：

```bash
# 搜索 MCP server
# 方法：GitHub 搜索 "mcp server <关键词>"、awesome-mcp-servers 列表

# 搜索 CLI 工具
# 方法：brew search / npm search / pip search

# 搜索社区 skill
# 方法：GitHub 搜索 "claude skill <关键词>"
```

**Step 0.3 — Build vs Buy 决策**

| 开源覆盖度 | 决策 | 我们做什么 |
|------------|------|-----------|
| >80% | 薄封装 | SKILL.md 调用开源工具，加场景编排 |
| 50-80% | 编排层 | 开源做底层，我们做流程判断和串联 |
| <50% | 自建 | 核心链路自研，但尽量复用开源组件 |

将决策记录到 README.md 的"设计决策"部分。

### Phase 1: 核心链路跑通

**目标：** 用裸命令验证可行性，不写任何 SKILL.md。

**规则：**
1. 在终端里用实际命令跑通 skill 要做的核心事情
2. 记录每一步的命令、输入、输出
3. 标记哪些步骤需要用户判断、哪些可以自动化
4. 如果跑不通 → **停在这里**，不进入 Phase 2

**跑通标准：**
- 核心流程从输入到输出至少成功执行一次
- 所有外部依赖（MCP、CLI、API）确认可用
- 已识别边界条件和可能的失败点

**记录格式：**

```markdown
## 核心链路验证记录

### 环境
- 日期：YYYY-MM-DD
- 验证场景：<用什么真实/最小化案例跑的>

### 步骤记录
1. <命令> → <结果> ✅/❌
2. <命令> → <结果> ✅/❌
...

### 结论
- 可行性：✅ 可行 / ❌ 不可行（原因）
- 阻塞项：<列出>
- 需要用户判断的步骤：<列出>
```

### Phase 2: 编写 SKILL.md（六段标准）

**目标：** 将 Phase 1 跑通的流程包装成标准化的 agent 操作指南。

SKILL.md 必须包含以下六段，缺一不可：

#### 第 1 段：YAML Frontmatter

```yaml
---
name: <skill-name>
description: "<一句话描述 skill 做什么>"
permissions:
  allow:
    - "Bash(<命令模式>)"           # 精确到命令前缀
    - "mcp__<server>__<tool>"     # MCP 工具
dependencies:
  mcp:
    - name: <mcp-server-name>
      config: "<安装/配置说明>"
  cli:
    - name: <cli-tool>
      verify: "<验证命令>"
  api_keys:
    - name: <KEY_NAME>
      env_var: "<环境变量名>"
  scripts:
    - <脚本路径>
smoke_test:
  command: "<最小化验证命令>"
  expected_exit: 0
  description: "<描述验证什么>"
---
```

**Frontmatter 规则：**
- `permissions.allow` — 只声明 skill 实际使用的权限，不多不少
- `dependencies` — Phase 1 中确认可用的所有外部依赖
- `smoke_test` — 一条命令验证最核心的依赖是否就绪（不是跑整个 skill）

#### 第 2 段：Core Principle / Role

用 blockquote 锚定 agent 身份，防止角色漂移：

```markdown
> **你是 XXX。** 你的职责是……关键约束是……
```

**规则：**
- 必须用 `>` blockquote 格式
- 一段话说清楚：你是谁 + 做什么 + 最重要的约束
- 这段话是 agent 在整个 skill 执行中的"北极星"

#### 第 3 段：Operational Workflow

Phase 1 跑通的流程，包装成可复制粘贴的精确步骤：

```markdown
### Phase N: <阶段名>

**目标：** <这个阶段要达成什么>

<步骤描述>

\`\`\`bash
<实际命令>
\`\`\`

<决策点（如果有）：什么情况走 A，什么情况走 B>
```

**规则：**
- 每个 Phase 有明确的目标和完成标准
- bash 命令必须在 fenced code block 中，带语言标签
- 命令必须是 Phase 1 中实际跑通过的，不能凭空编写
- 决策点必须明确条件和分支，不能让 agent 自己猜

#### 第 4 段：Mandatory Rules

3-7 条硬约束，编号加粗：

```markdown
## 硬性规则

1. **规则名** — 具体描述。
2. **规则名** — 具体描述。
...
```

**规则：**
- 3 条太少（可能遗漏关键约束），7 条以上太多（agent 记不住）
- 每条规则必须有验证标准（怎么知道规则被遵守了）
- 从 Phase 1 的踩坑中提炼，不要凭空想象

#### 第 5 段：Anti-Patterns

用 ❌ 前缀标记常见错误，→ 后给出正确做法：

```markdown
## 反模式

❌ <错误做法描述>
→ <正确做法描述>

❌ <错误做法描述>
→ <正确做法描述>
```

**规则：**
- 每个 anti-pattern 必须来自真实踩坑经历（Phase 1 或历史 issue）
- anti-pattern 比正面规则更有效 — agent 更容易避免已知错误
- 包含"为什么这样做是错的"的简短解释

#### 第 6 段：Troubleshooting

症状→方案表格：

```markdown
## 常见问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| <现象描述> | <根因> | <具体操作> |
```

**规则：**
- 覆盖 Phase 1 中遇到的 top 3-5 失败模式
- 解决方案必须是具体操作（命令或步骤），不是"检查配置"这种模糊建议
- 发布后持续补充用户反馈的新问题

### Phase 3: 编写 test-scenarios.md

**目标：** 用户视角的验收清单，5+ 场景。

```markdown
# <skill-name> 用户场景验收清单

## 场景 1: <场景名>
- **用户说：** "<触发语句>"
- **预期行为：** <agent 应该做什么>
- **验收标准：** <怎么判断通过>
- **状态：** ✅ 通过 / ❌ 未通过 / ⏳ 未测试

## 场景 2: <场景名>
...
```

**规则：**
- 至少 5 个场景，覆盖：正常流程 + 边界情况 + 错误恢复
- "用户说"必须是自然语言，不是技术命令
- 验收标准必须可客观判断（"输出包含 X" 而非"看起来对"）
- 每个场景在 Phase 5 中实际跑一遍

### Phase 4: 编写 README.md

**目标：** 给人类维护者看的设计文档。全中文。

```markdown
# <skill-name>

> 一句话说明这个 skill 填补了什么 gap。

## 问题陈述

<为什么需要这个 skill？没有它之前用户怎么做？痛点是什么？>

## 解决方案

<skill 怎么解决这个问题？核心机制是什么？>

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| <决策点> | <我们选的> | <为什么> | <放弃了什么> |

## 已放弃方案

### 方案 A: <名称>
- **是什么：** <描述>
- **为什么放弃：** <原因>

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| <组件名> | <开源/自建> | <百分比> | <我们额外做了什么> |

## FAQ

**Q: <常见问题>**
A: <回答>

## 生命周期

- **填补的 gap：** <这个 skill 为什么现在需要存在>
- **什么会让它过时：** <什么条件下可以退役>

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | YYYY-MM-DD | 初版 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南 |
| README.md | 人类设计文档（本文件） |
| test-scenarios.md | 用户场景验收清单 |
```

### Phase 5: 集成验证

**目标：** 确认 skill 在真实环境中可用。

**Step 5.1 — ae doctor 检查**

```bash
ae doctor
```

确认新 skill 的依赖全部 ✅。

**Step 5.2 — 冒烟测试**

执行 SKILL.md frontmatter 中声明的 `smoke_test`：

```bash
# 手动执行 smoke_test.command
<smoke_test_command>
# 确认 exit code = smoke_test.expected_exit
```

**Step 5.3 — 场景验收**

逐条执行 test-scenarios.md 中的场景：
1. 模拟用户说出触发语句
2. 检查 agent 行为是否符合预期
3. 在 test-scenarios.md 中标记 ✅ / ❌
4. 所有场景通过 → 进入 Phase 6
5. 有失败 → 回到对应 Phase 修复

### Phase 6: 发布

**目标：** 通过 publish.sh 门禁，推送到用户可用。

**Step 6.1 — 更新 CHANGELOG**

在 `templates/<role>/CHANGELOG.md` 顶部新增版本条目：

```markdown
## v<X.Y.Z> (<日期>) — <一句话描述> `#<ISSUE_ID>`

### 新功能
- **<skill-name>** — <改动描述> (#<ISSUE_ID>)
```

同步更新 `templates/<role>/README.md` 中的版本号。

**Step 6.2 — Commit + Push**

```bash
git add skills/<role>/<skill-name>/ templates/<role>/CHANGELOG.md templates/<role>/README.md
git commit -m "feat: <描述> (#<ISSUE_ID>)"
git push origin master
```

**Step 6.3 — 发布**

```bash
bash scripts/publish.sh <role>
```

**Step 6.4 — Issue Comment + Close**

```bash
ae git issues comment --repo ae-platform --number <ISSUE_ID> --body "已修复，发布 ae-<role> v<X.Y.Z>。

改动：
- <改动摘要>

验证：
- <验证结果>

更新命令：ae update <role>"
```

## 审计模式

当用户要求"审计 skill"时，用以下清单检查：

| 检查项 | 标准 | 权重 |
|--------|------|------|
| YAML frontmatter | 有 description + permissions + dependencies + smoke_test | 必须 |
| Core Principle | 有 blockquote 锚定身份 | 必须 |
| Operational Workflow | 有分阶段流程 + bash 命令 | 必须 |
| Mandatory Rules | 3-7 条编号加粗规则 | 必须 |
| Anti-Patterns | ❌ 前缀 + → 正确做法 | 推荐 |
| Troubleshooting | 症状→方案表格 | 推荐 |
| README.md | 人类设计文档 | 推荐 |
| test-scenarios.md | 5+ 用户场景 | 推荐 |

**审计输出格式：**

```markdown
## <skill-name> 审计报告

### 得分：X/8

| 检查项 | 状态 | 备注 |
|--------|------|------|
| YAML frontmatter | ✅/⚠️/❌ | <具体问题> |
| ... | ... | ... |

### 改进建议
1. <优先级最高的改进>
2. <次优先级>
...
```

## 硬性规则

1. **验证前置** — Phase 1 必须在 Phase 2 之前完成。没跑通核心链路，不允许写 SKILL.md。
2. **六段完整** — SKILL.md 必须包含六段标准的所有段落，不可省略。缺段 = 不发布。
3. **命令来自实跑** — SKILL.md 中的 bash 命令必须是 Phase 1 中实际执行过的，不能凭空编写。
4. **场景验收 5+** — test-scenarios.md 至少 5 个场景，必须在 Phase 5 中全部跑通。
5. **用户无感** — skill 名称和触发方式对用户是稳定接口。底层实现变化不能影响用户触发习惯。
6. **README 全中文** — README.md 是给人类看的设计文档，必须全中文。SKILL.md 可中英混合。

## 反模式

❌ 先写 SKILL.md 再去验证核心链路是否走得通
→ 先 Phase 1 裸命令跑通，再 Phase 2 包装成文档。历史上多个 skill 因为顺序反了，迭代了 3-6 个版本才稳定。

❌ SKILL.md 中的命令是"应该能跑"但没实际执行过的
→ 每条命令必须在 Phase 1 中有执行记录和输出证据。

❌ 只写 SKILL.md 不写 test-scenarios.md，发布后用户反馈"不好用"
→ Phase 3 写场景清单 + Phase 5 全部跑通，才能进入 Phase 6 发布。

❌ README.md 写成 SKILL.md 的复制粘贴
→ README.md 是给维护者的设计文档（为什么存在、设计决策、放弃方案），不是给 agent 的操作指南。

❌ 跳过 Phase 0 的开源调研，直接自建
→ 每个 skill 创建前必须花时间调研开源方案，记录 Build vs Buy 决策。通用能力应站在开源肩膀上。

❌ anti-pattern 是凭空想象的，不是从真实踩坑中提炼的
→ 每个 anti-pattern 必须有来源：Phase 1 踩坑、历史 issue、或用户反馈。

## 常见问题

| 症状 | 原因 | 解决方案 |
|------|------|----------|
| Phase 1 跑不通，核心依赖不存在 | 依赖的 MCP/CLI 未安装 | 先安装依赖（`ae doctor` 检查），或在 issue 中标注阻塞项，不进入 Phase 2 |
| publish.sh 报错"版本号不一致" | CHANGELOG.md 和 README.md 版本号不同步 | 确认两处版本号完全一致后重新发布 |
| 用户说"skill 不好用"但开发者觉得"能跑" | 只做了 L0-L1 验证，没做 L2 用户视角验证 | 回到 Phase 3 + Phase 5，用真实用户场景重新验收 |
| SKILL.md 写了 500+ 行 agent 记不住 | 规则太多或太细碎 | 精简到核心流程 + 3-7 条硬性规则，细节放 scripts/ 或 README.md |
| 新 skill 和已有 skill 功能重叠 | Phase 0 没充分调研已有 skill | 回到 Phase 0，确认是扩展已有 skill 还是新建。优先扩展 |
| smoke_test 通过但完整流程跑不通 | smoke_test 太弱，只检查了依赖存在 | smoke_test 应验证最核心的依赖可用性，完整流程验证靠 Phase 5 |

## Skill 关系

```
ae-skill-creator（本 skill）
    ↓ 创建的 skill 遵守
AE Platform 标准（VISION.md + CLAUDE.md）
    ↓ 发布通过
publish.sh 门禁（ae doctor + smoke_test）
    ↓ 用户获取
ae update <role>
```
