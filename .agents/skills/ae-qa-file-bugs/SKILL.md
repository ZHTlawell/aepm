---
name: ae-qa-file-bugs
description: "从测试发现、测试报告或差异清单结构化生成缺陷，并按配置的 issue provider 输出或提交"
dependencies:
  mcp: []
  cli:
    - name: ae
      verify: "ae --version"
  api_keys:
    - OPTIONAL_ISSUE_PROVIDER_TOKEN
  scripts: []
smoke_test:
  command: "ae --version"
  expected_exit: 0
  description: "ae CLI available"
---

# Skill: QA 缺陷回流

## 触发条件

当测试人员希望把测试发现、测试报告、差异报告或自然语言问题整理成标准 bug issue 时触发。

## 输入

- 一个或多个缺陷描述。
- 可选：截图、录屏、日志、接口响应、测试报告、`qa/12-change-impact.md`。

## 执行流程

1. 读取 `constraints/bug-report-standard.md`。
2. 读取 `.qa-agent.yml`（如果存在），识别 `issue_provider.type`。
3. 将输入拆分为独立缺陷。多个问题不要合并成一个 issue。
4. 对每个缺陷补齐：
   - 标题
   - 环境
   - 前置条件
   - 复现步骤
   - 实际结果
   - 期望结果
   - 严重程度
   - 影响范围
   - 验证标准
5. 信息不足时先追问，不要提交含糊 issue。
6. 如果 provider 支持查询，提交前查重；如果不支持，提醒用户手动查重。
7. 展示完整 issue 内容，等待用户确认。
8. 用户确认后：
   - `manual`：输出可复制的 issue 正文。
   - `gitee`：可通过 `ae git issues create` 提交。
   - 其他 provider：按项目 overrides 或适配器说明执行；没有适配器时降级为 `manual`。

## 输出

提交前展示：

```markdown
## 待提交缺陷

### [BUG] 模块 - 问题摘要

## 环境
## 前置条件
## 复现步骤
## 实际结果
## 期望结果
## 严重程度
## 影响范围
## 验证标准
```

提交后输出 issue 链接（如果已提交）和回归建议。

## 硬规则

- 提交前必须用户确认。
- 验证标准不能为空。
- 多个缺陷必须拆开。
- 禁止创建本地 issue 文件。
- 未配置 provider 时不要假设提交平台，输出标准 issue 正文即可。
- 调用外部缺陷平台前必须说明目标平台和项目。
