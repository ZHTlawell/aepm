# Work Chain 12 步启动链

> 来源：bible-ios-template `Template/Core/StartupSequence/` 实际代码。
> 所有 `.swift.tmpl` 文件为**从真实代码提取的骨架**，占位符仅 `{{PRODUCT_NAME}}` / `{{MEMO}}`。

## 顺序约束

**必须严格按以下顺序串行执行**（TS-022）。任一步卡住，后续全断（04-15 trajectory "坑7"）。

```
01_ComponentConfigWork    → 网络/缓存/埋点/StoreKit/UI 等组件统一初始化
02_AdjustConfigWork       → Adjust 归因 SDK 初始化
03_DebugToolsConfigWork   → 调试工具（prod 自动关闭；WePray 已关闭 Debugger）
04_LegalPromptWork        → GDPR/隐私政策弹窗（首次启动必弹）
05_ABTestLoadWork         → 从 Sensors Analytics 拉取 AB 测试配置
06_UserInitWork           → 用户初始化（BCAccount.login via LaunchTransitionViewController）
07_AppUpgradeWork         → 应用升级检查（bible-app 中空实现）
08_AfterLoginWork         → 登录后：BCStoreKit.checkBegin + 非 VIP restore
09_DataPreloadWork        → 数据预加载（bible-app 中 group task 全部注释）
10_WelcomeWork            → 首次欢迎页（BCABTest 决定 Welcome_XX 变体）
11_ConversionPageWork     → 转化页/付费墙（非 VIP 时展示，AB 控制频率，单次会话避免叠加）
12_MainPageLoadWork       → 主界面加载（TabBarController as rootViewController）
```

## 各 Work 职责速查

| Work | 关键点 | 常见阻塞 |
|------|-------|---------|
| ComponentConfig | 11 个 config*() 方法按序调用；`BCPurchaseUIManager.purchaseService = self` | Pod 未装齐 |
| AdjustConfig | `BCAdjust.appDidLaunch(logEnable: false)` | Adjust token 未填 |
| DebugTools | WePray 已关闭，需要时取消注释 `BCTrack.registerDebugger()` / `CT().Debugger_Start()` | — |
| LegalPrompt | `LegalPrompt.open(BCConsts.appName, theme:, completion:)` | LegalPrompt Pod 缺失 |
| ABTestLoad | `await BCABTest.shared.preload(types: ABTestType.preloadTypes, force: true)` | 后端不可达 |
| UserInit | `LaunchTransitionViewController.show(title:, completion:)`，内部 BCAccount.login | **最高频阻塞**：后端 504 / login 超时 |
| AppUpgrade | 默认空，按需加版本对比逻辑 | — |
| AfterLogin | `BCStoreKit.checkBegin()` + 非模拟器非 VIP `BCStoreKit.restore()` | StoreKit Sandbox 未配 |
| DataPreload | 产品自定义（CareDataManager / BibleDataManager 等） | 本地 json 资源缺失 |
| Welcome | `BCABTest.shared.syncFetchWecome()` → 动态加载 `Welcome_{memo}ViewController`；ObjC runtime 需 `@objc(Welcome_XXViewController)` | Welcome_01 未在 Xcode target |
| ConversionPage | `BCPurchaseUIManager.open(type:.addChild, info:, from:, completion:)`；单次会话避免叠加（`hasShownOnboardingPaywallThisSession` UserDefaults 标记消费一次） | BCPurchaseUI 分支不匹配（F4） |
| MainPageLoad | `window.rootViewController = TabBarController()` | TabBarController 没注册 Tab |

## 对接点（harness 关注）

1. **Speckit → DataPreloadWork**：根据 Speckit Data 模块定义的本地/远程资源，填充 `DataPreloadWork.work` 内的 task group
2. **Speckit → WelcomeWork**：Speckit Onboarding 页数决定 `Locals/Welcome_01/` 内 `OnboardingFlow` 的 slide 列表
3. **Speckit → ConversionPageWork**：Speckit Paywall 模块决定 `PurchaseUI{{MEMO}}ViewController` 的 skuIds / paywallTitle
4. **Speckit → MainPageLoadWork**：Speckit IA 的 Tab 数量 + 图标对应 `TabbarItemType` 枚举

## 已知 TODO

- `templates/work-chain/09_DataPreloadWork.swift.tmpl` 当前为占位骨架，需根据 Speckit Data 模块补充 task group
- `templates/work-chain/07_AppUpgradeWork.swift.tmpl` 若产品有版本强升需求需自行实现
