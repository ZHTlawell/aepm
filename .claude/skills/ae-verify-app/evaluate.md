# ae-verify-app 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-verify-app

## Test Stories

### Story 1: 单 App Baseline 验证（Happy Path）
- **Prompt**: "帮我验证一下 ShoeLens demo 的功能完整性。speckit 在 ~/projects/shoelens/speckit，demo 的 bundle ID 是 com.shoelens.demo，模拟器已启动。"
- **Expect**: Agent 按 Step 1-5 执行：(1) 读取 speckit/02-user-scenarios.md 提取功能点，生成 verify-cases.yaml，每个 case 包含 id、level（structural/behavioral/functional）、source、description、precondition、steps、checks；(2) 执行约束合规预检（AXe UI Tree 可用性检查）；(3) 对每个 test case 执行 Vision-guided 验证——截图、Vision 看图确认页面、定位元素、AXe tap 交互、再截图验证结果；(4) 生成 diff report（JSON 格式），包含 summary、coverage、coverage_by_level（structural/behavioral/functional 分别计算）；(5) 如有 non-pass 的 case，提示用户可用 `/ae-file-bugs` 自动生成 issue。
- **Max Time**: 600s

### Story 2: 双 App 对比模式 — demo vs prod
- **Prompt**: "我需要对比 ShoeLens 的 demo 和生成的成品。demo bundle ID: com.shoelens.demo，prod bundle ID: com.shoelens.prod，speckit 在 ~/projects/shoelens/speckit。"
- **Expect**: Agent 用同一套 verify-cases.yaml 分别对 demo 和 prod 执行验证，生成两份截图序列；然后执行 Step 3 双 app 对比：结构对比（逐 case 比较 status）、视觉对比（Claude Vision 看两张截图描述差异）、归因分析（功能缺失+speckit有描述=generation 问题，功能缺失+speckit无描述=extraction 问题，功能不同+约束无定义=constraint 缺失）。最终 diff report 包含归因字段。
- **Max Time**: 900s

### Story 3: WebView Hybrid App — AXe 不可用降级
- **Prompt**: "验证一个 WebView 为主的 App，AXe describe-ui 没法用。bundle ID: com.example.hybrid，speckit 在 ~/projects/hybrid-app/speckit。"
- **Expect**: Agent 在 Step 1.5 约束合规预检中检测到 AXe UI Tree 不可用（WebView hybrid），应：(1) 在 report 中标注所有 tap case 的可靠性为 `degraded`；(2) 降级到坐标 tap + Vision 定位模式，不使用 AXe describe-ui；(3) 每次 tap 前仍截图用 Vision 定位目标元素（不使用硬编码坐标）；(4) 在最终报告中明确说明 WebView 模式下的验证可靠性受限，建议哪些 case 需要人工复核。
- **Max Time**: 600s

### Story 4: 覆盖率计算和 Level 分类准确性
- **Prompt**: "验证 WePray demo，speckit 在 ~/projects/bible-app/speckit，bundle ID: com.kjv.bible.prayer.app。特别关注 AI 祈祷生成功能、onboarding 流程和 tab 导航。"
- **Expect**: verify-cases.yaml 中的 level 分类必须准确：(1) tab 导航按钮存在 = structural；(2) 点击 tab 切换页面 = behavioral；(3) AI 祈祷生成返回有意义的文本 = functional（需要真实 AI 服务）。coverage_by_level 应分别计算三个维度的通过率。functional 级别的 case 如果因缺少真实 AI 服务而无法验证，应标记为 not_tested 而非 fail，并在报告中说明原因。Camera/AR 相关 case 应标记为 not_tested（模拟器限制）。
- **Max Time**: 600s

### Story 5: 验证结果与 ae-file-bugs 的集成
- **Prompt**: "验证完成后帮我把所有失败的 case 自动提 issue 到 Gitee。diff report 已生成在 ~/projects/shoelens/verify-report/diff-report.json。"
- **Expect**: Agent 在验证完成后（coverage < 100%）主动提示用户可用 `/ae-file-bugs`；如果用户确认，读取 diff report JSON 中所有 status 为 missing 或 different 的 case，每个 case 生成一个 issue，issue 内容包含：case ID、差异描述、归因分析、对应的截图路径、speckit 来源引用。使用 `ae git issues create` 提交。如果 coverage = 100%，只提示验证通过，不引导 file-bugs。
- **Max Time**: 300s

You've hit your limit · resets 2am (Asia/Shanghai)

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
