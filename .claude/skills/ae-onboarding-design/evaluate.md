# ae-onboarding-design 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-onboarding-design

## Test Stories

### Story 1: 提供完整信息生成 Onboarding 页面
- **Prompt**: "帮我生成 ShoeLens 的 onboarding 页面，产品是 AI 球鞋鉴定工具，核心 feature：1. 拍照即鉴 — 一秒识别真伪；2. 价格追踪 — 实时掌握市场行情；3. 社区交流 — 和球鞋爱好者分享心得。主色调 #FF6B35"
- **Expect**: Skill 不需追问，直接生成 `onboarding/` 目录包含 index.html、styles.css、script.js 三个文件。HTML 包含 3 个 slide 页面，每页对应一个 feature，有标题+副标题+widget 卡片。CSS 使用 CSS 变量驱动配色（主色为 #FF6B35），有渐变背景和 backdrop-filter 毛玻璃效果。JS 实现 touch 滑动+分页圆点+CTA 按钮，最后一页 CTA 调用 `window.onboardingComplete()`。
- **Max Time**: 90s

### Story 2: 仅提供产品名称的追问交互
- **Prompt**: "帮我做个 onboarding 页面，产品叫 Bevel"
- **Expect**: Skill 识别信息不足，主动追问核心 feature 列表和价值描述，可选追问主色调偏好。不应在信息不完整时直接生成页面。待用户补充后再开始生成。
- **Max Time**: 30s

### Story 3: 指定极端设备尺寸验证响应式
- **Prompt**: "生成 FitTrack 的 onboarding，是健身追踪 App，feature 只有 1 个：AI 动作纠正。帮我确认在 iPhone SE 上能正常显示"
- **Expect**: Skill 处理只有 1 个 feature（即 1 页 slide）的边界情况，生成的 HTML/CSS 包含 `env(safe-area-inset-*)` 安全区适配，CSS 使用相对单位和弹性布局确保 375pt 宽度下内容不溢出、不截断。生成后引导用户用 Chrome DevTools 设备模拟 iPhone SE 预览。
- **Max Time**: 90s

### Story 4: 输出代码质量验证
- **Prompt**: "帮我生成 MindFlow 的 onboarding，冥想 App，3 个 feature：1. 引导冥想 — 跟着呼吸放松身心；2. 睡眠音乐 — 白噪音助眠；3. 情绪日记 — 记录每天的心情变化。要求像 Calm 那种风格"
- **Expect**: 生成的代码满足以下质量要求：(1) CSS 全部通过 CSS 变量（`--primary-color` 等）控制配色；(2) 无任何外部 CDN 或第三方库依赖；(3) 动画使用 `transform` + `opacity` 实现 GPU 加速；(4) 触摸滑动有 momentum 和 snap 效果；(5) 分页圆点正确反映当前页；(6) 最后一页 CTA 文案为 "Get Started"，前两页为 "Continue"。
- **Max Time**: 90s

### Story 5: 集成指引输出——Superwall 和 WKWebView
- **Prompt**: "onboarding 生成好了，我想用 Superwall 部署，帮我出个集成指引"
- **Expect**: Skill 提供两种集成方式的完整指引：(1) Superwall Flow 方式——上传目录、创建 Custom HTML、绑定 `app_install` placement；(2) iOS WKWebView 方式——包含完整的 Swift 代码片段（OnboardingViewController + WKScriptMessageHandler），监听 `onboardingComplete` 回调。指引应可直接复制使用。
- **Max Time**: 60s

You've hit your limit · resets 2am (Asia/Shanghai)

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
