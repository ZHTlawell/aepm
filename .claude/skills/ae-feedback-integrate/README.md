# ae-feedback-integrate

> Scale Global 旗下 iOS 产品的**用户反馈**全流程技能 —— 基于内部 `BCFeedback` Pod + `Template/Feature/Feedback/` 业务薄封装，沉淀 Loopcraft + bible-ios-template 实战代码。

## 问题陈述

用户反馈是 0.1 产品上 TestFlight 后**唯一可量化的满意度信号**（evaluate paywall 转化率、核心功能质量、用户对 AI 生成结果的接受度）。但 Scale Global 生态下接反馈有几个非直觉约束：

1. **不该自己造轮子，该用 `BCFeedback` + Template/Feature/Feedback 两层封装**：
   - Pod 层：`BCFeedback.survey` / `BCFeedback.feedback` + 统一 Models（BCSurveyData / BCFeedbackData / BCFeedbackItemData）
   - Template 层：`FeedbackHelper` / `FeedbackDataManager` / `FeedbackView` / `FeedbackThanksView` 4 通用文件
   - AI 如果用开源 survey 库或自己写 yes/no UI，会和生态脱节（埋点字段不对齐、本地持久化缺失、无法做 AB 测试）

2. **FeedbackSource 枚举 + 扩展映射是产品特定的**：
   - 每个产品的反馈来源不同（Loopcraft 是 `.paint(PaintingSource)`，WePray 可能是 `.chatResponse(ChatResponseSource)`）
   - 每个 case 必须在 Ext 里补完 `source` / `parameters` / `feedbackData` 三个映射 —— AI 很容易漏掉一个

3. **`BCFeedbackData` 预定义只适配 Plant 类产品**：
   - Pod 内置 `.identifyResult` / `.diagnoseResult` / `.plantFinder` 三个，文案是"识别错了/不清晰/名字不对"
   - 非 Plant 产品（Chat / Bible / Paint）照抄会出现屏幕上"识别错了"选项对 Bible 读者毫无意义的笑话
   - 必须自定义 `BCFeedbackData` static computed var + `[BCFeedbackItemData]` 选项集

4. **反馈文案要本地化**：
   - `BCFeedbackOption(key:)` 内部用 `Language.text(for: key)` 查表，key 不在 Localizable 中会显示裸 key
   - 多语言不做 = 英文市场以外的用户看到乱码般的 key 串

5. **`FeedbackHelper` 三件事不可拆**：
   - 持久化（FeedbackDataManager）+ 埋点（BCTrack）+ Thanks UI
   - AI 如果只做了埋点跳过持久化，用户下次看不到"已反馈"状态；跳过 Thanks UI，用户不知道反馈被收到

这些约束散在 `Template/Feature/Feedback/` 6 文件 + `Pods/BCFeedback` 若干模型文件中，AI 新接产品时靠猜必踩坑。

## 解决方案

这个 skill 把 Loopcraft + bible-ios-template 实战代码沉淀成标准模板：

- **通用 4 文件**：可直接 copy（`FeedbackHelper` / `FeedbackDataManager` / `FeedbackView` / `FeedbackThanksView`）
- **产品特定 2 文件模板**：`FeedbackSource` + `FeedbackSource+Ext`，agent 按 PM 提供的业务场景填充
- **非 Plant 产品自定义 `BCFeedbackData` 模板**：避免用错 Plant 类预定义
- **6 条硬性规则 + 7 条反模式 + 7 条故障排查 + 8 条已验证约束**，覆盖 BCFeedback + Template 层的主要坑
- **可选 Phase**：关键路径弹窗式 survey（`BCFeedback.survey(...)`），按 PM 需求启用

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 技术栈 | BCFeedback + Template/Feature/Feedback | Scale Global 生态统一，埋点字段对齐，已有持久化 | 纯自研：重复造轮子，失去生态集成价值 |
| 业务嵌入 vs 弹窗 | 两者都支持（业务嵌入为主）| 业务结果页嵌入 = 高触发率；关键路径弹窗 = 主动洞察 NPS | 只做一种：覆盖不全 |
| FeedbackSource enum 定义位置 | 产品仓库自己定义（本 skill 只给模板）| 每个产品反馈来源差异大 | 基类 enum + 派生：Swift enum 不支持派生 |
| 非 Plant 产品如何处理 `BCFeedbackData` | 自定义 static computed var + 自定义 subTexts key | 文案必须贴合业务场景 | 复用 Plant 类：用户看到不相关选项 |
| 文案本地化 | 强制走 Localizable key | 多语言产品必需 | 硬编码：英文以外市场体验崩 |

