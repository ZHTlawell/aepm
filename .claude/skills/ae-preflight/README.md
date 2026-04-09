# ae-preflight

> iOS 项目从"能跑"到"能发布"之间存在 10+ 项隐性检查，ae-preflight 把这些检查自动化并前置到发布流水线的第一关。

## 问题陈述

PM 用 vibe coding 生成的 iOS demo 能在模拟器上跑，但离 TestFlight/App Store 发布还有大量隐性阻塞项：

1. **签名配置缺失** — DEVELOPMENT_TEAM 空、Bundle ID 含 "Demo"、Xcode 未登录 Apple ID。这些问题在 `xcodebuild build` 时才暴露，而 PM 通常只在 Xcode GUI 里按 Run
2. **敏感信息泄露** — ae-dev 生成的代码可能硬编码 API Key（如 `sk-proj-...`），Secrets.plist 被 git track，.gitignore 缺失或不完整
3. **合规项遗漏** — PrivacyInfo.xcprivacy 自 2024 年起必须包含，Info.plist 权限声明与代码使用不一致会导致运行时 crash 或审核被拒
4. **资产不完整** — 无 App Icon（Archive 上传直接被拒）、无 Launch Screen 配置
5. **问题发现太晚** — 上述问题通常在 Archive/Upload 阶段才暴露，此时 PM 已经花了 30-60 分钟做签名配置，反复被打回的挫败感极强

核心矛盾：**PM 不知道要查什么，agent 不知道该查到什么程度。** 人肉 checklist 容易遗漏且无法验证，需要一个结构化的自动扫描方案。

## 解决方案

一个 7-Phase 的自动化预检 skill，定位为发布供应链的第一个模块：

1. **实际执行验证** — 所有检查通过命令行工具实际执行（`xcodebuild build`、`grep`、`sips`、`find`），不是读代码猜测
2. **三级分类输出** — BLOCKERS（必须修复）/ WARNINGS（建议修复）/ PASSED（已通过），PM 一目了然
3. **自动修复 + 人工确认分离** — 纯技术项（如生成 .gitignore）直接修，业务决策项（如最终 Bundle ID）需 PM 确认
4. **constraint_candidates 回写** — 扫描发现的通用问题转化为约束候选，供 ae-postflight 写入 CLAUDE.md，防止下次 demo 再犯同样的错
5. **publish-state.yaml 持久化** — 扫描结果写入项目文件，跨 session 保持状态，后续模块可读取前序结果

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 验证方式 | 实际执行命令 | "编译通过"必须是 `BUILD SUCCEEDED`，不是"看起来能编译"。grep 零匹配才是"无硬编码"，不是"Config.swift 看起来用了 plist" | 静态分析 / 读代码推断 — 误报率高，PM 不信任结果 |
| 报告格式 | 终端表格（BLOCKERS/WARNINGS/PASSED） | PM 需要在终端里直接看到该做什么，不需要打开额外文件 | JSON 输出 — 机器友好但 PM 读不了；Markdown 文件 — 需要额外打开 |
| 自动修复策略 | 技术项直接修，业务项确认后修 | .gitignore 生成无需讨论，但 Bundle ID 最终值是业务决策 | 全部自动修复 — 业务决策不能由 agent 单方面做；全部手动 — 纯技术项不值得打断 PM |
| 状态持久化 | publish-state.yaml | 供应链 5 个模块需要跨 session 共享状态（preflight 的 blockers 影响 apple-identity 的执行路径） | 内存传递 — 跨 session 丢失；数据库 — 过重 |
| 隐私合规范围 | PrivacyInfo + Info.plist 权限 + 合规弹窗 | 这三项覆盖了 App Store 审核最常被拒的隐私原因 | 全面合规审查（含 GDPR/CCPA 逐条） — 对 V0 原型过重，正式合规应由法务介入 |
| App Icon 验证深度 | file 类型 + sips 尺寸 + xcassets 路径 | 三步验证排除"有文件但格式不对"或"文件不在 xcassets 中"的假通过 | 只检查文件是否存在 — 遇到过 SVG 被当成 PNG 放入 xcassets 的情况 |

