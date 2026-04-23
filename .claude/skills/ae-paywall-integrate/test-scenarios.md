# ae-paywall-integrate 用户场景验收清单

本清单由龙哥审计阶段逐条跑通，每个场景在真实 Scale Global 项目（优先 WePray）上验证，通过后标记 ✅。

## 场景 1: 新项目首次接 Paywall（典型路径）

- **前置**：项目已完成 ae-preflight + ae-analytics-integrate，Podfile 已含 BCStoreKit/BCAccount，杭州团队已创建 ASC IAP 产品 + Sandbox 账号。PM 提供产品名称、Bundle ID、三档定价（weekly/monthly/yearly）、Premium 功能列表、Privacy/Terms URL。
- **用户说**："帮我接 paywall，方案是 weekly $5.99 / monthly $9.99 / yearly $39.99，年付默认推荐，7 天试用。"
- **预期行为**：Agent 按 Phase 1-5 执行：
  1. Phase 1 前置检查：Podfile 含 BCStoreKit ✓ / AdjustService 存在 ✓ / PM 确认 IAP 状态 ✓
  2. Phase 2 生成三个文件：SubscriptionService.swift / PaywallView.swift / AdjustService 订阅段注释补全
  3. Phase 3 注入 Onboarding 末尾 + 应用内 Premium 功能锁
  4. Phase 4 提示 PM 真机 Sandbox 验证
  5. Phase 5 输出交付物清单
- **验收标准**：
  - [ ] PaywallView.swift 右上角有 ✕ 关闭 + Privacy/Terms/Apple EULA 三链接 + Restore 按钮
  - [ ] SubscriptionService.restore() 用 withCheckedContinuation 包 callback
  - [ ] AdjustService 订阅事件方法被注释标记"BCStoreKit 自动上报，禁止调用"
  - [ ] 编译 BUILD SUCCEEDED
- **状态**：⏳ 未测试

## 场景 2: 前置条件缺失（Podfile 未含 BCStoreKit）

- **前置**：项目是外部非 Scale Global 系 App，Podfile 里没有 BCStoreKit/BCAccount。
- **用户说**："帮我接 paywall"
- **预期行为**：Phase 1 Step 1.1 grep 无匹配，Agent 立即 abort 并说明：
  > 本 skill 依赖 Scale Global 内部 BCStoreKit/BCAccount 生态，当前项目 Podfile 未引入。非 Scale Global 项目不适用。建议：
  > 1. 如果是 Scale Global 旗下，联系杭州团队把 `pod "BCStoreKit"` + `pod "BCAccount"` 加入 Podfile；
  > 2. 如果是外部项目，需单独实现纯 StoreKit 2 方案（目前未规划 skill）。
- **验收标准**：
  - [ ] Agent 不继续执行 Phase 2
  - [ ] 给出清晰的 abort 原因 + 两条后续建议
- **状态**：⏳ 未测试

## 场景 3: Restore Callback Race（踩坑防御）

- **前置**：Agent 已生成 SubscriptionService.swift。
- **用户说**：查看生成的代码，或 "restore 方法这样写对吗？"
- **预期行为**：Agent 生成的 `restore()` 方法必须用 `withCheckedContinuation` 包 `BCStoreKit.restore` callback，而**不是**直接写：
  ```swift
  func restore() async {
      BCStoreKit.restore { result in
          self.isSubscribed = BCAccount.isVip
      }
  }
  ```
- **验收标准**：
  - [ ] `restore()` 签名是 `async`
  - [ ] 方法体使用 `await withCheckedContinuation { continuation in BCStoreKit.restore { ... continuation.resume() } }`
  - [ ] 代码中有注释说明"Bug R / Wave 4"或等价的 callback race 警告
- **状态**：⏳ 未测试

## 场景 4: Adjust 订阅事件重复调用（反模式识别）

- **前置**：项目已接 Paywall，PM 反馈"Adjust 后台看到 AJ_vip 事件数是实际购买的 2 倍"。
- **用户说**："Adjust 后台订阅事件数翻倍，帮我查一下"
- **预期行为**：Agent 识别这是反模式第 2 条（手动调 AdjustService.trackVip 导致翻倍），grep 业务代码：
  ```bash
  grep -rn "AdjustService\.trackVip\|AdjustService\.trackWeekly\|AdjustService\.trackMonthly\|AdjustService\.trackYearly\|AdjustService\.trackSubscribe\|AdjustService\.trackPurchase" --include="*.swift" . | grep -v Pods
  ```
  定位业务代码中手动调用的位置，给出修复建议（删除业务代码调用，保留 AdjustService 方法定义作为 Event Token 清单）。
