# ae-notification-integrate

> Scale Global 旗下 iOS 产品的**本地通知**全流程技能 —— 基于内部 `BCUserNotification` + `BCPermission` 生态，沉淀 WePray 实战代码。**不覆盖远程推送**（Scale Global 生态目前无远程推送封装，另起 `ae-remote-push-integrate` 处理）。

## 问题陈述

0.1 产品上 TestFlight 后，通知是仅次于 paywall 的核心召回通道。但 Scale Global 生态下接通知有几个非直觉约束：

1. **不该用 Apple 官方 API，该用 `BCUserNotification` + `BCPermission` 封装**：
   - `BCUserNotificationManager.shared.addNotification(_:)` 有 identifier dedup（避免重复通知），直接 `center.add(_:)` 没有这个保护
   - `BCPermission.requestNotificationPermission(force:)` 有统一埋点（BCAnalyticsPage），直接 `center.requestAuthorization(options:)` 绕过埋点
   - AI 如果按 Apple 官方文档接入，会和整个生态脱节（权限埋点丢、通知堆积）

2. **权限请求时机是转化率毒药**：
   - Onboarding 强制弹通知权限 → 用户还没感知价值就要授权 → 拒授率 > 50%
   - iOS 对拒绝用户的 `requestAuthorization` 静默忽略，等于永久丢通道
   - 正确做法：设置页 toggle / 功能首次使用时再请求（用户已建立价值认知）

3. **Identifier 必须有前缀域**：
   - WePray 约定 `vip_cancel_reminder_<timestamp>` / `daily_verse_reminder` / `care_reminder_` 三类前缀
   - 前缀域用于 ① AppDelegate `didReceive` dispatch 打埋点 ② 订阅取消时 Group remove 批量清理
   - AI 如果用 UUID 或无前缀，两个功能都失效

4. **BCUserNotification 吞错**：
   - 源码第 42 行 `await try? center.add(data)`，add 失败静默返回
   - 业务层需要外部加 log（或对比 pending 数）才能知道是否真的加上了

5. **App 冷启动要同步系统权限状态**：
   - 用户在系统设置关了通知，App 里 UserDefault 的 `isEnabled` 还是 true → toggle 显示开但实际不触发
   - 必须 init 时 `syncWithSystem()` 反向同步

这些约束散在 WePray `NotificationService.swift` + `AppDelegate.swift` + `SettingsViewModel.swift` 三处，AI 新接产品时靠官方文档猜，一定踩一遍。

## 解决方案

这个 skill 把 WePray 实战代码沉淀成标准模板：

- **三个文件模板**：业务层 `NotificationService.swift` + AppDelegate 点击 dispatch extension + SettingsViewModel toggle
- **6 条硬性规则**：schedule 走 BCUserNotification / 权限走 BCPermission / identifier 带前缀 / 点击 dispatch 打埋点 / 权限请求时机 / 不激活远程推送
- **7 条反模式**：全部来自 WePray/官方文档踩坑差异（dedup 缺失、埋点绕开、Onboarding 强制弹、group remove 缺失、权限状态不同步、willPresent/didReceive 混用）
- **范围明确**：只做本地通知，远程推送另起 skill

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 技术栈 | BCUserNotification + BCPermission | Scale Global 生态统一用这套封装，有 dedup + 统一埋点 | 直接 Apple UN*API：绕开生态，重复造轮子 |
| 范围边界 | 仅本地通知 | 远程推送 Scale Global 无封装（没 BCPush），另起 skill 更清晰 | 一起做：会变成 A+B 混合，风险大 |
| 权限请求时机 | 用户主动（toggle / 功能首次使用）| 拒授率 < 30%（行业基准），审核无风险 | Onboarding 强制：拒授率 > 50%，审核 Guideline 4.5.4 风险 |
| Identifier 约定 | `{domain}_reminder_{suffix}` 前缀域 | 支持 Group remove + 点击 dispatch | UUID：无法按组清理 |
| WePray NotificationService 是否迁移到 BCUserNotificationManager | **建议迁移**（SKILL.md 模板已按迁移后写）| 统一生态 | 保持现状：两套并存，维护成本高 |

