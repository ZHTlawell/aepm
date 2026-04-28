---
description: "iOS Onboarding 全流程 — SwiftUI 原生 Welcome 模块 + AB 变体注册 + BCAppReviewPrompt 评分引导（Scale Global 生态）"
last_updated: "2026-04-23"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(pod *)"
    - "Bash(open *)"
    - "Bash(grep *)"
    - "Bash(find *)"
    - "Bash(mkdir *)"
    - "Bash(cp *)"
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

# Skill: Onboarding 全流程 (ae-onboarding-integrate)

> **经 bible-ios-template + plant-app 实战验证 + 杭州 Martinlehb 审计 2026-04-23。** Welcome 变体 SwiftUI 原生实现 + AB 变体注册 + Work Chain 集成 + 评分引导联动全流程。
>
> **重大变更（v0.63.0）：** 原 HTML 原型设计阶段（继承自 ae-onboarding-design）**已删除** — 杭州审计确认全部原生实现，不使用 HTML / WebView 方案。

## 核心原则

> **你是 Onboarding 工程师。** 基于 PM 提供的产品定位 + 核心 feature 清单，产出：① Welcome 变体 SwiftUI 原生实现（可选独立 Pod 或业务仓库内模块）；② ABTestType.welcome 变体注册；③ Work Chain `WelcomeWork` 集成；④ 评分引导联动。
>
> **关键约束（杭州审计确认）：**
> 1. **实现严格原生 SwiftUI**（P0-25）— 不使用 HTML / WebView 方案
> 2. **命名约定**：VC class 名 = `Welcome_{memo}ViewController`（memo 是 String 无硬性长度/字符限制，P0-23）；动态加载通过 `BCABTest.shared.syncFetchWecome()` + `NSClassFromString`
> 3. **欢迎页之间不抽象共性逻辑**（P0-22）— 唯一接口：实现 `WorkVoidCallbackTask` 协议。**各项目欢迎页可放业务仓库内，不强制独立 Pod 仓库**
> 4. **`hasShownKey` 不可清除或重置**（P0-26）— 欢迎页在 App 全生命周期**只弹一次**，通过 `WelcomeHasShownCacheKey` 持久化标记；AB 新变体上线不清除老用户 key，只影响新用户
> 5. **与 AB 联动**：variant 由 `BCABTest.shared.syncFetchWecome()` 返回 memo String 决定，对应加载 `Welcome_{memo}ViewController`
> 6. **完成后评分引导**：`BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")`（频控全局统一，未开放项目级配置，P0-24）

## 触发条件

- PM 说"做 onboarding"、"新用户引导"、"首启 welcome 页"
- 已有 Welcome 变体要加新版本（A/B 测试新文案 / 新视觉）
- preflight 报告标记"Welcome Pod 缺失"

## 角色分工

| 事项 | 谁做 |
|------|------|
| Podfile 含 Welcome 基础 Pod + 目标 Welcome_XX 变体 Pod | **杭州团队（或本 skill 生成后提 PR）** |
| 产品定位 + 核心 feature 清单 | PM |
| 视觉设计（配色 / 插图 / 文案）| PM + 设计师（本 skill 只给骨架）|
| HTML 原型（PM 审视阶段）| Agent |
| Welcome_XX Pod SwiftUI/UIKit 实现 | Agent |
| ABTestType.welcome case 注册 | Agent（如 `ae-abtest-integrate` 已接 + `.welcome` case 已在） |
| 神策后台 welcome 实验配置 | **PM + 数据团队** |
| Work Chain `WelcomeWork` 检查 | Agent |
| 多语言文案翻译 | PM（本 skill 给 en 占位）|
| BCAppReviewPrompt 评分引导接入 | Agent |

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 |
| `ae-abtest-integrate` 已完成 | `ABTestType.welcome` case 存在 + 神策 key `{productId}_welcome_{version}` 已配置 |
| `ae-i18n-integrate` 已完成 | Language extension + 多语言 Localizable 就绪（variant 自带文案也要多语言化）|
| Podfile 含 `Welcome`（基础 Pod） | `grep 'pod "Welcome"' Podfile` |
| `BCAppReviewPrompt` Pod 可用 | `grep 'pod "BCAppReviewPrompt"' Podfile`（完成后评分引导必需）|