- **验收标准**：
  - [ ] Agent 定位到具体文件行号
  - [ ] 说明原因：BCStoreKit 内部 ServiceManager.swift 已自动调 `BCAdjust.sendEvent`
  - [ ] 给出修复 diff
- **状态**：⏳ 未测试

## 场景 5: PaymentResult 失败场景完整处理

- **前置**：真机 Sandbox 验证中触发失败场景。
- **用户说**："点购买没反应，spinner 一直转"
- **预期行为**：Agent 排查：
  1. 查 Xcode Console 是否有 `🛒 [Subscription] purchase requested productId=...` 日志 → 确认按钮已触发
  2. 查是否有 `🛒 purchase result=...` 日志 → 确认 callback 是否触发
  3. 若无 result 日志 → BCStoreKit 挂起，按故障排查表查 ASC 产品状态 / Bundle ID / Sandbox 账号 / agreements
  4. 若有 result=appstorefailed/networkError/serverError 但 UI 无反应 → 检查 PaywallView 是否完整处理五分支（漏 case → spinner 不 reset）
- **验收标准**：
  - [ ] Agent 首先查日志定位问题，不是瞎猜
  - [ ] 正确区分"callback 没触发"vs"callback 触发但 UI 未响应"
  - [ ] 修复后 PaywallView 的 PrimaryButton 按 SKILL.md Step 2.2 模板含完整 5 分支 switch
- **状态**：⏳ 未测试

## 场景 6: Apple 合规审查（模拟 App Store 拒审）

- **前置**：Agent 已完成 Paywall 集成。
- **用户说**："App Store 拒审了，理由是 Guideline 3.1.1(a) 或 4.0"
- **预期行为**：Agent 按反模式第 4、6 条自查：
  1. 打开 PaywallView.swift grep `strikethrough\|originalPrice` → 确认无误导性折扣
  2. 确认右上角 ✕ 关闭按钮存在且可点
  3. 确认底部 Privacy / Terms / Apple Subscription Terms 三链接齐全
  4. 确认 Restore purchases 按钮存在
  5. 如有缺失，按 Step 2.2 模板补齐
- **验收标准**：
  - [ ] Agent 引用具体 Guideline 编号（3.1.1(a) / 4.0 / 3.1.2）
  - [ ] 准确定位缺失项，给出修复代码
  - [ ] 提醒 PM 提审时在 Review Notes 附 Sandbox 测试账号
- **状态**：⏳ 未测试

## 场景 7: VIP 状态服务端延迟

- **前置**：真机购买成功但 Paywall 不自动关闭。
- **用户说**："购买成功了但页面没关，iSubscribed 一直 false"
- **预期行为**：Agent 识别是服务端 flag 延迟（反模式相关 + 故障排查表）：
  1. 查 Xcode Console：`🛒 purchase result=success isSubscribed=false` 确认是这种场景
  2. 等 1-2 秒再观察 → 通常 `.accountUserChanged` 通知触发，`isSubscribed` 自动刷新
  3. 若长时间不同步：
     - 检查 SubscriptionService 是否正确监听 `.accountUserChanged`
     - 联系杭州团队检查服务端收据验证是否通
- **验收标准**：
  - [ ] Agent 不会建议改用 `Transaction.currentEntitlements`
  - [ ] 正确诊断为 BCAccount 服务端 flag 延迟
  - [ ] 给出 1-2 秒等待 + 服务端排查两步建议
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-7 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确的阻塞原因和修复 PR
- 龙哥审计通过，确认技术路线 + 代码模板符合 Scale Global 生态约定

## 已知阻塞项

（龙哥审计前预留）

- [ ] `BCStoreKit` 初始化位置未在 WePray Pray target 找到显式调用，需龙哥确认是否在 Template / BCAccount 内部自动初始化，如需显式 configure 要加 Phase 3 Step
- [ ] `BCStoreKit.product(of:)` 的 product 加载时机（启动时自动？还是首次访问 paywall 时？）需龙哥确认，如需预加载要加 Phase 3 Step
- [ ] BCAccount 服务端收据验证耗时典型值（用于"VIP flag 延迟"的合理等待阈值）待龙哥补充
