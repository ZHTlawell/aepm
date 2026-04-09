# ae-paywall-design

> 填补 PM 独立产出高转化率 Paywall 付费墙页面的能力 gap，让定价验证和 A/B 测试无需发版。

## 问题陈述

Paywall 付费率是 0.1 产品的核心验证指标，但当前存在三个瓶颈：

1. **定价调整成本高** — Native 写死的 paywall 每次改价格、改方案都要重新编译发版，等 Apple 审核 1-3 天。0.1 产品需要快速验证哪个定价方案转化最好
2. **缺少专业化设计** — PM 用 SwiftUI 写的 paywall 缺少关键转化元素（价格对比、"Save X%"、推荐标签、免费试用强调），付费率远低于行业水平
3. **StoreKit 2 门槛** — PM 不熟悉 StoreKit 2 的 Product/Transaction API，Native paywall 集成购买逻辑容易出错

## 解决方案

生成 Paywall 页面，支持两种输出模式：

- **HTML 模式（默认，推荐 0.1 阶段）** — 输出 `paywall/` 目录（index.html + styles.css + script.js），可上传 Superwall 或嵌入 WKWebView
- **Native 模式** — 输出 `PaywallView.swift`，包含完整 StoreKit 2 购买逻辑

核心机制：
- **转化率驱动的设计** — 默认高亮年付方案（行业最优实践）、显示折算月价 + Save % 标签、免费试用期突出展示
- **三回调架构** — `paywallPurchase(productId)` / `paywallDismiss()` / `paywallRestore()` 标准化 Native 桥接
- **风格统一** — 深色渐变背景与 ae-onboarding-design 保持一致的视觉语言，用户体验连贯

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 默认 HTML 模式 | HTML/CSS/JS | 支持 Superwall 热更新 + A/B 测试，0.1 阶段核心需求 | 默认 Native — 无法远程调整定价 |
| 同时提供 Native 模式 | SwiftUI + StoreKit 2 | 部分产品不用 Superwall 或已过 0.1 阶段，需要 Native 方案 | 只做 HTML — 无法覆盖后期需求 |
| 默认高亮年付 | 年付方案高亮 + BEST VALUE 标签 | 行业数据：年付转化后 LTV 最高，90%+ 的 Top App 都默认推年付 | 不预设推荐 — PM 不了解行业最佳实践时会做错选择 |
| 三个 JS 回调 | purchase / dismiss / restore | Apple 审核要求必须有 Restore 入口，关闭按钮是用户体验底线 | 单一回调 — 不符合 Apple 审核要求 |
| radio 选择行为 | 点击切换选中方案 | 用户只能选一个方案购买，radio 是最直观的交互模式 | checkbox 多选 — 逻辑上不合理 |
| 风格与 onboarding 统一 | 深色渐变 + 相同 CSS 变量体系 | onboarding → paywall 是连续流程，视觉断裂会降低信任感 | 独立配色 — 失去品牌一致性 |

## 已放弃方案

### 方案 A: RevenueCat Paywall SDK
- **是什么：** 使用 RevenueCat 的 Paywall SDK 自动生成和管理 paywall
- **为什么放弃：** RevenueCat Paywall SDK 模板有限，自定义程度低。我们需要与 onboarding 风格统一的完全自定义页面。且我们已选择 Superwall 作为远程配置层，两套系统并存增加复杂度

### 方案 B: 纯 Superwall 内置模板
- **是什么：** 不自己生成 HTML，完全使用 Superwall Dashboard 的可视化编辑器
- **为什么放弃：** 内置模板样式固定，无法实现我们的品牌化设计。且 Free 计划不支持 Custom HTML，但内置模板功能也有限

### 方案 C: 单文件输出
- **是什么：** 把 HTML/CSS/JS 全部内联到一个 `paywall.html` 中
- **为什么放弃：** 单文件超过 500 行后难以维护和迭代。PM 要改价格时需要在一大坨代码中找到正确位置。分离后 HTML 改文案、CSS 改样式、JS 改逻辑，职责清晰

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| StoreKit 2 购买 | Apple StoreKit 2 | 购买/恢复 API | 封装成 PM 可用的完整 PaywallView.swift |
| 页面托管 | Superwall Custom HTML | 托管 + A/B 测试 | 生成符合 Superwall 规范的 HTML 页面 + JS 回调桥接 |
| 定价展示 | 自建 | 100% 自建 | 折算月价、Save % 计算、推荐标签逻辑 |
| iOS 桥接 | WKScriptMessageHandler | Apple 原生 API | 标准化三回调接口 + Swift 集成代码片段 |

## FAQ

**Q: HTML paywall 里的购买按钮怎么真正触发 StoreKit 购买？**
A: HTML 里的 CTA 按钮调用 `window.paywallPurchase(productId)`。如果通过 Superwall 托管，SDK 自动桥接到 StoreKit。如果通过 WKWebView 嵌入，需要用 WKScriptMessageHandler 捕获消息后手动调用 StoreKit 2 的 `product.purchase()`。SKILL.md 里有完整的 Swift 集成代码。

**Q: Apple 审核会拒绝 WebView 形式的 paywall 吗？**
A: 不会。Superwall 的大量客户都使用 WebView paywall 通过审核。关键是页面中必须有 Restore 链接和 Terms/Privacy 链接，这些在我们的模板中已经包含。

**Q: 年付/周付的价格要自己算折合月价吗？**
A: 不用。PM 只需提供订阅方案（如"周 $4.99 / 年 $29.99"），skill 自动计算折算月价和节省百分比。

**Q: 能否同时测试多套定价方案？**
A: 可以。生成多个 HTML 变体（不同价格），上传到 Superwall Dashboard，配置 A/B 测试自动分流。这正是选择 HTML 模式的核心价值。

## 生命周期

- **填补的 gap：** PM 无法独立产出符合行业转化率标准的 Paywall 页面，且无法在不发版的情况下调整定价方案
- **什么会让它过时：** 当 Superwall 或 RevenueCat 的可视化 Paywall 编辑器足够成熟（拖拽式设计 + 品牌化定制 + 与 onboarding 风格联动），PM 不再需要生成 HTML 代码

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-04-07 | 首版。HTML 模式 + Native StoreKit 2 模式，深色渐变风格，方案选择/价格对比/免费试用，三回调接口 (#IHXLWR) |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：收集产品信息 → 设计定价展示 → 生成 HTML 或 Swift → 预览 → 集成 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、生命周期 |