前置未就绪 → **停在这里**。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "WePray" |
| 产品一句话简介 | 是 | 如 "AI-powered Bible study companion" |
| 核心 feature 列表（1-3 个）| 是 | 每页展示一个 feature，含名称 + 价值描述 |
| memo（变体标识）| 是 | 如 `01` / `02`（两位数），必须对应 ABTestType.welcome 的变体值 |
| 产品截图 / icon | 否 | widget 卡片预览 |
| 主色调 | 否 | 如 `#6C63FF` |
| 风格参考 | 否 | 如 "像 Calm" / "极简" |
| CTA 文案 | 否 | 默认 "Continue" / 最后页 "Get Started" |

---

## Phase 1: 前置检查

### Step 1.1: Podfile

```bash
grep -E 'pod "(Welcome|BCAppReviewPrompt)"' Podfile
```

**预期：** `Welcome` 基础 Pod + `BCAppReviewPrompt` 都有匹配。新 Welcome_XX 变体 Pod 会在 Phase 3 生成后加入 Podfile。

### Step 1.2: Welcome 基础 Pod 结构

```bash
find Locals/Welcome -type f -name "*.swift" 2>/dev/null
```

**预期：** 至少 `WelcomeProtocol.swift`（WelcomeDelegate + WelcomeViewController 父类）+ `WelcomeConsts.swift`。缺失 → 从 bible-ios-template copy。

### Step 1.3: ABTestType.welcome case

```bash
grep -nE "case welcome|ABTestType.welcome" Template/Core/AppConfig/ABTest/ABTestConfig.swift
```

**预期：** `case welcome` 存在 + `key` 返回 `{productId}_welcome_1` + `defaultValue` 为 `.string(value: "XX")`（指向默认 variant）。

### Step 1.4: WelcomeWork 存在性

```bash
cat Template/Core/StartupSequence/WelcomeWork.swift
```

**预期：** `WelcomeWork` 存在，用 `BCABTest.shared.syncFetchWecome()` + `NSClassFromString("Welcome_\(memo)ViewController")` 动态加载，并在 startupSequence 数组中。

### Step 1.5: 现有 Welcome 变体清单

```bash
ls Locals/ | grep "^Welcome_" | head -10
```

记录：已有哪些 `Welcome_XX` 变体 → Phase 3 新增时避免 memo 冲突。

### Step 1.6: 向 PM 确认

> 1. 新 variant 的 memo（如 `03`）？（和已有变体不重复）
> 2. 是否 A/B 对照老版本？如 A/B 两组：保留 Welcome_01 + 新加 Welcome_03
> 3. 产品定位 + 核心 feature 清单
> 4. 视觉参考（已有 Welcome_01 / 02 的样式，还是全新）

---

## Phase 2: Welcome 变体 SwiftUI 实现

> **范围变更说明（v0.63.0，杭州审计 P0-25）：** 原 Phase 2 "HTML 原型设计阶段" 已删除。杭州确认所有转化页/欢迎页**全部原生 SwiftUI 实现**，不使用 HTML / WebView 方案。视觉设计若需 PM 预审，走 Figma / Sketch 稿，不在本 skill 范围。

### Step 2.1: 目录骨架（独立 Pod 或业务仓库内均可）

**两种组织方式**（P0-22 杭州审计：不强制独立仓库）：

**方式 A — 业务仓库内模块**（推荐，减少 Pod 维护成本）：

```bash
MEMO="03"  # 由 BCABTest.shared.syncFetchWecome() 返回的变体标识决定
mkdir -p <Project>/Classes/Feature/Welcome_${MEMO}/{UI/Controller,UI/Page,UI/View,ViewModel,Model}
```

**方式 B — 独立 Pod**（跨产品复用场景才考虑）：

```bash
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Classes/{UI/Controller,UI/Page,UI/View,ViewModel,Model}
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Localizable/en.lproj
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Assets.xcassets
```

默认走方式 A；仅当该变体确需跨产品复用时升级为方式 B（需额外维护 Podspec + pod install）。

