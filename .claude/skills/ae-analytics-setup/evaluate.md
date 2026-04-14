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

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 52.1s（仅 Story 1 有效执行，实际耗时 179.6s）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 基础 Happy Path | 3/5 | 179.6s | 无实际项目源码，无法执行 SPM/xcodebuild | Phase 1 配置请求格式正确、字段完整；Phase 2-3 退化为文档模板而非实际代码集成；Phase 5 编译验证未执行 |
| 仅接入 Firebase | 0/5 | 66.7s | API 速率限制 | 输出 "You've hit your limit"，skill 未执行任何逻辑 |
| 编译失败处理 | 0/5 | 4.9s | API 速率限制 | 同上，无法评估错误处理能力 |
| AnalyticsService 质量 | 0/5 | 4.9s | API 速率限制 | 同上，无法评估封装层代码质量 |
| preflight + TestFlight 集成 | 0/5 | 4.4s | API 速率限制 | 同上，无法评估跨 skill 联动 |

## 瓶颈分析
- **API 速率限制导致 4/5 story 完全失效**：Story 2-5 全部因 rate limit 未产出任何结果，本轮测试数据严重不足，无法对 skill 核心能力（条件分支、错误处理、代码生成质量、跨 skill 集成）做出有效评估。建议拆分到多个时间窗口重跑，或申请更高 rate limit。
- **测试环境缺少真实 iOS 项目**：Story 1 因项目目录下无源码，Agent 退化为"纯文档生成"模式，Phase 2（SPM 引入）、Phase 3（封装层创建）、Phase 5（编译验证）均未真正执行。需要准备一个可编译的 scaffold 项目（至少含 project.yml + 空 AppDelegate）才能验证 skill 的核心代码集成能力。
- **Story 1 输出被截断**：只能看到 Phase 1 的部分内容，Phase 2-6 的交付质量无法从截断摘要中判定。建议测试框架保存完整输出或分 Phase 记录关键检查点。

## 结论
本轮测试因 API 速率限制仅 1/5 story 有效执行，且该 story 也因缺少真实项目源码而未触及核心代码集成路径，**结果不具备评估置信度**。优先级建议：① 准备可编译的 scaffold 测试项目；② 在充足 quota 下重跑全部 5 个 story；③ 再做正式评分。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 1/5 (20%) | 52.1s（仅 Story 1 有效执行，实际耗时 179.6s） |
