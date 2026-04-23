# ae-onboarding-integrate 用户场景验收清单

## 场景 1: 新产品首次接 Onboarding（典型路径）

- **前置**：Podfile 含 Welcome 基础 Pod + BCAppReviewPrompt，ae-abtest-integrate + ae-i18n-integrate 已完成。PM 提供产品简介 + 3 个核心 feature + memo `01`
- **用户说**："做 onboarding，3 页讲核心功能"
- **预期行为**：
  1. Phase 2 生成 HTML 原型（`onboarding/index.html + styles.css + script.js`）给 PM 审
  2. PM 审过视觉 + 文案
  3. Phase 3 生成 `Locals/Welcome_01/` Pod（Podspec + SwiftUI 实现 + Language + Localizable 多语言占位）
  4. Phase 4 `ABTestType.welcome.defaultValue = .string("01")` + 通知 PM 神策 control 组配 "01"
  5. Phase 5 Podfile 引入 + pod install + WelcomeWork 动态加载日志验证
  6. Phase 6 评分引导接入（`seekGoodReview`）
  7. Phase 7 真机冷启验证完整流程
- **验收标准**：
  - [ ] VC class 名严格 `Welcome_01ViewController`
  - [ ] VC inherit `Welcome.WelcomeViewController`
  - [ ] HTML 原型和 SwiftUI 实现视觉一致
  - [ ] 多语言 Localizable 占位已建（至少 10 种语言目录，en 有内容）
  - [ ] `BCAppReviewPrompt.tryToSystemScore(onboarding: true, "welcome")` 在 completion 之前调
  - [ ] 首次启动显示 → 完成后 BCCache 标记 → 二次启动跳过
  - [ ] 编译 BUILD SUCCEEDED
- **状态**：⏳ 未测试

## 场景 2: 加新 variant 做 A/B（增量路径）

- **前置**：已有 Welcome_01（上线运行），PM 要加 Welcome_02 做新文案对照
- **用户说**："onboarding 文案换一版对照"
- **预期行为**：
  1. Phase 1.5 确认：memo `02`（避免和 01 冲突）
  2. Phase 2 HTML 原型给 PM 审视觉
  3. Phase 3 生成 Welcome_02 Pod（独立目录 + 独立 Language key 前缀 `welcome_02_xxx`）
  4. Phase 4 神策后台 welcome 实验加 variant "02"，分流 50/50
  5. Phase 4 代码 defaultValue 不变（继续 "01"，除非 PM 决定切换默认）
  6. Phase 7 白名单设备验证 variant 切换
- **验收标准**：
  - [ ] Welcome_01 和 Welcome_02 两个 Pod 完全独立（不共享 UI/VM/Model）
  - [ ] 两个 Pod 的 `hasShownKey` 都是 `WelcomeHasShownCacheKey`（共享）
  - [ ] 白名单设备 variant "01" 看 Welcome_01，"02" 看 Welcome_02
  - [ ] 已看过 01 的用户切 02 不重复看（共享 cache）
- **状态**：⏳ 未测试

## 场景 3: 命名约定违反（反模式识别）

- **前置**：PM 要求 VC class 叫 `OnboardingViewController`（不按约定）
- **用户说**："VC 名字改成 OnboardingViewController 好看点"
- **预期行为**：Agent 拒绝并说明：
  > ❌ VC 名称必须严格 `Welcome_XXViewController`（XX = memo）。
  > 原因：WelcomeWork 用 `NSClassFromString("Welcome_\(memo)ViewController")` 动态加载，改名就找不到，fallback 到默认 variant，本次 AB 实验完全失效。
  > 
  > 如果只是希望"名字好看"，建议：
  > - Pod 内的 helper struct / sub-View 可以用 `OnboardingPage` 等
  > - 但入口 VC class 名不可改
- **验收标准**：
  - [ ] Agent 不按 PM 要求改
  - [ ] 说明具体后果（动态加载失败）
  - [ ] 给出"可自由命名"的范围（子组件）vs"必须固定"的范围（入口 VC）