### Step 2.2: Podspec（仅方式 B 独立 Pod 需要）

路径：`Locals/Welcome_${MEMO}/Welcome_${MEMO}.podspec`

```ruby
Pod::Spec.new do |s|
  s.name = 'Welcome_#{MEMO}'
  s.version = '1.0.0'
  s.summary = 'Welcome onboarding variant #{MEMO}'
  s.source_files = 'Welcome_#{MEMO}/Classes/**/*'
  s.resource_bundles = {
    'Welcome_#{MEMO}' => ['Welcome_#{MEMO}/Localizable/**/*', 'Welcome_#{MEMO}/Assets.xcassets']
  }
  s.dependency 'Welcome'           # 基础协议 Pod
  s.dependency 'AppImports'        # 共用导入
  s.dependency 'CL10nKit'          # 文案
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
end
```

### Step 3.3: WelcomeViewController 子类（严格命名）

路径：`Locals/Welcome_${MEMO}/Welcome_${MEMO}/Classes/UI/Controller/WelcomeViewController.swift`

**⚠️ class 名必须 `Welcome_${MEMO}ViewController`**（WelcomeWork 用 `NSClassFromString` 字符串匹配）。

```swift
import UIKit
import SwiftUI
import AppImports
import Welcome       // 基础 Pod

// ⚠️ class 名严格约定：Welcome_XXViewController（XX = memo）
public class Welcome_03ViewController: WelcomeViewController {

    // 父类（Welcome Pod 定义）要求的 init
    required public init(delegate: WelcomeDelegate, memo: String, completion: @escaping (UIViewController) -> ()) {
        super.init(delegate: delegate, memo: memo, completion: completion)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white

        // SwiftUI 嵌入
        let swiftUIView = WelcomePage(
            items: WelcomeViewModel.shared.items,
            onFinish: { [weak self] in
                guard let self else { return }
                // 通知 delegate 引导完成 → 评分引导
                self.delegate?.seekGoodReview()
                self.completion(self)  // 触发 WelcomeWork 的 dismiss
            }
        )
        let hostingVC = BCHostingController(rootView: swiftUIView)
        addChildVC(hostingVC)
    }
}
```

### Step 3.4: SwiftUI WelcomePage（实现 HTML 原型的 SwiftUI 版本）

路径：`Locals/Welcome_${MEMO}/Welcome_${MEMO}/Classes/UI/Page/WelcomePage.swift`

```swift
import SwiftUI
import AppImports

struct WelcomePage: View {
    let items: [WelcomeItem]
    let onFinish: () -> Void
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    WelcomeItemView(item: item).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button(action: {
                if currentIndex < items.count - 1 {
                    withAnimation { currentIndex += 1 }
                } else {
                    onFinish()
                }
            }) {
                Text(ctaText)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: 0x6C63FF))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var ctaText: String {
        currentIndex < items.count - 1
            ? Language.ctext_continue
            : Language.ctext_start_now  // 或 "Get Started"，来自 CL10nKit
    }
}
```

### Step 3.5: WelcomeItem + WelcomeViewModel

```swift
// Model/WelcomeItem.swift
public struct WelcomeItem {
    let icon: String         // SF Symbol 或 Assets 名
    let title: String        // 本地化 key
    let description: String  // 本地化 key
}

// ViewModel/WelcomeViewModel.swift
public class WelcomeViewModel {
    public static let shared = WelcomeViewModel()

    public var items: [WelcomeItem] {
        [
            WelcomeItem(icon: "book.closed", title: Language.welcome_03_page1_title, description: Language.welcome_03_page1_desc),
            WelcomeItem(icon: "sparkles",    title: Language.welcome_03_page2_title, description: Language.welcome_03_page2_desc),
            WelcomeItem(icon: "heart.fill",  title: Language.welcome_03_page3_title, description: Language.welcome_03_page3_desc),
        ]
    }
}
```

### Step 3.6: Pod 自有 Language extension

路径：`Locals/Welcome_${MEMO}/Welcome_${MEMO}/Classes/Language.swift`

