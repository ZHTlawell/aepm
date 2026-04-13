# ae-analytics-setup 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-analytics-setup

## Test Stories

### Story 1: 基础 Happy Path — 为 iOS 项目接入 Firebase + Adjust 双轨埋点
- **Prompt**: "帮我在 bible-app 项目接入埋点，Bundle ID 是 com.kjv.bible.prayer.app，ASC App ID 是 6761982880，产品名叫 WePray"
- **Expect**: 
  - Phase 1: 生成结构化的杭州团队配置请求（含 Firebase + Adjust 两部分），列出标准 Event Tokens 需求清单（AJ_weekly/monthly/yearly 等 10 个事件）
  - Phase 2: 在 project.yml 中添加 firebase-ios-sdk 和 ios_sdk 的 SPM 依赖，执行 `xcodegen generate` + `xcodebuild build` 验证编译通过
  - Phase 3: 创建 AnalyticsService 和 AdjustService 封装层，业务代码不直接调用 Firebase/Adjust API
  - Phase 4: 定义核心漏斗事件（Onboarding → Paywall → 购买）+ 产品特定事件
  - Phase 5: 编译验证 + 运行时验证指引
  - Phase 6: 输出完整的埋点接入报告，含事件对照表和杭州团队待确认清单
- **Max Time**: 300s

### Story 2: 指定仅接入 Firebase（不需要 Adjust）
- **Prompt**: "帮我在 ShoeLens 项目只接入 Firebase Analytics，不需要 Adjust。项目路径 ~/Projects/ShoeLens，Bundle ID com.shoelens.app，ASC App ID 1234567890"
- **Expect**: 
  - Phase 1 配置请求中只包含 Firebase 部分，不生成 Adjust 相关的 Event Token 需求
  - Phase 2 只添加 firebase-ios-sdk 的 SPM 依赖
  - Phase 3 只创建 AnalyticsService 封装层，不创建 AdjustService
  - Phase 3 中 GoogleService-Info.plist 加入 .gitignore，创建 .example 模板
  - 输出报告中 Adjust 部分标注为"未接入"
- **Max Time**: 240s

### Story 3: 项目编译失败（SPM resolve 失败）
- **Prompt**: "接入埋点，项目路径 ~/Projects/broken-app，Bundle ID com.test.broken，ASC App ID 9999999999，产品名 TestApp。（项目 project.yml 存在语法错误）"
- **Expect**: 
  - Phase 2 执行 `xcodebuild build` 时检测到 BUILD FAILED
  - Agent 不跳过编译失败直接进入后续 Phase
  - 尝试诊断失败原因（SPM resolve 失败 vs project.yml 语法错误）
  - 如果是网络问题建议重试，如果是项目问题提示 PM 先修复
  - 明确告知"编译未通过，不继续后续集成步骤"
- **Max Time**: 180s

### Story 4: AnalyticsService 封装层质量验证
- **Prompt**: "在 WePray 项目中接入完整的 Firebase + Adjust 埋点，重点关注 AI 聊天功能的埋点事件定义"
- **Expect**: 
  - AnalyticsService 包含通用漏斗事件（onboarding_page_view, paywall_view, paywall_plan_select 等）
  - AnalyticsService 包含产品特定事件（chat_message_send, chat_topic_select, chat_free_limit_hit 等）
  - AdjustService 的 eventTokens 字典结构正确，trackSubscriptionSelect 接受 plan 参数
  - 封装层使用 Singleton 模式（`static let shared`）
  - 业务代码调用点与事件注入位置对照表完整（Onboarding/Paywall/Tab/分享等位置）
  - Adjust App Token 存入 Secrets.plist，不硬编码
- **Max Time**: 300s

### Story 5: 与 ae-preflight 和 ae-testflight-publish 的集成
- **Prompt**: "WePray 的 preflight 报告显示缺少埋点，帮我接入后上 TestFlight"
- **Expect**: 
  - 识别触发来源是 ae-preflight 的检查结果
  - 完成埋点接入全流程（Phase 1-5）
  - Phase 5.4 触发 Archive + Upload TestFlight 流程，包含 bump build number
  - 输出报告中包含 TestFlight Build 版本号和上传时间
  - 提醒"Adjust 环境上线前必须从 Sandbox 切 Production"（约束 analytics-002）
  - 提醒"无埋点的 TestFlight 版本 = 盲测"（约束 ios-pub-027），表明本次已接入
- **Max Time**: 360s

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
