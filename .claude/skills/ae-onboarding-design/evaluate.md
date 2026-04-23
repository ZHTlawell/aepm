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

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 49.96s（仅 2 个 story 实际执行 skill 逻辑）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| S1: 完整信息生成 | 0/5 | 180.0s | 生成耗时超限（180s vs 上限 90s），TIMEOUT 无输出 | 核心生成路径完全失败，无法评估输出质量 |
| S2: 信息不足追问 | 5/5 | 16.5s | — | 正确识别信息缺失，追问了简介、feature 列表、主色调，未冒然生成 |
| S3: 单 feature + 响应式 | 0/5 | 44.5s | API rate limit | "You've hit your limit"——环境问题，非 skill 逻辑缺陷 |
| S4: 代码质量验证 | 0/5 | 4.4s | API rate limit | 同上，无法评估 CSS 变量/动画/滑动等质量指标 |
| S5: 集成指引输出 | 0/5 | 4.4s | API rate limit | 同上，无法评估 Superwall/WKWebView 指引质量 |

## 瓶颈分析
- **P0 — API 配额耗尽导致 3/5 story 无法执行**: Story 3-5 全部因 rate limit 失败，这是测试环境问题而非 skill 本身缺陷。**建议**: 下次测试拉长间隔或分多轮执行，确保配额充足；或在评测脚本中加 rate-limit 检测，命中时标记为 `SKIPPED` 而非 `FAIL`。
- **P0 — 核心生成路径超时**: Story 1 是 skill 最关键的 happy path（完整输入 → 直接生成），耗时 180s 远超 90s 上限且最终 TIMEOUT 无输出。**建议**: 排查是 LLM 生成 token 量过大（3 文件全量输出）还是工具调用链过长；考虑将 CSS/JS 模板化，仅让 LLM 填充文案和配色变量，大幅减少生成 token 数。
- **P1 — 有效测试覆盖率过低**: 5 个 story 中仅 2 个实际执行了 skill 逻辑（S1 超时、S2 通过），代码质量（S4）、边界情况（S3）、集成指引（S5）均未得到验证。**建议**: 修复环境问题后优先补跑 S3/S4/S5，尤其是 S4（代码质量）决定了 skill 的实际可用性。

## 结论
Skill 的追问逻辑（S2）表现完美，但核心生成路径（S1）超时失败，加上 3/5 story 因 API 配额耗尽未能执行，当前评估置信度极低。**最高优先级**: 解决生成超时问题（模板化降低 token 量）；然后在配额充足的环境下重跑全部 5 个 story，才能给出可靠的 skill 质量判定。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 1/5 (20%) | 49.96s（仅 2 个 story 实际执行 skill 逻辑） |
