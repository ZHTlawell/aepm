---
description: "Superwall 支付集成全流程 — 账号配置 + ASC 订阅商品 + SDK 接入 + StoreKit 2 购买"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version"
  expected_exit: 0
  description: "xcodebuild available"
---

# Skill: Superwall 支付集成 (ae-superwall-setup)

> **经 WePray (bible-app) 实战验证。** 方案由文龙确认：走 Superwall + StoreKit 2 原生 API，不走 BCStoreKit / purchase-service。

## 触发条件

PM 需要在 iOS App 中集成真实 StoreKit 支付时触发。典型场景：
- Demo 的 Paywall 只有 UI，需要接入真实购买逻辑
- preflight 报告中标记「Paywall 无 StoreKit 集成」
- 需要 A/B 测试不同 Paywall 方案

## 核心原则

1. **Superwall 管支付逻辑，Native UI 可保留** — 两种模式：Superwall 远程 Paywall（支持 A/B 测试）或 Native SwiftUI Paywall + Superwall 仅做支付处理
2. **ASC 订阅商品必须先建好** — Superwall SDK 需要从 ASC 拉取真实商品，没有商品 = SDK 报错
3. **杭州团队协助项前置沟通** — ASC Shared Secret、Adjust 付费事件联动等需要杭州团队配合

## 角色分工

| 事项 | 谁做 | 说明 |
|------|------|------|
| Superwall 账号注册 | PM | 建议用公司邮箱（文龙建议） |
| ASC 订阅商品创建 | PM（agent 操作 Playwright） | 需确认 SKU + 价格 |
| ASC Shared Secret | **杭州团队** | Superwall 验证订阅状态需要 |
| SDK 集成代码 | Agent | SPM 引入 + 初始化 + 购买流程 |
| Adjust 付费事件联动 | Agent + **杭州团队** | 客户端预埋 + 服务端事件需杭州配置 |
| Sandbox 测试 | PM | 真机 Sandbox 账号完整走通购买流程 |

## 前置条件

| 条件 | 说明 |
|------|------|
| ae-preflight 已通过 | 编译通过 + API Key 外部化 |
| ae-analytics-setup 已完成 | Firebase + Adjust 已接入（付费事件需联动） |
| Apple Developer 账号 | ASC 已有 App Record |
| ASC 订阅商品定价已确认 | 需产品/市场确认价格方案 |

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | Xcode 项目根目录 |
| 产品名称 | 是 | 如 "WePray" |
| 订阅定价方案 | 是 | Weekly/Monthly/Annual + 价格 + 试用期 |
| ASC App ID | 是 | 如 6761982880 |

---

## Phase 1: 前置准备（需杭州团队 + PM 配合）

### Step 1.1: 确认订阅定价

向 PM 确认（需与产品/市场对齐）：

> **订阅方案确认：**
>
> | 方案 | Product ID | 价格 | 试用期 |
> |------|-----------|------|--------|
> | Weekly | com.{bundleid}.weekly | $X.XX/week | 无 |
> | Monthly | com.{bundleid}.monthly | $X.XX/month | 无 |
> | Annual | com.{bundleid}.yearly | $X.XX/year | 7天免费试用 |
>
> WePray 参考：Weekly $5.99 / Monthly $9.99 / Annual $39.99（7天试用）

### Step 1.2: Superwall 账号注册

引导 PM 注册 Superwall 账号：

