# ae-notification-integrate 用户场景验收清单

本清单由龙哥审计阶段逐条跑通。每个场景在真实 Scale Global 项目（优先 WePray 或新产品）上验证，通过后标记 ✅。

## 场景 1: 新项目首次接本地通知（典型路径）

- **前置**：Podfile 已含 BCUserNotification + BCPermission，ae-analytics-integrate 已完成（BCTrack 可用），AppDelegate 已设 `UNUserNotificationCenter.current().delegate = self`。PM 提供 2 个提醒场景（daily 每日提醒 + trial 到期前 24h）+ 文案 + identifier 前缀域。
- **用户说**："加一个每日 8:00 的提醒和一个试用到期前 24 小时的提醒"
- **预期行为**：
  1. Phase 1 前置检查：Podfile ✓ / AppImports 导出 ✓ / AppDelegate delegate ✓
  2. Phase 2 生成：NotificationService.swift（含 daily_verse_reminder + trialCancelReminder 两场景）+ AppDelegate 点击 dispatch extension（2 个前缀 branch）+ SettingsViewModel toggle
  3. Phase 3 编译 + 提示 PM 真机验证
- **验收标准**：
  - [ ] NotificationService 的 schedule 方法用 `BCUserNotificationManager.shared.addNotification`（不是 `UNUserNotificationCenter.current().add`）
  - [ ] 权限请求用 `BCPermission.requestNotificationPermission(force: false)`（不是 `center.requestAuthorization`）
  - [ ] Identifier 格式为 `{前缀域}_{suffix}`（如 `daily_verse_reminder_<userId>`、`vip_cancel_reminder_<timestamp>`）
  - [ ] AppDelegate `didReceive` 按前缀 dispatch 打 BCTrack 埋点
  - [ ] 编译 BUILD SUCCEEDED
- **状态**：⏳ 未测试

## 场景 2: 前置条件缺失（Podfile 无 BCUserNotification）

- **前置**：项目 Podfile 没有 BCUserNotification 或 BCPermission。
- **用户说**："加通知"
- **预期行为**：Phase 1 Step 1.1 grep 无匹配，Agent 立即 abort 并说明：
  > 本 skill 依赖 Scale Global 内部 BCUserNotification + BCPermission，当前项目 Podfile 未引入。联系杭州团队加 pod（tag 固定版本：`BCUserNotification 1.0.2` + `BCPermission 1.1.0`）后重试。
- **验收标准**：
  - [ ] Agent 不继续执行 Phase 2
  - [ ] 给出具体 pod 名 + 版本号 + 加入方式建议
- **状态**：⏳ 未测试

## 场景 3: 权限请求时机审查（Onboarding 强制弹反模式）

- **前置**：PM 要求"在 Onboarding 第一页就弹通知权限"
- **用户说**："把权限请求放在 onboarding 第一页"
- **预期行为**：Agent 识别这是反模式第 4 条，拒绝并说明：
  > ❌ Onboarding 强制弹通知权限拒授率 > 50%，iOS 对拒绝用户的 requestAuthorization 静默忽略，等于永久丢通道。且 Apple Guideline 4.5.4 "should not prompt before providing context" 审核风险。
  > ✅ 建议：设置页 toggle（用户主动开关时请求）或功能首次使用时（用户已感知价值）。如确需在 Onboarding 内请求，放到最后一页（用户已完成产品理解）。
- **验收标准**：
  - [ ] Agent 不按 PM 要求强行实现
  - [ ] 给出具体数据（拒授率 > 50%） + Apple 审核 Guideline 引用
  - [ ] 给出 3 种可行的时机替代
- **状态**：⏳ 未测试

## 场景 4: Identifier 前缀约定（反模式识别）

- **前置**：Agent 已生成代码。
- **用户说**：查看 NotificationService 代码 / "这个 identifier 用 UUID 行不行？"
- **预期行为**：Agent 识别 UUID 反模式，说明：
  > ❌ UUID 或无前缀会导致 (1) 订阅取消时无法 Group remove 批量清理试用提醒 (2) AppDelegate didReceive 无法识别点击来源打埋点
  > ✅ 必须 `{前缀域}_{业务后缀}` 格式。WePray 参考约定：
  > - `daily_verse_reminder_<userId>` — 每日提醒
  > - `vip_cancel_reminder_<timestamp>` — 试用到期前提醒
  > - `care_reminder_<date>` — 关怀提醒
- **验收标准**：
  - [ ] Agent 拒绝 UUID 方案
  - [ ] 引用 WePray 具体前缀域约定
  - [ ] 解释两个具体后果（Group remove 失败 + 埋点失败）
- **状态**：⏳ 未测试

## 场景 5: BCUserNotification 静默吞错排查

