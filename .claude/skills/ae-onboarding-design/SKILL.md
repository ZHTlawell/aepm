---
description: "生成产品 Onboarding 幻灯片页面（HTML/CSS/JS，可嵌入 WebView 或 Superwall）"
---

# Skill: Onboarding 页面生成 (onboarding-design)

## 触发条件

当 PM 需要为产品生成 Onboarding 引导页面时触发。典型场景：
- 0.1 产品需要精美的 onboarding 幻灯片（2-3 页），展示核心 feature
- 需要提高用户付费意愿的 feature showcase 页面
- Superwall Flow 或 WebView 渲染的 onboarding 内容

## 核心原则

**Onboarding 是用户的第一印象，决定留存和付费转化。** 页面必须：
1. **聚焦价值** — 每页只展示一个核心 feature，突出用户获得的价值而非功能本身
2. **视觉精美** — 渐变背景 + 圆角卡片 + 流畅动画，达到 App Store 精品级视觉
3. **可复用** — 输出标准 HTML/CSS/JS，任何产品只需替换文案和配色即可使用

## 输入

PM 需要提供：

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "Bevel"、"ShoeLens" |
| 产品一句话简介 | 是 | 如 "AI-powered fitness & nutrition tracker" |
| 核心 feature 列表 | 是 | 1-3 个，每个包含名称和一句话价值描述 |
| 产品截图或 icon | 否 | 用于页面中的 widget 预览卡片，无则用 SF Symbols 占位 |
| 主色调 | 否 | 如 "#6C63FF"，无则根据产品品类自动选择 |
| 风格参考 | 否 | 如 "像 Bevel"、"像 Calm"、"极简" |
| CTA 文案 | 否 | 默认 "Continue"，最后一页默认 "Get Started" |

如果 PM 没有提供以上信息，**主动询问**，至少获取产品名称、简介和核心 feature 列表。

## 输出

在项目目录下生成 `onboarding/` 目录：

```
onboarding/
├── index.html          # 主容器（swipe + pagination + CTA）
├── styles.css          # 渐变背景 + 卡片 + 按钮样式
├── script.js           # 滑动逻辑 + CTA 回调
└── assets/             # icon/插画（如有）
```

## 设计规范（Bevel Carousel 模式）

每页的 HTML 结构：

```
┌─────────────────────────┐
│                         │
│     [Feature Title]     │  ← 大标题，feature 名称
│  [One-line value prop]  │  ← 副标题，一句话价值主张
│                         │
│  ┌───────────────────┐  │
│  │  Widget Card 1    │  │  ← 圆角卡片，展示 UI 效果
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │  Widget Card 2    │  │  ← 2-3 个 widget 预览卡
│  └───────────────────┘  │
│                         │
│       ● ○ ○             │  ← 分页圆点
│  ┌───────────────────┐  │
│  │    Continue →      │  │  ← 全宽 CTA 按钮
│  └───────────────────┘  │
└─────────────────────────┘
```

### 视觉要素

| 元素 | 规范 |
|------|------|
| 背景 | 线性渐变（主色 → 深色），每页渐变色略有变化 |
| 标题 | 28-32px，白色，font-weight 700 |
| 副标题 | 16-18px，白色 70% 透明度 |
| Widget 卡片 | 圆角 16px，半透明白色背景（rgba 255,255,255,0.15），backdrop-filter: blur(20px) |
| 分页圆点 | 当前页实心，其余半透明，8px 圆形 |
| CTA 按钮 | 全宽圆角按钮，白色背景，主色文字，font-weight 600 |
| 动画 | 页面切换 slide + fade，卡片入场 stagger animation |
| 安全区 | 顶部 env(safe-area-inset-top)，底部 env(safe-area-inset-bottom) |

### 交互行为

| 行为 | 实现 |
|------|------|
| 左右滑动 | touch events，带 momentum 和 snap |
| 圆点跟随 | 切换页面时更新 active dot |
| CTA 点击 | 非最后一页 → 前进到下一页；最后一页 → 调用 `window.onboardingComplete()` |
| 自动播放 | 无（用户主动滑动） |

### `window.onboardingComplete()` 回调

最后一页 CTA 点击时调用此函数。iOS 端通过 WKWebView 的 `WKScriptMessageHandler` 或 Superwall 的内置 close action 捕获。

默认实现（供预览）：
```javascript
window.onboardingComplete = window.onboardingComplete || function() {
  // iOS WKWebView: window.webkit.messageHandlers.onboardingComplete.postMessage({})
  // Superwall: 自动处理 close action
  console.log('Onboarding complete — ready for next step');
};
```

## 执行流程

### Step 1: 收集产品信息