## 已放弃方案

### 方案 A: 纯 Apple UN*API
- **是什么**：`UNUserNotificationCenter.current().add()` + `center.requestAuthorization(options:)` 原生接入
- **为什么放弃**：Scale Global 有 BCUserNotification + BCPermission 封装，不用就浪费生态红利；BCUserNotification 的 dedup 和 BCPermission 的统一埋点是业务稳定性基建

### 方案 B: 包含远程推送
- **是什么**：skill 里一起做 `registerForRemoteNotifications` + APNs 证书 + 服务端 deviceToken 上报
- **为什么放弃**：Scale Global 目前无封装（Podfile 无 BCPush，服务端无 push 端点），做成等于从零建 = B 类 skill；不符合用户"只做 A 类"约定。另起 `ae-remote-push-integrate`

### 方案 C: 强制 Onboarding 请求权限
- **是什么**：Onboarding 某页强制弹通知权限，最大化授权率
- **为什么放弃**：iOS 14+ 真实数据：Onboarding 弹权限拒授率 > 50%，且拒绝后系统永久静默忽略再次请求，相当于每两个用户就永久丢一个通道。审核 Guideline 4.5.4 明确"should not prompt before providing context"

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| BCUserNotification | Scale Global 内部 GitLab（1.0.2）| 30% — schedule add/remove/dedup 薄封装 | 业务层 NotificationService 模板 + identifier 前缀约定 + 点击 dispatch pattern |
| BCPermission | Scale Global 内部 GitLab（1.1.0）| 80% — 权限请求 + 埋点 | 时机约束（何时请求）+ 被拒后的引导流程 |
| UserNotifications | Apple | 100% — 底层 API | 不直接调（通过 BC 封装）|

## FAQ

**Q: 为什么 WePray 现有 `NotificationService.swift` 没用 `BCUserNotificationManager`？**
A: 推测是历史代码（Adjust 相关模块 2025/6 创建，WePray NotificationService 可能早于 BCUserNotification 1.0.2 引入）。SKILL.md 模板按"推荐走 BCUserNotificationManager"给出，WePray 迁移与否留给龙哥审计决定。

**Q: 远程推送 deviceToken → BCAdjust 这个回调本 skill 管不管？**
A: 保留但不激活。AppDelegate 已实现 `didRegisterForRemoteNotificationsWithDeviceToken → BCAdjust.appDidRegisterForRemoteNotifications`，但因为没有调 `registerForRemoteNotifications()`，实际不触发。保留给未来 `ae-remote-push-integrate` 铺垫。

**Q: 权限被拒的用户怎么恢复？**
A: iOS 系统行为 — 拒绝后再次调 `requestAuthorization` 会被静默忽略（return false 无弹窗）。唯一恢复路径：引导用户去系统设置 → 本 App → 通知 → 允许。通常用 `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` 跳转。

**Q: 通知内容怎么多语言化？**
A: 依赖 `ae-i18n-integrate`（下一个待做 skill）。目前 SKILL.md 模板文案用英文占位，PM 手动翻译。i18n skill 发布后，文案改走 `NSLocalizedString` + `Localizable.xcstrings`。

**Q: 通知 schedule 超过 64 个会怎样？**
A: iOS 限制每 App 最多 64 个 pending notification。超过会自动丢弃最旧的。日常产品一般用不到，但循环提醒场景（如每日 + 每周 + 季节性多份）累加可能触顶。控制方式：长周期循环用 `repeats: true`（占 1 个），一次性业务提醒（如 trial cancel）及时 removeNotificationRequestGroups 清理。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目接本地通知的 AI 自动化能力。WePray NotificationService + AppDelegate 点击 dispatch 的模式，不应让下一个产品重新踩坑。
- **什么会让它过时**：
  - Scale Global 引入远程推送（BCPush / 服务端推送服务）→ 本 skill 扩容或拆分新 skill
  - BCUserNotification / BCPermission 升级 API 不兼容 → Phase 2 模板要重写
  - iOS 更新权限模型（如 16 的 Critical Alert）→ 规则要补

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，基于 WePray 审计，交付龙哥审计 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南（六段标准）|
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单 |
