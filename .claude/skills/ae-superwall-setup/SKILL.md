---
description: "Superwall 账号配置、App 创建、SDK 集成引导"
---

# Skill: Superwall 项目集成 (superwall-setup)

## 触发条件

当 PM 需要在 iOS 项目中集成 Superwall SDK 时触发。典型场景：
- 0.1 产品采用"夹心"架构（Native + Superwall WebView + Native）
- 需要配置 Superwall Dashboard 的 App、API Key、Placement
- 项目已添加 SuperwallKit SPM 依赖但 API Key 还是 placeholder

## 核心原则

**Superwall 是 onboarding + paywall 的远程配置层，支持 A/B 测试和热更新。** 正确集成后：
- Onboarding / Paywall 页面可在 Dashboard 远程修改，无需发版
- 可配置 A/B 测试，对比不同页面的转化率
- 事件触发（placement）与页面内容解耦

## 前置条件

- iOS 项目已创建（Xcode）
- 已有 Apple Developer 账号
- SuperwallKit SPM 依赖已添加（或准备添加）

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | Xcode 项目根目录 |
| 产品名称 | 是 | 用于在 Superwall Dashboard 创建 App |
| Placement 列表 | 否 | 默认 `app_install`（onboarding）+ `paywall` |
| Apple App ID | 否 | 用于关联 StoreKit 产品 |

## 执行流程

### Step 1: 检查项目状态

读取项目代码，确认：

1. **SPM 依赖** — 检查 `Package.resolved` 或 `.xcodeproj` 中是否已有 `SuperwallKit`
2. **现有配置** — 搜索代码中的 `Superwall.configure`，检查是否已有 API Key
3. **App 入口** — 找到 `@main` App struct 或 `AppDelegate`，确认 SDK 初始化位置

```bash
# 检查 SuperwallKit 依赖
grep -r "SuperwallKit" <project_path>/Package.resolved 2>/dev/null
grep -r "Superwall" <project_path>/*.xcodeproj/project.pbxproj 2>/dev/null

# 检查现有配置
grep -rn "Superwall.configure\|superwallApiKey\|SUPERWALL" <project_path>/
```

如果未添加 SPM 依赖，引导 PM：
> 在 Xcode 中：File → Add Package Dependencies → 输入 `https://github.com/superwall/Superwall-iOS` → Add Package

### Step 2: Superwall Dashboard 配置引导

引导 PM 在 Superwall Dashboard 完成配置（Agent 无法直接操作 Dashboard UI，需要 PM 配合）：

**2a. 创建账号（如未有）**
1. 访问 [superwall.com](https://superwall.com)，点击 Sign Up
2. 使用 Apple Developer 关联的邮箱注册
3. 选择 Free 计划（0.1 验证阶段足够）

**2b. 创建 App**
1. Dashboard → Apps → Create App
2. 填写产品名称
3. 选择 Platform: iOS
4. 获得 **API Key**（格式：`pk_xxxxxxxx`）

**2c. 注册 Placement**
1. Dashboard → Placements → Create
2. 创建以下 placement：

| Placement 名称 | 触发时机 | 关联页面 |
|----------------|---------|---------|
| `app_install` | 首次安装打开 | Onboarding 页面 |
| `paywall` | 触发付费墙时 | Paywall 页面 |

**2d. 上传页面（可选，如已用 /ae-onboarding-design 和 /ae-paywall-design 生成）**
1. Dashboard → Paywalls → Create → Custom HTML
2. 上传 `onboarding/` 目录内容 → 绑定到 `app_install`
3. 上传 `paywall/` 目录内容 → 绑定到 `paywall`

每完成一步，让 PM 确认并提供 API Key。

### Step 3: 项目代码集成

拿到 API Key 后，修改项目代码：

**3a. SDK 初始化**

在 App 入口处添加 Superwall 配置：

```swift
// App.swift 或 AppDelegate.swift
import SuperwallKit

@main
struct MyApp: App {
    init() {
        Superwall.configure(apiKey: "pk_xxxxxxxx")  // 替换为真实 Key
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**3b. Placement 触发**

在合适位置触发 placement：

```swift
// Onboarding — 首次安装时
func showOnboardingIfNeeded() {
    let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    if isFirstLaunch {
        Superwall.shared.register(placement: "app_install")
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}

// Paywall — 用户触发付费功能时
func showPaywall() {
    Superwall.shared.register(placement: "paywall")
}
```

**3c. 购买处理（如用 Superwall 管理支付）**

```swift
// Superwall 默认自动处理 StoreKit 购买
// 如需自定义，实现 SuperwallDelegate:
Superwall.shared.delegate = self

extension AppFlowManager: SuperwallDelegate {
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case .transactionComplete(_, _, _, _):
            // 购买成功
            break
        case .paywallClose:
            // 用户关闭 paywall
            break
        default:
            break
        }
    }
}
```

### Step 4: 验证集成

**4a. 日志检查**

运行 App，在 Xcode Console 中确认：
```
[Superwall] Configured with API key: pk_xxxx...
[Superwall] Device registered
```

**4b. Placement 触发测试**

触发每个 placement，确认 Dashboard 中出现对应事件：
- Dashboard → Analytics → Events 中应看到 `app_install` / `paywall` 事件

**4c. 页面展示测试**

如果已上传页面到 Dashboard：
- 触发 `app_install` → 应显示 onboarding 页面
- 触发 `paywall` → 应显示 paywall 页面

### Step 5: 配置清单输出

完成后向 PM 输出配置清单：

```
Superwall 集成完成：

✅ SDK 初始化 — API Key 已配置
✅ Placement 注册:
   - app_install → Onboarding
   - paywall → Paywall
✅ 日志验证 — SDK 初始化成功

Dashboard 信息：
- App: {产品名称}
- API Key: pk_xxxx...（已写入代码）
- URL: https://superwall.com/dashboard/apps/{app_id}

后续操作：
- 上传 onboarding/paywall HTML 到 Dashboard
- 配置 StoreKit Product IDs
- 设置 A/B 测试（如需）
```

## 注意事项

### API Key 安全

- API Key（`pk_` 开头）是**公开 Key**，可以安全地写入代码中
- 不需要存入 credentials.env 或 .gitignore

### Superwall Free 计划限制

- 最多 250 MAU（0.1 验证阶段足够）
- 支持 A/B 测试
- 不支持自定义 HTML（需 Pro 计划）—— 如果用免费计划，onboarding/paywall 需要用 Superwall 内置模板

### 与 /ae-onboarding-design 和 /ae-paywall-design 的关系

```
/ae-onboarding-design → 生成 HTML 页面
/ae-paywall-design    → 生成 HTML 页面
                          ↓
/ae-superwall-setup   → 配置 Superwall → 上传页面 → 绑定 placement
```

三个 skill 配合使用：先生成页面，再配置 Superwall 上传并关联。

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| `Superwall not configured` | 检查 `configure(apiKey:)` 是否在 App 启动时调用 |
| Placement 触发无反应 | Dashboard 中检查 placement 是否已创建并绑定了页面 |
| 页面不显示 | 确认 Custom HTML 已上传且 placement 绑定正确 |
| StoreKit 错误 | sandbox 环境需在 Settings → App Store → Sandbox Account 登录测试账号 |
| Free 计划不支持 Custom HTML | 升级到 Pro 或改用 Superwall 内置模板 |

## 复用说明

所有 0.1 产品都需要 Superwall 集成。配置流程标准化后，每个新产品只需 10 分钟完成集成。
