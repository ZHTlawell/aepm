---
description: "iOS 埋点全流程 — Firebase Analytics + Adjust SDK 接入（杭州团队协作）"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(grep *)"
    - "Bash(find *)"
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

# Skill: iOS 埋点接入 (ae-analytics-integrate)

> **经 WePray (bible-app) 实战验证。** Firebase Analytics + Adjust SDK 双轨埋点全流程，含杭州团队协作步骤。

## 触发条件

PM 需要在 iOS App 中接入数据分析和归因追踪时触发。典型场景：
- Demo 即将上 TestFlight，需要追踪用户行为和转化漏斗
- preflight 报告中标记「无 Firebase / Adjust 接入」
- 投放前需要归因追踪

## 核心原则

1. **双轨埋点** — Firebase Analytics 管行为分析 + 漏斗，Adjust 管归因 + 付费转化。两者互补不替代
2. **杭州团队前置** — Firebase 项目创建 + GoogleService-Info.plist + Adjust App Token + Event Tokens 全部由杭州团队提供，Agent 不能自行创建
3. **封装层隔离** — 创建 `AnalyticsService` 统一封装，业务代码不直接调用 Firebase/Adjust API
4. **先接再上 TestFlight** — 无埋点的 TestFlight 版本 = 盲测（约束 ios-pub-027）

## 角色分工

| 事项 | 谁做 | 说明 |
|------|------|------|
| Firebase 项目创建 + GoogleService-Info.plist | **杭州团队（文龙）** | 在 scalingengine 账号下创建，plist 涉及安全通过飞书发送 |
| Adjust 后台配置（新账号 Connection） | **杭州团队（文龙/周文博）** | 新 Apple 账号需在 Adjust 后台做 Connection 操作 |
| Adjust App Token + Event Tokens 提供 | **杭州团队（周文博）** | 整理到飞书文档，PM/Agent 读取 |
| SPM 引入 SDK + 代码集成 | Agent | Firebase SDK + Adjust SDK + AnalyticsService 封装 |
| 埋点事件定义 | PM + Agent | 基于产品核心漏斗定义事件 |
| 验证事件数据 | PM | 在 Firebase Console + Adjust Dashboard 确认 |

## 前置条件

| 条件 | 说明 |
|------|------|
| ae-preflight 已通过 | 编译通过 + API Key 外部化 |
| ASC App 已创建 | 需要 Bundle ID 和 App ID |
| 杭州团队已收到配置请求 | 需提前沟通，配置通常需要半天 |

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | Xcode 项目根目录 |
| Bundle ID | 是 | 如 com.kjv.bible.prayer.app |
| ASC App ID | 是 | 如 6761982880 |
| 产品名称 | 是 | 如 "WePray" |

---

## Phase 1: 请求杭州团队配置

**此 Phase 是阻塞项，必须先发出请求再做其他工作。**

### Step 1.1: 发送配置请求

在 issue 上或飞书发送以下信息给杭州团队：

> **埋点接入配置请求**
>
> | 项目 | 值 |
> |------|-----|
> | App 名称 | {产品名称} |
> | Bundle ID | {bundle_id} |
> | ASC App ID | {app_id} |
> | Apple Developer 账号 | {账号名} ({team_id}) |
>
> **需要提供：**
>
> **1. Firebase Analytics（必需）**
> - [ ] 在 Firebase Console 创建项目，添加 iOS App（Bundle ID: `{bundle_id}`）
> - [ ] 导出 `GoogleService-Info.plist` 发给我（飞书文件）
>
> **2. Adjust SDK（必需）**
> - [ ] 新账号需在 Adjust 后台做 Apple 账号 Connection（**只有文龙/周文博可操作**）
> - [ ] 提供 Adjust App Token
> - [ ] 提供所有 Event Tokens（整理到飞书文档）
>
> **标准 Event Tokens 需求清单：**
>
> | 事件名 | 类型 | 用途 |
> |--------|------|------|
> | AJ_weekly | 客户端 | 选择周订阅 |
> | AJ_monthly | 客户端 | 选择月订阅 |
> | AJ_yearly | 客户端 | 选择年订阅 |
> | AJ_subscribe | 服务端 | 开始订阅/试用 |
> | AJ_vip | 客户端 | 成为 VIP |
> | AJ_share | 客户端 | 分享 App |
> | AJ_discount | 客户端 | 打折包购买 |
> | AJ_purchase | 服务端 | 实际付费（含金额） |
> | AJ_cancel | 服务端 | 试用取消 |
> | AJ_refund | 服务端 | 退款 |

