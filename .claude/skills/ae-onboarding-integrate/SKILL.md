---
description: "iOS Onboarding 全流程 — HTML 原型 + Welcome_XX Pod 打包 + AB 变体注册 + BCAppReviewPrompt 评分引导（Scale Global 生态）"
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

> **经 bible-ios-template + plant-app 实战验证。** 合并原 `ae-onboarding-design`（HTML/CSS/JS 设计）能力 + 新增 `Welcome_XX` Pod 打包 + AB 变体注册 + Work Chain 集成 + 评分引导联动全流程。

## 核心原则

> **你是 Onboarding 工程师。** 基于 PM 提供的产品定位 + 核心 feature 清单，产出：① **设计阶段** — HTML/CSS/JS 原型（用于 PM 审视视觉）；② **集成阶段** — `Welcome_XX` Pod（SwiftUI/UIKit 实现，严格遵守命名约定）；③ ABTestType.welcome 变体注册；④ Work Chain `WelcomeWork` 集成；⑤ 多语言 + 评分引导联动。
>
> **关键约束：**
> 1. **命名严格约定**：Pod 名 = `Welcome_XX`（两位数 memo），VC class 名 = `Welcome_XXViewController`（动态加载依赖字符串匹配）
> 2. **Welcome 基础 Pod 必须存在**：提供 `WelcomeViewController` 父类 + `WelcomeDelegate` 协议，所有变体 inherit
> 3. **一次性展示**：BCCache 标记 `hasShowCacheKey`，用户完成后不再展示（否则用户每次启动都被打扰）
> 4. **与 AB 测试联动**：variant = 独立 Pod，通过 `BCABTest.shared.syncFetchWecome()` 决定加载哪个
> 5. **完成后评分引导**：`BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")`

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

## Phase 2: HTML 原型设计（设计阶段）

### Step 2.1: 生成 `onboarding/` 目录（沿用原 ae-onboarding-design）

```
onboarding/
├── index.html          # 主容器（swipe + pagination + CTA）
├── styles.css          # 渐变背景 + 卡片 + 按钮
└── script.js           # 滑动逻辑 + CTA 回调
```

**设计规范** — Bevel Carousel 模式：

```
┌─────────────────────────┐
│     [Feature Title]     │  ← 大标题
│  [One-line value prop]  │  ← 副标题
│  ┌───────────────────┐  │
│  │  Widget Card 1    │  │  ← 圆角卡片，展示 feature
│  └───────────────────┘  │
│       ● ○ ○             │  ← 分页圆点
│  ┌───────────────────┐  │
│  │    Continue →      │  │  ← CTA
│  └───────────────────┘  │
└─────────────────────────┘
```

### Step 2.2: 本地预览给 PM 看

```bash
open onboarding/index.html
```

**PM 在浏览器设备模拟中审视视觉、文案、流程**。改几轮后再进入 Phase 3 的 iOS 实现（避免实现后再推翻）。

### Step 2.3: 输出设计产出

确认文件：
- `onboarding/index.html` + styles.css + script.js
- 每页的 feature 文案（1-3 页）
- 主色 + 字体 + 插图资源清单

---

## Phase 3: Welcome_XX Pod 生成

### Step 3.1: Pod 目录骨架

```bash
MEMO="03"  # PM 提供
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Classes/{UI/Controller,UI/Page,UI/View,ViewModel,Model}
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Localizable/en.lproj
mkdir -p Locals/Welcome_${MEMO}/Welcome_${MEMO}/Assets.xcassets
```

### Step 3.2: Podspec

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

**⚠️ 如 `ae-i18n-integrate` 已完成**，Phase 3.8 同步扩展所有语言（`de.lproj` / `zh-Hans.lproj` 等，每个 Welcome_XX Pod 独立 Localizable）。

### Step 3.8: 多语言扩展（同 ae-i18n-integrate Phase 3.2）

```bash
TARGET_LANGS=("de" "es" "fr" "it" "ja" "nl" "pt-BR" "zh-Hans" "zh-Hant")
SOURCE="Locals/Welcome_${MEMO}/Welcome_${MEMO}/Localizable/en.lproj/Localizable.strings"

for lang in "${TARGET_LANGS[@]}"; do
    target="Locals/Welcome_${MEMO}/Welcome_${MEMO}/Localizable/${lang}.lproj"
    mkdir -p "$target"
    cp "$SOURCE" "$target/Localizable.strings"
done
```

**复制 en 作为占位**，通知 PM 组织翻译。

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

1. **Pod 名 + VC class 名严格约定** — Pod = `Welcome_XX`，VC = `Welcome_XXViewController`，否则 `NSClassFromString` 找不到，fallback 到默认 variant。
2. **Welcome_XX 的 VC 必须 inherit Welcome 基础 Pod 的 `WelcomeViewController`** — 否则 WelcomeWork 的 `as? WelcomeViewController.Type` 转换失败。
3. **`BCCache` key `WelcomeHasShownCacheKey` 跨变体共享** — 用户看过任一 Welcome 变体后都不再展示其他变体。不要给每个 variant 单独 key（会让切换变体的用户被打扰二次）。
4. **完成时先 `seekGoodReview` 后 `completion`** — 顺序错乱（先 completion 后 seekGoodReview）会让评分弹窗无法挂到 rootVC（VC 已销毁）。
5. **AB defaultValue 和神策 control 组严格对齐** — 参考 ae-abtest-integrate 硬性规则 4。新 variant 上线前先和 PM 对齐两边 default。
6. **Welcome_XX Pod 独立多语言 Localizable** — 每个 Pod 自带 `.lproj` 目录，不共享主项目的 Localizable.strings（避免 Pod 分发时文案缺失）。
7. **HTML 原型和 SwiftUI 实现必须视觉一致** — HTML 是 PM 审视阶段产出，SwiftUI 是真实实现，两者文案 + 配色 + 布局必须对齐（否则 PM 审过的和用户看到的不一样）。

---

## 反模式

❌ **VC class 名不按 `Welcome_XXViewController` 格式（如叫 `OnboardingVC`）**
→ `NSClassFromString("Welcome_\(memo)ViewController")` 找不到 → 加载失败 fallback 默认 variant → 本次 AB 无效。

❌ **Welcome_XX VC 不 inherit `WelcomeViewController`（直接继承 UIViewController）**
→ `as? WelcomeViewController.Type` 转换失败 → 和上条一样 fallback。

❌ **为每个 variant 独立 `hasShowCacheKey`**
→ 用户切换变体后重复看 onboarding，体验崩。必须共享 key（用户一生只看一次 onboarding）。

❌ **在 Welcome VC `viewDidLoad` 里调 `seekGoodReview`**
→ 打开 onboarding 就弹评分，用户没看产品就评分 → SKStoreReviewController 概率更低 + 审核 Guideline 5.6.1 风险。必须在用户**完成** onboarding 后调。

❌ **完成时 completion 在 seekGoodReview 之前**
→ VC 已 dismiss，`BCAppReviewPrompt.tryToSystemScore` 挂不到 rootVC，评分弹窗不显示。

❌ **Welcome_XX Pod 文案写到项目主 Localizable.strings**
→ 违反 i18n 分层（参考 ae-i18n-integrate 反模式第 9 条）。Pod 独立分发时文案丢失。

❌ **HTML 原型和 SwiftUI 实现文案/视觉不一致**
→ PM 审视 HTML 通过后，SwiftUI 实现"简化"了文案或改了颜色 → 上线后 PM 发现"和我审的不一样"要返工。

❌ **新 variant 上线前未在神策配置 control 组默认值为 "03"**
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
