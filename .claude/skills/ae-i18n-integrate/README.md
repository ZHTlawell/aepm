# ae-i18n-integrate

> Scale Global 旗下 iOS 产品的**多语言**全流程技能 —— 基于内部 `CL10nKit` + `BCLocalization` + 开源 `Localize_Swift` 四层生态，沉淀 bible-ios-template + plant-app 实战代码。

## 问题陈述

0.1 产品做完英文 V1 要出海，必须做多语言。但 Scale Global 生态下接多语言有几个非直觉约束：

1. **不该自己用 NSLocalizedString，该用分层 Language 封装**：
   - CL10nKit Pod 已内置 310+ 通用文案 `ctext_xxx`（cancel / ok / save / loading / retry / ...）
   - 项目只加**业务专属** key（带产品前缀，如 `wepray_chat_placeholder`）
   - Pod 级专属文案定义在该 Pod 自己的 Language extension（如 Welcome_01 的 `welcome_01_title`）
   - AI 如果按 Apple 官方文档走 `NSLocalizedString`，会和生态脱节，失去 CL10nKit 的通用文案复用，也失去 BCLocalization 的 Locale 扩展（日期/数字/货币格式化）

2. **埋点和展示的本地化策略完全相反**：
   - 展示给用户：走 `Language.text(for:)`（跟随用户当前语言）
   - 埋点事件名 / parameter key / 枚举 value：**必须英文硬编码**（跨地区后台数据聚合需要统一 key）
   - AI 很容易错地用 `Language.xxx` 做 event name，导致用户切中文后事件名变中文，BI 无法聚合数据

3. **Scale Global 标准支持 10 语言**：
   - 基于老 Pod（BCAppSearch / DeleteAccountPage）的 `.lproj` 目录推断：en / de / es / fr / it / ja / nl / pt-BR / zh-Hans / zh-Hant
   - 新产品通常起步只有 en（参考 bible-ios-template），要扩展到全量很机械但容易漏

