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

### `ios-pub-012` ForEach 视图标识必须稳定（禁止每次构建重新生成 UUID）

**规则**：`Identifiable` 模型的 `id` 属性禁止使用 `UUID()` 作为存储属性默认值。每次 `init` 都会生成新 UUID，配合 SwiftUI `ForEach` 会让整列子视图被认为是新元素，整列重建。频繁重建（例如 stream chat 消息逐字追加、定时器驱动的列表）会触发 watchdog `0x8BADF00D` 主线程超时崩溃。

**来源**：bible-app build 6（2026-04-17）真机崩溃，根因为 `ChatMessage.id = UUID()` 默认值，TTS 流式更新触发整列 ForEach 重建，主线程在 setNeedsLayout 中超过 watchdog 阈值。

**❌ 错误**：
```swift
struct ChatMessage: Identifiable {
    let id = UUID()              // ⚠️ 每次 init 重新生成
    let role: Role
    let content: String
}

ForEach(messages) { msg in
    MessageRow(message: msg)     // 整列每次更新都被认为是新元素
}
```

**✅ 正确**：
```swift
struct ChatMessage: Identifiable {
    let id: UUID                 // 必须由调用方传入并稳定保留
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

// 或：使用业务自带稳定主键（serverId / hash）
struct ChatMessage: Identifiable {
    let id: String               // 由后端返回，全程不变
    let role: Role
    let content: String
}
```

**例外（不会被标记）**：
- `let id = UUID()` 出现在 `class`（引用语义，init 只调用一次）— 但仍建议显式传入
- 非 `Identifiable` 上下文中的 UUID 默认值

---

### `ios-pub-013` 音视频框架实例必须存为属性（禁止局部变量 + delegate）

**规则**：`AVSpeechSynthesizer` / `AVAudioPlayer` / `AVAudioRecorder` 等使用 `weak` delegate 的 AV 框架对象，禁止以局部 `let` / `var` 形式创建后再设置 delegate 或调用 `speak/play/record`。函数返回时实例释放，delegate 也随之失效，回调路径访问已释放对象 → `EXC_BAD_ACCESS`。

**来源**：bible-app build 9（2026-04-17）TTS Listen 按钮崩溃，根因为函数局部 `let synth = AVSpeechSynthesizer(); synth.delegate = self; synth.speak(...)`，`synth` 出函数即被释放。

**❌ 错误**：
```swift
func play(text: String) {
    let synth = AVSpeechSynthesizer()      // ⚠️ 局部变量
    synth.delegate = self
    let utterance = AVSpeechUtterance(string: text)
    synth.speak(utterance)                  // 函数返回 → synth 释放 → delegate 回调时 EXC_BAD_ACCESS
}
```

**✅ 正确**：
```swift
final class TTSService: NSObject {
    private let synth = AVSpeechSynthesizer()   // ✅ 实例属性，与 service 同生命周期

    override init() {
        super.init()
        synth.delegate = self
    }

    func play(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        synth.speak(utterance)
    }
}
```

**适用类型清单**：`AVSpeechSynthesizer`、`AVAudioPlayer`、`AVAudioRecorder`、`AVAudioEngine`、`AVCaptureSession`。

---

### `ios-pub-070` 所有 .swift 源文件必须在 Xcode target 内（pre-archive）

**规则**：项目源码目录下任何 `.swift` 文件必须在 `*.xcodeproj/project.pbxproj` 或对应 `Podfile` 引用的 Pod 内。Archive 前自动扫描，未注册文件 fail。

**来源**：bible-app build 12 `cannot find 'XxxService' in scope` 编译失败，根因为新增 Swift 文件未跑 `pod install` / `xcodegen`，文件物理存在但 target 不可见。

**❌ 错误**：
```
BibleAppDemo/Services/NewService.swift   ← 文件存在
BibleAppDemo.xcodeproj/project.pbxproj   ← 未引用 NewService.swift
```

**✅ 正确**：
```bash
# 编辑 project.yml / Podfile / 直接 Xcode 添加文件 后必须重跑：
xcodegen generate          # XcodeGen 项目
pod install                # CocoaPods 项目

# Pre-archive 自动扫描：
bash ~/.ae/pm/scripts/preflight-files-registered.sh .
```