### Step 1.2: 等待期间可做的准备

在等待杭州团队配置期间，可以先完成：
- Phase 2 Step 2.1-2.2（SPM 引入 SDK）
- Phase 3 Step 3.1（AnalyticsService 封装骨架）
- Phase 4（埋点事件定义）

---

## Phase 2: SDK 引入

### Step 2.1: Firebase SDK via SPM

**XcodeGen 项目** — 在 `project.yml` 中添加：

```yaml
packages:
  firebase-ios-sdk:
    url: https://github.com/firebase/firebase-ios-sdk
    from: "11.0.0"

targets:
  <TargetName>:
    dependencies:
      - package: firebase-ios-sdk
        product: FirebaseAnalytics
```

**标准 Xcode 项目：**
> Xcode → File → Add Package Dependencies → `https://github.com/firebase/firebase-ios-sdk` → 只选 FirebaseAnalytics

### Step 2.2: Adjust SDK via SPM

**XcodeGen 项目** — 在 `project.yml` 中添加：

```yaml
packages:
  ios_sdk:
    url: https://github.com/adjust/ios_sdk
    from: "5.0.0"

targets:
  <TargetName>:
    dependencies:
      - package: ios_sdk
        product: AdjustSdk
```

**标准 Xcode 项目：**
> Xcode → File → Add Package Dependencies → `https://github.com/adjust/ios_sdk` → 选 AdjustSdk

### Step 2.3: 重新生成项目 + 验证编译

```bash
# XcodeGen 项目
xcodegen generate

# 验证编译（SPM 首次 resolve 可能需要几分钟）
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS Simulator" 2>&1 | tail -10
```

**必须 BUILD SUCCEEDED 才能继续。** SPM resolve 失败通常是网络问题，重试即可。

---

## Phase 3: 代码集成

### Step 3.1: Firebase 初始化

将杭州团队提供的 `GoogleService-Info.plist` 放入项目根目录（与 Info.plist 同级），并加入 Xcode target。

**⚠️ 安全注意：** GoogleService-Info.plist 包含 API Key，应加入 `.gitignore`。同时创建 `GoogleService-Info.plist.example` 模板提交 git。

```swift
// App 入口
import FirebaseCore

@main
struct MyApp: App {
    init() {
        FirebaseApp.configure()  // 自动读取 GoogleService-Info.plist
    }
}
```

### Step 3.2: Adjust 初始化

```swift
import AdjustSdk

// App 入口，在 FirebaseApp.configure() 之后
func initializeAdjust() {
    let appToken = "<Adjust App Token>"  // 从 Secrets.plist 读取
    let environment = ADJEnvironmentSandbox  // 上线前改 ADJEnvironmentProduction
    
    let config = ADJConfig(appToken: appToken, environment: environment)
    Adjust.initSdk(config)
}
```

**Adjust App Token 存入 Secrets.plist**（与 API Key 管理方式一致）：

```xml
<key>AdjustAppToken</key>
<string>j4xrwchd88w0</string>
<key>AdjustEnvironment</key>
<string>sandbox</string>
```

### Step 3.3: 创建 AnalyticsService 封装层

创建统一的埋点服务，业务代码只调用这一层：

```swift
import FirebaseAnalytics
import AdjustSdk

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}
    
    // MARK: - Onboarding 漏斗
    
    func logOnboardingPageView(pageIndex: Int, pageName: String) {
        Analytics.logEvent("onboarding_page_view", parameters: [
            "page_index": pageIndex,
            "page_name": pageName
        ])
    }
    
    func logOnboardingComplete() {
        Analytics.logEvent("onboarding_complete", parameters: nil)
    }
    
    // MARK: - Paywall 转化
    
    func logPaywallView(source: String) {
        Analytics.logEvent("paywall_view", parameters: ["source": source])
    }
    
    func logPaywallPlanSelect(plan: String) {
        Analytics.logEvent("paywall_plan_select", parameters: ["plan": plan])
    }
    
    func logPaywallStartTrial() {
        Analytics.logEvent("paywall_start_trial", parameters: nil)
    }
    
    func logPaywallDismiss() {
        Analytics.logEvent("paywall_dismiss", parameters: nil)
    }
    
    // MARK: - 核心功能行为（按产品定制）
    
    func logTabSelect(tab: String) {
        Analytics.logEvent("tab_select", parameters: ["tab": tab])
    }
    
    func logPurchaseSuccess(productId: String) {
        Analytics.logEvent("purchase_success", parameters: ["product_id": productId])
    }
}
```

