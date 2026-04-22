# ae-app-to-testflight 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-app-to-testflight

## Test Stories

### Story 1: 首次发布 Happy Path — XcodeGen 项目从零到 TestFlight
- **Prompt**: "帮我把 bible-app 发布到 TestFlight，项目路径 ~/projects/bible-app，产品名 Faithful Guide，我的 Apple ID 是 test@example.com。这是首次发布。"
- **Expect**: Agent 按 Phase 0-5 全流程执行：(0) 扫描项目状态，确认 preflight 已通过、读取项目配置（XcodeGen/标准）、确认首次发布；(1) 与 PM 确认 Bundle ID（推荐格式 + 注意事项），通过 `ae asc bundle-id register` 注册，通过 `ae asc app create` 创建 App；(2) 写入签名配置到 project.yml、声明 iPad 方向、配置出口合规、验证编译通过；(3) xcodegen generate + xcodebuild archive + 创建 ExportOptions.plist + xcodebuild -exportArchive 上传；(4) 出口合规声明 + 创建内部测试组 + 添加测试员；(5) 输出分发信息摘要 + 更新 publish-state.yaml。
- **Max Time**: 600s

### Story 2: 更新版本 — 跳过 Phase 1 直接 Archive + Upload
- **Prompt**: "bible-app 有代码更新，需要推一个新的 TestFlight 版本。之前已经发布过了。"
- **Expect**: Agent 识别为更新场景（非首次发布），跳过 Phase 1（Apple 身份注册），直接进入 Phase 2 Step 2.5 bump build number（agvtool next-version -all 或修改 project.yml），然后执行 Phase 3 Archive + Upload + Phase 4 分发。不重复注册 Bundle ID、不重复创建 App。内部测试组已存在则直接使用，新 build 对内部测试员秒生效。
- **Max Time**: 300s

### Story 3: ASC API 凭据缺失 — 阻塞处理
- **Prompt**: "帮我发布 TestFlight，项目在 ~/projects/my-app。"
- **Expect**: Agent 在前置条件检查阶段执行 `ae asc auth validate --pretty`，如果返回"缺少 ASC 凭据"，Agent 应中断流程，明确告知用户需要配置 ASC API Key：(1) 说明在 ASC 哪里创建 API Key（用户和访问 - 集成 - 团队密钥）；(2) 给出 credentials.env 配置模板（ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_PATH）；(3) 提醒 .p8 文件只能下载一次；(4) 提醒需要安装 PyJWT + cryptography。不跳过凭据检查直接尝试后续步骤。
- **Max Time**: 120s

### Story 4: Archive 产物质量验证 — 签名 + ExportOptions 正确性
- **Prompt**: "Archive 和上传总是失败，帮我排查一下。项目用的是标准 Xcode 项目（非 XcodeGen），Team ID 是 ABC123，Bundle ID 是 com.example.myapp，Scheme 是 MyApp。"
- **Expect**: Agent 按故障排查流程操作：(1) 检查签名配置（security find-identity 列出证书）；(2) 确认 Bundle ID 已在 Portal 注册（ae asc bundle-id list --filter-identifier）；(3) 检查 iPad 方向声明（约束 ios-pub-017）；(4) 验证编译通过（xcodebuild build -destination "generic/platform=iOS"）；(5) 执行 archive 并分析失败原因，参照故障排查表给出具体解决方案（而非模糊建议）。对标准 Xcode 项目给出 Xcode UI 操作指引而非 project.yml 修改。
- **Max Time**: 300s

### Story 5: 外部测试 + 与 ae-preflight 的前置依赖验证
- **Prompt**: "我需要把 App 发给 100 个外部用户测试，不是团队内部人员。另外这个项目还没跑过 preflight。"
- **Expect**: Agent 处理两个要点：(1) preflight 未通过时，先引导用户执行 `/ae-preflight`，不直接开始 TestFlight 流程；(2) 外部测试路径：说明需要 Beta 审核（24-48h）、可能需要 Privacy Policy URL、需通过 ASC Web UI 操作（ae asc 暂不支持外部测试组创建）；(3) 建议分步策略——先走内部测试（秒生效）验证基本功能，再提交外部测试；(4) 提醒约束 ios-pub-027（推荐先接埋点再上 TestFlight）。
- **Max Time**: 180s

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 0/5 (0%)
- **平均耗时**: 47.1s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| S1 首次发布 Happy Path | 1/5 | 60.5s | 输出摘要为空，无法验证任何 Phase 是否执行 | 运行未超时但无可观测输出，疑似 agent 未触发 skill 或输出捕获异常 |
| S2 更新版本 | 2/5 | 53.0s | 未识别更新场景，退化为信息收集 | 向用户追问项目路径合理，但未展示 skip Phase 1 / bump build number 的更新流程意识；prompt 中未给路径是测试设计缺陷 |
| S3 ASC 凭据缺失 | 0/5 | 52.6s | max turns (10) 死循环 | 核心期望是检测凭据缺失后**中断并指引**，实际陷入重试循环，完全未输出凭据配置模板 |
| S4 Archive 排查 | 0/5 | 64.9s | max turns (10) 死循环 | 同 S3，agent 未能在命令失败后切换到诊断模式，反复执行失败命令直至耗尽回合 |
| S5 外部测试 + preflight | 0/5 | 4.3s | API rate limit 触顶 | "You've hit your limit" — 非 skill 本身问题，属运行环境限制，无法评估实际能力 |

## 瓶颈分析
- **max turns 死循环（S3/S4）**：agent 在命令失败时缺乏"失败 → 诊断 → 中断"的退出逻辑，反复重试同一操作直至回合耗尽。Skill 需要在 SKILL.md 中显式声明错误处理分支（如"若 `ae asc auth validate` 失败，立即输出凭据配置指引并 STOP"），或在 agent 层增加 fail-fast 策略。
- **更新场景识别弱（S2）**：prompt 中已明确说"之前已经发布过了"，但 agent 未从对话意图推断出应跳过 Phase 1。建议在 Skill 的触发条件中增加更明确的场景分类 prompt（首次 vs 更新），并在 Phase 0 阶段通过 `ae asc app list` 自动判断是否已存在 App。
- **输出可观测性缺失（S1）**：Happy Path 的输出摘要为空，导致无法评分。需排查测试框架的输出捕获机制，确认 agent 的 stdout/交互文本是否被正确记录。

## 结论
Skill 当前处于**不可用**状态（0% 通过率）。最高优先级：修复 max turns 死循环问题（为错误场景增加显式退出分支）；其次修复测试框架输出捕获以确保 S1 可评估；第三优化更新场景的意图识别逻辑。建议在修复后对 S1-S4 进行回归测试，S5 需在 rate limit 充裕时单独复测。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 0/5 (0%) | 47.1s |