- **状态**：⏳ 未测试

## 场景 4: 评分引导时机错（反模式识别）

- **前置**：Welcome_03 的 VC `viewDidLoad` 里直接调 `self.delegate?.seekGoodReview()`
- **用户说**：审计 / 用户投诉"onboarding 一打开就弹评分"
- **预期行为**：Agent 识别反模式第 4 条：
  > ❌ 在 viewDidLoad 调 seekGoodReview：用户还没完整看 onboarding 就被弹评分，转化率差 + App Review Guideline 5.6.1 "Don't harass users to rate your app" 风险。
  > 
  > ✅ 修复：在用户**完成** onboarding（点 Get Started）时调。顺序：
  > ```swift
  > self.delegate?.seekGoodReview()  // 1. 先准备评分
  > self.completion(self)            // 2. 再 dismiss VC
  > ```
  > 注意：completion 必须在 seekGoodReview 之后（否则 VC 已 dismiss，评分弹窗挂不到 rootVC）。
- **验收标准**：
  - [ ] Agent 定位到 viewDidLoad
  - [ ] 引用 Guideline 5.6.1
  - [ ] 给出正确的时机 + 顺序
- **状态**：⏳ 未测试

## 场景 5: hasShown key 重复（反模式识别）

- **前置**：PM 建议"加 variant 02 后让已看 01 的用户重新看 02"，让 Agent 给每 variant 独立 cache key
- **用户说**："每个 variant 单独记一次"
- **预期行为**：Agent 拒绝反模式第 3 条：
  > ❌ 每 variant 独立 hasShown key 会让 A/B 分流切换时的老用户反复看 onboarding，体验崩。
  > 
  > ✅ 共享 `WelcomeHasShownCacheKey` 是 Scale Global 约定的：用户一生只看一次 onboarding，AB 变体只影响"第一次看的是哪个版本"。
  > 
  > 如果 PM 想让老用户重新看新 variant，应该：
  > - 选 A：强制所有用户（一次性）重置 hasShownKey —— 通过 App Upgrade work 清除一次
  > - 选 B：做成"新功能引导"（不是 onboarding），独立 cache key
- **验收标准**：
  - [ ] Agent 不按 PM 要求独立 key
  - [ ] 说明共享 key 的设计意图
  - [ ] 给出两种业务替代方案
- **状态**：⏳ 未测试

## 场景 6: AB default 不对齐（跨 skill 问题）

- **前置**：新 variant 02 上线，代码 `ABTestType.welcome.defaultValue = .string("02")`，但神策后台 welcome 实验 control 组还是 "01"
- **用户说**：BI 报告"control 组用户行为异常"
- **预期行为**：Agent 识别跨 skill 依赖问题：
  > 违反 ae-abtest-integrate 硬性规则 4。
  > 代码默认 "02" vs 神策 control "01"，导致：
  > - 实验未 launch（服务端拉不到）：代码走 "02"
  > - 实验 launch 后 control 组：神策返回 "01"
  > 两边行为不一致 → 无法判断"实验生效了"还是"默认变了"。
  > 
  > 修复：PM 在神策后台把 control 组值改为 "02"（和代码对齐），或代码 defaultValue 改回 "01"（和神策对齐）。PM 业务决策为准。
- **验收标准**：
  - [ ] Agent 引用 ae-abtest-integrate 规则 4
  - [ ] 精确列出两边 default
  - [ ] 让 PM 做最终决策
- **状态**：⏳ 未测试

## 场景 7: Pod 文案写到项目主 Localizable（i18n 违反）

