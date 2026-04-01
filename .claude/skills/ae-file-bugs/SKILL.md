---
description: "从 verify-app diff report 批量提交 bug"
---

# Skill: 从验证报告批量提 Bug (file-bugs)

## 触发条件

当用户在 `/ae-verify-app` 完成后说"把差异提 bug"、"提 bug"、"file bugs"，或者想基于 diff report 批量提交 issue 时触发。

## 核心原则

**PM 不做流程 QA。** verify-app 已经完成了对比、截图、归因，本 skill 把这些结果直接转化为 issue，PM 只需确认。

## 执行流程

### Step 1: 定位 diff report

找到最近的 diff report JSON 文件。按以下优先级查找：

1. 用户指定的路径（如 "用 verify/reports/diff-iter1.json 提 bug"）
2. 当前项目中最新的 `diff-*.json` 或 `diff-report.json`
3. `verify/reports/` 目录下最新的 diff report

如果找不到，提示用户先跑 `/ae-verify-app`。

### Step 2: 解析并筛选

读取 JSON，筛选出需要提 bug 的 case：

- `status: "different"` → 需要提 bug
- `status: "missing_in_prod"` → 需要提 bug
- `status: "pass"` → 跳过
- `status: "not_tested"` → 跳过（标注原因即可，如 simulator 无法测试 camera）
- `status: "navigation_error"` → 跳过（这是测试框架问题，不是产品 bug）

### Step 3: 自动生成 issue 草稿

对每个需要提 bug 的 case，自动生成标题和正文：

**标题规则：**

根据 `attribution` 字段映射前缀：

| attribution | 前缀 | 含义 |
|-------------|------|------|
| `extraction` | `[SPECKIT-GAP]` | speckit 提取遗漏 |
| `generation` | `[GEN-BUG]` | 成品生成偏差 |
| `constraint` | `[CONSTRAINT-GAP]` | 约束缺失 |
| null / 不确定 | `[BUG]` | 待 AE Team 归因 |

标题格式：`{前缀} {项目名} — {case description}`

**正文模板：**

```markdown
## 描述
{case.detail}

## 归因
- **阶段**: {attribution → 中文}
- **验证级别**: {case.level}（structural/behavioral/functional）
- **来源**: {case.source}

## 验证信息
- **Case ID**: {case.id}
- **状态**: {case.status}
- **Diff Report**: {report 文件路径}
- **迭代轮次**: iter{report.iteration}

## 截图
{如果有 demo_screenshot 和 prod_screenshot，列出路径}
{如果没有截图，标注"截图待补充 — 可通过 runner.py 重新采集"}

## 验收标准
- 重新运行 `/ae-verify-app`，Case {case.id} 状态从 {case.status} 变为 pass
{如果是 UI 类差异，补充具体的视觉验收条件，如"卡片圆角与 demo 一致（16px）"}

## 环境信息
- 项目: {从 report 或 test cases 推断}
- ae-pm 版本: {读取 CHANGELOG.md 最新版本}
```

### Step 4: 展示草稿列表，等待 PM 确认

将所有草稿以编号列表展示给用户：

```
从 diff-iter1.json 中发现 7 个需要提交的 bug：

1. [GEN-BUG] ShoeLens — Welcome carousel 差异（A2）
2. [GEN-BUG] ShoeLens — Paywall 简化（A3）
3. [GEN-BUG] ShoeLens — Brand drill 未完整实现（E3）
4. [GEN-BUG] ShoeLens — Style filter 内容缺失（E4）
5. [GEN-BUG] ShoeLens — Collabs filter 内容缺失（E5）
6. [GEN-BUG] ShoeLens — Language & Currency 页面结构不同（G3）
7. [GEN-BUG] ShoeLens — Toast 反馈未验证（T1）

请确认：
- "全部提交" — 提交以上所有 bug
- "提交 1,3,5" — 只提交指定编号
- "跳过 7" — 排除指定编号，提交其余
- "取消" — 不提交
```

### Step 5: 批量提交

根据用户确认，逐条通过 CLI 提交：

```bash
ae pm submit-bug "[GEN-BUG] ShoeLens — Welcome carousel 差异" "issue 正文"
```

每条提交后记录返回的 issue 链接。

### Step 6: 汇总报告

全部提交完成后，展示汇总：

```
已提交 6 个 bug：

| # | Issue | 标题 |
|---|-------|------|
| 1 | IHQXXX | [GEN-BUG] ShoeLens — Welcome carousel 差异 |
| 2 | IHQXXY | [GEN-BUG] ShoeLens — Paywall 简化 |
| ... | ... | ... |

跳过 1 个（T1 — Toast 反馈未验证，PM 判断暂不提交）
```

## 合并相似 case

如果多个 case 描述的是同一个问题的不同表现（如 E4/E5 都是 filter tab 内容缺失），**主动提议合并**：

> "E4 (Style filter) 和 E5 (Collabs filter) 看起来是同一类问题 — filter tab 内容未实现。要合并为一个 issue 吗？"

合并后标题示例：`[GEN-BUG] ShoeLens — Category filter tabs (Style/Collabs) 内容未实现`

## 重要规则

- **禁止创建本地 issue 文件** — 所有 bug 必须通过 `ae pm submit-bug` CLI 命令提交
- **禁止直接调用 curl/Gitee API** — 统一走 CLI
- **必须等用户确认后才提交** — 不可自动提交
- **每个 issue 独立提交** — 除非用户同意合并相似 case
