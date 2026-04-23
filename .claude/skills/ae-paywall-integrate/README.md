# ae-paywall-integrate

> Scale Global 旗下 iOS 产品的 Paywall 全流程技能 —— 从 UI 设计到 BCStoreKit 订阅封装到 Sandbox 验证一条龙。替代原 `ae-paywall-design`（原 skill 只产 UI，不接订阅）。

## 问题陈述

0.1 产品要上 TestFlight 做付费转化率验证，必须有 Paywall。但 Scale Global 生态下 Paywall 接入比外部项目复杂：

1. **订阅判定不走 StoreKit 原生 API**：VIP 状态来自服务端 `BCAccount.isVip`，不是 `Transaction.currentEntitlements`。AI 如果按 Apple 官方 StoreKit 2 文档接入，会和服务端失同步。
2. **Adjust 联动已在 BCStoreKit 内部自动化**：`Pods/BCStoreKit/.../ServiceManager.swift` 已自动调 `BCAdjust.sendEvent(vip/weekly/monthly/yearly/subscribe)` + `sendSubscription(price:currency:)`。AI 如果在业务代码里手动调 `AdjustService.trackVip()` 等，会导致投放数据翻倍。
3. **BCStoreKit.restore 是 callback API**：Swift 5.5+ 的 `async/await` 风潮下，AI 很容易写成 `func restore() async { BCStoreKit.restore { ... } }`，callback 还没触发函数就 return 了，`await` 形同虚设。WePray Bug R / Wave 4 专门踩过。
4. **PaymentResult 五分支**：`.success/.cancelled/.appstorefailed/.networkError/.serverError` 必须全处理，`.cancelled` 静默、其他三失败必须弹用户态 alert，否则 spinner 卡死用户看不懂。

这些 Scale Global 特有的约束散在 WePray 代码的 Bug 注释里（Bug R / Bug Q / Bug T / Bug K），AI 新接项目时如果靠官方文档猜，一定踩一遍。

## 解决方案

这个 skill 把 WePray 经过 4 波 QA 迭代沉淀出来的代码模板 + 约束清单固化：

- **三个文件模板**：`SubscriptionService.swift`（~70 行，薄封装）、`PaywallView.swift`（~470 行 SwiftUI）、`AdjustService.swift` 订阅段（仅作 Event Token 注释清单）
- **6 条硬性规则**：ASC IAP 不自建、订阅事件禁止手动调、restore 必须 continuation、PaymentResult 五分支、VIP 走 BCAccount、合规三要素
- **7 条反模式**：全部来自 WePray 真实踩坑（Bug R/Q/T/K + Pods 审计发现）
- **沙盒验证流程**：真机 Sandbox 账号 + 三流程（购买/恢复/失败）+ Adjust Sandbox 视图确认

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 技术栈 | 纯 BCStoreKit 路线 | Scale Global 旗下项目统一用 BCStoreKit + BCAccount 内部库，服务端 VIP 判定已成基建 | 纯 StoreKit 2：外部项目可用，但 Scale Global 项目会和服务端失同步 |
| 与 ae-paywall-design 关系 | 合并（原 skill 将下线）| 原 skill 只产 UI 不接订阅，实际用户要的是端到端 | 并列两个 skill：用户要在两个 skill 之间跳，体验差 |
| UI 形式 | 仅 SwiftUI 原生 | WePray 实战验证，Scale Global 项目主流 | HTML + WKWebView：和 BCStoreKit 桥接复杂，Scale Global 无先例 |
| Adjust 联动 | 引用 ae-analytics-integrate，订阅事件不重复 | BCStoreKit 内部已自动上报，业务代码重复=翻倍 | 业务代码自己调：违反职责单一 |
| 杭州 IAP 配置边界 | 前置条件（skill 外完成）| IAP 产品是 ASC 全局配置，PM 必须提前协调，不做在 skill 里 | Phase 1 包在内：复杂度高，且 Agent 无权触碰 ASC |

## 已放弃方案

### 方案 A: 纯 StoreKit 2（Apple 官方路线）
- **是什么**：Swift 5.5+ 的 `Product.products(for:)` / `product.purchase()` / `Transaction.updates` / `currentEntitlements`
- **为什么放弃**：Scale Global 生态 VIP 状态统一走服务端，纯 StoreKit 2 判定会和 `BCAccount.isVip` 失同步。另外 BCStoreKit 内部已自动对接 Adjust，自建等于重造轮子。

