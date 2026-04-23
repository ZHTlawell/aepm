---
description: "iOS Paywall 全流程 — UI 设计 + BCStoreKit 订阅封装 + 沙盒验证（杭州团队 BCStoreKit/BCAccount 生态）"
last_updated: "2026-04-23"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(pod *)"
    - "Bash(open *)"
    - "Bash(grep *)"
    - "Bash(find *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: pod
      verify: "pod --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version"
  expected_exit: 0
  description: "xcodebuild available"
---

# Skill: Paywall 全流程 (ae-paywall-integrate)

> **经 WePray (bible-app) 实战验证。** 基于 Scale Global 内部 BCStoreKit/BCAccount/BCAdjust 生态，产出 iOS Paywall UI + 订阅封装 + 沙盒验证全流程。**非 Scale Global 系项目不适用**（没有 BCStoreKit 内部库）。

## 核心原则

> **你是 Paywall 工程师。** 基于产品核心功能和订阅方案，产出：① `SkuType` 枚举（所有 SKU 统一注册）；② 继承 `PurchaseUIBaseViewController` 的产品子类（命名 `PurchaseUI{memo}ViewController`）；③ `SubscriptionService` 封装层。关键约束：
>
> 1. **ASC IAP 产品（订阅组 + Product IDs + Sandbox 测试账号）必须在触发本 skill 前由杭州团队创建完成**
> 2. **所有 SKU 必须在 `public enum SkuType: String, CaseIterable {}` 中声明**（raw value = ASC product identifier），**禁止硬编码字符串**
> 3. **转化页必须继承 `PurchaseUIBaseViewController`**，基类启动时自动遍历 `SkuType.allCases` 拉取 Products，子类不重复实现 product 加载
> 4. **BCStoreKit 内部已自动上报 Adjust 订阅事件**（vip/weekly/monthly/yearly/subscribe/purchase），业务代码**禁止重复调用** `AdjustService` 对应方法

## 触发条件

- PM 说"加 paywall"、"接订阅"、"做付费墙"
- ae-preflight 报告中标记"无 IAP 配置"或"无 SubscriptionService"
- Demo 即将上 TestFlight，需要测试付费转化率

## 角色分工

| 事项 | 谁做 | 说明 |
|------|------|------|
| ASC 订阅组创建 | **杭州团队（触发本 skill 前完成）** | Subscription Group |
| Product ID 创建（weekly/monthly/yearly） | **杭州团队** | 如 `com.app.weekly` |
| IAP 产品本地化 + 截图 | **杭州团队** | ASC 审核 IAP 产品需要 |
| Tax Agreement / Banking | **杭州团队** | ASC 全局配置 |
| Sandbox 测试账号 | **杭州团队** | ASC → Users and Access → Sandbox Testers |
| BCStoreKit / BCAccount Pod 配置 | **杭州团队（内部 GitLab）** | Podfile 中的 `:git => GITLAB_BASE_URL` 条目 |
| Adjust App Token + Event Tokens | **杭州团队** | 已在 ae-analytics-integrate 前置完成 |
| 方案定价（周/月/年/试用天数） | PM | 如 $5.99/week、$39.99/year、7-day free trial |
| Premium 功能列表（3-5 条） | PM | Paywall 上方展示 |
| Paywall UI（SwiftUI） | Agent | PaywallView.swift |
| SubscriptionService 封装 | Agent | 绑定 `BCAccount.isVip` + `restore()` |
| 编译 + 沙盒真机验证 | PM | 真机 Sandbox 账号走完整流程 |

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 + API Key 外部化 |
| ae-analytics-integrate 已完成 | `AdjustService.swift` 存在且含 Event Tokens |
| Podfile 含 BCStoreKit + BCAccount | `grep 'pod "BCStoreKit"' Podfile` 有匹配 |
| ASC IAP 产品 Ready to Submit | 向杭州团队确认 ASC 后台状态 |
| Sandbox 账号已激活 | ASC → Sandbox Testers 列表可见 |
| 产品定价方案 + Premium 功能列表 | PM 口头/飞书提供 |

