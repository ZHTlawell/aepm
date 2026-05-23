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

## 输入

- 产品项目目录或 QA 入驻包。
- 可选：`.qa-agent.yml`。
- 可选：PRD、产品图、接口文档、数据库说明、测试用例、测试报告、历史 Bug、自动化说明。

## 执行流程

1. 读取 `constraints/product-agent-memory.md`、`constraints/material-intake.md` 和 `constraints/qa-onboarding.md`。
2. 先确认产品目录和资料包位置，不要先追问产品业务细节。
3. 检查资料包是否存在：
   - `.qa-agent.yml`
   - `qa-onboarding-input/`
   - 产品图、PRD、接口、数据库、测试用例、历史 Bug、测试报告、自动化资料等至少一类真实资料。
4. 如果用户只提供一句产品简介或少量自然语言描述：
   - 只记录为“初始产品身份”。
   - 明确说明当前资料不足，不能进入产品专属 QA Agent 模式。
   - 输出资料清单，要求用户先补充文档或目录。
   - 不要开始询问细碎产品业务规则。
5. 资料存在后，再识别产品身份：
   - 产品名称
   - 产品类型
   - 目标用户
   - 核心业务闭环
   - 所属仓库/目录
6. 检查是否已有 `.qa-memory/product-profile.md`。
   - 如果已有且产品身份不同，停止并提示创建新产品 Agent。
   - 如果已有且产品身份相同，进入记忆更新流程。
7. 执行资料完整性检查，计算产品熟悉度评分。
8. 资料检查后，再主动追问缺失信息。问题数量不做固定上限，但必须按优先级分批提问，目标是补齐产品/模块理解。
9. 当熟悉度达到 85 分，生成或更新 `.qa-memory/`。
10. 输出是否进入产品专属模式。

## 追问策略

追问分两个阶段：

### 阶段 A：资料未提供或明显不足

只引导用户补充资料，不追问细节业务规则。示例：

```text
请先把可用资料放到 <product_dir>/qa-onboarding-input/：
- 产品图或流程图
- PRD / 需求文档
- 接口文档
- 数据库或数据模型说明
- 现有测试用例
- 历史 Bug
- 测试报告
- 自动化说明
```

### 阶段 B：资料已提供但存在缺口

当 Agent 不熟悉产品或模块时，优先追问能提升理解质量的问题：

1. 当前任务必须知道的信息。
2. 会影响测试范围的信息。
3. 会影响风险等级的信息。
4. 会影响用例预期结果的信息。
5. 会影响发布判断的信息。

每轮问题按主题聚合，先问最高优先级。用户回答后更新熟悉度评分和待确认项。

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
