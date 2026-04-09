# ae-superwall-setup 测试场景

## 场景 1：首次集成 Superwall
- **用户说**："帮我在项目里集成 Superwall"
- **预期行为**：检查项目是否已有 SuperwallKit 依赖，引导添加 SPM 依赖、创建 Dashboard App、获取 API Key、配置代码
- **验证标准**：代码中有正确的 Superwall.configure 调用，API Key 非 placeholder

## 场景 2：已有 SPM 依赖但 API Key 未填
- **用户说**："Superwall 已经加了但 API Key 还没填"
- **预期行为**：跳过依赖添加，直接引导 Dashboard 配置
- **验证标准**：不重复添加依赖

## 场景 3：配置 Placement 触发点
- **用户说**："帮我设置 app_install 和 paywall 两个 placement"
- **预期行为**：引导 Dashboard 创建 placement，在代码中添加 register 调用
- **验证标准**：代码中有对应的 register 调用

## 场景 4：无 Apple Developer 账号
- **用户说**："帮我配 Superwall"（没有 Apple Developer 账号）
- **预期行为**：识别到前置条件缺失，提示需要先注册 Apple Developer Program
- **验证标准**：不跳过前置条件检查

## 场景 5：从 onboarding/paywall 衔接
- **用户说**："onboarding 和 paywall 都做好了，用 Superwall 管理"
- **预期行为**：引导上传 HTML 到 Dashboard，配置 campaign 触发规则
- **验证标准**：Dashboard 中有对应 campaign