前置未就绪 → **停在这里**，向 PM 说明缺项，不继续。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "WePray" |
| Bundle ID | 是 | 如 com.kjv.bible.prayer.app |
| Product IDs | 是 | weekly / monthly / yearly 三档（来自杭州）|
| 方案定价 | 是 | 如 weekly $5.99, monthly $9.99, yearly $39.99 |
| 免费试用天数 | 否 | 如 7-day free trial |
| Premium 功能列表 | 是 | 3-5 条 feature（对比 free vs premium）|
| Privacy Policy URL | 是 | Apple 合规要求 |
| Terms of Use URL | 是 | Apple 合规要求 |
| 主色调 | 否 | 沿用 onboarding 配色 |

---

## Phase 1: 前置检查

**目标：** 确认项目已具备 BCStoreKit 生态，IAP 后台就绪。

### Step 1.1: 检查 Podfile

```bash
grep -E 'pod "(BCStoreKit|BCAccount|BCAccountExtension|BCAdjust|BCSensor)"' Podfile
```

**预期：** 至少 `BCStoreKit` + `BCAccount` 两行存在（tag 固定版本）。若缺失 → 联系杭州团队加 pod，本 skill 暂停。

### Step 1.2: 检查 AdjustService

```bash
find . -path ./Pods -prune -o -name "AdjustService.swift" -print 2>/dev/null
```

**预期：** 有匹配（来自 ae-analytics-integrate 产物）。缺失 → 先跑 ae-analytics-integrate。

### Step 1.3: 向 PM 确认 IAP 后台

口头/飞书问 PM：

> 杭州团队那边 ASC IAP 产品状态：
> 1. 订阅组已创建？Group Reference Name 是？
> 2. 三档 Product ID（weekly / monthly / yearly）Ready to Submit？
> 3. Sandbox 测试账号已激活？账号邮箱 + 地区 = ?

**三项都有明确答案，才进入 Phase 2。**

### Step 1.4: 检查 BCStoreKit 初始化点

```bash
grep -rn "BCStoreKit\|BCAccount" --include="*.swift" Template/ App/ 2>/dev/null | grep -v "import " | head -5
```

**预期：** 在 AppDelegate/SceneDelegate/App 入口能找到 `BCStoreKit.` 或 `BCAccount.` 的配置调用。若完全没有 → 向杭州团队/龙哥确认初始化方式（通常模板项目已内置）。

---

## Phase 2: 代码生成

**目标：** 生成 4 个核心文件：`SkuType.swift` / `PurchaseUI{memo}ViewController.swift` / `SubscriptionService.swift` / `PaywallView.swift`（+ 补全 `AdjustService.swift` 订阅段）。

### Step 2.0: `SkuType` 枚举 + `PurchaseUI{memo}ViewController` 命名（前置约束）

**SKU 统一注册**（杭州审计确认 P0-1）。路径：`<Project>/Classes/Config/SkuType.swift`

```swift
import Foundation

public enum SkuType: String, CaseIterable {
    case weekly  = "com.{product}.weekly"
    case monthly = "com.{product}.monthly"
    case yearly  = "com.{product}.yearly"
    // 新增 SKU → 必须加到此枚举；禁止在业务代码硬编码 product identifier 字符串
}
```

**转化页子类命名约定**（杭州审计确认 P0-23）。

- 项目转化页继承 `PurchaseUIBaseViewController`（BCStoreKit Pod 提供）
- 类名格式：**`PurchaseUI{memo}ViewController`**（memo 是 AB 变体 String，无长度/字符硬性限制，由 `ABTestType.vip` 返回决定）
- 基类启动时自动遍历 `SkuType.allCases` 拉取 Products，**子类不重复实现 product 加载**（P0-2）
- 示例（memo = "07"）：

```swift
import UIKit
import BCStoreKit

public class PurchaseUI07ViewController: PurchaseUIBaseViewController {
    // 不重写 product 加载 —— 基类已自动用 SkuType.allCases 预拉
    // 只负责 UI（选 SKU / CTA / 关闭 / Restore）
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
}
```