```swift
import Foundation
import BCLocalization
import CL10nKit

fileprivate class Welcome_03 {}

public extension Language {
    static var welcome_03_page1_title: String { self.text(for: "welcome_03_page1_title") }
    static var welcome_03_page1_desc:  String { self.text(for: "welcome_03_page1_desc") }
    static var welcome_03_page2_title: String { self.text(for: "welcome_03_page2_title") }
    static var welcome_03_page2_desc:  String { self.text(for: "welcome_03_page2_desc") }
    static var welcome_03_page3_title: String { self.text(for: "welcome_03_page3_title") }
    static var welcome_03_page3_desc:  String { self.text(for: "welcome_03_page3_desc") }
}
```

### Step 3.7: Pod 自有 Localizable.strings

路径：`Locals/Welcome_${MEMO}/Welcome_${MEMO}/Localizable/en.lproj/Localizable.strings`

```
"welcome_03_page1_title" = "Your Daily Verse";
"welcome_03_page1_desc"  = "Personalized scripture for your spiritual journey.";
"welcome_03_page2_title" = "AI Companion";
"welcome_03_page2_desc"  = "Ask anything about the Bible in natural language.";
"welcome_03_page3_title" = "Grow in Faith";
"welcome_03_page3_desc"  = "Track your Bible study streak and reflect.";
```

### Step 3.8: 多语言策略（P0-16 杭州审计）

**第一版 Welcome 变体只适配英文（en-only）。** 杭州审计确认：

- 欢迎页各自独立，**不做统一多语言化**
- **只有当某 variant 数据表现好**（转化率达预期）时，再单独为该 variant 投入多语言化
- 避免过早在低价值 variant 上消耗翻译成本

因此 Welcome_{memo}/Localizable/ 默认**仅生成 `en.lproj/`**，不批量建其他语言目录。若 variant 验证胜出后需补多语言，再单独走 `/ae-i18n-integrate` 对该 variant 执行批量扩展。

---

## Phase 4: AB 变体注册

### Step 4.1: ABTestType.welcome defaultValue 更新

如要把新 variant 设为默认，修改 `Template/Core/AppConfig/ABTest/ABTestConfig.swift`：

```swift
public var defaultValue: BCABTestResult {
    switch self {
    case .welcome:
        return .string(value: "03")  // 新默认
    // ...
    }
}
```

**⚠️ 同时通知 PM 在神策后台调整 welcome 实验的 control 组值到 "03"，对齐代码和后台 default**（参考 ae-abtest-integrate 硬性规则 4）。

### Step 4.2: 神策后台 welcome 实验配置

**PM 在神策操作：**
1. welcome 实验添加新 variant 值 `"03"`
2. 调整分流（如原 50% / 50% → 33% / 33% / 34% 三组）
3. 或暂时只给白名单设备 variant `"03"` 做内测

### Step 4.3: Podfile 添加新 Welcome_XX Pod

```ruby
# Podfile 末尾业务 Pod 区域
pod "Welcome_03", :path => "Locals/Welcome_03"  # local 开发，迁移到 GitLab 后改 :git
```

```bash
pod install 2>&1 | tail -5
```

**预期：** `Pod installation complete!` + `Pods.xcodeproj` 包含 `Welcome_03` target。

---

## Phase 5: Work Chain 集成验证

### Step 5.1: WelcomeWork 应已存在

不需要修改 WelcomeWork.swift —— 它通过 `NSClassFromString("Welcome_\(memo)ViewController")` 动态加载，只要 Pod 和 class 命名对就能工作。

### Step 5.2: 验证动态加载

加调试日志：

```swift
// WelcomeWork.swift createWelcom
private func createWelcom(completion: @escaping (_ sender: UIViewController)->()) -> WelcomeViewController? {
    let memo = BCABTest.shared.syncFetchWecome()
    print("🎬 [Welcome] AB memo=\(memo)")

    if let vc = self.createWelcome(with: memo, completion: completion) {
        print("🎬 [Welcome] loaded Welcome_\(memo)ViewController")
        return vc
    }
    print("⚠️ [Welcome] dynamic load failed, falling back to default")
    // ...
}
```

### Step 5.3: BCCache hasShown 机制验证

```swift
// WelcomeWork.isCompleted 读取 BCCache.boolValue(key: "WelcomeHasShownCacheKey")
```

