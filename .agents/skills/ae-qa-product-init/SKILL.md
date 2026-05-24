---
name: ae-qa-product-init
description: "将通用 QA Agent 初始化为某个产品的专属测试 Agent，建立产品边界、熟悉度评分和 QA Memory"
dependencies:
  mcp: []
  cli: []
  api_keys: []
  scripts: []
smoke_test:
  command: "echo ok"
  expected_exit: 0
  description: "pure LLM skill"
---

# Skill: 产品专属 QA Agent 初始化

## 触发条件

当用户第一次使用本开源项目，或希望把通用 QA Agent 初始化为某个产品的专属测试 Agent 时触发。

## 核心原则

- 一个产品对应一个仓库或目录。
- 当前 Agent 只服务当前产品。
- 如果用户提供另一个产品的文档或需求，必须提示用户创建新的产品 Agent。
- 熟悉度达到 85/100 后，才允许进入“产品专属 QA Agent 模式”。
- 渐进式引导：每轮只推进一个主任务，只问一个问题。

## 输入

- 产品项目目录或 QA 入驻包。
- 用户在对话中上传的文件、粘贴的内容或提供的已有资料路径。
- 可选：`.qa-agent.yml`。
- 可选：PRD、产品图、接口文档、数据库说明、测试用例、测试报告、历史 Bug、自动化说明。

## 执行流程

1. 读取 `constraints/product-agent-memory.md`、`constraints/material-intake.md` 和 `constraints/qa-onboarding.md`。
2. 先确认产品目录。能创建目录时，自动创建：
   - `.qa-agent.yml`
   - `qa-onboarding-input/`
   - `qa/`
   - `.qa-memory/`
3. 初始化完成后，只要求用户提供第一份产品资料。优先建议 PRD 或产品截图。
4. 如果用户已经提供资料，对资料进行归档：
   - 产品图/截图/流程图 -> `qa-onboarding-input/02-product-screens/`
   - PRD/需求/验收标准 -> `qa-onboarding-input/03-product-docs/`
   - 接口文档 -> `qa-onboarding-input/04-api-docs/`
   - 数据库/数据模型 -> `qa-onboarding-input/05-database-docs/`
   - 测试用例 -> `qa-onboarding-input/06-test-cases/`
   - 历史 Bug -> `qa-onboarding-input/07-bug-history/`
   - 测试报告 -> `qa-onboarding-input/08-test-reports/`
   - 自动化说明/脚本 -> `qa-onboarding-input/09-automation/`
5. 检查资料包是否存在真实资料：
   - `.qa-agent.yml`
   - `qa-onboarding-input/`
   - 产品图、PRD、接口、数据库、测试用例、历史 Bug、测试报告、自动化资料等至少一类真实资料。
6. 如果用户只提供一句产品简介或少量自然语言描述：
   - 只记录为“初始产品身份”。
   - 明确说明当前资料不足，不能进入产品专属 QA Agent 模式。
   - 输出资料清单，要求用户先补充文档或目录。
   - 不要开始询问细碎产品业务规则。
7. 资料存在后，再识别产品身份：
   - 产品名称
   - 产品类型
   - 目标用户
   - 核心业务闭环
   - 所属仓库/目录
8. 检查是否已有 `.qa-memory/product-profile.md`。
   - 如果已有且产品身份不同，停止并提示创建新产品 Agent。
   - 如果已有且产品身份相同，进入记忆更新流程。
9. 执行资料完整性检查，计算产品熟悉度评分。
10. 资料检查后，再主动追问缺失信息。每轮只问一个最高优先级问题，目标是补齐产品/模块理解。
11. 当熟悉度达到 85 分，不要自动进入后续测试任务。先请求用户确认是否固化/更新 `.qa-memory/`。
12. 用户确认后，生成或更新 `.qa-memory/`，并写入 `.qa-memory/changelog.md`。
13. QA Memory 更新完成后，输出可选择的测试任务菜单，让用户选择一个任务继续。
14. 输出是否进入产品专属模式。

## 追问策略

追问分三个阶段，每轮只推进一个动作。

### 阶段 0：产品目录未确认

只问产品目录，不要求资料，不展示完整目录结构。示例：

```text
下一步只做一件事：确定这个 QA Agent 要绑定的产品目录。

请提供产品目录路径，例如：
<product_dir>
```

### 阶段 A：资料未提供或明显不足

只引导用户提供第一份资料，不追问细节业务规则，不一次性列出所有资料类型。示例：

```text
初始化已完成。

下一步只做一件事：提供第一份产品资料。

建议优先提供 PRD 或产品截图。你可以上传文件、粘贴内容，或提供已有文件路径。
```

默认不要展示完整资料目录或所有资料类型。只有用户明确问“资料放哪里”、要求查看目录结构，或正在生成资料完整度报告时，才展开目录清单。

### 阶段 B：资料已提供但存在缺口

当 Agent 不熟悉产品或模块时，优先追问能提升理解质量的问题：

1. 当前任务必须知道的信息。
2. 会影响测试范围的信息。
3. 会影响风险等级的信息。
4. 会影响用例预期结果的信息。
5. 会影响发布判断的信息。

每轮只问一个最高优先级问题。用户回答后更新熟悉度评分和待确认项，再决定下一轮问题。

### 阶段 C：熟悉度达到 85/100

达到 85/100 后，只做确认，不自动执行测试任务。示例：

```text
当前产品熟悉度已达到 85/100，可以进入产品专属 QA Agent 模式。

下一步只做一件事：请确认是否将当前产品知识固化为 QA Memory。

确认后，我会生成或更新：
- .qa-memory/product-profile.md
- .qa-memory/module-map.md
- .qa-memory/open-questions.md
- .qa-memory/changelog.md
```

用户确认并完成 QA Memory 更新后，再给任务选择清单：

```text
QA Memory 已更新。

下一步只做一件事：请选择一个测试任务。

1. 生成产品理解包
2. 检查资料一致性
3. 扫描高风险模块
4. 生成测试用例
5. 分析新模块测试任务
6. 做发布前质量检查
```

## 输出

写入：

```text
qa/00-product-agent-readiness.md
.qa-agent.yml
.qa-memory/product-profile.md
.qa-memory/module-map.md
.qa-memory/open-questions.md
.qa-memory/changelog.md
```

`qa/00-product-agent-readiness.md` 格式：

```markdown
# 产品专属 QA Agent 初始化结果

## 产品身份

## 熟悉度评分

当前分数：__/100
结论：可进入产品专属模式 / 暂不可进入

## 已掌握信息

## 缺失信息

## 必须追问

## 建议下一步
```

## 硬规则

- 低于 85 分不能宣称“已熟悉该产品”。
- 产品身份冲突时必须停止，不允许合并第二个产品的资料。
- 关键记忆更新必须让用户确认。
- 用户未提供产品资料包前，不要开始询问细碎产品业务细节。
- 短产品简介只能作为初始身份，不能作为产品熟悉依据。
- 引导用户时不要一次列出多个待办或多个问题；除非用户明确要求查看完整清单。
- 初始化完成后的默认下一步只允许要求“提供第一份产品资料”，不允许同时列出 PRD、产品图、接口、数据库、测试用例、历史 Bug、测试报告和自动化资料。
- 熟悉度达到 85/100 后，必须先让用户确认固化 QA Memory，不能自动执行风险扫描、用例生成、发布检查或新模块测试。