> 1. 访问 [superwall.com](https://superwall.com) → Sign Up
> 2. **建议用公司邮箱注册**（文龙建议，方便团队管理）
> 3. 选择 Free 计划（250 MAU，验证阶段足够）
> 4. Dashboard → Apps → Create App → 填产品名 → iOS
> 5. **获取 API Key**（格式 `pk_xxxxxxxx`）

拿到 API Key 后继续。

### Step 1.3: ASC 创建订阅商品

通过 `ae asc` CLI 创建订阅组和订阅商品。

**Step 1.3a: 检查已有订阅**

```bash
ae asc subscription list --app-id <AppID> --pretty
```

如果已有订阅组和商品，跳到 Step 1.4。

**Step 1.3b: 创建订阅组**

```bash
ae asc subscription create-group \
  --app-id <AppID> \
  --name "<产品名> Pro" \
  --pretty
```

记录返回的 `id`（Group ID）。

**Step 1.3c: 逐个创建订阅商品**

```bash
# Weekly
ae asc subscription create --group-id <GroupID> \
  --product-id <BundleID>.weekly --name "<产品名> Weekly" \
  --duration ONE_WEEK --display-name "Weekly" --pretty

# Monthly
ae asc subscription create --group-id <GroupID> \
  --product-id <BundleID>.monthly --name "<产品名> Monthly" \
  --duration ONE_MONTH --display-name "Monthly" --pretty

# Yearly
ae asc subscription create --group-id <GroupID> \
  --product-id <BundleID>.yearly --name "<产品名> Yearly" \
  --duration ONE_YEAR --display-name "Yearly" --pretty
```

**Step 1.3d: 在 ASC Web UI 配置定价**

> 定价需在 ASC Web UI 中设置（API 定价链路涉及 territory 查询，复杂度高）。

1. 打开 `https://appstoreconnect.apple.com/apps/<AppID>/distribution/subscriptions`
2. 点击每个订阅商品 → Subscription Prices → Add Pricing
3. 设置基础价格（如 Weekly $0.99 / Monthly $2.99 / Yearly $19.99）

**ASC 订阅商品状态必须为 "Ready to Submit" 或 "Approved" 才能在 Sandbox 测试。**

### Step 1.4: 杭州团队协助项

> **需要杭州团队（文龙/运营）提供：**
>
> | 项目 | 用途 | 提供方式 |
> |------|------|---------|
> | ASC App-Specific Shared Secret | Superwall 验证订阅状态 | ASC → App → App Information → App-Specific Shared Secret |
> | Adjust 服务端事件 Token 确认 | AJ_purchase / AJ_cancel / AJ_refund 需服务端触发 | 飞书文档或 Adjust 后台 |
>
> **如果暂时拿不到 Shared Secret：** Superwall 仍可在 Sandbox 环境测试购买流程，只是无法验证订阅续期状态。可先推进 Phase 2-3，Shared Secret 后补。

---

## Phase 2: SDK 集成

### Step 2.1: SPM 添加 SuperwallKit

**XcodeGen 项目** — 在 `project.yml` 中添加：

```yaml
packages:
  SuperwallKit:
    url: https://github.com/superwall/Superwall-iOS
    from: "4.0.0"

targets:
  <TargetName>:
    dependencies:
      - package: SuperwallKit
```

```bash
xcodegen generate
```

**标准 Xcode 项目：**
> Xcode → File → Add Package Dependencies → 输入 `https://github.com/superwall/Superwall-iOS` → Add Package

### Step 2.2: API Key 存入 Secrets.plist

Superwall API Key (`pk_` 开头) 虽然是公开 Key，但统一走 Secrets.plist 管理（与 preflight 约束对齐）：

```xml
<!-- Secrets.plist -->
<key>SuperwallAPIKey</key>
<string>pk_xxxxxxxx</string>
```

### Step 2.3: SDK 初始化

在 App 入口添加 Superwall 配置：

```swift
import SuperwallKit

@main
struct MyApp: App {
    init() {
        // Superwall 初始化（必须在 App 启动时）
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "SuperwallAPIKey") as? String
            ?? (Bundle.main.infoDictionary?["SuperwallAPIKey"] as? String)
            ?? { fatalError("Missing SuperwallAPIKey in Secrets.plist") }()
        Superwall.configure(apiKey: apiKey)
    }
}
```

### Step 2.4: Placement 注册

创建两个核心 Placement：

```swift
// Onboarding 结束后展示 Paywall
func showPaywallAfterOnboarding() {
    Superwall.shared.register(placement: "onboarding_complete")
}

// 用户触发付费功能时
func showPaywall() {
    Superwall.shared.register(placement: "paywall")
}
```

同时在 Superwall Dashboard → Placements 中创建对应的 placement 并绑定 Paywall 页面。

### Step 2.5: 订阅状态管理

```swift
// 判断用户是否为 VIP
var isVIP: Bool {
    Superwall.shared.subscriptionStatus == .active
}

// 在需要付费的功能前检查
func accessPremiumFeature() {
    if isVIP {
        // 直接使用
    } else {
        showPaywall()
    }
}
```

### Step 2.6: 恢复购买

Apple 审核要求必须有恢复购买功能：

```swift
// 在 Settings/Profile 页面提供恢复购买按钮
Button("Restore Purchases") {
    Superwall.shared.restorePurchases()
}
```

---

## Phase 3: Adjust 付费事件联动

### Step 3.1: 客户端事件（Agent 处理）

将 Adjust 付费事件从 Paywall 按钮点击移到 Superwall 支付回调：

```swift
// SuperwallDelegate
extension AppFlowManager: SuperwallDelegate {
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case .transactionComplete(let transaction, let product, _, _):
            // 真实购买成功，触发 Adjust 事件
            AdjustService.shared.trackSubscription(product: product)
            AnalyticsService.shared.logPurchaseSuccess(productId: product.productIdentifier)

        case .subscriptionStart(let product, _):
            AdjustService.shared.trackVIP()

        case .paywallClose:
            AnalyticsService.shared.logPaywallDismiss()

        default:
            break
        }
    }
}
```

### Step 3.2: 服务端事件（杭州团队配置）

以下事件需要服务端触发，**由杭州团队在 Adjust 后台或 purchase-service 中配置**：

| 事件 | Token | 触发时机 | 配置方 |
|------|-------|---------|--------|
| AJ_purchase | 由杭州提供 | 实际扣款成功 | 杭州团队 |
| AJ_cancel | 由杭州提供 | 试用取消 | 杭州团队 |
| AJ_refund | 由杭州提供 | 退款 | 杭州团队 |

> **通知杭州团队：** Superwall 会通过 Webhook 通知购买状态变更。如果使用 Superwall 的服务端验证（非 purchase-service），需要在 Superwall Dashboard → Settings → Webhooks 中配置回调 URL。

---

## Phase 4: Sandbox 测试验证

### Step 4.1: 创建 Sandbox 测试账号

> 1. ASC → Users and Access → Sandbox Testers → 「+」
> 2. 创建一个测试邮箱（不能是真实 Apple ID）
> 3. 在 iPhone → Settings → App Store → Sandbox Account 登录

### Step 4.2: 完整购买流程验证

在 TestFlight 或 Debug 版本上测试：

| 测试项 | 预期结果 | 验证方式 |
|--------|---------|---------|
| Paywall 展示 | 显示所有订阅方案 + 价格 | 目视确认 |
| 选择方案 → 购买 | StoreKit 弹出支付确认 → 成功 | Sandbox 账号 |
| 购买后状态 | VIP 功能解锁 | 检查 `subscriptionStatus == .active` |
| 恢复购买 | 已购买的订阅恢复 | 卸载重装 → 恢复 |
| Adjust 事件 | 购买事件在 Adjust Dashboard 可见 | 检查 Adjust 后台 |
| Firebase 事件 | `purchase_success` 在 Firebase Console 可见 | 检查 Firebase 后台 |

### Step 4.3: 上线前切换

- [ ] Adjust 环境从 `ADJEnvironmentSandbox` 改为 `ADJEnvironmentProduction`
- [ ] 确认 Superwall API Key 是 Production Key（非 Test Key）
- [ ] 确认 ASC 订阅商品状态为 "Approved"

---

## Phase 5: 输出

```
═══════════════════════════════════════════
  Superwall 集成完成 ✅
═══════════════════════════════════════════

配置信息:
  Superwall API Key: pk_xxxx...
  Subscription Group: {组名}
  Products:
    - {weekly_id}: ${price}/week
    - {monthly_id}: ${price}/month
    - {yearly_id}: ${price}/year (7天试用)

Placement:
  - onboarding_complete → Paywall
  - paywall → Paywall

验证结果:
  ✅ Sandbox 购买成功
  ✅ VIP 状态正确
  ✅ 恢复购买正常
  ✅ Adjust 付费事件可见
  ✅ Firebase 购买事件可见

杭州团队待确认:
  - [ ] ASC Shared Secret 已配置到 Superwall
  - [ ] Adjust 服务端事件已配置
  - [ ] Adjust 环境已切 Production
═══════════════════════════════════════════
```

---

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `Superwall not configured` | `configure(apiKey:)` 未在 App 启动时调用 | 检查 App init() |
| Paywall 不显示商品/价格为 $0 | ASC 订阅商品未创建或状态不对 | 检查 ASC 商品状态 |
| StoreKit 购买弹窗不出现 | Sandbox 账号未登录 | Settings → App Store → Sandbox Account |
| 购买成功但状态不更新 | Superwall delegate 未设置 | 确认 `Superwall.shared.delegate = self` |
| Adjust 看不到付费事件 | 事件触发点在按钮而非支付回调 | 移到 `transactionComplete` 回调中 |
| Free 计划不支持 Custom HTML | Superwall Free 限制 | 用 Native Paywall + Superwall 仅做支付，或升级 Pro |
| `Superwall API Key is invalid` | 用了 Test Key 而非 Production Key | Dashboard → API Keys 检查 |

## 与其他 skill 的关系

```
/ae-preflight ─────→ 编译通过
        │
        ▼
/ae-analytics-setup → Firebase + Adjust 接入
        │
        ▼
/ae-superwall-setup → Superwall + StoreKit 2 支付
        │
        ▼
/ae-testflight-publish → Archive → TestFlight（带真实支付）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-030 | StoreKit 2 中 `purchase()` 设置的即时订阅状态不能被异步 `currentEntitlements` 检查覆盖。Sandbox 环境 entitlement 有延迟，不能作为唯一真相源 | WePray 购买成功后 Profile 仍显示 "Free Plan"，因为 `checkSubscriptionStatus()` 覆盖了 `purchase()` 的结果 |
| ios-pub-032 | 所有展示订阅状态的 UI 必须绑定到 SubscriptionService 的 `isSubscribed`，不能硬编码 "Free Plan" | WePray ProfileView 中 "Free Plan" 是硬编码字符串，购买后未更新 |

## 技术决策记录

| 决策 | 选择 | 原因 | 确认人 |
|------|------|------|--------|
| 支付方案 | Superwall（非 BCStoreKit） | 无需 purchase-service 后端，大幅简化 | 文龙 |
| 客户端 SDK | StoreKit 2 原生 API | 新产品无历史包袱，不依赖内部 Pod | 文龙 |
| Paywall UI | 可选 Native / Superwall 远程 | Native 更灵活，远程支持 A/B | PM 决策 |