## 已放弃方案

### 方案 A: Fastlane precheck
- **是什么：** 用 Fastlane 的 precheck action 做 App Store 合规检查
- **为什么放弃：** Fastlane precheck 主要检查 App Store 元数据（描述、截图、关键词），不检查代码层面的签名、秘钥泄露、PrivacyInfo 等问题。与我们的需求互补但不替代

### 方案 B: Xcode Analyze
- **是什么：** 用 `xcodebuild analyze` 做静态分析
- **为什么放弃：** Xcode Analyze 关注的是内存泄漏、逻辑错误等代码质量问题，不覆盖签名配置、资产完整性、隐私合规等发布就绪检查

### 方案 C: 统一到 ae-ship 中
- **是什么：** 不做独立 preflight，在 Archive/Upload 流程中遇到问题再修
- **为什么放弃：** Archive 一次要 3-5 分钟，每次失败打回再改再 Archive 的循环让 PM 极其沮丧。前置检查 30 秒跑完，节省的是后续的反复折腾

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| 签名检查 | xcodebuild + security（Apple 原生工具） | 100% | 将离散命令编排为结构化扫描流程 |
| 秘钥扫描 | grep 正则匹配 | 70% | 针对 ae-dev 生成的常见模式（sk-proj-、sk-live-）定制正则，减少误报 |
| 图片验证 | sips（Apple 原生工具） | 100% | 与 xcassets 路径交叉验证，排除"文件存在但未被项目引用" |
| 合规检查 | 手工 grep | 50% | 针对 App Store 2024+ 新规（PrivacyInfo.xcprivacy）定制检查逻辑 |
| 发布状态管理 | 自建（publish-state.yaml） | — | 供应链 5 模块共享的跨 session 状态协议 |

## FAQ

**Q: preflight 和直接 `xcodebuild build` 有什么区别？**
A: `xcodebuild build` 只告诉你编译失败，不告诉你为什么以及怎么修。preflight 在编译之前先扫描 10+ 项常见问题，给出具体的修复方案和操作步骤。编译验证是 preflight 的最后一步，不是唯一的一步。

**Q: constraint_candidates 是什么？谁消费它们？**
A: 扫描中发现的"下次 demo 生成时应该避免的问题"（如硬编码 API Key、Bundle ID 含 Demo）。ae-postflight（供应链最后一个模块）会读取这些候选项，经 PM 确认后写入项目 CLAUDE.md，形成约束闭环。

**Q: publish-state.yaml 会不会被 git commit？**
A: 应该 commit。它是项目的发布状态记录，后续 session 和其他供应链模块需要读取。但 publish-state.yaml 中不含敏感信息（无密码、无 token）。

**Q: 为什么不支持 Manual Signing 项目？**
A: 支持但检查项更多（需要 Provisioning Profile 文件）。对 PM 而言，Automatic Signing 是最佳路径——让 Xcode 自动管理，减少人工操作。preflight 会检测 Signing Style 并给出建议。

## 生命周期

- **填补的 gap：** PM 从 vibe coding demo 到 TestFlight 发布之间没有系统化的质量关卡。签名、秘钥、合规、资产等检查全靠经验和运气
- **什么会让它过时：** 当 ae-dev 生成的 demo 能保证开箱即 production-ready（签名预配置、无硬编码、PrivacyInfo 内置），preflight 的大部分检查项将变成 PASSED。但签名验证（需要实际编译确认）和 Xcode 账号检查（需要人工登录）短期内不会被消除

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-04-09 | 首版。7 Phase 完整流程（项目识别→签名→秘钥→隐私→资产→报告→自动修复→状态持久化）。bible-app (Faithful Guide) 实跑验证，模拟器 BUILD SUCCEEDED。#II8UYE |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：7 Phase 扫描流程 + 报告模板 + 自动修复方案 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、生命周期 |
