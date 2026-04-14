# ae-testflight-publish 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-testflight-publish

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

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
