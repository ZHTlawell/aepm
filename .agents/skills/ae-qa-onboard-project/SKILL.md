---
name: ae-qa-onboard-project
description: "按项目测试入驻顺序生成产品理解包、模块地图、用户路径和 QA Memory"
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

# Skill: QA 项目入驻理解

## 触发条件

当测试人员需要快速熟悉一个新项目，或已经完成 `/ae-qa-intake-check` 并准备生成项目理解包时触发。

## 输入

- 项目目录或 QA 入驻包。
- 可选：`qa/00-intake-check.md`。

## 执行流程

1. 检查 `.Codex/overrides/`。
2. 读取 `constraints/qa-onboarding.md`。
3. 如果存在 `qa/00-intake-check.md`，先读取完整度结论；如果不存在，先做轻量资料归类。
4. 按以下层次建立项目认知：
   - L1 产品层：产品定位、目标用户、核心业务闭环。
   - L2 功能层：模块、页面、角色权限、业务规则。
   - L3 技术层：接口、数据库、第三方服务、配置、日志。
   - L4 质量层：历史 Bug、测试用例、报告、自动化、遗留风险。
5. 每个关键结论标注来源和置信度。
6. 将不确定事项写入开放问题，不要自行决断。

## 输出

写入 `qa/`：

```text
01-product-brief.md
02-module-map.md
03-user-journeys.md
04-business-rules.md
05-api-data-map.md
10-open-questions.md
```

同时维护 `.qa-memory/`：

```text
.qa-memory/
  product-summary.md
  module-map.md
  risk-seeds.md
  open-questions.md
```

## 输出要求

- 产品理解必须用测试人员视角表达：测什么、为什么重要、缺什么资料。
- 模块地图至少包含模块名称、入口、关键操作、关联接口、关联数据、测试关注点。
- 用户路径至少包含主路径、异常路径、权限差异。
- 开放问题必须能被产品、开发或测试负责人回答。

