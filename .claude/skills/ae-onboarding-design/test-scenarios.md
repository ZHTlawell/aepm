# ae-onboarding-design 测试场景

## 场景 1：标准 onboarding 生成
- **用户说**："帮我生成 3 页 onboarding，产品叫 Bevel，是一个 AI 健身追踪器"
- **预期行为**：agent 确认核心 feature 列表，生成 onboarding/ 目录（index.html + styles.css + script.js）
- **验证标准**：HTML 可在浏览器中直接打开，3 页滑动正常，CTA 按钮可点击

## 场景 2：缺少必填输入
- **用户说**："帮我做个 onboarding"（未提供产品名和 feature）
- **预期行为**：主动追问产品名称、一句话简介、核心 feature 列表
- **验证标准**：至少获取三项必填信息后才开始生成

## 场景 3：自定义配色和风格
- **用户说**："做 onboarding，主色调用 #FF6B6B，风格像 Calm 那种极简的"
- **预期行为**：使用指定主色调和极简风格生成
- **验证标准**：CSS 中主色调为 #FF6B6B，整体风格简洁

## 场景 4：用于 Superwall WebView
- **用户说**："这个 onboarding 要放到 Superwall 里"
- **预期行为**：确保 HTML 兼容 WebView（无外部 CDN、字体内联、viewport 适配），添加 Superwall bridge 回调
- **验证标准**：HTML 中包含 Superwall 事件回调，无外部网络请求

## 场景 5：onboarding 后衔接 paywall
- **用户说**："onboarding 做好了，接着帮我做 paywall"
- **预期行为**：复用 onboarding 的配色和风格，引导进入 ae-paywall-design
- **验证标准**：paywall 的配色风格与 onboarding 一致
