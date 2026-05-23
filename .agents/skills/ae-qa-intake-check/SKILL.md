---
name: ae-qa-intake-check
description: "QA 项目入驻资料完整性检查，输出评分、缺口影响和下一步建议"
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

# Skill: QA 入驻资料检查

## 触发条件

当测试人员接手新项目，或用户提供项目资料包并希望判断资料是否足够开展测试入驻时触发。

## 输入

- 项目目录或资料包目录。
- 可选：PRD、Speckit、产品图、接口文档、数据库说明、测试用例、历史 Bug、测试报告、自动化说明。

## 执行流程

1. 检查当前项目是否存在 `.Codex/overrides/`，读取其中除 README.md 外的 `.md` 文件。
2. 读取 `constraints/qa-onboarding.md`。
3. 扫描输入目录，按资料类型归类：
   - project_structure
   - product_overview
   - product_screens
   - product_docs
   - api_docs
   - database_docs
   - test_cases
   - bug_history
   - test_reports
   - automation
4. 按完整性评分表给出 0-100 分。
5. 对缺失资料说明影响，不要直接补全事实。
6. 给出下一步建议：是否可以进入 `/ae-qa-onboard-project`，或应先补哪些资料。

## 输出

输出 `qa/00-intake-check.md`：

```markdown
# QA 入驻资料检查

## 完整度评分

总分：__/100
结论：资料充分 / 基本可用 / 风险较高 / 不建议继续

## 已提供资料

| 类型 | 路径 | 说明 |
|------|------|------|

## 缺失资料

| 类型 | 影响 | 建议补充方式 |
|------|------|--------------|

## 风险提示

## 建议下一步
```

## 硬规则

- 低于 60 分时，不要输出完整测试结论。
- 低于 40 分时，建议先补资料再入驻。
- 任何“看起来应该是”的内容必须标记为 `inferred`。