**动态加载**：Work Chain ConversionPageWork 根据 `BCABTest.shared.syncFetchVip()` 返回的 memo，`NSClassFromString("PurchaseUI\(memo)ViewController")` 动态加载对应子类。

### Step 2.1: SubscriptionService.swift（薄封装 ~70 行）

路径：`<Project>/Classes/Services/SubscriptionService.swift`（或项目惯例位置）

```swift
import Foundation
import BCStoreKit
import BCAccount

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var isSubscribed = false

    /// Session-level flag 防止启动/Onboarding Paywall 重复展示
    @Published var hasShownLaunchPaywall = false

    private var observer: NSObjectProtocol?

    private init() {
        isSubscribed = BCAccount.isVip

        // 购买/恢复后 BCAccount 会发 .accountUserChanged 通知
        observer = NotificationCenter.default.addObserver(
            forName: .accountUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isSubscribed = BCAccount.isVip
            }
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Restore purchases via BCStoreKit
    ///
    /// ⚠️ BCStoreKit.restore 是 callback API，直接 `async` 会立即返回，
    /// 必须用 withCheckedContinuation 才能真正等结果。
    func restore() async {
        print("🛒 [Subscription] restore requested")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            BCStoreKit.restore { [weak self] result in
                Task { @MainActor in
                    print("🛒 [Subscription] restore result=\(result) BCAccount.isVip=\(BCAccount.isVip)")
                    self?.isSubscribed = BCAccount.isVip
                    continuation.resume()
                }
            }
        }
    }
}
```

### Step 2.2: PaywallView.swift（SwiftUI ~470 行）

路径：`<Project>/Classes/UI/Views/Paywall/PaywallView.swift`

关键结构（完整模板见 examples/PaywallView.swift.template，以下列核心片段）：

**PricingPlan 枚举**（按 PM 提供的定价填充）：

```swift
enum PricingPlan: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case annual = "Annual"

    var productID: String {
        switch self {
        case .weekly:  return "<PM 提供的 weekly product id>"
        case .monthly: return "<PM 提供的 monthly product id>"
        case .annual:  return "<PM 提供的 yearly product id>"
        }
    }

    var price: String { /* PM 提供 */ }
    var period: String { /* /week /month /year */ }
    var badge: String? { /* annual 返回 "BEST VALUE" */ }
    var savings: String? { /* annual 返回 "Save X% vs monthly"（基于真实计算，不编造）*/ }
    var originalPrice: String? { return nil }  // ⚠️ 不加 strikethrough，避免 Apple 3.1.1(a) 拒审
}
```

**购买按钮**（完整 5 分支 PaymentResult 处理）：

```swift
PrimaryButton(title: isPurchasing ? "Processing..." : "Start Free Trial") {
    isPurchasing = true
    let pid = selectedPlan.productID
    print("🛒 [Subscription] purchase requested productId=\(pid) plan=\(selectedPlan.rawValue)")

    // 产品未加载的防御性日志
    if BCStoreKit.product(of: pid) == nil {
        print("⚠️ [Subscription] product \(pid) NOT loaded. Check: (1) ASC 状态=Ready to Submit (2) Bundle ID 匹配 (3) 已登录 Sandbox 账号 (4) agreements/banking/tax 完成")
    }

    BCStoreKit.purchaseSubscription(productId: pid) { [self] result in
        DispatchQueue.main.async {
            print("🛒 [Subscription] purchase result=\(result) isSubscribed=\(subscriptionService.isSubscribed)")
            isPurchasing = false
            switch result {
            case .success:
                if subscriptionService.isSubscribed { onDismiss() }
            case .cancelled:
                break  // 用户自己取消，静默
            case .appstorefailed:
                purchaseErrorMessage = "Purchase could not be completed through the App Store. Please check that you're signed in to the App Store and try again."
                showPurchaseError = true
            case .networkError:
                purchaseErrorMessage = "Network error. Please check your connection and try again."
                showPurchaseError = true
            case .serverError:
                purchaseErrorMessage = "Purchase failed due to a server error. Please try again in a moment, or contact support if the problem persists."
                showPurchaseError = true
            }
        }
    }
}
```

