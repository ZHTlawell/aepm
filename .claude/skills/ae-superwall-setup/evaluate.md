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

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 3/5 (60%)
- **平均耗时**: 77.6s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| S1: 全流程 Happy Path | 2/5 | 82.6s | 过度阻塞在澄清问题上 | 用户已提供全部必填输入（路径/产品名/ASC ID/定价），agent 仍问 4 个问题且未启动任何 Phase；至少 Phase 1 定价确认表应直接输出 |
| S2: Native Paywall 模式 | 2/5 | 66.8s | 技术细节错误 | 正确识别 Native UI + Superwall 支付模式，但错误声称"不需要 `register(placement:)`"——SKILL.md 要求在按钮点击中调用该 API；同样阻塞在 4 个问题上无实质输出 |
| S3: 前置条件不满足 | 4/5 | 65.2s | — | 正确列出前置条件表、明确阻塞并引导先跑 `/ae-preflight`、展示正确的流程依赖链；扣 1 分因未尝试检查可验证条件（如项目是否存在） |
| S4: SDK 代码质量 | 3/5 | 109.2s | 未生成 Swift 代码 | Phase 1 执行正确（定价确认、Superwall 注册引导、ASC 命令）且提到 Secrets.plist 存储 Key；但 5 项代码质量标准无一可验证——输出在 Phase 1 就截止，未进入 SDK 集成阶段 |
| S5: 后续流程集成 | 3/5 | 64.2s | 输出截断 | SuperwallDelegate 检查表技术准确（transactionComplete 而非按钮点击），Adjust 代码示例正确；但 Sandbox 测试、上线清单、衔接 testflight-publish 部分因截断不可评估 |

## 瓶颈分析
- **过度阻塞（S1/S2）**: Agent 在用户已提供全部必填输入时仍抛出 3-4 个澄清问题，导致零实质输出。根因是 skill 未区分"已有信息直接执行"与"缺失信息才询问"的分支逻辑。**建议**: 在 SKILL.md 中为每个 Phase 标注"若已提供 X 则跳过询问直接执行"，并在 prompt 中强化"用户已给的信息视为已确认"。
- **路径访问 → 全面停滞**: 项目路径不在 sandbox 允许范围内时，agent 将整个流程阻塞，而非先执行不依赖文件系统的步骤（Phase 1 定价确认、Superwall 注册引导、ASC 商品创建均不需要读项目文件）。**建议**: SKILL.md 中明确标注每个 Step 的文件系统依赖，无依赖的步骤应无条件推进。
- **S2 技术错误（register placement）**: Native Paywall 模式下 `register(placement:)` 是核心调用，agent 却排除了它。**建议**: 在 SKILL.md 的"两种模式"章节补充明确代码片段对比表，避免 agent 凭推理猜测 API 用法。

## 结论
Skill 在防御性场景（前置条件拦截）表现良好，但在核心 happy path 上因过度询问和路径依赖导致 0 实质产出；建议优先修复"已有输入直接执行"逻辑和 Phase 间的文件系统依赖解耦，预计可将通过率从 60% 提升至 80%+。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 0/5 (0%) | 47.8s |
| 2026-04-14 | 3/5 (60%) | 77.6s |
