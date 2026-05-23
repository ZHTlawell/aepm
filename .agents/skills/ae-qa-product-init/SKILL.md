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

1. 读取 `constraints/product-agent-memory.md` 和 `constraints/qa-onboarding.md`。
2. 识别产品身份：
   - 产品名称
   - 产品类型
   - 目标用户
   - 核心业务闭环
   - 所属仓库/目录
3. 检查是否已有 `.qa-memory/product-profile.md`。
   - 如果已有且产品身份不同，停止并提示创建新产品 Agent。
   - 如果已有且产品身份相同，进入记忆更新流程。
4. 执行资料完整性检查，计算产品熟悉度评分。
5. 主动追问缺失信息，问题数量不做固定上限，但必须按优先级分批提问，避免一次性压垮用户。
6. 当熟悉度达到 85 分，生成或更新 `.qa-memory/`。
7. 输出是否进入产品专属模式。

## 追问策略

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

