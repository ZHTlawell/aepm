# ae-app-to-testflight

> PM 手上只有一个能本地跑的 demo，从零到 TestFlight 之间的每一步都有术语壁垒，ae-app-to-testflight 用浏览器自动化 + 逐步引导消除这个壁垒。

## 问题陈述

PM 完成 vibe coding 拿到一个本地可运行的 iOS demo 后，要将它分发给团队试用，需要经过：

1. **App ID 注册**（Apple Developer Portal） — PM 不知道什么是 App ID、Bundle ID、Team ID，也不知道要去哪个网站操作
2. **App Store Connect 创建 App** — 需要在另一个网站上创建 App 记录，填写 SKU、选择 Bundle ID
3. **Xcode 签名配置** — DEVELOPMENT_TEAM、CODE_SIGN_STYLE、Provisioning Profile 等概念对 PM 完全陌生
4. **Archive + Upload** — 构建目标必须选 "Any iOS Device"（不能选模拟器），Distribute 选项有 4-5 种，选错了不会报错但上传不到 TestFlight
5. **TestFlight 分发** — 内部测试 vs 外部测试 vs 公开链接，各自的审核要求和生效时间不同

核心矛盾：**Apple 的发布流程面向专业开发者设计，每一步都假设用户懂 iOS 开发术语。** PM 搜索教程会得到大量过时信息（Xcode 版本差异、证书管理方式变化），真正能跑通的教程很少且不连贯。

实际遇到的坑：
- **Apple 网站拦截 Playwright 自带 Chromium** — Apple CDN 通过 TLS 指纹检测，Chromium 被识别为自动化工具，CSS/JS 返回空响应导致页面白屏。这个问题花了一个完整 session 才定位到
- **许可协议未接受** — Apple Developer Program 许可协议更新后必须手动接受，否则所有 API 操作静默失败，错误信息不明确

## 解决方案

一个 5-Phase 的端到端引导 skill，核心设计：

1. **Playwright MCP 浏览器自动化** — Agent 直接操作 Apple Developer Portal 和 App Store Connect，PM 只需要提供 Apple ID 密码和 2FA 确认
2. **术语消除** — 不说"证书"、"Provisioning Profile"，说"点哪里→填什么→看到什么说明成功了"
3. **阻塞项前置** — Phase 0 先扫描项目状态（编译、签名配置、App Icon），一次性列出所有缺失项，避免走到 Phase 3 Archive 才发现缺 App Icon
4. **Automatic Signing 优先** — 开发 + TestFlight 阶段不走 Manual Signing，让 Xcode 自动管理证书和 Profile，减少 PM 需要理解的概念
5. **分 Phase 确认** — 每个 Phase 完成后输出确认清单，PM 确认后才继续下一步

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 注册方式 | Playwright MCP 浏览器自动化 | PM 不熟悉 Apple 网站布局，agent 代操作最快。Apple 无 CLI 可用于 App ID 注册 | Fastlane produce — 需要安装 Ruby 全家桶 + app-specific password，对 PM 门槛更高 |
| 浏览器引擎 | 系统 Chrome（`--browser chrome`） | Apple CDN 通过 TLS 指纹检测拦截 Playwright 自带 Chromium，CSS/JS 返回空响应。系统 Chrome 的指纹与正常用户一致 | Playwright 自带 Chromium — 实测 developer.apple.com 白屏，不可用 |
| 签名方式 | Automatic Signing | TestFlight 阶段用 Automatic 最简单，PM 无需理解证书体系 | Manual Signing — 对正式上线有意义，但对 TestFlight 内测没必要增加复杂度 |
| Archive 方式 | 推荐 Xcode GUI，备选命令行 | Xcode GUI 的 Organizer 窗口让 PM 能直观看到 Archive 产物和上传进度，出错时截图更方便 | 纯命令行 — PM 看不到进度，出错时 log 输出不够直观 |
| 分发起步 | 内部测试优先 | 内部测试员秒生效不需要 Beta 审核，PM 能最快拿到手机上的反馈 | 直接外部测试 — 需要 Beta 审核（24-48h），还可能需要 Privacy Policy URL |
| 登录流程 | agent 填写 + PM 人工 2FA | Apple 的 2FA 必须在受信任设备上确认，无法自动化 | App-specific password — 只能用于 CLI 工具，无法绕过网页登录的 2FA |

## 已放弃方案

