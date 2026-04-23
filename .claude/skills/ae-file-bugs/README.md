# ae-file-bugs

> 填补 verify-app 验证报告到 Gitee issue 之间的"最后一公里"——自动化批量提 bug，PM 只需确认。

## 问题陈述

PM 使用 `/ae-verify-app` 完成 demo vs 成品的差异对比后，会得到一份包含多个 case 的 diff report（JSON）。将这些差异逐条手动提交为 Gitee issue 存在三个问题：

1. **重复劳动** — 每个 case 都需要手写标题、正文、归因、验收标准，一份报告通常有 5-15 个差异项，逐条提交耗时 30-60 分钟
2. **归因不一致** — 差异可能来自提取遗漏（SPECKIT-GAP）、生成偏差（GEN-BUG）或约束缺失（CONSTRAINT-GAP），手动提交时归因标签经常遗漏或不准确
3. **信息丢失** — diff report 中包含 case ID、验证级别、截图路径等结构化数据，手动转写容易遗漏关键字段

## 解决方案

作为 verify-app pipeline 的下游 skill，自动解析 diff report JSON，为每个需要提 bug 的 case 生成标准化的 issue 草稿，经 PM 确认后批量提交到 Gitee。

核心机制：
- **自动定位 diff report** — 按优先级查找用户指定路径 > 当前项目最新 > `verify/reports/` 目录
- **智能筛选** — 只对 `different` 和 `missing_in_prod` 状态的 case 生成 issue，跳过 pass/not_tested/navigation_error
- **归因映射** — 根据 `attribution` 字段自动添加前缀标签（`[SPECKIT-GAP]`/`[GEN-BUG]`/`[CONSTRAINT-GAP]`/`[BUG]`）
- **相似合并建议** — 检测同类差异（如多个 filter tab 内容缺失），主动提议合并为一个 issue
- **PM 确认门禁** — 展示编号列表后等待 PM 选择"全部提交"/"部分提交"/"取消"

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 归因前缀来源 | 从 diff report 的 attribution 字段映射 | verify-app 已完成归因分析，不重复劳动 | 让 PM 在提交时手动选择归因——增加 PM 工作量 |
| PM 确认 vs 全自动 | 必须等 PM 确认 | PM 是产品质量的最终把关人，有些差异 PM 可能认为可接受或需要合并 | 全自动提交——PM 失去筛选权，可能产生冗余 issue |
| 相似 case 合并 | 主动提议但不强制 | 减少重复 issue，但有些看似相似实则是不同问题 | 强制合并——可能误合并不同根因的问题 |
| 标题格式 | `{归因前缀} {项目名} — {case 描述}` | 在 Gitee issue 列表中一眼可辨归因类型和涉及页面 | 纯描述标题——缺少归因维度，不便于分类统计 |
| 提交方式 | 逐条通过 `ae` CLI 提交 | 每条独立提交可获取独立 issue ID，方便逐个跟踪和关闭 | 批量 API 调用——失败时不好定位哪条出了问题 |

## 已放弃方案

### 方案 A: 生成本地 issue markdown 文件
- **是什么：** 在项目目录下生成 `issues/` 文件夹，每个 case 一个 `.md` 文件
- **为什么放弃：** AE Platform 核心原则——所有 issue 必须通过 CLI 提交到 Gitee 远端，禁止本地 issue 文件。本地文件容易被遗忘，且无法被 AE Team 直接跟进

### 方案 B: 与 verify-app 合并为单一 skill
- **是什么：** 在 verify-app 完成对比后自动进入 bug 提交流程
- **为什么放弃：** 违反单一职责——verify-app 负责"发现差异"，file-bugs 负责"提交 issue"。PM 可能跑完验证后不想立刻提 bug，或者想先和团队讨论。解耦后两个 skill 各自演进更灵活

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Gitee issue 创建 | ae-git.py（自建 CLI） | 100% API 封装 | 无 — 纯复用 |
| diff report 解析 | ae-verify-app（自建） | 100% | 本 skill 消费其产出的 JSON 格式 |
| 归因体系 | ae-platform 自建 | 无对标 | extraction/generation/constraint 三阶段归因是 AE 独有 |

本 skill 无外部开源依赖。核心价值在于 AE 独有的 verify-app → file-bugs 流水线编排和归因映射逻辑。

## FAQ

**Q: diff report JSON 格式是什么？从哪来？**
A: 由 `/ae-verify-app` skill 产出，包含 case ID、status、attribution、detail、验证级别等字段。通常保存在 `verify/reports/diff-*.json`。

**Q: 同一个 diff report 可以多次执行 file-bugs 吗？**
A: 可以，但会产生重复 issue。建议在首次提交后记录已提交的 case ID，避免重复。

**Q: 没跑过 verify-app 能直接用 file-bugs 吗？**
A: 不能。本 skill 依赖 verify-app 产出的 diff report JSON。如果没有 report，skill 会提示先执行 `/ae-verify-app`。

**Q: 归因不确定时怎么处理？**
A: attribution 为 null 或不确定时，自动使用 `[BUG]` 前缀，由 AE Team 后续归因。PM 无需纠结归因准确性。

## 生命周期

- **填补的 gap：** verify-app 产出差异报告后，缺少自动化的 issue 提交流程。PM 需要手动将结构化数据转写为 issue，既费时又容易信息丢失
- **什么会让它过时：** 当 verify-app 具备端到端的 CI/CD 集成能力（diff → issue → 修复 → 重新验证 → 自动关闭），file-bugs 作为独立 skill 可能被合并到自动化 pipeline 中

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.8.0 (ae-pm) | 2026-03-26 | 首版：读取 diff report，自动生成 issue 草稿（归因前缀 + 验证级别 + case ID），PM 确认后批量提交 |
| v0.9.0 (ae-pm) | 2026-03-26 | 配套 `ae pm file-bugs` CLI 命令上线 |
| v0.10.0 (ae-pm) | 2026-03-27 | 强制验收标准字段；verify-app 完成后自动引导使用 `/ae-file-bugs` |
| v0.12.0 (ae-pm) | 2026-03-27 | 重命名 `/file-bugs` → `/ae-file-bugs`，统一 ae- 前缀 |
| v0.30.0 (ae-pm) | 2026-04-09 | 首次审计得分 3/8，待补齐六段标准 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：解析 diff report → 生成草稿 → PM 确认 → 批量提交的完整流程 |
| README.md | 人类设计文档（本文件）：归因映射设计、pipeline 定位、放弃方案 |
