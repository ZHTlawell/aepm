# ae-preflight 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-preflight

## Test Stories

### Story 1: 标准 iOS 项目 TestFlight 预检
- **Prompt**: "帮我跑一下 preflight，项目在当前目录，准备发 TestFlight"
- **Expect**: Skill 按 Phase 0-5 顺序执行：(0) 识别项目类型（XcodeGen/Standard）和 scheme 列表；(1) 检查 DEVELOPMENT_TEAM、Bundle ID、签名方式，尝试 `xcodebuild build` 验证编译；(2) grep 扫描硬编码 API Key 和敏感文件泄露；(3) 检查 PrivacyInfo.xcprivacy、Info.plist 权限声明；(3.5) 检查 Firebase/Adjust SDK 接入状态；(4) 验证 App Icon 尺寸和 Launch Screen 配置。最终输出结构化 PREFLIGHT REPORT，分 BLOCKERS / WARNINGS / PASSED 三区，包含 NEXT STEPS。
- **Max Time**: 180s

### Story 2: 指定 App Store 目标的完整检查
- **Prompt**: "项目在 ~/Projects/FaithfulGuide，目标是 App Store 正式发布，帮我做 preflight"
- **Expect**: Skill 识别目标为 `appstore`（比 testflight 检查项更多），除标准检查外额外关注：合规弹窗是否存在（GDPR/隐私政策）、埋点 SDK 完整性（Firebase + Adjust 都应接入）、DPLA 协议提醒。报告中明确标注 `Target: appstore`。
- **Max Time**: 200s

### Story 3: 项目路径不存在或非 iOS 项目
- **Prompt**: "帮我 preflight 检查 /tmp/empty-dir"
- **Expect**: Skill 在 Phase 0 项目识别阶段发现目录下无 `.xcodeproj`、`project.yml`、`*.swift` 文件，明确告知用户"未找到 iOS 项目"，不应继续执行后续 Phase 或输出空白报告。如果目录不存在，直接提示路径无效。
- **Max Time**: 30s

### Story 4: 报告质量——BLOCKERS 准确识别与修复建议
- **Prompt**: "preflight 跑完了，有几个 blocker，帮我看看哪些能自动修复"
- **Expect**: Skill 在 Phase 6 中列出可自动修复的项目表格（无 .gitignore → 生成标准模板；无 PrivacyInfo.xcprivacy → 生成骨架；API Key 硬编码 → 提取到 Secrets.plist），区分"需要 PM 确认"和"直接修"两类。对需要人工操作的 blocker（如 Xcode 登录 Apple ID）给出明确操作步骤，不尝试自动修复。
- **Max Time**: 120s

### Story 5: 与 ae-testflight-publish 的流程衔接
- **Prompt**: "preflight 全部通过了，下一步该做什么？"
- **Expect**: Skill 在 Phase 7 写入 `publish-state.yaml`（status: done，scanned_at 日期，blockers/warnings 列表），并在报告 NEXT STEPS 中明确引导用户：签名阻塞 → `/ae-testflight-publish`；资产缺失 → `/ae-store-assets`；埋点缺失 → `/ae-analytics-setup`；编译通过 → 直接进入 `/ae-testflight-publish` Phase 3-4。体现 skill 之间的流程衔接。
- **Max Time**: 60s

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
