# ae-file-bugs 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-file-bugs

## Test Stories

### Story 1: 基础 Happy Path — 从 diff report 批量提 bug
- **Prompt**: "把差异提 bug，用 verify/reports/diff-iter1.json"
- **Expect**: 
  - Step 1: 定位到 verify/reports/diff-iter1.json 文件
  - Step 2: 解析 JSON，筛选 status="different" 和 "missing_in_prod" 的 case，跳过 pass/not_tested/navigation_error
  - Step 3: 为每个 case 生成 issue 草稿，标题含正确前缀（[GEN-BUG]/[SPECKIT-GAP]/[CONSTRAINT-GAP]/[BUG]），正文包含描述/归因/验证信息/截图/验收标准/环境信息
  - Step 4: 展示编号列表，等待 PM 确认（"全部提交" / "提交 1,3,5" / "跳过 7" / "取消"）
  - Step 5: PM 确认后通过 `ae pm submit-bug` 逐条提交
  - Step 6: 展示汇总报告，含每条 issue 的编号和链接
- **Max Time**: 180s

### Story 2: 选择性提交 + 跳过指定 bug
- **Prompt**: "提 bug，跳过第 3 和第 7 个"
- **Expect**: 
  - 正确理解"跳过 3,7"指令，提交其余 bug
  - 汇总报告中明确列出被跳过的 case 及跳过原因
  - 不提交被跳过的 case
  - 已提交的 case 返回正确的 issue 链接
  - 支持多种确认方式："提交 1,3,5" / "跳过 7" / "全部提交" / "取消"
- **Max Time**: 120s

### Story 3: diff report 不存在或格式错误
- **Prompt**: "提 bug"
- **Expect**: 
  - 按优先级查找 diff report：用户指定路径 > 当前项目最新 diff-*.json > verify/reports/ 目录
  - 如果找不到任何 diff report，提示用户先运行 /ae-verify-app
  - 如果 JSON 格式错误（非标准 diff report），给出明确错误信息而非 crash
  - 如果 report 中所有 case 都是 pass/not_tested，告知"无需提交 bug"
  - 不尝试创建本地 issue 文件
- **Max Time**: 60s

### Story 4: issue 标题前缀和正文质量验证
- **Prompt**: "用 verify/reports/diff-iter2.json 提 bug，里面有 extraction 和 generation 两种归因类型"
- **Expect**: 
  - attribution=extraction 的 case 使用 [SPECKIT-GAP] 前缀
  - attribution=generation 的 case 使用 [GEN-BUG] 前缀
  - attribution=constraint 的 case 使用 [CONSTRAINT-GAP] 前缀
  - attribution=null 的 case 使用 [BUG] 前缀
  - 标题格式正确："{前缀} {项目名} -- {case description}"
  - 正文包含完整字段：描述、归因（中文）、验证级别（structural/behavioral/functional）、Case ID、Diff Report 路径、迭代轮次
  - 验收标准明确：重新运行 /ae-verify-app 后 Case 状态从 X 变为 pass
  - UI 类差异补充视觉验收条件（如"卡片圆角与 demo 一致 16px"）
- **Max Time**: 180s

### Story 5: 合并相似 case + 与 ae-verify-app 的集成
- **Prompt**: "提 bug，E4 和 E5 看起来是同一类问题，帮我合并"
- **Expect**: 
  - Agent 主动识别相似 case 并提议合并（如 E4 Style filter + E5 Collabs filter → "Category filter tabs 内容未实现"）
  - 合并后标题示例：[GEN-BUG] ShoeLens -- Category filter tabs (Style/Collabs) 内容未实现
  - 合并后正文包含两个 case 的 Case ID 和详细信息
  - 合并后验收标准覆盖两个 case
  - 所有提交通过 `ae pm submit-bug` CLI，禁止直接 curl/Gitee API
  - 禁止创建本地 issue 文件
  - 提交的 issue 可被后续 /ae-verify-app 迭代验证引用
- **Max Time**: 180s

## 最近一次评估
（待执行）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
（待执行）

## 瓶颈分析
（待执行）

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