### 方案 A: Fastlane 全流程自动化
- **是什么：** 用 Fastlane 的 produce（创建 App）+ gym（Archive）+ pilot（上传 TestFlight）一条龙
- **为什么放弃：** Fastlane 需要 Ruby 环境 + Gemfile + app-specific password + match 证书管理。对 PM 而言安装和配置本身就是一个新的障碍，且出错时 Fastlane 的日志对 PM 不友好。Playwright 方案让 PM 在浏览器里看到实际操作过程，心理安全感更高

### 方案 B: Apple App Store Connect API
- **是什么：** 用 Apple 官方的 ASC API（REST）直接创建 App、管理 TestFlight
- **为什么放弃：** ASC API 需要生成 API Key（JWT），且不支持 App ID 注册（必须在 Developer Portal 操作）。只能覆盖部分流程，仍然需要浏览器操作 Developer Portal

### 方案 C: xcrun altool / notarytool
- **是什么：** 用 Apple 命令行工具上传 IPA
- **为什么放弃：** altool 已被 Apple 废弃，notarytool 主要用于 macOS 应用公证。Xcode 自带的 Organizer 上传功能更可靠且 PM 可以看到进度

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| 浏览器自动化 | Playwright MCP（@playwright/mcp） | 90% | 发现并解决 Apple TLS 指纹检测问题（必须 `--browser chrome`）；编写 Apple 网站的具体操作路径 |
| 签名管理 | Xcode Automatic Signing（Apple 原生） | 100% | 将 GUI 操作翻译为 PM 可理解的逐步指引 |
| Archive + Upload | xcodebuild + Xcode Organizer（Apple 原生） | 100% | 常见失败场景的诊断表（证书缺失、Bundle ID 不匹配、App Icon 问题） |
| TestFlight 分发 | App Store Connect 网页（Apple 原生） | 100% | 内部/外部/公开链接三种分发方式的场景建议 |

## FAQ

**Q: Playwright MCP 白屏怎么办？**
A: 99% 是因为没加 `--browser chrome`。执行 `claude mcp get playwright` 确认 Args 中包含 `--browser chrome`。Apple CDN 通过 TLS 指纹拦截 Playwright 自带 Chromium。

**Q: 2FA 能自动化吗？**
A: 不能。Apple 的 2FA 必须在受信任设备（iPhone/Mac）上人工确认。agent 会在需要 2FA 时暂停并提示 PM 操作。

**Q: 首次发布大概需要多长时间？**
A: 30-45 分钟。主要时间花在：Apple 网站操作（10 分钟）、Xcode Archive（3-5 分钟）、上传（5-15 分钟，取决于包大小和网络）、Apple 处理（10-30 分钟）。后续更新只需 Archive + Upload，约 5 分钟。

**Q: 为什么不用 Fastlane？**
A: Fastlane 是开发者工具，PM 需要先配置 Ruby + Gemfile + app-specific password + match。这些配置本身就是一个新的障碍。Playwright 方案让 PM 在浏览器里看到实际操作，出问题时能截图，心理门槛更低。

**Q: 能直接发 App Store 吗？**
A: 本 skill 只覆盖 TestFlight。App Store 正式上架需要额外的元数据（截图、描述、隐私政策、App Review 信息），由 ae-store-assets 和 ae-ship 覆盖。

## 生命周期

- **填补的 gap：** PM 从本地可运行的 demo 到团队可试用的 TestFlight 版本之间，存在 Apple 注册、签名配置、Archive 上传等一系列专业开发者才熟悉的操作
- **什么会让它过时：** 当 Apple 提供一键发布到 TestFlight 的功能（如 Xcode Cloud 免费版覆盖全流程且无需手动配置），或当 Fastlane/类似工具足够简单到 PM 可以零配置使用时，本 skill 的大部分流程可以退役。但 Apple 网站操作、术语翻译和故障排查部分短期内仍有价值

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-04-09 | 首版。5 Phase 完整流程（状态扫描→App 注册→签名配置→Archive 上传→TestFlight 分发），Playwright MCP 浏览器自动化。#II8VWP |
| v1.1 | 2026-04-09 | 修复 Apple TLS 指纹拦截问题：Playwright MCP 必须使用 `--browser chrome`（系统 Chrome），不能用自带 Chromium。#II8VWP |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：5 Phase 发布流程 + Playwright 操作步骤 + 故障排查表 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、TLS 指纹问题记录 |