- **前置**：真机测试中，PM 反馈"schedule 代码跑了但通知不触发"
- **用户说**："schedule 调了，到时间没响"
- **预期行为**：Agent 按故障排查表逐条排查：
  1. 检查权限：设置 → 本 App → 通知 → 是否允许
  2. 检查 Focus Mode：是否屏蔽
  3. 检查 trigger 时间：是否已过（UNCalendar 过去时间不触发）
  4. 打印 `pending notification requests` 确认 schedule 成功：
     ```swift
     let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
     print("Pending: \(pending.map { $0.identifier })")
     ```
  5. 若 schedule 失败无 error：提示是 BCUserNotification 1.0.2 源码 `await try? center.add(data)` 吞 error，需要临时绕过用原生 `center.add` + catch 打印错误
- **验收标准**：
  - [ ] Agent 给出有序排查步骤，不是瞎猜
  - [ ] 引用 BCUserNotification 源码第 42 行吞错问题
  - [ ] 给出临时 debug 代码（打印 pending 数）
- **状态**：⏳ 未测试

## 场景 6: App 冷启动系统权限状态不同步

- **前置**：用户在系统设置关了通知权限 → 重启 App → 设置页 toggle 显示开（实际不触发）
- **用户说**："我关了系统通知，App 里还显示开着"
- **预期行为**：Agent 定位 `syncWithSystem()` 未调用：
  - 检查 `NotificationService.init()` 是否 `Task { await self.syncWithSystem() }`
  - 检查 `syncWithSystem` 实现是否调 `BCUserNotificationPermission.shared.getSettings()` 判断 `authorizationStatus != .authorized`
  - 修复后 toggle 应在冷启动时自动变关
- **验收标准**：
  - [ ] Agent 直接定位到 init 缺 syncWithSystem 调用（或 syncWithSystem 实现不完整）
  - [ ] 给出完整模板代码（SKILL.md Step 2.1 syncWithSystem 段）
- **状态**：⏳ 未测试

## 场景 7: Group remove 清理试用提醒

- **前置**：用户订阅成功后 → 需清除"试用到期前 24h 提醒"（因为已订阅不再到期）
- **用户说**："订阅成功了，别再提醒要取消了"
- **预期行为**：Agent 生成 `cancelTrialReminders()` 方法：
  ```swift
  public func cancelTrialReminders() async {
      await BCUserNotificationManager.shared.removeNotificationRequestGroups(["vip_cancel_reminder_"])
  }
  ```
  调用时机：`SubscriptionService` 监听到 `BCAccount.isVip` 变 true 时触发（参考 ae-paywall-integrate 的 `.accountUserChanged` 通知）。
- **验收标准**：
  - [ ] 用 `removeNotificationRequestGroups(["vip_cancel_reminder_"])`，不是 `removePendingNotificationRequests(withIdentifiers:)`
  - [ ] 前缀参数和 Phase 2 schedule 时的前缀一致
  - [ ] 集成点在 SubscriptionService VIP 状态变化时触发
- **状态**：⏳ 未测试

## 场景 8: 远程推送超出范围（scope guard）

- **前置**：PM 问"服务端怎么推送？"或"怎么接 APNs 证书？"
- **用户说**："服务端怎么 push 用户？"
- **预期行为**：Agent 说明本 skill 不覆盖远程推送：
  > 本 skill 仅覆盖**本地通知**（UNCalendar 定时、UNTimeInterval 相对时间、业务事件触发）。远程推送涉及 APNs 证书、服务端 push 服务、BCPush（Scale Global 目前无此封装），不在本 skill 范围。待 `ae-remote-push-integrate`（未来 B 类 skill）处理。
  >
  > 如果确实需要远程推送，先确认：
  > 1. 杭州团队是否已有服务端 push 服务？
  > 2. 是否计划引入 BCPush 封装？
  > 3. APNs 证书（.p8 / .p12）谁负责上传？
- **验收标准**：
  - [ ] Agent 明确 abort，不尝试加服务端相关代码
  - [ ] 说明本地和远程的区别
  - [ ] 给出前置确认问题（把皮球踢给杭州）
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-8 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确阻塞原因和修复 PR
- 龙哥审计通过，确认：
  - 技术路线（BCUserNotification + BCPermission）正确
  - WePray 现有 NotificationService 是否需迁移到 BCUserNotificationManager
  - 权限请求时机策略（用户主动触发）是否需调整

## 已解决阻塞项（杭州 Martinlehb 审计 2026-04-23，IJD7GE #note_49775397）

- [x] **P0-4 WePray NotificationService 是历史遗留**：新项目统一使用 `BCUserNotificationPermission`，覆盖"首次请求"和"用户拒绝后二次请求"两种场景。SKILL.md 硬性规则 2 已标注。
- [x] **P0-5 推送服务去重**：`addNotification` 内部先检查已注册则跳过，**可放心多次调用**。硬性规则 1 改为明确"可放心多次调用"语义。
- [x] **P0-6 force 参数语义**：作用于"首次拒绝后二次申请"场景 — `force: true` 跳转系统 Settings 让用户开权限开关；`force: false` 不跳转静默处理。硬性规则 2 已补充。
- [x] **P0-7 deep link 未来扩展**：当前 Scale Global 生态无通用 deep link pattern，作为未来扩展点注明。硬性规则 6 已声明。