**Apple 合规三链接**（缺一拒审）：

```swift
HStack(spacing: 8) {
    Button("Privacy Policy")    { open(<PRIVACY_URL>) }
    Text("·")
    Button("Terms of Use")      { open(<TERMS_URL>) }
    Text("·")
    Button("Subscription Terms") { open("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") }
}
```

**Restore 按钮**：

```swift
Button("Restore purchases") {
    Task {
        print("🛒 [Restore] requested from paywall")
        await subscriptionService.restore()
        print("🛒 [Restore] completed isSubscribed=\(subscriptionService.isSubscribed)")
        if subscriptionService.isSubscribed { onDismiss() }
    }
}
```

**埋点联动**（只打客户端 UI 事件，订阅事件 BCStoreKit 自动）：

| UI 事件 | 调用 |
|---------|------|
| `.onAppear` | `AnalyticsService.paywallViewed(source:)` |
| 方案点击 | `AnalyticsService.paywallPlanSelected(plan:)` |
| 关闭按钮 | `AnalyticsService.paywallDismissed()` |
| 购买 CTA | **不调 AdjustService** — BCStoreKit 内部自动上报 vip/weekly/monthly/yearly/subscribe |

### Step 2.3: AdjustService.swift（补全订阅事件段）

如 ae-analytics-integrate 生成的 AdjustService.swift 没有订阅事件段，补上以下模板（Event Tokens 由杭州团队通过龙哥飞书提供）：

```swift
enum AdjustService {
    private enum Token {
        // 客户端事件
        static let weekly    = "<AJ_weekly_token>"
        static let monthly   = "<AJ_monthly_token>"
        static let yearly    = "<AJ_yearly_token>"
        static let vip       = "<AJ_vip_token>"
        static let discount  = "<AJ_discount_token>"
        static let share     = "<AJ_share_token>"
        // 服务端事件（客户端预埋）
        static let subscribe = "<AJ_subscribe_token>"
        static let purchase  = "<AJ_purchase_token>"
        static let cancel    = "<AJ_cancel_token>"
        static let refund    = "<AJ_refund_token>"
    }

    // ⚠️ 以下订阅相关事件 BCStoreKit 内部已自动调用，业务代码禁止重复调用
    // static func trackWeekly()   { BCAdjust.sendEvent(Token.weekly) }
    // static func trackMonthly()  { BCAdjust.sendEvent(Token.monthly) }
    // static func trackYearly()   { BCAdjust.sendEvent(Token.yearly) }
    // static func trackVip()      { BCAdjust.sendEvent(Token.vip) }
    // static func trackSubscribe(){ BCAdjust.sendEvent(Token.subscribe) }
    // static func trackPurchase(revenue: Double, currency: String = "USD")
    //     { BCAdjust.sendEvent(Token.purchase, revenue: revenue, currency: currency) }

    // 以下是业务代码主动调用的事件
    static func trackShare()    { BCAdjust.sendEvent(Token.share) }
    static func trackDiscount() { BCAdjust.sendEvent(Token.discount) }
}
```

---

## Phase 3: 入口注入

**目标：** 把 PaywallView 接入到业务流触发点。

### Step 3.1: Onboarding 末尾展示（转化漏斗关键节点）

在 Onboarding 最后一步 dismiss 之前，检查 `SubscriptionService.shared.hasShownLaunchPaywall`，若为 false → push PaywallView，设置 flag 避免重复。

### Step 3.2: 应用内触发点（功能锁）

Premium 功能入口（如"无限聊天"、"高级翻译"）判断 `@ObservedObject var sub = SubscriptionService.shared`，`!sub.isSubscribed` 时展示 `PaywallView(onDismiss: ...)`。

### Step 3.3: 编译验证

