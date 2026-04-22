# iOS App 上架硬约束

> PM 用 AI 工具生成 iOS App 时必须遵守的代码级硬约束。违反会导致 App Store 拒审、用户功能不可用或可访问性失败。
>
> **单一真源**：本文件是 preflight linter 扫描规则的源头，每条规则有唯一 ID（`ios-pub-xxx`），linter 报告与本文件一一对应。

---

## Part 1 — 硬红线（Blockers）

违反以下规则会导致：Apple Review 拒审、上架后崩溃、用户功能不可用。**必须 100% 遵守**。

### `ios-pub-010` 触控区域 ≥ 44pt

**规则**：所有可交互元素（Button、onTapGesture、NavigationLink、Image.resizable 附 onTapGesture 等）的触控区域（frame 的 width 和 height）最小值必须 ≥ 44pt。

**来源**：[Apple Human Interface Guidelines — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

**❌ 错误**：
```swift
Button(action: closeView) {
    Image(systemName: "xmark")
}
.frame(width: 36, height: 36) // 36pt < 44pt

NavigationLink(destination: ProfileView()) {
    Image("avatar")
}
.frame(width: 32, height: 32)
```

**✅ 正确**：
```swift
Button(action: closeView) {
    Image(systemName: "xmark")
}
.frame(width: 44, height: 44) // 满足 44pt 最低标准

// 或：让图标小但触控区域大
Button(action: closeView) {
    Image(systemName: "xmark")
        .frame(width: 24, height: 24) // 视觉尺寸
}
.frame(width: 44, height: 44) // 触控区域
.contentShape(Rectangle())
```

**例外**：**不可交互**的纯装饰 Image / Text 没有触控区域要求。

---

### `ios-pub-011` Button 必须有非空 action

**规则**：所有 `Button` 和 `.onTapGesture` 的 action 闭包必须包含实际逻辑。空闭包、仅 print 语句、仅注释占位都算「空响应」——用户点了没反应是严重可用性问题。

**❌ 错误**：
```swift
Button(action: {}) {  // 完全空
    Text("Share")
}

Button {
    print("tapped")  // 仅 print
} label: {
    Text("Settings")
}

Button {
    // TODO: 跳转  ← 仅注释占位
} label: {
    Text("Profile")
}

.onTapGesture { }  // 空闭包
```

**✅ 正确**：
```swift
Button(action: shareContent) {
    Text("Share")
}

Button {
    showSettings = true  // 明确的状态变更
} label: {
    Text("Settings")
}

Button {
    Task { await loadProfile() }
} label: {
    Text("Profile")
}
```

**合法例外（不会被标记）**：
- 闭包内有赋值（`showSheet = true`）
- 闭包内有函数调用（`viewModel.save()`）
- 闭包内有 async Task
- 有 `// TODO: xxx` 注释**且**有其他可执行代码

---

### `ios-pub-001` 禁止硬编码 API Key

**规则**：任何 API Key / Secret / Token 禁止以明文字符串出现在 `.swift` 源码中。必须外部化到 `Secrets.plist`（加入 `.gitignore`）或 Environment Variable 或 Keychain。

**❌ 错误**：
```swift
let openAIKey = "sk-proj-abc123def456..." // 明文硬编码

struct Config {
    static let apiKey = "sk-live-xxxxxxxxxxxxxxxxxxxx"
}
```

**✅ 正确**：
```swift
// Secrets.plist 中存储 key（加入 .gitignore）
enum Secrets {
    static var openAIKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return "" }
        return dict["OPENAI_API_KEY"] ?? ""
    }
}
```

**同时必须**：
- `.gitignore` 包含 `Secrets.plist` / `GoogleService-Info.plist` / `*.env`
- `git ls-files | grep Secrets.plist` 必须为空

---

### `ios-pub-029` 境外 API Base URL 必须可配置

**规则**：依赖境外 API（OpenAI、Gemini、Claude、Firebase 等）的功能，API Base URL 必须通过 Secrets.plist 配置，不能硬编码域名。中国网络环境下直连通常失败，需支持代理/中转。

**❌ 错误**：
```swift
let url = URL(string: "https://api.openai.com/v1/chat/completions")!
```

**✅ 正确**：
```swift
let baseURL = Secrets.openAIBaseURL  // 从 Secrets.plist 读取，默认 https://api.openai.com
let url = URL(string: "\(baseURL)/v1/chat/completions")!
```

---

### `ios-pub-003` 必须有 PrivacyInfo.xcprivacy

**规则**：App Store 2024 年起强制要求 `PrivacyInfo.xcprivacy` 文件声明 Required Reasons API 使用（UserDefaults / File Timestamp / 系统信息等）。

**✅ 正确**：在项目中添加 `PrivacyInfo.xcprivacy`：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array>
        </dict>
    </array>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

---

### `ios-pub-020` Info.plist 必须声明使用的权限

**规则**：代码中使用 AVCaptureSession / CLLocationManager / PHPhotoLibrary / CNContactStore / ATTrackingManager 等需权限的 API 时，`Info.plist` 必须声明对应的 UsageDescription，否则运行时 crash。

**映射表**：
| 代码 API | Info.plist 必需 key |
|---------|-------------------|
| `AVCaptureSession` | `NSCameraUsageDescription` |
| `CLLocationManager` | `NSLocationWhenInUseUsageDescription` |
| `PHPhotoLibrary` | `NSPhotoLibraryUsageDescription` |
| `CNContactStore` | `NSContactsUsageDescription` |
| `ATTrackingManager` | `NSUserTrackingUsageDescription` |

---

### `ios-pub-002` App Icon 必须 1024x1024 PNG

**规则**：`Assets.xcassets/AppIcon.appiconset/` 必须包含 1024x1024 PNG（App Store 用）。缺失会导致 Archive 上传失败。

---

### `ios-pub-040` Bundle ID 禁止含 Demo/Test/Example

**规则**：`PRODUCT_BUNDLE_IDENTIFIER` 必须是正式的反向域名格式，不能包含 `Demo` / `Test` / `Example` / `Sample`。

**❌ 错误**：`com.mycompany.MyAppDemo`

**✅ 正确**：`com.mycompany.myapp`

---

### `ios-pub-050` 所有可交互元素必须设 accessibilityIdentifier

**规则**：所有 Button / TextField / Toggle / NavigationLink 等可交互元素必须设置 `accessibilityIdentifier`。E2E 自动化测试（AE 的 /ae-verify-app）依赖此属性精确定位。

**❌ 错误**：
```swift
Button("Submit", action: submit)
```

**✅ 正确**：
```swift
Button("Submit", action: submit)
    .accessibilityIdentifier("submit_button")
```

---

### `ios-pub-060` iOS 前端必须 SwiftUI Native，禁止 WebView

**规则**：不得用 `WKWebView` 加载 HTML/JS 作为主要 UI。WebView 内容的 accessibility tree 为空，E2E 验证和 App Review 可访问性都会失败。

**详见** [`tech-stack.md`](./tech-stack.md)。

---

## Part 2 — 建议项（Warnings）

违反以下规则可以上架，但会影响用户体验、投放数据或长期运营质量。

### `ios-pub-100` Launch Screen 必须配置

应通过 Info.plist 的 `UILaunchScreen` 或 `LaunchScreen.storyboard` 配置启动画面。

### `ios-pub-110` 首次启动应有隐私合规弹窗

应在首次启动时展示隐私政策同意弹窗（特别是欧盟 GDPR、中国《个人信息保护法》要求）。

### `ios-pub-120` 建议接入 Firebase Analytics + Adjust

无埋点的 TestFlight 等于盲测；无 Adjust 的投放无法做归因。详见 `/ae-analytics-integrate`。

### `ios-pub-130` 付费功能必须实现 Restore Purchases

StoreKit 2 要求 Paywall 提供 Restore 按钮且有实际恢复逻辑。空实现会被 Apple Review 拒。

### `ios-pub-140` 项目结构：单文件 ≤ 500 行

大文件超出 AI agent 和 code review 的处理能力，按功能模块拆分。

---

## Part 3 — 规则 ID 约定

- `ios-pub-0xx` — 基础（签名、秘钥、隐私）
- `ios-pub-01x` — 触控与交互
- `ios-pub-02x` — 权限
- `ios-pub-03x` — 资产
- `ios-pub-04x` — 配置（Bundle ID、Team）
- `ios-pub-05x` — 可访问性
- `ios-pub-06x` — 技术选型
- `ios-pub-1xx` — 建议项（非硬红线）

新增规则时：
1. 先在 preflight 扫描中发现 → 在 SKILL.md 「已验证的约束」表加一行
2. 同步到本文件 Part 1 或 Part 2
3. linter 实现时引用同一 ID
