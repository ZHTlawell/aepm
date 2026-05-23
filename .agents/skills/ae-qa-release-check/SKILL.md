---
name: ae-qa-release-check
description: "发布前质量门禁检查，基于测试结果、缺陷状态、风险地图和变更影响输出 Go/No-Go 建议"
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

# Skill: QA 发布准入检查

## 触发条件

当版本准备发布、提测完成、回归结束或用户要求判断“能不能发”时触发。

## 输入

- `qa/06-risk-map.md`
- `qa/09-test-cases.md`
- `qa/12-change-impact.md`
- 测试报告
- 缺陷列表及状态
- 可选：自动化执行结果、发布说明、灰度方案。

## 执行流程

1. 读取 `constraints/release-quality-gate.md`。
2. 汇总 P0、P1 用例执行情况。
3. 检查未关闭缺陷：
   - Blocker / Critical 默认 No-Go。
   - Major 需要明确影响范围和规避方案。
4. 检查本次变更影响范围是否已覆盖。
5. 检查历史高频回归点是否已验证。
6. 检查资料缺口和环境差异是否影响判断。
7. 输出 Go / Conditional Go / No-Go 建议。

## 输出

写入 `qa/13-release-check.md`：

```markdown
# 发布准入检查

## 结论

Go / Conditional Go / No-Go

## 依据

## 用例执行概况

| 优先级 | 总数 | 通过 | 失败 | 阻塞 | 未执行 |
|--------|------|------|------|------|--------|

## 未关闭缺陷

| 严重程度 | 数量 | 影响 | 处理建议 |
|----------|------|------|----------|

## 变更覆盖

## 历史风险回归

## 发布风险

## 建议
```

## 硬规则

- 不知道缺陷状态时不能给 Go，只能给 Conditional Go 或 No-Go。
- P0 未全部通过时必须 No-Go。
- 结论必须说明依据，不允许只给一句“可以发”。