```bash
xcodebuild build \
  -workspace <ProjectName>.xcworkspace \
  -scheme <SchemeName> \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15
```

**必须 BUILD SUCCEEDED 才能继续。**

---

## Phase 4: 沙盒验证

**目标：** 真机 + Sandbox 账号走完整购买/恢复/取消三流程，确认日志输出。

### Step 4.1: 真机登录 Sandbox 账号

设置 → App Store → Sandbox Account → 登录杭州提供的测试账号。**地区必须覆盖 Product 定价地区（通常 US）。**

### Step 4.2: Run on Device（Xcode）

```bash
xcodebuild build \
  -workspace <ProjectName>.xcworkspace \
  -scheme <SchemeName> \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates
```

在真机上打开 App，Xcode Console 过滤 `[Subscription]`。

### Step 4.3: 购买流程验证

| 步骤 | 预期日志 | 预期 UI |
|------|---------|--------|
| 触发 Paywall | `paywall_view` 埋点 | 三方案正常展示 |
| 选择方案 | `paywall_plan_select` 埋点 | 卡片高亮切换 |
| 点击购买 | `🛒 purchase requested productId=...` | 系统 Sandbox 购买弹窗 |
| 确认购买 | `🛒 purchase result=success isSubscribed=true` | Paywall 自动关闭 |
| 跳转 Premium 功能 | — | 解锁成功 |

### Step 4.4: 恢复购买验证

| 步骤 | 预期日志 |
|------|---------|
| 卸载重装 App | — |
| 打开 Paywall 点 Restore | `🛒 [Restore] requested` |
| 恢复成功 | `🛒 [Restore] completed isSubscribed=true` |

### Step 4.5: 失败场景验证

| 场景 | 操作 | 预期 |
|------|------|------|
| 取消购买 | 系统弹窗点 Cancel | `result=cancelled`，Paywall 停留、无 alert |
| 未登录 Sandbox | 登出 Sandbox 账号点购买 | `result=appstorefailed`，弹 alert |
| 断网 | 飞行模式点购买 | `result=networkError`，弹 alert |

### Step 4.6: Adjust Dashboard 验证（Sandbox 视图）

**需显式切 Sandbox 视图**（Production 视图看不到测试数据）。

| 事件 | 触发条件 | Dashboard 出现 |
|------|---------|---------------|
| AJ_weekly/monthly/yearly | 购买对应方案 | Sandbox Events，可能延迟 5-30 分钟 |
| AJ_vip | 任何订阅成功 | 同上 |
| AJ_subscribe | 订阅（含试用）成功 | 同上 |

**BCStoreKit 自动上报的，不用业务代码手动调。**

---

## Phase 5: 输出

```
═══════════════════════════════════════════
  Paywall 集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}
Bundle ID：{bundle_id}

代码产出：
  - SubscriptionService.swift ({行数} 行)
  - PaywallView.swift ({行数} 行)
  - AdjustService.swift 补全 ({新增订阅 Event Token 注释段})

方案配置：
  - weekly：{product_id} - ${price}/week
  - monthly：{product_id} - ${price}/month
  - annual：{product_id} - ${price}/year ⭐ BEST VALUE

沙盒验证：
  - [x] 购买流程（三方案）
  - [x] 恢复购买
  - [x] 取消购买
  - [x] 未登录/断网失败场景
  - [x] Adjust Sandbox 事件可见

待确认（上线前）：
  - [ ] ASC IAP 产品状态 = Ready for Review
  - [ ] Adjust 环境切 Production
  - [ ] App Store 截图含 Paywall 页面
  - [ ] App Review Notes 提供 Sandbox 测试账号
═══════════════════════════════════════════
```

---

## 硬性规则

