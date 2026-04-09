# ae-superwall-setup

> 填补 PM 独立完成 Superwall SDK 集成的能力 gap，将 Dashboard 配置 + 代码集成从"查文档自己摸索"变为 step-by-step 引导。

## 问题陈述

Superwall 是 onboarding/paywall 的远程配置层，支持热更新和 A/B 测试。但 PM 独立集成时遇到三个障碍：

1. **配置链路长** — 注册账号 → 创建 App → 获取 API Key → 添加 SPM 依赖 → 代码初始化 → 注册 Placement → 上传页面 → 绑定 — 任何一步出错都导致整条链路不通，PM 容易卡住
2. **Dashboard 操作与代码修改交替** — Superwall 集成需要在 Dashboard UI 和 Xcode 代码之间反复切换，agent 无法直接操作 Dashboard，需要精确引导 PM 完成 Dashboard 侧操作
3. **与 onboarding/paywall 生成的衔接** — ae-onboarding-design 和 ae-paywall-design 生成了 HTML 页面，但"上传到 Superwall 并绑定到 Placement"这最后一步没有自动化

## 解决方案

提供 **step-by-step 引导流程**，将 Superwall 集成拆解为 5 个 Step，每一步明确告诉 PM 做什么、agent 做什么：

- **Step 1: 检查项目状态** — agent 自动检查 SPM 依赖、现有配置、App 入口位置
- **Step 2: Dashboard 配置引导** — 引导 PM 在 Superwall Dashboard 创建 App、获取 API Key、注册 Placement（agent 无法操作 Dashboard，逐步指引 PM）
- **Step 3: 代码集成** — agent 自动修改项目代码，完成 SDK 初始化 + Placement 触发 + 购买处理
- **Step 4: 验证** — 日志检查 + Dashboard 事件确认 + 页面展示测试
- **Step 5: 配置清单输出** — 输出完整的集成状态报告

核心机制：
- **人机协作模式** — agent 处理代码修改，PM 处理 Dashboard UI 操作，每一步都有明确的交接点
- **三件套闭环** — 与 ae-onboarding-design + ae-paywall-design 构成完整的"生成页面 → 配置 Superwall → 上传绑定"流程

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| Superwall vs RevenueCat | Superwall | Superwall 专注 paywall/onboarding 远程配置 + A/B 测试，Custom HTML 支持好。RevenueCat 侧重订阅管理，paywall 功能是后加的 | RevenueCat Paywalls — 模板少，自定义差，且与我们 HTML 生成方案不兼容 |
| 引导式 vs 自动化 | step-by-step 引导 | Dashboard 是第三方 Web UI，agent 无法直接操作（无 API），必须引导 PM 手动完成 | 全自动（用 Playwright 操作 Dashboard）— Dashboard 频繁改版，自动化维护成本过高 |
| Free 计划起步 | 推荐 Free（250 MAU） | 0.1 产品用户量远低于 250，Free 计划足够验证 | 直接上 Pro — 0.1 阶段浪费预算 |
| Placement 预设 | 默认 app_install + paywall | 覆盖 onboarding（首次安装）和 paywall（付费触发）两个最常见场景 | 不预设，让 PM 自己定义 — PM 不了解 Superwall 概念时会困惑 |
| API Key 直接写代码 | 硬编码在 App 初始化 | Superwall 的 `pk_` 开头 Key 是公开 Key（Public Key），Apple 也建议直接嵌入。不需要 .env 或 CI 注入 | 走 credentials.env — 过度安全，增加配置复杂度 |

## 已放弃方案

### 方案 A: Superwall API 自动化配置
- **是什么：** 通过 Superwall REST API 自动创建 App、注册 Placement、上传 HTML
- **为什么放弃：** Superwall 的管理 API 不公开（只有 client SDK），无法通过 API 完成 Dashboard 操作。即使未来开放 API，Dashboard 操作通常只做一次，自动化 ROI 不高

### 方案 B: 跳过 Superwall，直接 WKWebView
- **是什么：** 不用 Superwall，直接用 WKWebView 加载本地 HTML
- **为什么放弃：** 失去远程配置能力 — 改页面需要发版，无法 A/B 测试。Superwall 的核心价值正是"不发版即可更新 onboarding/paywall"

### 方案 C: 合并到 ae-paywall-design 中
- **是什么：** 把 Superwall 配置步骤作为 ae-paywall-design 的 Step 6 集成指引
- **为什么放弃：** Superwall 配置是独立的基础设施工作，不仅服务 paywall 也服务 onboarding。且配置流程涉及 Dashboard 操作 + 代码修改 + 验证，足够独立成一个 skill。三件套分离后，PM 可以按需组合使用

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Superwall iOS SDK | [superwall/Superwall-iOS](https://github.com/superwall/Superwall-iOS) | SDK 层 | 标准化 PM 可执行的集成引导流程 |
| SPM 依赖管理 | Swift Package Manager | 依赖安装 | 自动检测项目中是否已有 SuperwallKit 依赖 |
| StoreKit 2 | Apple StoreKit 2 | 购买 API | 与 Superwall delegate 的集成代码模板 |

## FAQ

**Q: 这个 skill 和 Superwall 官方文档有什么区别？**
A: 官方文档是通用的，假设读者是开发者。本 skill 针对 PM 场景，与 ae-onboarding-design / ae-paywall-design 配合使用，agent 自动完成代码修改部分，PM 只需按指引操作 Dashboard。

**Q: Superwall Free 计划够用吗？**
A: 0.1 产品阶段完全够用（250 MAU 上限）。但 Free 计划不支持 Custom HTML paywall — 如果要上传 ae-paywall-design 生成的 HTML 页面，需要 Pro 计划。Free 计划可以使用 Superwall 内置模板。

**Q: 已有 RevenueCat 的项目怎么办？**
A: Superwall 和 RevenueCat 可以共存。Superwall 管 paywall 展示和 A/B 测试，RevenueCat 管订阅状态和收入分析。但如果只是 0.1 产品验证，建议先只用 Superwall + StoreKit 2，减少集成复杂度。

**Q: 三件套必须一起用吗？**
A: 不必须。ae-onboarding-design 和 ae-paywall-design 可以独立使用（直接嵌入 WKWebView）。ae-superwall-setup 是可选的"增强层"，加上后获得热更新和 A/B 测试能力。

## 生命周期

- **填补的 gap：** PM 不熟悉 Superwall 集成流程，Dashboard 配置 + 代码修改 + 验证的完整链路没有 step-by-step 引导
- **什么会让它过时：** 当 Superwall SDK 提供 `Superwall.quickStart()` 一行代码自动完成全部配置（含 Dashboard 侧），或当 Xcode 模板/SPM plugin 内置 Superwall 配置向导

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-04-07 | 首版。5 Step 引导流程：项目检查 → Dashboard 配置 → 代码集成 → 验证 → 清单输出。与 ae-onboarding-design + ae-paywall-design 构成三件套 (#IHXLWK) |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南：检查项目 → 引导 Dashboard 配置 → 修改代码 → 验证集成 |
| README.md | 人类设计文档（本文件）：设计决策、放弃方案、生命周期 |