**扫描脚本**：`scripts/preflight-files-registered.sh` 列出业务源文件目录里所有 `.swift`，对每个 grep `*.pbxproj`，未命中 + 不在 `Pods/` 下 → fail。

---

### `ios-pub-071` API 契约：禁止双前缀路径与 `code==200` 严校验

**规则**：

1. **路径无双前缀**：`baseURL` 已含 `/api`（如 `https://app.bible.itemvaults.com/api`）时，请求路径**禁止**再以 `/api/` 开头，否则形成 `/api/api/v1/...`。
2. **状态码非严等**：HTTP 200 区间判定必须用 `200..<300` 或 `code >= 200 && code < 300`，**禁止** `code == 200` 严校验。后端正常返回 201/204/206 都会被误判为失败。

**来源**：bible-app build 8 chat API 联调失败，错误同时命中两个：(a) `/api/llm/v1/chat` 在 base URL 已含 `/api` 时变成 `/api/api/llm/v1/chat`；(b) ChatService 用 `if response.code == 200` 严校验，后端返 201 时被误判 500。

**❌ 错误**：
```swift
let baseURL = "https://app.bible.itemvaults.com/api"
let path = "/api/llm/v1/chat"               // ⚠️ 双 /api
let url = URL(string: baseURL + path)!

if response.statusCode == 200 {              // ⚠️ 严校验
    handleSuccess()
} else {
    handleError()                            // 201/204 → 进 error
}
```

**✅ 正确**：
```swift
let baseURL = Secrets.apiBaseURL             // 含 /api
let path = "/llm/v1/chat"                    // 不重复前缀
let url = URL(string: baseURL + path)!

if (200..<300).contains(response.statusCode) {
    handleSuccess()
}
```

**扫描方式**：preflight-swiftui-lint 扫描字符串字面量含 `"/api/api"` 即报；扫描 `BinaryOperatorExpr` 中 `statusCode == 200` / `code == 200` 即报。

---

### `ios-pub-080` 受版权内容必须扫描并声明授权

**规则**：app 内嵌的圣经经文、歌词、诗词、长段引用文本必须使用**公共版权**或已购授权来源，并在 app 内/隐私政策中标注。Bible 翻译版本：`KJV` / `ASV` / `WEB` / `BBE` 公共版权可直接使用；`NIV` / `ESV` / `NASB` / `NLT` / `MSG` / `CSB` 等需 Biblica/Crossway/Lockman/Tyndale 等授权。

**来源**：bible-app 12 轮 TF 中曾误用 NIV 经文片段（受 Biblica 版权保护），后切换为 KJV（公共版权）。Apple Review 5.2.1 要求第三方知识产权合规，违规直接拒审。

**❌ 错误**：
```swift
// 直接嵌入 NIV 译文
let verse = "For God so loved the world that he gave his one and only Son... (John 3:16, NIV)"
```

**✅ 正确**：
```swift
// 使用 KJV 公共版权
let verse = "For God so loved the world, that he gave his only begotten Son... (John 3:16, KJV)"

// 或：取得授权后在 SubscriptionTerms / Acknowledgments 标注
// "Scripture quotations marked NIV are taken from the Holy Bible, New International Version®, 
//  NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.®. Used by permission."
```

**扫描脚本**：`scripts/preflight-content-copyright.sh` grep 源文件中 `(NIV)` / `(ESV)` / `(NASB)` / `(NLT)` / `(MSG)` / `(CSB)` 等受版权标记，若发现且 `Acknowledgments.md` 不含对应授权声明则 fail。

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
- `ios-pub-01x` — 触控、交互、视图与框架生命周期（含 SwiftUI 反模式、AV 框架）
- `ios-pub-02x` — 权限
- `ios-pub-03x` — 资产
- `ios-pub-04x` — 配置（Bundle ID、Team）
- `ios-pub-05x` — 可访问性
- `ios-pub-06x` — 技术选型
- `ios-pub-07x` — 构建门禁（pre-archive 编译、文件注册、API 契约）
- `ios-pub-08x` — 内容合规（版权、授权声明）
- `ios-pub-1xx` — 建议项（非硬红线）

新增规则时：
1. 先在 preflight 扫描中发现 → 在 SKILL.md 「已验证的约束」表加一行
2. 同步到本文件 Part 1 或 Part 2
3. linter 实现时引用同一 ID