1. **ASC IAP 不自行创建** — 订阅组 + Product IDs + Sandbox 账号全部由杭州团队创建，Agent 不使用 ASC API 自行配置。
2. **所有 SKU 在 `SkuType` 枚举统一注册** — `public enum SkuType: String, CaseIterable {}`，raw value = ASC product identifier。**禁止在业务代码硬编码 product identifier 字符串**。（杭州审计 P0-1）
3. **转化页继承 `PurchaseUIBaseViewController`** — 类名必须 `PurchaseUI{memo}ViewController`；基类已用 `SkuType.allCases` 自动预拉 Products，**子类不重复实现 product 加载**。（P0-2/23）
4. **VIP 状态延迟等待阈值 = 3s** — `BCAccount.isVip` 服务端验证典型 1-2s，阈值设 3s，超时后调 `get_vip_info` 重拉，不阻塞主流程。（P0-3）
5. **BCStoreKit 订阅事件禁止手动调** — `BCStoreKit` 内部 `ServiceManager.swift` 已自动 `BCAdjust.sendEvent`（vip/weekly/monthly/yearly/subscribe）+ `sendSubscription`，业务代码重复调会双倍计数。
6. **`BCStoreKit.restore` 必须 `withCheckedContinuation`** — 原 callback API，直接包 `async func` 会立即返回，`await` 无效。
7. **`PaymentResult` 五分支必须全处理** — `.success/.cancelled/.appstorefailed/.networkError/.serverError`，`.cancelled` 静默，其他三失败必须弹用户态 alert。
8. **`VIP` 状态走 `BCAccount.isVip`，不用 `Transaction.currentEntitlements`** — BCAccount 是服务端判定，和 StoreKit 可能短暂不同步，监听 `.accountUserChanged` 通知刷新。
9. **Apple 合规三要素不可省** — 右上角 ✕ 关闭按钮 + Privacy/Terms/Apple Subscription Terms 三链接 + Restore 按钮。缺任一 ASC 审核 Guideline 4.0 / 3.1.2 拒。

---

## 反模式

❌ **直接 `async func restore() async { BCStoreKit.restore { ... } }`**
→ callback 还没触发函数就 return 了，`await` 立即完成。必须用 `withCheckedContinuation` 等待回调。WePray Bug R / Wave 4 踩过。

❌ **在 PaywallView 里手动 `AdjustService.trackWeekly()` / `trackVip()` / `trackSubscribe()`**
→ BCStoreKit 内部已自动上报，重复会导致投放数据翻倍、归因错乱。只调用客户端 UI 事件（`paywallViewed/PlanSelected/Dismissed`）。

❌ **用 `Transaction.currentEntitlements` 或 StoreKit 2 原生 API 判定 VIP**
→ Scale Global 生态 VIP 状态统一走服务端（`BCAccount.isVip`），使用原生 API 会和服务端失同步。

❌ **`PricingPlan.originalPrice` 返回 `$X.XX` 做 strikethrough**
→ Apple Guideline 3.1.1(a)"误导性折扣展示"拒审。保持 `return nil`，或用 "Save X% vs monthly" 文案对比真实月付方案。

❌ **购买按钮点击后不打日志直接调 BCStoreKit**
→ 卡死时 QA/开发无法定位是按钮未响应、product 未加载、还是 BCStoreKit 挂起。必须按 `🛒 [Subscription] purchase requested productId=...` 格式打日志。WePray Bug Q / QA #1 踩过。

❌ **Paywall 省略右上角 ✕ 关闭按钮**
→ Apple Guideline 4.0 Human Interface 必须允许用户关闭。Subscription Prompt 类 Paywall 强制可关闭。

