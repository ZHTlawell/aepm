---
name: ae-qa-change-impact
description: "根据 Git diff、需求单或版本说明分析影响范围和建议回归路径"
dependencies:
  mcp: []
  cli:
    - name: git
      verify: "git --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "git --version"
  expected_exit: 0
  description: "git available"
---

# Skill: QA 变更影响分析

## 触发条件

当用户提供 Git diff、PR、需求单、版本说明或变更描述，希望判断测试影响范围和回归路径时触发。

## 输入

- Git diff、commit、PR、需求单、版本说明，或自然语言变更描述。
- 可选：`.qa-memory/`、历史 Bug、测试用例集。

## 执行流程

1. 读取 `.qa-memory/` 和 `qa/` 中已有项目认知。
2. 如果用户提供的是代码仓库，优先查看 Git diff：
   - 当前工作区变更：`git diff --stat`、`git diff --name-only`
   - 已提交变更：按用户提供的 commit 或分支比较
3. 将变更文件或需求映射到模块、页面、API、数据、历史 Bug。
4. 输出影响范围、风险等级和建议回归用例。
5. 标注资料不足导致的不确定项。

## 输出

写入 `qa/12-change-impact.md`：

```markdown
# 变更影响分析

## 变更摘要

## 影响范围

| 模块 | 影响点 | 风险等级 | 证据 |
|------|--------|----------|------|

## 建议回归

| 优先级 | 用例/路径 | 原因 |
|--------|-----------|------|

## 历史 Bug 关联

## 不确定项
```

## 硬规则

- 不知道影响时要写“不确定”，不要写“无影响”。
- 涉及登录、权限、支付、数据删除、状态流转时默认提升风险等级。

