---
name: ae-qa-start
description: "QA 新项目入驻总入口，串起资料检查、项目理解、一致性检查、风险扫描和初版用例生成"
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

# Skill: QA 新项目入驻总入口

## 触发条件

当测试人员第一次接手项目，希望“一步步熟悉项目并生成初始测试资产”时触发。

## 输入

- 项目目录或 QA 入驻包。
- 可选：产品图、PRD、接口文档、数据库说明、历史 Bug、测试报告、自动化说明。

## 执行流程

按顺序执行以下能力的核心逻辑，不要跳步：

1. `/ae-qa-intake-check`
   - 判断资料完整性。
   - 低于 40 分时停止，并建议补资料。
   - 40-59 分时只生成初步理解和缺口清单。
2. `/ae-qa-onboard-project`
   - 生成产品理解包、模块地图、用户路径和开放问题。
3. `/ae-qa-consistency-check`
   - 检查 PRD、产品图、API、DB、用例、Bug、自动化之间的冲突。
4. `/ae-qa-risk-scan`
   - 生成风险地图、历史回归热点和优先级。
5. `/ae-qa-generate-cases`
   - 生成 P0/P1/P2/P3 分级测试用例和自动化候选。

## 输出

输出 `qa/00-qa-start-summary.md`：

```markdown
# QA 新项目入驻汇总

## 入驻结论

## 已生成产物

| 文件 | 用途 |
|------|------|

## 关键风险

## 资料缺口

## 第一周测试建议

## 下一步命令
```

## 硬规则

- 资料不足时不要强行生成完整用例。
- 每一步都必须引用对应产物或说明为什么跳过。
- 最终汇总必须让测试人员知道“明天先测什么”。