❌ **跳过 Sandbox 真机只跑模拟器**
→ 模拟器 StoreKit Testing 用 `.storekit` 文件 mock，无法暴露 Sandbox 账号地区不匹配、agreements 未签等真实问题。上线前必须真机 Sandbox。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `BCStoreKit.product(of: pid) == nil` | (1) ASC 产品未 Ready to Submit (2) Bundle ID 不匹配 (3) 未登录 Sandbox 账号 (4) Tax/Banking/Agreements 未签 | 按顺序排查：ASC 后台状态 → Bundle ID → Settings → App Store → Sandbox Account → 杭州确认 agreements |
| `purchase result=appstorefailed` | 未登录 Sandbox / Sandbox 账号失活 / 账号地区不覆盖产品定价 | 重新登录 Sandbox；若账号已激活无效，找杭州重建 |
| `await subscriptionService.restore()` 立即返回 | 未用 `withCheckedContinuation` 包 callback | 用 Step 2.1 模板中的 `withCheckedContinuation` 写法 |
| `purchase result=success` 但 `isSubscribed=false` | `BCAccount.isVip` 服务端收据验证延迟（典型 1-2s，server 转 Apple 验证） | 等待阈值 **3s**，超时后调 `BCAccount.get_vip_info` 重拉 VIP 状态，不阻塞主流程；若 3s 后仍不同步，背景 retry 或让用户手动 Restore |
| Adjust Dashboard 无订阅事件 | 查了 Production 视图 / Sandbox 事件延迟 | 切 Sandbox 视图；等 5-30 分钟 |
| Adjust 订阅事件数翻倍 | 业务代码手动调了 AdjustService.trackVip/trackWeekly 等 | 删除业务代码的手动调用，只保留 AdjustService.trackShare/trackDiscount 等非订阅事件 |
| 购买卡住不 return（无 result 日志） | BCStoreKit 挂在 StoreKit 等待 | 检查 ASC 产品状态；检查真机是否卡在待家长同意；检查 Scheme 是否启用了 `.storekit` 配置文件（Sandbox 真机不需要） |

---

## 与其他 skill 的关系

```
/ae-preflight ───────────────→ 编译通过 + API Key 外部化
       │
       ▼
/ae-analytics-integrate ─────→ Firebase + Adjust + AdjustService/AnalyticsService 骨架
       │
       ▼
/ae-paywall-integrate ───────→ PaywallView + SubscriptionService + BCStoreKit 联调（本 skill）
       │
       ▼
/ae-app-review-check ────────→ Paywall 合规（关闭按钮 / 三链接 / 误导性折扣）自查
       │
       ▼
/ae-asc-submit ──────────────→ 提审（Review Notes 附 Sandbox 账号）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| paywall-001 | `BCStoreKit.restore` 是 callback API，直接 `async` 包会立即 return | WePray Bug R / Wave 4 |
| paywall-002 | BCStoreKit 内部自动上报 Adjust 订阅事件，业务代码重复调导致翻倍 | Pods/BCStoreKit/ServiceManager.swift 审计 |
| paywall-003 | VIP 状态走 `BCAccount.isVip` 服务端 flag，不是 StoreKit 2 原生 API | WePray 整个订阅链路 |
| paywall-004 | `BCAccount.isVip` 和 StoreKit 可能短暂不同步，需监听 `.accountUserChanged` | WePray SubscriptionService |
| paywall-005 | `PaymentResult` 五分支必须全处理，`.cancelled` 静默、三失败弹 alert | WePray Bug T / Wave 4 |
| paywall-006 | `BCStoreKit.product(of: pid) == nil` 通常是 ASC/Bundle ID/Sandbox 账号/agreements 四个原因之一 | WePray Bug Q / QA #1 |
| paywall-007 | Paywall 价格展示字号必须显眼（20pt heavy），融入卡片会影响转化 | WePray Bug K / QA #15 |
| paywall-008 | Apple Guideline 3.1.1(a) 禁止误导性折扣 strikethrough，年付对比用 "Save X% vs monthly" 真实计算 | WePray PaywallView originalPrice 设计 |
| paywall-009 | Paywall 右上角 ✕ 关闭 + Privacy/Terms/Apple EULA 三链接 + Restore 按钮，缺一审核拒 | Apple Guideline 4.0 / 3.1.2 |
| paywall-010 | Sandbox 真机购买，Adjust Dashboard 需显式切 Sandbox 视图，延迟 5-30 分钟 | 对齐 ae-analytics-integrate ios-pub-033 |

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 BCStoreKit + BCAccount 生态，此 skill 覆盖从代码生成到沙盒验证的全流程。非 Scale Global 项目（无内部库）不适用，需单独实现纯 StoreKit 2 方案。
