---
name: ae-qa-generate-cases
description: "生成 P0/P1/P2/P3 分级测试用例、冒烟清单、回归清单和自动化候选"
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

# Skill: QA 测试用例生成

## 触发条件

当测试人员已经具备项目理解包和风险地图，需要生成初版测试用例、补齐覆盖缺口或为版本回归生成用例时触发。

## 输入

- `qa/01-product-brief.md`
- `qa/02-module-map.md`
- `qa/03-user-journeys.md`
- `qa/06-risk-map.md`
- 可选：历史测试用例、历史 Bug、变更影响分析。

## 执行流程

1. 读取 `constraints/test-case-standard.md`。
2. 如果缺少产品理解包或风险地图，先提醒用户执行对应 skill。
3. 先生成 P0 冒烟用例，再生成 P1 核心回归。
4. 对高风险模块补充异常、权限、边界、数据一致性用例。
5. 从历史 Bug 生成回归用例。
6. 标注自动化候选。

## 输出

写入 `qa/09-test-cases.md`：

```markdown
# 测试用例集

## P0 冒烟用例

| ID | 模块 | 场景 | 前置条件 | 测试数据 | 步骤 | 预期结果 | 来源 | 自动化建议 |
|----|------|------|----------|----------|------|----------|------|------------|

## P1 核心回归

## P2 模块回归

## P3 探索测试

## 自动化候选
```

## 硬规则

- 每条用例必须有前置条件、步骤、预期结果和来源。
- 不要生成无法执行的泛泛描述。
- 历史 Bug 回归用例必须能验证“修复没有再次失效”。

