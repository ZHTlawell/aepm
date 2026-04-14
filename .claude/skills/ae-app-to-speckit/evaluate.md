# ae-app-to-speckit 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-app-to-speckit

## Test Stories

### Story 1: 基础 Happy Path — 从 App Store 逆向提取 speckit
- **Prompt**: "帮我分析 CamScanner 这个 App，生成 speckit，App Store 链接是 https://apps.apple.com/app/id388627783"
- **Expect**: 
  - Phase 0: 执行 `wda-start.sh` 建立 WDA 连接，`mobile_take_screenshot` 确认屏幕可用，发现 bundle_id 并写入 exploration-state.json，向 PM 收集 PII 关键词
  - Phase 1: WebSearch 获取 App Store 信息，生成 app-profile.json（含 name/tagline/features/iap_list），生成 feature-checklist.md（每个功能有 ID/来源/优先级/覆盖状态）
  - Phase 1.5: 启动 App 寻找帮助页/功能目录，补充 Phase 1 未发现的功能到 checklist
  - Phase 2a: Tab 遍历 + 子入口遍历，每个功能至少一张截图
  - Phase 2b: 3-5 条核心流程端到端走通，每步截图
  - Phase 2d: 运行 coverage-stats.py 检查覆盖率 (core >= 80%)
  - Phase 2e: 运行 privacy-mask.py 脱敏
  - Phase 3: 生成 01-project-positioning.md + 02-user-scenarios.md + 04-design-spec.md
  - Phase 4: 生成 review-checklist.md
  - 所有截图使用语义化命名（如 2a-F01-scan-entry.png）
  - exploration-state.json 持续更新
- **Max Time**: 1800s

### Story 2: 付费墙阻断后的增量补测
- **Prompt**: "上次分析 CamScanner 时有几个功能被付费墙挡住了，我已经买了周会员，帮我继续补测"
- **Expect**: 
  - 检测到 speckit/ 目录已存在，读取 exploration-state.json 确认中断点
  - 执行 Phase 0 重新建立 WDA 连接（不依赖旧 session ID）
  - 读取 pending_paid_flows 列表，逐个补测
  - 每个功能：导航到入口 -> 端到端走通 -> 每步截图
  - feature-checklist 中对应功能状态从 ⛔ 更新为 🔄
  - exploration-state.json 中移除已完成的 pending_paid_flows
  - 进入增量更新模式的 Phase 3：追加新流程到 02-user-scenarios.md 末尾，不覆盖已有内容
- **Max Time**: 900s

### Story 3: WDA 断开 + MCP 不可用的降级场景
- **Prompt**: "帮我分析一个 App，名叫 Notion。手机连着但好像 WDA 挂了"
- **Expect**: 
  - Phase 0 执行 wda-start.sh 尝试重连
  - 如果 WDA 启动失败，引导用户执行 /ae-mobile-setup
  - 如果 WDA 启动成功但 MCP tools 不可用，自动切换到 wda-cli.py 替代方案
  - exploration-state.json 中标记 "mcp_available": false
  - 后续所有操作使用 wda-cli.py（screenshot/tap/launch/source/swipe）
  - 截图使用 screenshot-save.py 保存（绕过 mobile_save_screenshot 黑屏 bug）
  - 功能流程不因 MCP 不可用而中断
- **Max Time**: 600s

### Story 4: feature-checklist 覆盖率和质量验证
- **Prompt**: "分析美图秀秀 App，重点覆盖所有修图功能，App Store 链接 https://apps.apple.com/app/id416048305"
- **Expect**: 
  - feature-checklist.md 中每个功能有唯一 ID（F01, F02...）
  - 功能来源区分 app_store / in_app / discovered 三类
  - Phase 2 探索过程中，agent 主动通过推理发现 checklist 未列出的功能（source="discovered"）
  - Phase 2d 强制执行覆盖率 checkpoint，运行 coverage-stats.py
  - 截图精简规则生效：重复样式长列表只截首尾两屏 + 备注总数
  - Module 02 中每个流程步骤都有真实截图引用（不允许截图占位符）
  - Module 04 中每个颜色值标注来源截图和元素位置
  - 覆盖状态语义正确：⬜ 未覆盖 / ✅ 有入口截图 / 🔄 端到端走通 / ⛔ 付费墙 / 🔒 需登录
- **Max Time**: 1200s

### Story 5: 与 ae-mobile-setup 和 ae-mobile-agent 的集成
- **Prompt**: "我第一次用真机分析 App，手机刚插上 USB，帮我分析微信读书"
- **Expect**: 
  - Phase 0 检测到 go-ios / WDA 未就绪，引导执行 /ae-mobile-setup
  - 环境就绪后，使用 /ae-mobile-agent 的 observe-think-act-verify 循环进行手机操控
  - 每次操作后必须 mobile_take_screenshot 确认（不盲操作）
  - 点击操作使用标准 tap 模板：list_elements -> 找目标 -> 计算中心点 -> click -> 截图确认
  - 遇到需要 PM 手动操作的步骤（登录微信账号），暂停并通知 PM
  - 探索过程中发现脚本 bug 时，当场使用 /ae-submit-bug 提交 issue
  - 产出的 speckit 可直接进入下游 demo-to-speckit / demo-to-figma 流水线
- **Max Time**: 1800s

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 0/5 (0%)
- **平均耗时**: 50.3s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 基础 Happy Path | 0/5 | 78.5s | 权限配置未自动生效 | 卡在写入权限提示，Phase 0 未启动，全流程零产出 |
| 付费墙增量补测 | 0/5 | 79.6s | max turns (10) 耗尽 | 未能读取已有 state 并恢复，循环耗尽轮次 |
| WDA 断开降级 | 0/5 | 45.4s | max turns (10) 耗尽 | 未触发 wda-start.sh 重连或 wda-cli.py 降级路径 |
| checklist 覆盖率 | 0/5 | 43.8s | API rate limit | 触发速率限制，skill 无任何容错/重试逻辑 |
| 集成 mobile-setup | 0/5 | 4.2s | API rate limit | 4.2s 即终止，完全未进入 skill 逻辑 |

## 瓶颈分析
- **权限声明未被 harness 正确消费（Story 1）**：SKILL.md 已声明 `Write({workdir}/speckit/**)` 权限，但运行时仍要求用户手动授权。说明 permissions 字段要么未被加载，要么 skill 内部写入路径与声明不匹配。这是最高优先级问题——权限不通则整个 skill 无法自动化。
- **max turns 上限过低 + 缺乏进度管理（Story 2/3）**：10 轮 turn limit 对于需要多步环境检查 + WDA 重连 + 状态恢复的场景远远不够。skill 内部也没有在前几轮做有效聚合（例如一次性完成 Phase 0 全部步骤），导致轮次浪费在碎片化调用上。建议：a) 测试 harness 给予至少 30-50 turns；b) skill prompt 中强调单轮合并多步操作。
- **无 rate limit 容错（Story 4/5）**：遇到 API 速率限制后直接终止，无 backoff 重试或暂停等待机制。对于本身就是长流程的 skill，应在 prompt 或 harness 层面加入限流感知和优雅降级（如保存当前进度到 exploration-state.json 后退出，下次可恢复）。

## 结论
Skill 当前处于**不可用状态**——5 个 story 全部零产出，核心流程从未被触发。最高优先级：修复权限声明与运行时的对接（Story 1 是 smoke test，必须先通过）；其次提升 turn limit 并优化单轮步骤密度；最后补充 rate limit 容错和断点续传能力。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 0/5 (0%) | 50.3s |
