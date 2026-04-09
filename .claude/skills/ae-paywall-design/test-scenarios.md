# ae-paywall-design 测试场景

## 场景 1：标准 HTML paywall 生成
- **用户说**："帮我生成 paywall 页面，周付 $4.99，年付 $29.99"
- **预期行为**：确认产品名称和核心功能列表，生成 paywall/ 目录，年付方案高亮 BEST VALUE
- **验证标准**：HTML 可在浏览器打开，两个方案可切换选择，年付默认高亮

## 场景 2：Native StoreKit 2 模式
- **用户说**："我要 Native 的 paywall，不要 HTML"
- **预期行为**：生成 PaywallView.swift，包含 StoreKit 2 购买逻辑和完整 UI
- **验证标准**：Swift 代码可编译，包含 Product.purchase() 调用

## 场景 3：缺少订阅方案
- **用户说**："帮我做个 paywall"（未提供价格方案）
- **预期行为**：主动追问产品名称、核心功能列表、订阅方案（至少 2 个含价格）
- **验证标准**：至少获取必填信息后才开始生成

## 场景 4：含免费试用
- **用户说**："paywall 要有 3 天免费试用，CTA 写 Start Free Trial"
- **预期行为**：突出免费试用信息，CTA 文案改为指定文案，底部标注 Cancel anytime
- **验证标准**：页面有试用文案，CTA 正确，有取消说明

## 场景 5：Superwall 集成
- **用户说**："这个 paywall 要放到 Superwall 上"
- **预期行为**：确保 HTML 兼容 Superwall WebView，添加购买事件回调
- **验证标准**：HTML 中包含 Superwall 购买桥接代码