确认：
- 首次启动 → 显示 Welcome
- 完成后 → `BCCache.setBool(true, key: hasShowCacheKey)`
- 二次启动 → `isCompleted == true` → `callback()` 跳过

---

## Phase 6: 评分引导联动

### Step 6.1: WelcomeDelegate.seekGoodReview

WelcomeWork extension 已实现：

```swift
extension WelcomeWork: WelcomeDelegate {
    func seekGoodReview() {
        BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")
    }
}
```

### Step 6.2: 新 variant 在"完成"时触发

```swift
// Welcome_03ViewController 完成时
self.delegate?.seekGoodReview()   // 通知 WelcomeWork
self.completion(self)             // 触发 dismiss
```

**⚠️ 顺序：先 seekGoodReview（准备评分弹窗）再 completion（移除 VC），确保评分弹窗在 onboarding 关闭前触发**。

### Step 6.3: 验证评分弹窗时机

真机首次启动：
1. Onboarding 完整走完（3 页 Continue → Get Started）
2. 点 Get Started → `seekGoodReview` 调用 → `BCAppReviewPrompt` 决定是否弹（基于频控）
3. 弹出系统评分 prompt（`SKStoreReviewController`，每年最多 3 次）或静默（频控触发）

---

## Phase 7: 集成验证

### Step 7.1: 编译通过

```bash
pod install
xcodebuild build -workspace <Name>.xcworkspace -scheme <Scheme> \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15
```

### Step 7.2: 真机冷启完整验证

1. 卸载 App → 重新安装
2. 启动 → Xcode Console 应打：
   ```
   🔬 [ABTest] preload done
   🎬 [Welcome] AB memo=03
   🎬 [Welcome] loaded Welcome_03ViewController
   ```
3. 走完 3 页 → 点 Get Started → 评分弹窗（或静默）
4. 关闭 App → 再启动 → 不再显示 Welcome（`isCompleted == true`）

### Step 7.3: AB 分流验证

神策白名单设备：
- 设备 A 加到 variant "01" 白名单 → 启动显示 Welcome_01
- 设备 B 加到 variant "03" 白名单 → 启动显示 Welcome_03
- 确认 `BCCache` key 唯一（不同变体共享 `WelcomeHasShownCacheKey`，用户看过任一变体后都不再展示其他）

---

## Phase 8: 输出

```
═══════════════════════════════════════════
  Onboarding 集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}
新 variant memo：{memo}（如 "03"）

HTML 原型：
  - onboarding/index.html + styles.css + script.js
  - PM 已审视

Welcome_{memo} Pod：
  - Podspec: Locals/Welcome_{memo}/Welcome_{memo}.podspec
  - SwiftUI 实现：WelcomePage / WelcomeItemView / WelcomeViewModel
  - VC class: Welcome_{memo}ViewController（严格命名）
  - 文案 keys: welcome_{memo}_page{1..N}_{title,desc}（Language extension）
  - 多语言：{N} 种语言占位已建（en 为内容，其他待翻译）

AB 测试：
  - ABTestType.welcome defaultValue = "{default_memo}"
  - 神策后台 key: {productId}_welcome_1

Work Chain：
  - WelcomeWork（第 10 步）动态加载：NSClassFromString("Welcome_{memo}ViewController")
  - BCCache key "WelcomeHasShownCacheKey" 控制一次性展示

评分引导：
  - 完成后调 BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")

待 PM 处理：
  - [ ] 神策后台 welcome 实验添加 variant "{memo}"
  - [ ] 调整分流（如 50/50 / 33/33/34）
  - [ ] {N-1} 种语言翻译填充
  - [ ] 白名单设备验证
═══════════════════════════════════════════
```

---

## 硬性规则

