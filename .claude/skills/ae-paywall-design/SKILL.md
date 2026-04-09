---
description: "生成产品 Paywall 页面（HTML WebView 或 Native StoreKit 2）"
dependencies:
  mcp: []
  cli: []
  api_keys: []
  scripts: []
---

# Skill: Paywall 页面生成 (paywall-design)

## 触发条件

当 PM 需要为产品生成 Paywall 付费墙页面时触发。典型场景：
- 0.1 产品需要 paywall 页面展示订阅选项
- 需要测试不同定价方案的付费转化率
- Superwall 托管或 Native StoreKit 的 paywall 页面

## 核心原则

**Paywall 付费率是 0.1 产品的核心验证指标。** 页面必须：
1. **突出价值** — 先展示用户能获得什么，再展示价格
2. **降低决策门槛** — 默认高亮推荐方案（通常是年付），标注省多少
3. **信任感** — 明确标注免费试用期、随时取消、Apple 安全支付

## 输入

PM 需要提供：

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "CamScanner" |
| 核心功能列表 | 是 | 3-5 个 premium feature（paywall 上方展示） |
| 订阅方案 | 是 | 至少 2 个：如 周 $4.99 / 年 $29.99 |
| Apple Product ID | 否 | 如 `com.app.weekly`，无则用占位符 |
| 免费试用天数 | 否 | 如 "3-day free trial"，默认无 |
| 主色调 | 否 | 沿用 onboarding 配色，或指定 |
| 输出模式 | 否 | `html`（默认，WebView/Superwall）或 `native`（SwiftUI） |

如果 PM 没有提供以上信息，**主动询问**，至少获取产品名称、功能列表和订阅方案。

## 输出

### 模式 A：HTML WebView（默认，推荐 0.1 阶段）

在项目目录下生成 `paywall/` 目录：

```
paywall/
├── index.html          # Paywall 页面
├── styles.css          # 样式
└── script.js           # 方案选择 + 购买回调
```

### 模式 B：Native StoreKit 2

生成 SwiftUI 视图文件：

```
PaywallView.swift       # 完整的 paywall 视图 + StoreKit 2 购买逻辑
```

## 设计规范

### 页面结构（HTML 模式）

```
┌─────────────────────────┐
│         ✕ (close)       │  ← 右上角关闭按钮
│                         │
│    [Premium Features]   │  ← 功能列表（带 ✓ 图标）
│    ✓ Feature 1          │
│    ✓ Feature 2          │
│    ✓ Feature 3          │
│                         │
│  ┌─────────────────┐    │
│  │  BEST VALUE     │    │  ← 推荐标签
│  │  Yearly $29.99  │    │  ← 高亮方案
│  │  $2.49/month    │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │  Weekly $4.99   │    │  ← 普通方案
│  └─────────────────┘    │
│                         │
│  ┌───────────────────┐  │
│  │   Start Free Trial │  │  ← CTA（有试用期时）
│  └───────────────────┘  │
│                         │
│  Restore · Terms · Privacy │ ← 底部链接
└─────────────────────────┘
```

### 视觉要素

| 元素 | 规范 |
|------|------|
| 背景 | 深色渐变（与 onboarding 风格统一） |
| 功能列表 | 白色文字 + 主色 ✓ 图标，行间距 12px |
| 推荐方案 | 主色边框 + "BEST VALUE" 标签 + 内部高亮 |
| 普通方案 | 半透明白色边框，未选中状态 |
| 选中状态 | 方案卡片边框变主色，左侧出现实心圆 |
| CTA 按钮 | 全宽圆角，主色背景，白色文字 |
| 价格对比 | 年付方案显示折算月价 + "Save X%" 标签 |
| 底部链接 | 小字灰色，Restore / Terms / Privacy |
| 关闭按钮 | 右上角 ✕，半透明白色 |

### 交互行为

| 行为 | 实现 |
|------|------|
| 方案选择 | 点击切换选中状态（radio 行为） |
| CTA 点击 | 调用 `window.paywallPurchase(productId)` |
| 关闭 | 调用 `window.paywallDismiss()` |
| Restore | 调用 `window.paywallRestore()` |

### 回调接口