### 方案 B: HTML WebView + BCStoreKit 桥接
- **是什么**：paywall/ 目录产 HTML，通过 `WKScriptMessageHandler` 桥接 `BCStoreKit.purchaseSubscription`
- **为什么放弃**：Scale Global 项目无先例，桥接层额外一跳，定价本地化（`product.displayPrice`）失效，不值得。

### 方案 C: Superwall 托管
- **是什么**：用户上传 HTML 到 Superwall Dashboard，JS 回调 Superwall SDK 自动对接 StoreKit
- **为什么放弃**：收费，且 Superwall SDK 和 BCStoreKit 的 Adjust 自动上报会冲突（两边都会打 vip/subscribe），需要额外屏蔽配置，不划算。

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| BCStoreKit | Scale Global 内部 GitLab（1.4.0） | 80% — 订阅购买、Adjust 自动联动、恢复购买 | 薄封装层（SubscriptionService）+ UI 层（PaywallView）+ 踩坑清单 |
| BCAccount | Scale Global 内部 GitLab（1.8.0） | 100% — 服务端 VIP 状态 + `.accountUserChanged` 通知 | 监听通知刷新 `isSubscribed` |
| BCAdjust | Scale Global 内部库 | 100% — Adjust 事件上报 | 业务层 `AdjustService` 薄封装（仅非订阅事件）|
| SwiftUI | Apple | 100% — UI 框架 | 基于 WePray 迭代出的 PaywallView 模板 |

## FAQ

**Q: 我的项目不是 Scale Global 旗下，能用这个 skill 吗？**
A: 不能。Podfile 不含 BCStoreKit/BCAccount 的项目本 skill 直接 abort，前置检查不过。外部项目需要单独做纯 StoreKit 2 版本，目前未规划。

**Q: BCStoreKit 自动上报 Adjust，那 ae-analytics-integrate 里的 AdjustService.trackWeekly 等还要保留吗？**
A: ae-analytics-integrate 现有 AdjustService 的订阅事件方法（`trackWeekly/Monthly/Yearly/Vip/Subscribe/Purchase`）其实是冗余的，业务代码不应调用。本 skill 的 Phase 2c 会在这些方法前加注释说明，或者直接注释掉保留 Token 映射。龙哥审计时可以决定是否清理 ae-analytics-integrate。

**Q: 价格展示能不能写 strikethrough 做折扣对比？**
A: 不行。Apple Guideline 3.1.1(a) 禁止误导性折扣展示（无真实参考价格的虚标"原价"）。改用 "Save X% vs monthly" 这种基于真实月付方案的对比文案。

**Q: 为什么要监听 `.accountUserChanged` 通知？**
A: 因为 `BCAccount.isVip` 是服务端 flag，购买成功后服务端要验证收据再更新 flag，这期间 StoreKit 已经 return `.success` 了。不监听通知，`isSubscribed` 不会自动刷新，Paywall 不会自动关闭。

**Q: Sandbox 账号地区怎么匹配？**
A: 让杭州团队创建 Sandbox 账号时选和产品定价一致的地区（通常 US）。账号地区不匹配会导致 `product.products(for:)` 返回空或价格异常。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目接 Paywall 的 AI 自动化能力。WePray 4 波 QA 迭代踩的坑，不应让下一个产品再踩一遍。
- **什么会让它过时**：
  - Scale Global 迁移到 StoreKit 2 原生（服务端 VIP 改为 JWS 校验）→ 本 skill 要重写
  - Superwall / RevenueCat 成为 Scale Global 默认选型 → 本 skill 要加 mode
  - BCStoreKit 升级 API 不兼容（如换成 async/await）→ Step 2.1 模板要重写

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，基于 WePray 1.4.x 审计，交付龙哥审计 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南（六段标准）|
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单（5+ 场景）|

## 与 ae-paywall-design 的关系

本 skill 合并了原 `ae-paywall-design` 的能力：

| 原 skill 能力 | 本 skill 处理 |
|--------------|--------------|
| HTML WebView Paywall | ❌ 废弃（见"已放弃方案 B"）|
| SwiftUI Native Paywall | ✅ 继承（基于 WePray 模板迭代）|
| StoreKit 2 集成 | ❌ 改为 BCStoreKit（见"已放弃方案 A"）|
| Superwall 集成指引 | ❌ 废弃（见"已放弃方案 C"）|
| 价格文案生成 | ✅ 继承（PM 提供真实价格，禁止 strikethrough）|

本 skill 发布后，`ae-paywall-design` 建议下线。龙哥审计过本 skill 后再处理下线流程。