- **前置**：Welcome_03 的文案 key 不小心加到了 `Template/Resources/Localizations/en.lproj/Localizable.strings`
- **用户说**：审计 / 独立分发 Pod 时文案丢失
- **预期行为**：Agent 识别 i18n 反模式第 9 条：
  > ❌ Welcome_03 Pod 的文案应该在 `Locals/Welcome_03/Welcome_03/Localizable/*.lproj/Localizable.strings`（Pod bundle 内），不是项目主 Localizable。
  > 原因：Pod 独立分发给其他产品复用时，文案跟 Pod bundle 走，写在主项目会丢失。
  > 
  > 修复：
  > 1. 从 Template/Resources/Localizations/en.lproj/Localizable.strings 移除 welcome_03_xxx keys
  > 2. 加到 Locals/Welcome_03/Welcome_03/Localizable/en.lproj/Localizable.strings
  > 3. 其他语言同步（Phase 3.8 批量 bash）
- **验收标准**：
  - [ ] Agent 识别归属错误
  - [ ] 给出迁移步骤（移除 + 加入 + 同步）
  - [ ] 引用 ae-i18n-integrate 反模式第 9 条
- **状态**：⏳ 未测试

## 场景 8: 动态加载失败 fallback

- **前置**：新 Welcome_04 VC class 名写错（写成 `WelcomeZeroFourVC`），真机启动
- **用户说**："新版本 onboarding 上线了，用户看到的还是 01"
- **预期行为**：Agent 按 Phase 5.2 调试日志定位：
  > Xcode Console 应看到：
  > ```
  > 🎬 [Welcome] AB memo=04
  > ⚠️ [Welcome] dynamic load failed, falling back to default
  > 🎬 [Welcome] loaded Welcome_01ViewController   （default）
  > ```
  > 如果看到 `dynamic load failed`：VC class 名不对，检查 `Locals/Welcome_04/.../Controller/WelcomeViewController.swift`。
  > 必须是：`public class Welcome_04ViewController: WelcomeViewController`。
  > 
  > 修复后 `pod install` 重新编译。
- **验收标准**：
  - [ ] Agent 知道查调试日志（不瞎猜）
  - [ ] 定位到 class 名违反命名约定
  - [ ] 给出修复 + 重新编译步骤
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-8 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确阻塞原因和修复 PR
- 龙哥审计通过：
  - HTML + SwiftUI 双阶段交付模式合理
  - Welcome_XX Pod 结构（Podspec + VC + SwiftUI + ViewModel + Language + Localizable）是否标准
  - `hasShownKey` 跨 variant 共享策略
  - 评分引导时机（completion 前）
  - 和 ae-paywall-design / ae-onboarding-design 的合并下线策略

## 已解决阻塞项（杭州 Martinlehb 审计 2026-04-23，IJD7GE #note_49775397）

- [x] **P0-22 独立仓库非强制**：欢迎页之间不抽象共性逻辑，唯一接口 `WorkVoidCallbackTask` 协议；**可放业务仓库内，不强制独立 Pod 仓库**。SKILL.md Step 2.1 已提供两种组织方式（业务仓库模块 A / 独立 Pod B）。
- [x] **P0-23 memo 无长度限制**：memo 是 String，对长度/字符无硬性限制，用于拼接 VC 类名。SKILL.md 硬性规则 2 已标注。
- [x] **P0-24 频控全局统一**：`BCAppReviewPrompt` 频控规则所有项目共用，未开放项目级自定义配置，作为未来扩展点。SKILL.md 硬性规则 9 已标注。
- [x] **P0-25 HTML 全部删除**：杭州确认所有转化页/欢迎页**全部原生 SwiftUI 实现**，不使用 HTML / WebView 方案。原 Phase 2 HTML 原型阶段已删除，改为 Step 2.1 SwiftUI 目录骨架。反模式新增"用 HTML / WebView 方案"禁令。
- [x] **P0-26 hasShownKey 不可清除**：欢迎页在 App 全生命周期**只弹一次**，该 key 不可清除或重置。SKILL.md 硬性规则 4 + 反模式"清除 hasShownKey 让老用户重看"禁令已加。
- [x] **P0-16 第一版 en-only**：欢迎页各自独立，第一版仅 `en.lproj/`，variant 转化好再投多语。Step 3.8 多语言策略段已改写。