## 已放弃方案

### 方案 A: 纯自研反馈 UI
- **是什么**：自写 SwiftUI 的 yes/no / 星级 / 文本输入反馈组件
- **为什么放弃**：BCFeedback Pod 已含 SurveyPopCenter + FeedbackPopUp + Models，重造等于放弃生态集成（埋点字段格式 / 持久化 / AB 测试适配）

### 方案 B: 直接调 BCTrack 不走 Helper
- **是什么**：业务代码 `BCTrack.track("feedback", parameters: [...])` 直接打点
- **为什么放弃**：漏持久化（下次看不到"已反馈"）+ 漏 Thanks UI（用户不知道收到了）+ parameters 格式易漂移（各页面各写各的）

### 方案 C: 所有产品复用 Plant 预定义
- **是什么**：用 `BCFeedbackData.identifyResult` / `.diagnoseResult` / `.plantFinder` 给非 Plant 产品
- **为什么放弃**：选项文案是 Plant 类业务语义（识别 / 诊断 / 推荐植物），给 Chat / Bible / Paint 产品用会让选项和业务场景完全脱节

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| BCFeedback | Scale Global 内部 GitLab（1.6.0）| 60% — Survey + Feedback 详情页 Models + PopUp 组件 | Template 4 文件 + 产品特定 FeedbackSource 模式 + 非 Plant BCFeedbackData 模板 |
| BCSensor / BCTrack | Scale Global 内部库 | 100% — 埋点底层（ae-analytics-integrate 已接）| 事件名约定：`feedback` + parameters 格式 |
| MLModelCacheManager | AppImports（内部库）| 100% — 泛型本地持久化 | FeedbackDataManager 的 `FeedbackResult` 数组 key 约定 |

## FAQ

**Q: Loopcraft 里 `FeedbackSource` 只有 `.paint(PaintingSource)` 一个 case，我的产品要多个怎么办？**
A: enum 本来就是多 case 的，按产品场景加。例：
```swift
enum FeedbackSource: Codable, Equatable {
    case chatResponse(_ data: ChatResponseSource)
    case bibleStudy(_ data: BibleStudySource)
    case paywallSatisfaction(_ data: PaywallSource)
}
```
每加一个 case 必须同步在 Ext 里补 source / parameters / feedbackData 三个 switch 分支。

**Q: 我的产品是混合类型，既有 AI 生成（文案反馈）又有模型识别（结果反馈），能不能复用 Plant 的 `.identifyResult`？**
A: 模型识别类可以复用（因为 `.identifyResult` 的 subTexts 是"识别错了 / 照片不清 / 名字不对"，对识别类业务适配）。文案生成类必须自定义（subTexts 要改成"文案不准 / 语气差 / 太冗长"之类）。

**Q: 如果 PM 不想要 Thanks View 弹窗怎么办？**
A: 改 `FeedbackHelper.feedback` 去掉 `FeedbackThanksView.show()` 行。但建议保留 —— 明确告诉用户"反馈已收到"是基本体验，去掉会让用户不确定是否生效。

**Q: 用户同一个结果页反复点 yes / no 切换，会打多个埋点吗？**
A: 会。每次点击都打一次 `feedback` 事件。FeedbackDataManager 只持久化最新一次（按 source 去重），但埋点是全量记录的。如果 PM 希望只记录最终选择，需要在业务层加防抖。

**Q: 反馈数据在哪里查？**
A: 神策（BCSensor 内部路由）和 Firebase Analytics（BCTrack 双轨）。事件名 `feedback`，type `click`，parameters 包含 `resource`（source）+ `eparam1`（yes/no）+ 业务特定字段。神策后台 URL 和认证见 `reference_sensors_analytics.md`。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目接用户反馈的 AI 自动化能力。Loopcraft + bible-ios-template 已沉淀的 `Template/Feature/Feedback/` 6 文件模式，不应让下一个产品重新写一遍。
- **什么会让它过时**：
  - Scale Global 换反馈工具（如转 Intercom / Zendesk）→ 本 skill 重写
  - BCFeedback 升级 API 不兼容（如改为 SwiftUI 原生而非 UIKit PopUp）→ Phase 2 模板要重写
  - 非 Plant 产品的 `BCFeedbackData` 自定义如果成为普遍模式，应反推进 BCFeedback Pod 预定义

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，基于 Loopcraft + bible-ios-template 审计 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南（六段标准）|
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单 |
