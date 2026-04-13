# ae-superwall-setup 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-superwall-setup

## Test Stories

### Story 1: 全流程 Happy Path — XcodeGen 项目集成 Superwall
- **Prompt**: "帮我在 bible-app 项目中集成 Superwall 支付，项目路径 ~/projects/bible-app，产品名 WePray，ASC App ID 是 6761982880。订阅方案：Weekly $5.99、Monthly $9.99、Annual $39.99（7天试用）。"
- **Expect**: Agent 按 Phase 1-5 顺序执行：(1) 确认订阅定价方案并展示确认表格；(2) 引导 PM 注册 Superwall 账号并获取 pk_ 开头的 API Key；(3) 通过 `ae asc subscription` 命令检查/创建订阅组和订阅商品（weekly/monthly/yearly）；(4) 列出杭州团队协助项（Shared Secret、Adjust 事件）；(5) 在 project.yml 中添加 SuperwallKit SPM 依赖并 xcodegen generate；(6) 创建 Superwall 初始化代码、Placement 注册、订阅状态管理、恢复购买按钮。最终输出集成完成摘要。
- **Max Time**: 600s

### Story 2: 仅需 Native Paywall + Superwall 做支付处理
- **Prompt**: "我已经有自己设计的 Paywall UI 了，不想用 Superwall 的远程 Paywall。只需要 Superwall 处理支付逻辑。项目路径 ~/projects/my-app，ASC App ID 12345。"
- **Expect**: Agent 识别出用户选择 Native UI + Superwall 仅做支付处理的模式；SDK 集成中不创建 Superwall 远程 Paywall，而是在用户已有的 Paywall 按钮点击事件中调用 `Superwall.shared.register(placement:)`；订阅状态管理仍走 `Superwall.shared.subscriptionStatus`；恢复购买仍然需要添加。不引导用户去 Superwall Dashboard 创建 Paywall 页面。
- **Max Time**: 300s

### Story 3: 前置条件不满足 — 未跑 ae-preflight
- **Prompt**: "帮我集成 Superwall 支付，项目在 ~/projects/new-app。"
- **Expect**: Agent 检查前置条件时发现 ae-preflight 未通过（无 publish-state.yaml 或 preflight.status 不为 done），Agent 应中断并提示用户先执行 `/ae-preflight`。不直接开始 Superwall 集成。如果项目编译不通过，同样应阻塞并说明原因。
- **Max Time**: 120s

### Story 4: SDK 代码质量验证 — 生成的 Swift 代码是否正确
- **Prompt**: "集成 Superwall，项目 ~/projects/prayer-app，标准 Xcode 项目（无 project.yml），ASC App ID 999，方案 Monthly $4.99 + Yearly $29.99。"
- **Expect**: 生成的 Swift 代码必须满足：(1) Superwall.configure 在 App init() 中调用，API Key 从 Secrets.plist 读取而非硬编码；(2) register(placement:) 调用包含至少两个 placement（onboarding_complete 和 paywall）；(3) subscriptionStatus 判断使用 `.active` 而非自定义状态；(4) 包含恢复购买按钮代码（Apple 审核要求）；(5) SuperwallDelegate 实现中 Adjust 事件触发在 transactionComplete 回调中而非按钮点击事件中。标准 Xcode 项目走 Xcode UI 添加 SPM 而非修改 project.yml。
- **Max Time**: 300s

### Story 5: 与 ae-analytics-setup + ae-testflight-publish 的集成
- **Prompt**: "Superwall 集成完成了，接下来需要验证 Adjust 付费事件能正确上报，然后打包上 TestFlight 给团队测试。"
- **Expect**: Agent 识别后续流程：(1) 确认 SuperwallDelegate 中的 Adjust 事件触发代码已就位（transactionComplete 中调用 AdjustService）；(2) 提示杭州团队协助项的状态（Shared Secret、服务端事件 Token 是否已配置）；(3) 引导进入 Phase 4 Sandbox 测试，包括创建 Sandbox 测试账号、完整购买流程验证（Paywall 展示、购买弹窗、VIP 状态、恢复购买）；(4) 提示上线前切换清单（Adjust 环境、Superwall Key、ASC 商品状态）；(5) 自然衔接到 `/ae-testflight-publish` 进行 Archive + Upload。
- **Max Time**: 300s

## 最近一次评估
（待执行）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
（待执行）

## 瓶颈分析
（待执行）

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