1. **实现必须 SwiftUI 原生**（P0-25）— 不使用 HTML / WebView 方案，不使用 Superwall 托管。
2. **VC class 名严格约定** — `Welcome_{memo}ViewController`（memo 是 String，无长度/字符限制），否则 `NSClassFromString` 找不到，fallback 到默认 variant。
3. **Welcome VC 实现 `WorkVoidCallbackTask` 协议**（P0-22）— 欢迎页之间不抽象共性逻辑，唯一接口约束是该协议（`func work(_ callback: @escaping VoidCallback)`）；可放独立 Pod 也可放业务仓库。
4. **`hasShownKey` 不可清除或重置**（P0-26）— `WelcomeHasShownCacheKey` 跨变体共享，用户全生命周期只弹一次。新 variant 上线只影响新用户，不清除老用户 key 让他们重看。
5. **完成时先 `seekGoodReview` 后 `completion`** — 顺序错乱会让评分弹窗无法挂到 rootVC（VC 已销毁）。
6. **AB defaultValue 和神策 control 组严格对齐** — 参考 ae-abtest-integrate 硬性规则 4。新 variant 上线前先和 PM 对齐两边 default。
7. **第一版 Welcome 只适配英文**（P0-16）— 欢迎页各自独立，不做统一多语言化；variant 数据表现好（高转化）再单独投入多语言。
8. **Welcome 若独立 Pod，Pod 自带 `.lproj`** — 不共享主项目的 Localizable.strings（避免 Pod 分发时文案缺失）；若放业务仓库内，文案随业务走。
9. **评分引导频控不开放项目级配置**（P0-24）— `BCAppReviewPrompt` 内置全局频控规则，所有项目共用，不试图定制。

---

## 反模式

❌ **VC class 名不按 `Welcome_{memo}ViewController` 格式（如叫 `OnboardingVC`）**
→ `NSClassFromString("Welcome_\(memo)ViewController")` 找不到 → 加载失败 fallback 默认 variant → 本次 AB 无效。

❌ **用 HTML / WebView 方案实现欢迎页**（P0-25 审计禁止）
→ 杭州生态强制 SwiftUI 原生，走 WebView 会和 Work Chain / BCAccount / BCABTest 集成脱节。

❌ **为每个 variant 独立 `hasShowCacheKey`**
→ 用户切换变体后重复看 onboarding，体验崩。必须共享 `WelcomeHasShownCacheKey`（用户一生只看一次 onboarding）。

❌ **新 variant 上线想"让老用户重新看"而清除 hasShownKey**（P0-26 审计禁止）
→ 破坏"一生只弹一次"承诺，用户体验崩。新 variant 只对新用户生效。

❌ **在 Welcome VC `viewDidLoad` 里调 `seekGoodReview`**
→ 打开 onboarding 就弹评分，用户没看产品就评分 → SKStoreReviewController 概率更低 + 审核 Guideline 5.6.1 风险。必须在用户**完成** onboarding 后调。

❌ **完成时 completion 在 seekGoodReview 之前**
→ VC 已 dismiss，`BCAppReviewPrompt.tryToSystemScore` 挂不到 rootVC，评分弹窗不显示。

❌ **强制欢迎页做成独立 Pod 仓库**（P0-22 审计：不强制）
→ 增加 Pod 维护成本。默认放业务仓库内即可，仅跨产品复用才升级独立 Pod。

❌ **第一版 Welcome 变体就批量建 10 语言 `.lproj`**（P0-16 审计）
→ 先适配英文验证转化，variant 数据好再投入多语言，避免翻译浪费。

❌ **新 variant 上线前未在神策配置 control 组默认值对齐**
→ 代码改 default 为 "03"，神策 control 组返回 "01"，实验 control 组 vs variant 组行为不对照。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| 动态加载失败，永远走默认 variant | (1) VC class 名不符 `Welcome_XXViewController` (2) 未 inherit WelcomeViewController (3) Pod 没在 Podfile 引入 | (1)(2) 改 class 名和继承 (3) `pod install` 后 Xcode target 里确认 |
| 用户每次启动都看 Welcome | (1) `BCCache.setBool(true, key: hasShowCacheKey)` 未被调用 (2) BCCache 存储失败 | (1) 确认 completion 走到 `self?.isCompleted = true` (2) BCCache 依赖 BCUtils Pod，确认已安装 |
| Welcome 完成后没弹评分 | (1) `seekGoodReview` 未调 (2) completion 先于 seekGoodReview (3) BCAppReviewPrompt 频控触发（每年 3 次上限） | (1)(2) 调整 VC 完成顺序 (3) iOS 限制，设备 `Settings → App Store → In-App Ratings & Reviews` 确认开启 |
| 多语言文案不显示（裸 key）| Welcome_XX Pod 的 Localizable.strings 没打到 Pod bundle | Podspec 的 `resource_bundles` 配了 `Localizable/**/*`，pod install 后 `Pods.xcodeproj` 的 target 应看到 `.lproj` |
| AB 白名单设备仍走默认 | ABTestLoadWork 未 preload / 神策 SDK 未 setup | 参考 ae-abtest-integrate 故障排查 |
| Welcome_XX Pod 编译失败 "WelcomeViewController not found" | Podspec 没 declare `s.dependency 'Welcome'` | 加依赖，pod install |
| 评分弹窗第二年不出现 | `SKStoreReviewController.requestReview` 每年最多 3 次 | 系统行为，无解；可在设置里引导用户手动评分 |

