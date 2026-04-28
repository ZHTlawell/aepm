# ae-onboarding-integrate

> Scale Global 旗下 iOS 产品的 **Onboarding 全流程**技能 —— 合并原 `ae-onboarding-design`（HTML/CSS/JS 设计）能力 + 新增 `Welcome_XX` Pod 打包 + AB 变体注册 + Work Chain 集成 + 评分引导联动，沉淀 bible-ios-template + plant-app 实战模式。

## 问题陈述

0.1 产品上 TestFlight 前必须做 Onboarding。但 Scale Global 生态下的 Onboarding 不是简单一个 View，而是**一套约定严密的 AB 测试驱动体系**：

1. **Welcome 不是单个 View，是 Welcome_XX 独立 Pod**：
   - 每个 variant（`01` / `02` / `03`...）是完整独立 Pod，有自己的 SwiftUI 实现 + Language extension + Localizable + Assets
   - AB 分流 = 动态加载不同 Pod 的 VC class（`NSClassFromString("Welcome_\(memo)ViewController")`）
   - AI 如果做成单 VC + 配置切换，失去 Scale Global 的快速 A/B 迭代能力

2. **命名是硬约束**：
   - Pod 名 `Welcome_XX`（两位数 memo）
   - VC class 名 `Welcome_XXViewController`
   - 不按格式命名 = 动态加载失败 = 回落默认 variant = 本次 AB 无效

3. **VC 必须 inherit 基础 Pod 的 WelcomeViewController**：
   - `Welcome` 基础 Pod 定义 `WelcomeProtocol.swift` + `WelcomeViewController` 父类
   - 所有 variant VC inherit 这个父类 + 使用 `WelcomeDelegate` 协议
   - 直接继承 UIViewController 会导致 `as? WelcomeViewController.Type` 转换失败

4. **评分引导时机**（Apple Guideline 5.6.1 风险）：
   - `BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")` 必须在用户**完成** onboarding 后调
   - 且必须在 `completion`（dismiss VC）**之前**，否则评分弹窗挂不到 rootVC
   - AI 很容易弄反顺序或在 viewDidLoad 里调

5. **BCCache hasShownKey 跨变体共享**：
   - 所有 variant 共用 `WelcomeHasShownCacheKey` 标记
   - 用户看过 variant 01 后再切 variant 02 不会重复打扰
   - AI 如果给每 variant 独立 key，切换变体的用户看两次 onboarding

6. **多语言必须 Pod 独立**：
   - 每个 Welcome_XX Pod 自带 `Localizable/*.lproj`（参考 ae-i18n-integrate）
   - 写到项目主 Localizable.strings 会导致 Pod 独立分发时文案丢失

7. **HTML 原型 vs SwiftUI 实现是两套交付物**：
   - PM 在设计阶段审 HTML（快速迭代视觉）
   - Agent 实现阶段转 SwiftUI（最终交付）
   - 两者文案 + 配色 + 布局必须一致，否则 PM 审过的和用户看到的不一样

8. **AB default 和神策 control 组必须对齐**（继承自 ae-abtest-integrate 约束）：
   - 代码 `ABTestType.welcome.defaultValue = .string("01")`
   - 神策 control 组也必须返回 "01"
   - 不对齐 = 实验未 launch vs launch control 组用户看到不同 variant

这些约束散在 `Template/Core/StartupSequence/WelcomeWork.swift` + `Locals/Welcome` / `Welcome_01` / `Welcome_02` + `BCAppReviewPrompt` Pod + ABTestConfig 多处，AI 新接产品靠猜必踩。

## 解决方案

这个 skill **合并原 `ae-onboarding-design`** 能力，扩展为完整集成：

- **Phase 2 HTML 原型**（沿用原 ae-onboarding-design）：PM 审视阶段
- **Phase 3 Welcome_XX Pod 生成**：Podspec / VC / SwiftUI / ViewModel / Language extension / Localizable 全套模板
- **Phase 4 AB 变体注册**：ABTestType.welcome 默认值 + 神策后台协同
- **Phase 5 Work Chain 集成**：WelcomeWork 动态加载验证
- **Phase 6 评分引导**：BCAppReviewPrompt 联动
- **7 条硬性规则 + 8 条反模式 + 7 条故障排查 + 10 条已验证约束**

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| Variant 形态 | 独立 Pod（Welcome_XX）| Scale Global 生态统一，可独立迭代/分发 | 单 VC 配置切换：失去快速 A/B |
| 命名约定 | Pod `Welcome_XX` + VC `Welcome_XXViewController` | WelcomeWork 动态加载依赖字符串匹配 | 更灵活命名：加载失败 |
| hasShown cache | 跨 variant 共享单 key | 用户一生只看一次 onboarding | 每 variant 独立 key：切换变体重复打扰 |
| 设计 vs 实现 | 两阶段（HTML 原型 + SwiftUI 实现）| PM 快速视觉迭代 + 高质量最终交付 | 直接 SwiftUI：PM 审阅成本高 |
| 和 ae-onboarding-design 关系 | 合并 | 减少用户 skill 选择负担 | 并列：用户需选 design vs integrate，多一层决策 |
| 评分引导时机 | 用户完成 onboarding 后 + completion 前 | Apple Guideline 5.6.1 最佳实践 | 打开 onboarding 就弹：审核拒 + 转化率低 |

