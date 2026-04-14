# ae-paywall-design 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-paywall-design

## Test Stories

### Story 1: 完整信息生成 HTML Paywall
- **Prompt**: "帮我生成 CamScanner Pro 的 paywall 页面。Premium 功能：1. 无限扫描；2. OCR 文字识别；3. 云端同步；4. 去水印。订阅方案：周付 $4.99，年付 $29.99。有 3 天免费试用。"
- **Expect**: 生成 `paywall/` 目录包含 index.html、styles.css、script.js。页面包含 4 个 feature 列表项（带勾选图标），2 个订阅方案卡片（年付默认高亮，标注 "BEST VALUE" 和折算月价 $2.49/月），显示 "Save 50%" 标签，CTA 按钮文案为 "Start Free Trial"，底部有 Restore / Terms / Privacy 链接，右上角有关闭按钮。
- **Max Time**: 90s

### Story 2: 仅提供产品名称的追问流程
- **Prompt**: "帮我做个 paywall，产品是 PhotoEditor"
- **Expect**: Skill 识别缺少必填信息，依次追问：Premium 功能列表（3-5 个）、订阅方案和价格、是否有免费试用期。不应在信息不完整时直接生成。
- **Max Time**: 30s

### Story 3: 三方案定价与 Native SwiftUI 输出
- **Prompt**: "生成 FitLog 的 paywall，native 模式。功能：AI 饮食分析、训练计划、进度报告。方案：周付 $2.99，月付 $7.99，年付 $39.99。Product ID 分别是 com.fitlog.weekly、com.fitlog.monthly、com.fitlog.yearly"
- **Expect**: 生成 `PaywallView.swift` 文件而非 HTML 目录。包含 StoreKit 2 的 `Product.products(for:)` 加载逻辑、`product.purchase()` 购买流程、`Transaction.currentEntitlements` 恢复购买。3 个方案都展示，年付高亮并显示 "Save X%"。Product ID 使用用户提供的真实值。
- **Max Time**: 90s

### Story 4: 定价计算与展示准确性验证
- **Prompt**: "paywall 方案：周付 $6.99，年付 $49.99，帮我算一下年付省多少并展示"
- **Expect**: Skill 准确计算：年付折算月价 = $49.99/12 = $4.17/月，周付折算月价 = $6.99 x 4.33 = $30.27/月，节省百分比 = (30.27 - 4.17) / 30.27 = 86%（或按年对比：周付年化 $363.48 vs 年付 $49.99，Save 86%）。数字展示应准确无误，标签放在推荐方案卡片上。
- **Max Time**: 60s

### Story 5: JS 回调接口与 Superwall 集成
- **Prompt**: "paywall 做好了，我要接入 Superwall，帮我确认 JS 回调是否完整，并给集成指引"
- **Expect**: Skill 验证生成的 script.js 包含三个回调函数：`paywallPurchase(productId)`、`paywallDismiss()`、`paywallRestore()`，每个回调通过 `window.webkit.messageHandlers` 与 iOS 端通信。提供 Superwall 集成步骤（上传 Dashboard、创建 Custom HTML、绑定 placement）和 iOS WKWebView 集成的 Swift 代码片段（PaywallViewController + 三个 messageHandler）。
- **Max Time**: 60s

You've hit your limit · resets 2am (Asia/Shanghai)

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
