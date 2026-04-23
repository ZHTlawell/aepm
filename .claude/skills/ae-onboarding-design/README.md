# ae-onboarding-design

> 填补 PM 独立产出 App Store 级 Onboarding 页面的能力 gap，不依赖设计师和前端开发。

## 问题陈述

0.1 产品（快速验证阶段的 MVP）都需要 Onboarding 引导页，但当前流程有三个痛点：

1. **人力瓶颈** — PM 想做精美的 onboarding 幻灯片，必须找设计师出图 + 前端切页面，一套下来 2-3 天。0.1 产品追求的是"一天跑通验证"，等不起
2. **风格割裂** — PM 自己用 SwiftUI 写的 onboarding 和后续的 Superwall paywall 风格不统一，用户第一印象大打折扣
3. **无法热更新** — Native 写死的 onboarding 改文案/配色都要重新发版，无法做 A/B 测试

## 解决方案

用 HTML/CSS/JS 生成 Onboarding 幻灯片，采用 **Bevel Carousel 模式**（渐变背景 + 圆角 widget 卡片 + 分页圆点 + CTA），输出标准 `onboarding/` 目录。

核心机制：
- **纯前端，零依赖** — 不引入任何第三方库，纯 HTML/CSS/JS，任何 WebView 都能渲染
- **CSS 变量驱动** — 换产品只需改几个 CSS 变量（主色、渐变方向），10 分钟复用
- **双集成路径** — 可直接嵌入 iOS WKWebView，也可上传到 Superwall 作为 Custom HTML Flow
- **回调桥接** — 通过 `window.onboardingComplete()` 与 Native 层通信，WKScriptMessageHandler 或 Superwall 自动捕获

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| HTML vs SwiftUI | HTML/CSS/JS | 可被 Superwall 托管实现热更新和 A/B 测试，Native 无法做到 | SwiftUI Native — 无法远程更新，每次改动需发版 |
| Bevel Carousel 模式 | 渐变背景 + 圆角卡片 | 这是 App Store 精品 App 的主流 onboarding 风格（Bevel、Calm、Headspace），用户熟悉度高 | 全屏截图轮播 — 过于简单，无法体现设计品质 |
| 触摸滑动实现 | 原生 touch events + snap | 零依赖，控制力强，momentum + elastic overscroll 体验流畅 | Swiper.js — 引入 200KB 外部依赖，且 Superwall 环境下可能有加载问题 |
| 动画全部 transform + opacity | GPU 加速 | 首屏渲染 < 100ms，60fps 流畅滑动 | 使用 left/top 属性 — 触发 layout reflow，卡顿明显 |
| 配色方案按品类预设 | 6 个品类预设 + 自定义 | PM 不提供色调时仍能快速生成，减少决策疲劳 | 完全自由选择 — PM 非设计师，选色困难 |
| 安全区适配 | env(safe-area-inset-*) | 刘海屏和底部指示条不遮挡内容 | 固定 padding — 不同机型表现不一致 |

## 已放弃方案

### 方案 A: Lottie 动画驱动
- **是什么：** 每页用 Lottie JSON 动画展示 feature，视觉效果更丰富
- **为什么放弃：** 需要设计师用 After Effects 制作动画文件，违背"PM 独立产出"的目标。作为 Phase 2 扩展保留

### 方案 B: React/Vue SPA
- **是什么：** 用前端框架构建 onboarding 页面
- **为什么放弃：** 引入构建工具链（webpack/vite），PM 环境复杂度大增。Superwall Custom HTML 环境不支持 SPA 路由。纯 HTML/CSS/JS 足够满足 2-3 页幻灯片的需求

### 方案 C: SwiftUI Native 实现
- **是什么：** 用 SwiftUI TabView + PageTabViewStyle 原生实现
- **为什么放弃：** 无法被 Superwall 托管，意味着改文案/配色都需要重新编译发版。HTML 方案支持热更新和 A/B 测试，是 0.1 产品验证阶段的核心需求

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| 幻灯片交互 | 自建（原生 touch events） | 100% 自建 | Swiper.js 是主流方案但引入依赖，我们选择零依赖实现 |
| 页面托管 | Superwall Custom HTML | 托管层 | Superwall 提供远程配置和 A/B 测试，我们提供页面内容 |
| iOS 桥接 | WKScriptMessageHandler | Apple 原生 API | 标准化回调接口 `onboardingComplete()` |

## FAQ

**Q: 和 Superwall 内置的 onboarding 模板什么区别？**
A: Superwall Free 计划不支持 Custom HTML，只能用内置模板（样式固定、无法定制）。升级到 Pro 后可以上传我们生成的 HTML，获得完全自定义的视觉效果 + A/B 测试能力。

**Q: 生成的页面能在 Android 上用吗？**
A: 可以。输出是标准 HTML/CSS/JS，Android WebView 同样能渲染。但当前集成指引只覆盖 iOS（WKWebView + Superwall iOS SDK），Android 集成需自行适配。

**Q: 页面不好看怎么调？**
A: 配色改 CSS 变量，文案改 HTML，布局改 CSS。每次修改后 `open onboarding/index.html` 在 Chrome 设备模拟中实时预览，无需编译。

**Q: 为什么不用 Figma 出设计稿？**
A: 0.1 产品阶段不值得投入设计资源。本 skill 的定位是"足够好的标准化方案"，等产品验证通过后再投入专业设计。

## 生命周期

- **填补的 gap：** PM 无法独立产出精美的 Onboarding 页面，必须依赖设计师和前端。0.1 产品验证阶段无法承受这个人力和时间成本
- **什么会让它过时：** 当 Superwall 或类似平台提供高质量的可视化 Onboarding 编辑器（拖拽式），PM 可以在 Dashboard 直接设计页面而无需生成 HTML 代码

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-04-07 | 首版。Bevel Carousel 模式，渐变背景 + 圆角 widget 卡片 + 分页圆点 + CTA。无外部依赖，响应式适配 iPhone SE ~ 16 Pro Max (#IHXLWQ) |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：收集产品信息 → 设计配色 → 生成 HTML/CSS/JS → 预览 → 集成 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、生命周期 |