4. **多 Pod 语言覆盖必须一致**：
   - 项目主 strings + 所有 Locals/* Pod 的 strings 都要补齐同样语言
   - 部分覆盖（主界面翻了、onboarding 没翻）会让用户看到"半翻译"体验
   - bible-ios-template 当前就是这样：项目主只有 en，Welcome_01 / Welcome_02 也只有 en，但 BCAppSearch / DeleteAccountPage 有 9 语言

5. **InfoPlist.strings 是独立文件**：
   - `NSCameraUsageDescription` / `NSUserTrackingUsageDescription` 等系统权限弹窗文案不在主 Localizable.strings
   - 每种语言必须独立翻译（系统不 fallback 英文，缺失会显示空字符串或崩）

6. **`remove_unused_localized_keys.py` 脚本路径写死 plant 项目**：
   - 当前 `Scripts/remove_unused_localized_keys.py` 是从 plant-app 直接拷贝的，三个路径变量写死
   - 每个产品都要改，或本 skill 通用化（加 argparse）

这些约束散在 `Template/Resources/Localizations/` + `Locals/*/Localizable/` + `Pods/CL10nKit` + `Pods/BCLocalization` 多处，AI 新接产品时靠猜必踩坑。

## 解决方案

这个 skill 把 Scale Global 生态 + bible-ios-template 实战模式沉淀成标准流程：

- **文案分层决策树**：通用去 CL10nKit / 项目业务去 Template Language / Pod 专属去各 Pod
- **批量多语言扩展脚本**：Phase 3.1-3.2 两行 bash 把项目主 + 所有 Locals Pod 语言目录一键扩到 10 种
- **InfoPlist.strings 全覆盖**：Phase 4 系统权限文案每种语言补齐
- **埋点英文一致性扫描**：Phase 5.3 grep 误用 `BCTrack.track(Language.xxx)` 的位置
- **7 条硬性规则 + 9 条反模式 + 8 条故障排查 + 10 条已验证约束**

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 技术栈 | CL10nKit + BCLocalization（生态内） | Scale Global 统一，通用文案共享红利 | 纯 Apple NSLocalizedString：失去 Pod 级通用文案 + 日期/数字扩展 |
| 文件格式 | `.strings`（老格式，每语言一个目录）| CL10nKit 生态和所有老 Pod 用的都是 `.strings` | `.xcstrings`（Xcode 15+ 新格式）：生态不支持，迁移成本高 |
| 通用文案归属 | CL10nKit Pod 集中维护 | 跨产品共享，更新一次所有产品受益 | 每个项目自己维护：重复定义，更新不同步 |
| 埋点文案策略 | 事件名英文硬编码，parameter value 枚举英文硬编码 | BI 后台跨地区数据聚合 | 埋点也本地化：无法聚合 |
| 支持语言 | Scale Global 标准 10 语言 | 出海主要市场覆盖 | 按需加减：每个产品各自判断，PM 决策 |
| `remove_unused_localized_keys.py` | 通用化（加 argparse）| 多项目复用 | 各项目自己维护 copy：版本漂移 |

## 已放弃方案

### 方案 A: 纯 Apple NSLocalizedString + .xcstrings
- **是什么**：完全用 Apple 原生 API，放弃 CL10nKit 生态
- **为什么放弃**：(1) 失去 310+ 通用文案共享；(2) 和 Locals Pod（用 `Language.xxx`）不兼容；(3) `.xcstrings` Xcode 15+ 才支持，生态大量老 Pod 用 `.strings` 迁移成本高

### 方案 B: 全部文案堆在项目主 Language.swift
- **是什么**：不分层，所有 key（通用 + 业务 + Pod）都在 Template/Resources/Localizations/Language.swift
- **为什么放弃**：Pod 分发时带不上自己的文案（Welcome_01 Pod 独立发布时 Language 找不到 key），而且通用 key 每个产品自己定义 = 重复劳动

### 方案 C: 一次性扩展所有 10 语言 + 全部翻译完成
- **是什么**：本 skill 包含 AI 翻译或专业翻译集成
- **为什么放弃**：翻译是 PM 级业务决策（找哪家翻译公司 / 预算 / 审校流程），AI 翻译质量不稳定。本 skill 只交付"骨架 + 英文占位"，翻译由 PM 组织

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Localize_Swift | 开源 | 40% — 底层查表 + 动态语言切换 | 通过 BCLocalization / CL10nKit 间接使用 |
| BCLocalization | Scale Global 内部（1.6.1）| 20% — Locale/Date/Number 扩展 | LocaleInfo / BCAppLanguage 应用语言管理 |
| CL10nKit | Scale Global 内部（1.10.2）| 80% — 通用文案 `ctext_xxx` 注册表 + `Language.text/enText` API | 项目业务 key 分层 + 多语言扩展流程 + 埋点一致性 |

## FAQ

**Q: 我们产品只有英文市场，不需要做多语言吧？**
A: 现在不做，迁移成本小（硬编码字符串改 `Language.ctext_xxx` 是机械替换）。等 V1 上线后再出海，全代码 grep 改字符串成本高。建议：**Phase 1-2 立刻做**（规范化 key 分层 + 消灭硬编码），**Phase 3-4 等出海决策后再做**（扩展多语言目录 + 翻译）。

**Q: 翻译质量怎么保证？**
A: 本 skill 不负责翻译。Phase 3.4 会给 PM 输出"待翻译文件清单"，PM 组织翻译（专业翻译 / AI 翻译 / 社区翻译）。建议首批出海市场用专业翻译保质量，扩展市场可 AI 翻译 + 人工抽查。

**Q: 新 Pod（如 loopcraft 自己的 LoopModule）的文案要放哪？**
A: 该 Pod 自己的 Language extension + 自己的 Localizable.strings（跟 Pod bundle 分发）。例：`Pods/LoopModule/Classes/Language.swift` 定义 `Language.loop_module_xxx`，对应 `Pods/LoopModule/Localizable/*.lproj/Localizable.strings`。**不要**写到项目主 Language.swift。

**Q: `remove_unused_localized_keys.py` 误删业务正在用的 key 怎么办？**
A: 脚本只扫 `Language.static_var_name` 匹配，漏检动态 key（`Language.text(for: dynamicKey)`）。跑之前先 dry-run 输出删除列表，手动 review；有动态 key 用法的项目加白名单或跳过脚本。

**Q: ASC App Store 元数据（应用标题 / 描述 / 关键词 / 截图文案）怎么多语言？**
A: 不在本 skill 范围，走 `/ae-asc-submit`（ASC 提审 skill）。App Store 元数据和 App 内文案是分开的系统（ASC 后台或 fastlane deliver 管理）。

**Q: 拉丁美洲西班牙语（es-419）要不要和欧洲西班牙语（es）分开？**
A: Scale Global 当前只有 `es`（没细分），按 PM 出海市场需求决定。iOS 如果只提供 `es.lproj`，拉美用户也会 fallback 到 `es`，一般够用。细分后要双倍翻译成本 + 维护。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目接多语言的 AI 自动化能力。bible-ios-template 起步 en-only、plant-app 已有 10 语言的现状，应抽象成标准扩展流程。
- **什么会让它过时**：
  - Apple `.xcstrings` 成为生态标准（Scale Global 迁移）→ 文件格式和工具链重写
  - CL10nKit 重构为更动态的文案加载（如从服务端拉）→ 分层策略要重写
  - 更多 Locals Pod 加入但语言不统一 → 需要强约束或 CI 检查

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，基于 bible-ios-template + plant-app 审计 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南（六段标准 + 8 Phase）|
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单 |