向 PM 确认所有输入项。如果 PM 只给了产品名称，追问：
- "这个产品的核心卖点是什么？列出 1-3 个 feature，每个用一句话描述价值。"
- "有没有偏好的主色调？没有的话我根据品类自动选。"

### Step 2: 设计配色方案

根据产品品类和 PM 偏好，确定：
- **主色**（Primary）：渐变起点、CTA 文字色
- **深色**（Dark）：渐变终点
- **每页渐变变体**：略微旋转色相，让每页有区分度但保持统一感

参考配色方案：

| 品类 | 主色 | 渐变方向 |
|------|------|---------|
| 健身/健康 | #6C63FF → #3B1F8E | 135deg |
| 摄影/设计 | #FF6B6B → #8E1F3B | 135deg |
| 效率/工具 | #00C9A7 → #1F8E6C | 135deg |
| 教育/学习 | #4ECDC4 → #1F8E7A | 135deg |
| 社交/通讯 | #FF9F43 → #8E5B1F | 135deg |
| 通用 | #667EEA → #3B1F8E | 135deg |

### Step 3: 生成 HTML/CSS/JS

生成 `onboarding/` 目录下的三个文件。**关键质量要求：**

1. **CSS 全部使用 CSS 变量** — 方便后续调整配色
2. **响应式** — 适配 iPhone SE 到 iPhone 16 Pro Max 所有尺寸
3. **安全区适配** — 使用 `env(safe-area-inset-*)` 处理刘海和底部指示条
4. **触摸滑动流畅** — 使用 `touch-action: pan-y` + 自定义 touch handler，带 elastic overscroll
5. **无外部依赖** — 纯 HTML/CSS/JS，不引入任何第三方库
6. **性能** — 首屏渲染 < 100ms，动画全部使用 `transform` + `opacity`（GPU 加速）

### Step 4: 本地预览

生成完成后，引导 PM 预览：

**方式 A：浏览器预览（快速）**
```bash
open onboarding/index.html
```
在 Chrome DevTools 中开启设备模拟（iPhone 15 Pro），检查视觉效果。

**方式 B：模拟器 WebView 预览（真实）**
如果项目中有 iOS 代码，可以创建一个临时 WebView controller 加载 `index.html` 在模拟器中预览。

### Step 5: 迭代调整

PM 预览后可能要求调整：
- 配色调整 → 修改 CSS 变量
- 文案调整 → 修改 HTML 内容
- 卡片内容调整 → 修改 widget 卡片区域
- 增减页数 → 增减 slide section + 更新 JS 配置

每次调整后重新预览，直到 PM 满意。

### Step 6: 集成指引

PM 确认后，提供集成方式：

**方式 A：Superwall Flow（推荐）**
1. 将 `onboarding/` 目录上传到 Superwall Dashboard
2. 创建新 Paywall/Flow，选择 "Custom HTML"
3. 绑定到 `app_install` placement
4. CTA 的 close action 由 Superwall 自动处理

**方式 B：iOS WebView 直接嵌入**
1. 将 `onboarding/` 目录拷贝到 Xcode 项目的 Resources
2. 在 `OnboardingViewController` 中用 `WKWebView` 加载 `index.html`
3. 注册 `WKScriptMessageHandler` 监听 `onboardingComplete` 回调
4. 回调触发后 dismiss onboarding，进入主页面

提供 Swift 代码片段：

```swift
// OnboardingViewController.swift
import WebKit

class OnboardingViewController: UIViewController, WKScriptMessageHandler {
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "onboardingComplete")
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "onboarding") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onboardingComplete" {
            dismiss(animated: true)
        }
    }
}
```

## 验证标准

1. 在浏览器设备模拟或 iOS 模拟器中打开，页面正常渲染
2. 左右滑动流畅，有 momentum 和 snap 效果
3. 分页圆点正确跟随当前页
4. 每页包含 feature 标题 + 价值描述 + widget 卡片
5. 最后一页 CTA 点击触发 `onboardingComplete` 回调
6. 适配 iPhone SE（375pt）到 iPhone 16 Pro Max（430pt）
7. 安全区正确处理（刘海区域不被内容遮挡）

## 后续扩展（Phase 2）

- **Personalization Quiz 模式** — 交互式问卷收集用户偏好（如 Interior AI 的风格选择）
- **视频/Lottie 动画** — 在 widget 卡片区域嵌入产品演示视频或 Lottie 动画
- **A/B 测试** — 生成多套配色/文案变体，配合 Superwall 的 A/B 测试功能
- **数据追踪** — 在 JS 中埋点 page_view / swipe / cta_click 事件

## 复用说明

所有 0.1 产品都需要 onboarding 页面。此 skill 的输出可直接用于 Superwall Flow 或 iOS WebView，支持热更新和 A/B 测试。