```javascript
// 购买 — iOS 端通过 WKScriptMessageHandler 捕获
window.paywallPurchase = function(productId) {
  if (window.webkit && window.webkit.messageHandlers.paywallPurchase) {
    window.webkit.messageHandlers.paywallPurchase.postMessage(productId);
  }
};

// 关闭
window.paywallDismiss = function() {
  if (window.webkit && window.webkit.messageHandlers.paywallDismiss) {
    window.webkit.messageHandlers.paywallDismiss.postMessage('dismiss');
  }
};

// 恢复购买
window.paywallRestore = function() {
  if (window.webkit && window.webkit.messageHandlers.paywallRestore) {
    window.webkit.messageHandlers.paywallRestore.postMessage('restore');
  }
};
```

## 执行流程

### Step 1: 收集产品信息

向 PM 确认所有输入项。如果 PM 只给了产品名称，追问：
- "Premium 用户能用哪些功能？列 3-5 个。"
- "订阅方案是什么？周付/月付/年付各多少钱？"
- "有没有免费试用期？"

### Step 2: 设计定价展示

根据 PM 提供的方案，计算展示数据：
- 年付折算月价（如 $29.99/年 = $2.49/月）
- 与周付/月付的对比节省百分比（如 "Save 58%"）
- 默认高亮年付方案（转化率最高）

### Step 3: 生成文件

**HTML 模式：** 生成 `paywall/` 目录。质量要求同 onboarding-design：
- CSS 变量驱动配色
- 响应式适配全系列 iPhone
- 安全区处理
- 无外部依赖
- GPU 加速动画

**Native 模式：** 生成 `PaywallView.swift`，包含：
- StoreKit 2 的 `Product.products(for:)` 加载
- `product.purchase()` 购买流程
- `Transaction.currentEntitlements` 恢复购买
- `@Environment(\.dismiss)` 关闭

### Step 4: 本地预览

**HTML 模式：**
```bash
open paywall/index.html
```
Chrome DevTools 设备模拟查看。

**Native 模式：**
需要在 Xcode 项目中引入文件，StoreKit Testing 配置 sandbox。

### Step 5: 迭代调整

常见调整：
- 价格修改 → 改 HTML 文案 + JS productId 映射
- 增减方案 → 增减方案卡片
- 功能列表调整 → 修改 feature list 区域
- A/B 测试 → 生成多个 HTML 变体，通过 Superwall 分流

### Step 6: 集成指引

**Superwall 托管（推荐）：**
1. 上传 `paywall/` 到 Superwall Dashboard → Paywalls → Create → Custom HTML
2. 绑定到 `paywall` placement
3. JS 回调由 Superwall SDK 自动桥接到 StoreKit

**iOS WKWebView 直接嵌入：**
1. 拷贝 `paywall/` 到 Xcode Resources
2. WKWebView 加载 + `WKScriptMessageHandler` 监听三个回调
3. `paywallPurchase` 触发 StoreKit 2 购买
4. `paywallDismiss` dismiss 视图
5. `paywallRestore` 调用 `Transaction.currentEntitlements`

提供 Swift 集成代码片段：

```swift
class PaywallViewController: UIViewController, WKScriptMessageHandler {
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        let uc = config.userContentController
        uc.add(self, name: "paywallPurchase")
        uc.add(self, name: "paywallDismiss")
        uc.add(self, name: "paywallRestore")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "paywall") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "paywallPurchase":
            guard let productId = message.body as? String else { return }
            Task { await purchaseProduct(productId) }
        case "paywallDismiss":
            dismiss(animated: true)
        case "paywallRestore":
            Task { await restorePurchases() }
        default: break
        }
    }

    private func purchaseProduct(_ id: String) async {
        guard let product = try? await Product.products(for: [id]).first else { return }
        _ = try? await product.purchase()
    }

    private func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            // Handle restored transactions
        }
    }
}
```

## 验证标准

1. paywall 页面在浏览器设备模拟或模拟器中正常渲染
2. 订阅方案正确展示价格和周期
3. 年付方案默认高亮，显示折算月价和节省百分比
4. 点击方案切换选中状态
5. CTA 点击触发 `paywallPurchase` 回调（含 productId）
6. 关闭按钮触发 `paywallDismiss` 回调
7. 底部 Restore 链接触发 `paywallRestore` 回调
8. 适配 iPhone SE ~ iPhone 16 Pro Max

## 复用说明

所有 0.1 产品都需要 paywall。paywall 付费率是核心验证指标，需要支持后续通过 Superwall A/B 测试迭代定价和展示方式。