### Step 3.4: 创建 AdjustService 封装层

```swift
import AdjustSdk

final class AdjustService {
    static let shared = AdjustService()
    private init() {}
    
    // Event Token 映射（从杭州团队飞书文档读取）
    private let eventTokens: [String: String] = [
        "weekly": "<AJ_weekly_token>",
        "monthly": "<AJ_monthly_token>",
        "yearly": "<AJ_yearly_token>",
        "subscribe": "<AJ_subscribe_token>",
        "vip": "<AJ_vip_token>",
        "share": "<AJ_share_token>",
        "discount": "<AJ_discount_token>",
        "purchase": "<AJ_purchase_token>",
    ]
    
    func trackSubscriptionSelect(plan: String) {
        guard let token = eventTokens[plan] else { return }
        let event = ADJEvent(eventToken: token)
        Adjust.trackEvent(event)
    }
    
    func trackVIP() {
        guard let token = eventTokens["vip"] else { return }
        let event = ADJEvent(eventToken: token)
        Adjust.trackEvent(event)
    }
    
    func trackShare() {
        guard let token = eventTokens["share"] else { return }
        let event = ADJEvent(eventToken: token)
        Adjust.trackEvent(event)
    }
    
    func trackSubscription(product: Any) {
        guard let token = eventTokens["subscribe"] else { return }
        let event = ADJEvent(eventToken: token)
        Adjust.trackEvent(event)
    }
}
```

### Step 3.5: 注入埋点到业务代码

在项目的关键位置调用 AnalyticsService + AdjustService：

| 位置 | Firebase 事件 | Adjust 事件 |
|------|--------------|-------------|
| Onboarding 每页 | `onboarding_page_view(index, name)` | — |
| Onboarding 完成 | `onboarding_complete` | — |
| Paywall 展示 | `paywall_view(source)` | — |
| 选择方案 | `paywall_plan_select(plan)` | `trackSubscriptionSelect(plan)` |
| 点击开始试用 | `paywall_start_trial` | `trackSubscription()` + `trackVIP()` |
| 关闭 Paywall | `paywall_dismiss` | — |
| Tab 切换 | `tab_select(tab)` | — |
| 分享 | — | `trackShare()` |
| **产品特定事件** | **按产品核心功能定制** | — |

**WePray 示例的产品特定事件：**
- `chat_message_send` — 聊天活跃度
- `chat_topic_select` — 话题偏好
- `chat_free_limit_hit` — 免费额度触顶
- `bible_book_open` — 书卷打开
- `bible_chapter_read` — 章节阅读

---

## Phase 4: 埋点事件定义

### Step 4.1: 核心漏斗事件（通用，所有产品必须有）

```
安装 → Onboarding 漏斗（逐页追踪）→ Paywall 转化 → 付费/跳过 → 核心功能使用 → 留存
```

| 漏斗节点 | Firebase 事件 | 说明 |
|---------|--------------|------|
| 安装 | `first_open`（自动） | Firebase 内置 |
| Onboarding 第 N 页 | `onboarding_page_view` | params: page_index, page_name |
| Onboarding 完成 | `onboarding_complete` | 完成率 = complete / first_open |
| Paywall 展示 | `paywall_view` | params: source (onboarding / in_app) |
| 选择方案 | `paywall_plan_select` | params: plan (weekly / monthly / annual) |
| 开始试用 | `paywall_start_trial` | 转化核心指标 |
| 关闭 Paywall | `paywall_dismiss` | 流失节点 |
| Tab 切换 | `tab_select` | 功能使用分布 |
| 购买成功 | `purchase_success` | 真实付费（待 Superwall 接入后触发） |

### Step 4.2: 产品特定事件

根据产品核心功能定义额外事件。向 PM 确认：

> **你的产品核心功能是什么？需要追踪哪些行为？**
> 例如：
> - 如果是 AI Chat 类 → chat_send, chat_topic, free_limit_hit
> - 如果是工具类 → feature_X_use, export_complete
> - 如果是内容类 → content_view, bookmark, share

---

## Phase 5: 验证

### Step 5.1: 编译验证

```bash
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS" -allowProvisioningUpdates 2>&1 | tail -10
```

### Step 5.2: 运行时验证

在模拟器或真机运行 App：

1. **Firebase** — Xcode Console 搜索 `[Firebase/Analytics]`，应看到初始化成功日志
2. **Adjust** — Xcode Console 搜索 `[Adjust]`，应看到 SDK 初始化和 session 上报

### Step 5.3: 后台数据验证