## 已放弃方案

### 方案 A: 单 VC 配置切换做 AB
- **是什么**：一个 `WelcomeViewController`，通过读 AB 配置切换文案/颜色
- **为什么放弃**：(1) 变体差异大（例：Welcome_01 是 3 页，Welcome_02 可能 5 页 + 新交互），配置切换难以覆盖结构差异 (2) 失去"每 variant 独立迭代"的速度 —— 改 variant_02 不能影响 variant_01 的稳定性

### 方案 B: 保留 ae-onboarding-design 独立
- **是什么**：设计和集成两个 skill 分开
- **为什么放弃**：用户做完 design 手里只有 HTML，还要再找 integrate skill 做 Pod 化，多一层决策。合并一个 skill 端到端，用户体验更顺。

### 方案 C: Onboarding 放在项目主 target（非独立 Pod）
- **是什么**：Welcome 代码直接写到项目 `Template/Feature/Welcome/` 下
- **为什么放弃**：Scale Global 约定所有 variant 用 Pod 分发（便于后续抽取到跨产品共享 / 被其他产品复用）。主 target 实现违反 TS-027。

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Welcome（基础 Pod） | Scale Global 内部 | 20% — 协议和父类 | 子 Pod 模板 + 命名约定 |
| SwiftUI `TabView(.page)` | Apple | 100% — 分页滚动 | 业务封装 |
| BCAppReviewPrompt | Scale Global 内部 | 100% — 系统评分弹窗 + 频控 | 调用时机约定 |
| BCCache | Scale Global 内部（BCUtils 子模块）| 100% — 本地缓存 | hasShown key 统一命名 |
| CL10nKit | Scale Global 内部 | 100% — 文案 API | 通用 ctext_continue / start_now 等 |

## FAQ

**Q: 原 ae-onboarding-design 还能用吗？**
A: 暂时保留（源码未删），但**建议直接使用 ae-onboarding-integrate**。后者包含 design 阶段 + 完整集成。ae-onboarding-design 会在龙哥审计本 skill 通过后下线（参考 ae-paywall-design 处理）。

**Q: Welcome_XX 的 XX 是两位数还是可以三位？**
A: 当前约定两位数（`01` / `02` / ...）。理论上 `100` 也能工作（`NSClassFromString` 字符串匹配不限长度），但 AB 后台配置 + 代码 switch case 习惯两位。超过 `99` 说明已上线 variant 太多，应清理旧的。

**Q: 可以同时保留 3+ variant 吗？**
A: 可以（神策支持多 variant 分流）。但一般 2 个 variant 即可（A/B 对照），多 variant 会摊薄每组样本量，统计显著性低。

**Q: PM 反悔，完成 onboarding 后想加挽留弹窗怎么办？**
A: 在 `seekGoodReview` 之前加挽留弹窗逻辑：
```swift
self.showRetentionOffer {  // 业务自己的挽留弹窗
    self.delegate?.seekGoodReview()
    self.completion(self)
}
```
`BCAppReviewPrompt` 和挽留弹窗是两个独立决策，按业务需要串联。

**Q: 如果产品没有 AB 需求，直接用 Welcome_01 就行吗？**
A: 也得走 AB 架构（`ABTestType.welcome` + syncFetchWecome），即使只有一个 variant。好处：
1. 未来要做 A/B 不用重构
2. 神策后台可以做"全量""流量切断"控制（紧急回退）

**Q: HTML 原型可以直接放进 WKWebView 实现吗？**
A: 可以（技术上），但不符合 TS-020（Scale Global iOS 架构要求 SwiftUI + BCHostingController）。ae-speckit-to-app 约束禁 WKWebView 实现主要 UI。HTML 只作为设计阶段产出。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目的 Onboarding 端到端 AI 自动化。从 HTML 设计到 Pod 化 + AB 集成 + 评分引导，每一步都有约定。
- **什么会让它过时**：
  - Apple 推出新 onboarding 规范（如 iOS 20 的系统级 Onboarding API）→ 重写
  - Scale Global 迁移到 React Native / 跨端方案 → Pod 机制不适用
  - AB 平台换（神策 → 其他）→ ABTestType 注册方式变

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，合并原 ae-onboarding-design + 新增 Pod 打包 / AB 注册 / Work Chain 集成 / 评分引导 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南（六段标准 + 8 Phase）|
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单 |

## 与 ae-onboarding-design 的关系

本 skill **合并并升级**原 `ae-onboarding-design`：

| 原 skill 能力 | 本 skill 处理 |
|--------------|--------------|
| HTML/CSS/JS 幻灯片原型 | ✅ 继承（Phase 2）|
| Superwall Flow / WebView 渲染 | ❌ 废弃（和 Scale Global SwiftUI 架构不符）|
| Pod 化 + AB 集成 | 🆕 新增（Phase 3-5）|
| 评分引导联动 | 🆕 新增（Phase 6）|

本 skill 发布后，`ae-onboarding-design` 建议下线（和 `ae-paywall-design` 一起，在龙哥审计后处理）。