---

## 与其他 skill 的关系

```
/ae-analytics-integrate ──→ BCTrack（Welcome 展示/完成埋点）
       │
       ▼
/ae-abtest-integrate ─────→ ABTestType.welcome + 神策 welcome 实验
       │
       ▼
/ae-i18n-integrate ───────→ Welcome_XX Pod 独立 Localizable
       │
       ▼
/ae-onboarding-integrate ─→ HTML 原型 + Welcome_XX Pod（本 skill）
       │
       └──→ BCAppReviewPrompt（评分引导）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| onboarding-001 | VC class 名必须 `Welcome_XXViewController`（XX = memo），WelcomeWork 用字符串拼接加载 | Template/Core/StartupSequence/WelcomeWork.swift:68 |
| onboarding-002 | VC 必须 inherit `Welcome.WelcomeViewController`（基础 Pod 的协议/父类）| `as? WelcomeViewController.Type` 转换 |
| onboarding-003 | `BCCache.boolValue(key: "WelcomeHasShownCacheKey")` 跨 variant 共享，用户一生看一次 onboarding | WelcomeWork.isCompleted |
| onboarding-004 | `seekGoodReview` 必须在 `completion` 之前调（顺序反了评分弹窗挂不到 rootVC）| Welcome_01/02 实现 + WelcomeWork delegate |
| onboarding-005 | `BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")` 有内部频控（每年 3 次上限 + 自有业务频控）| BCAppReviewPrompt Pod |
| onboarding-006 | 每个 Welcome_XX 是独立 Pod，多语言 Localizable 独立 | Locals/Welcome_01 / Welcome_02 结构 |
| onboarding-007 | Welcome 基础 Pod 定义 `WelcomeProtocol.swift`（delegate + VC 父类），所有变体依赖 | Locals/Welcome 目录 |
| onboarding-008 | AB 变体 default 从代码读（`ABTestType.welcome.defaultValue`），和神策 control 组必须对齐 | ABTestConfig.swift + ae-abtest-integrate 规则 4 |
| onboarding-009 | HTML 原型（设计阶段）和 SwiftUI 实现（集成阶段）是两套交付物，视觉必须对齐 | 原 ae-onboarding-design + Welcome_XX Pod 合并 |
| onboarding-010 | onboarding 完成 != App 首次使用，冷启才会触发 WelcomeWork，之后进 MainPageLoadWork | AppDelegate.startupSequence 顺序 |

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 Welcome + Welcome_XX 变体 Pod 模式 + AB 测试驱动的动态加载。新产品起步至少 1 个 variant（memo "01"），后续 A/B 迭代加 `02/03/...`。非 Scale Global 项目可用类似模式但不依赖 BCABTest。

## 与 ae-onboarding-design 的关系

本 skill **合并并升级**原 `ae-onboarding-design`：
- 原 `ae-onboarding-design` 只做 HTML 原型（设计阶段）
- 本 skill 包含原能力（Phase 2）+ 新增 Welcome_XX Pod 实现（Phase 3）+ AB 注册（Phase 4）+ Work Chain 集成（Phase 5）+ 评分引导（Phase 6）
- 原 `ae-onboarding-design` 保留到龙哥审计通过本 skill 后再下线（参考 `ae-paywall-design` 处理方式）