| 平台 | 验证方式 | 预期 |
|------|---------|------|
| Firebase Console | DebugView（需启用 `-FIRDebugEnabled` launch argument） | 实时看到事件 |
| Adjust Dashboard | Events → 对应 Token | 看到测试事件（Sandbox 环境有延迟） |

**Firebase DebugView 启动参数：**
> Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Add `-FIRDebugEnabled`

### Step 5.4: Archive + Upload TestFlight

埋点验证通过后：

```bash
# bump build number
# XcodeGen: 修改 project.yml 中的 CURRENT_PROJECT_VERSION

xcodegen generate

xcodebuild archive \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -archivePath /tmp/<ProductName>.xcarchive \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=<TeamID>

xcodebuild -exportArchive \
  -archivePath /tmp/<ProductName>.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -exportPath /tmp/<ProductName>Export \
  -allowProvisioningUpdates
```

---

## Phase 6: 输出

```
═══════════════════════════════════════════
  埋点接入完成 ✅
═══════════════════════════════════════════

Firebase Analytics:
  项目: {firebase_project_id}
  SDK: v{version}
  事件数: {N} 个

Adjust SDK:
  App Token: {token}
  SDK: v{version}
  环境: Sandbox（⚠️ 上线前改 Production）
  客户端事件: {N} 个已接入
  服务端事件: {N} 个待杭州配置

埋点事件对照表:
  | 事件 | Firebase | Adjust | 状态 |
  |------|----------|--------|------|
  | ... | ... | ... | ✅/🔲 |

杭州团队待确认:
  - [ ] Firebase Console 可见事件数据
  - [ ] Adjust Dashboard 可见测试事件
  - [ ] 服务端事件（AJ_purchase/cancel/refund）已配置
  - [ ] 上线前 Adjust 环境切 Production

TestFlight Build:
  版本: {version} (Build {build_number})
  上传时间: {timestamp}
═══════════════════════════════════════════
```

---

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-026 | 新 Apple 账号接入 Adjust 需杭州团队前置 Connection 操作 | WePray 换账号后 Adjust 无法关联 |
| ios-pub-027 | 无埋点的 TestFlight 版本 = 盲测 | WePray Build 1 无数据 |
| ios-pub-028 | GoogleService-Info.plist 中 `IS_ANALYTICS_ENABLED` 必须为 `true`，否则 SDK 静默不上报 | WePray Build 5 数据为 0，改 plist 后 Build 6 正常 |
| ios-pub-033 | Adjust Sandbox 环境验证数据时，API 必须显式传 `sandbox=true`，Dashboard 也需切 Sandbox 视图 | WePray Adjust 数据「看不到」实际是查了 Production 视图 |
| analytics-001 | GoogleService-Info.plist 含 API Key，必须加 .gitignore | 安全合规 |
| analytics-002 | Adjust 环境上线前必须从 Sandbox 切 Production | 否则事件不计入正式报表 |
| analytics-003 | Firebase DebugView 需启动参数 -FIRDebugEnabled | 否则实时调试看不到事件 |
| analytics-004 | 业务代码不直接调 Firebase/Adjust API，通过 AnalyticsService 封装 | 后续换 SDK 只改一处 |

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `GoogleService-Info.plist not found` | plist 未加入 Xcode target | 确认 Target Membership 已勾选 |
| Firebase 初始化 crash | plist 中的 Bundle ID 与项目不匹配 | 让杭州团队重新生成 plist |
| Adjust 无数据 | App Token 错误或 Connection 未做 | 确认 Token + 联系杭州团队 |
| SPM resolve 失败 | 网络问题（firebase-ios-sdk 仓库较大） | 重试，或配置代理 |
| 事件在 Firebase Console 不显示 | DebugView 未开启 + 普通视图有 24h 延迟 | 启用 `-FIRDebugEnabled` |
| Adjust 事件延迟 | Sandbox 环境正常延迟 | 等 30 分钟后检查 |

## 与其他 skill 的关系

```
/ae-preflight ─────────→ 编译通过 + 预检埋点缺失
        │
        ▼
/ae-analytics-integrate ───→ Firebase + Adjust 埋点接入 ✅
        │
        └── /ae-app-to-testflight → 带埋点的 TestFlight 版本
```

## 复用说明

所有需要投放的 iOS 产品都需要 Firebase + Adjust 双轨埋点。核心漏斗事件（Onboarding → Paywall → 购买）通用，产品特定事件按产品定制。**杭州团队配置通常需要半天响应时间，建议提前发出请求。**
