# Changelog

## v0.25.0 (2026-04-09) — Speckit→上架供应链 Module 1: ae-preflight `#II8UYE`

### 新功能
- **`/ae-preflight` skill** — iOS 项目发布前预检：自动扫描签名配置、硬编码秘钥、PrivacyInfo.xcprivacy、App Icon、隐私合规等生产就绪问题，输出结构化报告 + constraint_candidate 列表 (#II8UYE)
- **publish-state.yaml 状态追踪** — 跨 session 持久化供应链各模块进展（preflight → apple_identity → store_assets → ship → postflight），每个模块记录 blockers / warnings / passed / constraint_candidates

### 供应链规划
- 完整供应链 5 模块设计：ae-preflight → ae-apple-identity → ae-store-assets → ae-ship → ae-postflight
- bible-app (Faithful Guide) 作为第一个实跑验证案例，Module 1 已在真实项目上验证通过（模拟器 BUILD SUCCEEDED）

## v0.24.5 (2026-04-09) — Playwright MCP 必须用系统 Chrome 访问 Apple 网站 `#II8VWP`

### Bug 修复
- **Apple 页面白屏 / 点击无响应** — Apple CDN 通过 TLS 指纹检测拦截 Playwright 自带 Chromium，导致 developer.apple.com 和 appstoreconnect.apple.com 的 CSS/JS 返回空响应。修复：Playwright MCP 注册时必须加 `--browser chrome` 使用系统 Chrome (#II8VWP)
- **ae-testflight-publish skill 更新** — Playwright 环境检查和故障排查文档同步更新，明确 `--browser chrome` 要求

## v0.24.4 (2026-04-09) — ae git issues list-comments 子命令 `#II8YJH`

### 新功能
- **list-comments 子命令** — `ae git issues list-comments --repo <repo> --number <number> --pretty`，列出 issue 的所有评论（id、作者、时间、body），支持分页 (#II8YJH)

## v0.24.3 (2026-04-09) — ae link 注入日常开发通用权限 `#II8UJR`

### Bug 修复
- **ae link 缺少通用权限** — `ae link pm .` 只注入 skill 专用权限，缺少 Write/Edit 项目目录、git、xcodebuild 等日常开发权限，导致用户频繁手动授权 (#II8UJR)

### 改进
- 新增 `cli/config/base-permissions.yml` 配置文件，集中管理通用权限
- `ae link` 自动合并：通用权限 + skill 专用权限，一次 link 即可无缝开发
- 覆盖权限：Read/Write/Edit、git、ae、xcodebuild/xcodegen/xcrun、brew/npm/pip3、cat/which/ls/open 等

## v0.24.2 (2026-04-09) — CLI 架构修复：消除 stale clone + ae git 可用 `#II8SXT`

### Bug 修复
- **ae git 命令不可用** — `~/.ae/bin/ae` 指向旧版独立 clone，`ae git` 子命令无法到达用户 (#II8SXT)
- **CLAUDE.md 未注册到 additionalDirectories** — skills 目录已注册但 role 根目录未注册 (#II8SXT)

### 架构改进
- **消除 `~/.ae/cli/` 独立 clone** — CLI 直接 symlink 到 role 包的 `cli/ae`，`ae update` 自动迁移

## v0.24.0 (2026-04-09) — 统一 Git CLI 工具 `#II8R1M`

### 新功能
- **ae-git.py 统一封装** — 新增 `scripts/ae-git.py`，封装 Gitee API 调用，替代所有 `curl + python3` 裸调用。支持 issue 创建/评论/列表/查看/关闭、图片上传、token 验证 (#II8R1M)
- **鲁棒 JSON 解析** — 自动清洗 Gitee API 返回的控制字符，429/5xx 自动重试，有意义的错误码 (#II8R1M)
- **proxy 自动处理** — 每次 API 调用前自动 unset 代理变量，调用方无需手动处理 (#II8R1M)

### 改进
- **CLI 迁移** — `ae pm submit-bug`、`ae pm submit-requirement`、`ae pm comment-issue`、`ae feedback upload`、`ae setup`、`ae doctor` 全部迁移到 ae-git.py，消除代码重复 (#II8R1M)

## v0.23.0 (2026-04-08) — Feedback Loop 自动化 `#II887G`

### 新功能
- **使用反馈自动收集** — 通过 PostToolUse hook 静默记录 ae-skill 相关的工具错误，缓存到 `~/.ae/pm/feedback/pending.jsonl`，用户使用过程中完全无感 (#II887G)
- **ae update 反馈上传** — 更新时自动检测待上传反馈，展示摘要并询问确认后上传到 Gitee，用户可选择跳过 (#II887G)
- **ae feedback 子命令** — `ae feedback`（查看）、`ae feedback upload`（上传）、`ae feedback clear`（清除），支持手动管理反馈 (#II887G)

## v0.22.3 (2026-04-08) — Issue 路由修复 `#II7SH8`

### Bug 修复
- **submit-bug/requirement 路由歧义** — Skill 中"查阅当前 CLAUDE.md"改为明确指向 `~/.ae/<role>/.claude/CLAUDE.md`，修复非 ae-pm workspace 下 issue 提交到错误仓库的问题 (#II7SH8)

## v0.22.2 (2026-04-08) — WDA fallback 逻辑修复 `#II7RKZ`

### Bug 修复
- **fallback 未触发** — 修复 `test-without-building` hang 后验证超时直接退出、未进入 `test` fallback 的问题；重构为"尝试→验证→失败则 fallback"两轮流程 (#II7RKZ)
- **诊断信息增强** — 失败时输出 30 行日志 + 提示用户反馈 `xcodebuild -version` / `ios version` / 完整日志 (#II7RKZ)

## v0.22.1 (2026-04-08) — WDA iOS 26 兼容性修复 `#II7RKZ`

### Bug 修复
- **wda-start.sh iOS 版本检测** — 启动前自动检测 iOS 版本，iOS 26+ 提前警告兼容性风险 (#II7RKZ)
- **DDI 自动挂载** — iOS 17+ 设备自动执行 `ios image auto` 挂载 Developer Disk Image，修复 iOS 26 DDI 不匹配导致的启动失败 (#II7RKZ)
- **xcodebuild 自动 fallback** — `test-without-building` 失败时自动回退到 `test`（含完整 build），解决 exit code 74 崩溃 (#II7RKZ)
- **失败诊断增强** — WDA 启动失败时输出最后 20 行日志 + iOS 26 专项诊断建议（含 pymobiledevice3 备选方案）(#II7RKZ)

## v0.22.0 (2026-04-07) — Paywall 页面生成 + Superwall 集成 `#IHXLWR` `#IHXLWK`

### 新增能力
- **`/ae-paywall-design` skill** — 自动生成产品 Paywall 付费墙页面（HTML/CSS/JS 或 Native StoreKit 2），支持订阅方案选择、价格对比、免费试用 (#IHXLWR)
  - 深色渐变风格与 onboarding 统一，功能列表 + 方案卡片 + CTA
  - 方案选择交互（radio），默认高亮年付 + 显示折算月价 + Save %
  - 三个 JS 回调：`paywallPurchase(productId)` / `paywallDismiss()` / `paywallRestore()`
  - 附带 Superwall 和 iOS WKWebView + StoreKit 2 两种集成指引 + Swift 代码片段
- **`/ae-superwall-setup` skill** — Superwall 账号配置、App 创建、SDK 初始化、Placement 注册的完整引导流程 (#IHXLWK)
  - Step-by-step 引导 PM 在 Dashboard 创建 App、获取 API Key、注册 Placement
  - 自动修改项目代码完成 `Superwall.configure(apiKey:)` + placement 触发
  - 验证集成：日志检查 + Dashboard 事件确认
  - 与 `/ae-onboarding-design` + `/ae-paywall-design` 三件套配合：生成页面 → 配置 Superwall → 上传绑定

## v0.21.1 (2026-04-07) — 每次对话自动检查更新 `#II6W5Y`

### 改进
- **移除 24h 频率限制** — SessionStart hook 从每 24 小时检查一次改为每次新对话都检查，确保频繁发布时用户及时拿到更新 (#II6W5Y)

## v0.21.0 (2026-04-07) — Onboarding 页面生成 `#IHXLWQ`

### 新增能力
- **`/ae-onboarding-design` skill** — 自动生成产品 Onboarding 幻灯片页面（HTML/CSS/JS），可嵌入 Superwall Flow 或 iOS WebView (#IHXLWQ)
  - MVP 采用 Bevel Carousel 模式：渐变背景 + 圆角 widget 卡片 + 分页圆点 + CTA 按钮
  - 输入：产品名称 + 核心 feature 列表（1-3 个）+ 可选配色/截图/风格参考
  - 输出：`onboarding/` 目录（index.html + styles.css + script.js），无外部依赖
  - 触摸滑动 + snap + 分页圆点 + `window.onboardingComplete()` 回调
  - 响应式适配 iPhone SE ~ iPhone 16 Pro Max，安全区处理
  - 附带 Superwall Flow 和 iOS WKWebView 两种集成指引 + Swift 代码片段
  - Phase 2 规划：Personalization Quiz 模式、视频/Lottie、A/B 测试

## v0.20.5 (2026-04-07) — 自动更新 + changelog 展示 `#II6W5Y`

### 改进
- **Hook 自动 pull** — SessionStart hook 检测到更新后自动执行 `git pull`，用户无需手动操作 (#II6W5Y)
- **更新后展示 changelog** — 自动 pull 后提取新版本的 CHANGELOG diff 写入缓存，Agent 在首次回复末尾展示本次更新了哪些功能 (#II6W5Y)

## v0.20.4 (2026-04-07) — hook matcher 修复 `#II6W5Y`

### Bug 修复
- **SessionStart hook 缺少 matcher** — `_register_update_hook` 写入 settings.json 时补上 `"matcher": "startup"`，修复 hook 注册了但从未被 Claude Code 触发的问题；同时自动修复已有的缺失 matcher 旧条目 (#II6W5Y)

## v0.20.3 (2026-04-07) — update.sh 分支检测 `#II6W5Y`

### Bug 修复
- **ae update 分支硬编码** — `_update_repo` 的 `git pull origin main` 改为动态检测默认分支，修复 ae-go（master 分支）更新时静默失败报「无网络」的问题 (#II6W5Y)

## v0.20.2 (2026-04-07) — 自动更新检查 bugfix `#II6W5Y`

### Bug 修复
- **Hook 注册失败** — 将 `_register_update_hook` 调用嵌入 `_register_global_skills` 内部，解决 `ae update` 时旧版 update.sh 已在内存导致新注册逻辑不执行的 bootstrapping 问题 (#II6W5Y)
- **ae-go 分支名硬编码** — `ae-update-check.sh` 从硬编码 `main` 改为动态检测默认分支（`symbolic-ref` + fallback `main`/`master`），修复 ae-go（master 分支）永远检测不到更新的问题 (#II6W5Y)

## v0.20.1 (2026-04-07) — SessionStart hook 自动更新检查 `#II6W5Y`

### 改进
- **更新检查改为 Claude Code Hook** — 从 agent 指令内联 git fetch 改为 SessionStart hook 脚本（`~/.config/ae/update-check.sh`），不依赖 agent 自觉执行，100% 自动触发 (#II6W5Y)
- **ae install / ae update 自动注册 hook** — 安装或更新时自动将检查脚本复制到 `~/.config/ae/` 并注册 SessionStart hook 到 `~/.claude/settings.json`
- **ae update 自动清除更新缓存** — 更新完成后删除 `.update-available` 缓存文件，避免更新后仍显示旧通知

## v0.20.0 (2026-04-07) — 自动更新检查 `#II6W5Y`

### 新增
- **版本更新自动检查** — 每次对话静默检查 ae-pm 是否有新版本（每 24 小时最多一次），有更新时在回复末尾提示用户，无需用户主动关注版本变化 (#II6W5Y)
- **移除手动检查** — 原「主动检查是否有更新」章节（Gitee API curl）已被自动检查取代，简化用户操作

## v0.19.2 (2026-04-05) — wda-start/wda-cli hotfix `#IHZ83R` `#IHZ8CQ`

### Bug 修复
- **wda-start.sh WDA 路径查找** — 优先读 `~/.config/ae/mobile-setup.json` 的 `wda_project` 字段，不再硬编码用户私人路径 (#IHZ83R)
- **wda-start.sh 重复 WDA App** — 传递 `DEVELOPMENT_TEAM` + `PRODUCT_BUNDLE_IDENTIFIER` 给 xcodebuild，确保与 `/ae-mobile-setup` 安装时签名一致，不在手机上产生第二个 WDA
- **wda-cli.py tap/swipe 404** — 从旧版私有 API (`/wda/tap/0`) 改为 W3C Actions API (`POST /session/{sid}/actions`)，兼容 WDA 11.x (#IHZ8CQ)

## v0.19.1 (2026-04-05) — 中断恢复支持付费后补测 `#IHZ7DQ`

### 改进
- **增量补测模式** — 中断恢复支持「付费后回来补测」场景：检测 pending_paid_flows → PM 确认已付费 → 只走待测功能端到端 → 增量更新 speckit (#IHZ7DQ)
- **覆盖状态正式定义** — 明确 ⬜/✅/🔄/⛔/🔒 五种状态的语义区分，⛔ 表示「有入口截图但核心流程未验证」 (#IHZ7DQ)
- **exploration-state.json schema 扩展** — 新增 pending_paid_flows / speckit_generated / payment_strategy / mcp_available / bundle_id 字段 (#IHZ7DQ)
- **Phase 3 增量更新** — speckit 已生成时，补测回来只追加新流程到 Module 02，不覆盖已有内容 (#IHZ7DQ)

## v0.19.0 (2026-04-05) — Interior AI 实战反馈 6 issue 修复 `#IHZ79E` `#IHZ79I` `#IHZ79N` `#IHZ7A2` `#IHZ7AU` `#IHZ7B0`

### Bug 修复
- **wda-start.sh UDID 解析 bug** — `ios list` 返回字符串数组时按对象解析导致 KeyError，现在兼容两种格式 (#IHZ79E)

### 新增能力
- **wda-cli.py** — WDA HTTP API 统一 CLI，当 mobile-mcp tools 不可用时的完整 fallback：screenshot/tap/swipe/launch/source/apps (#IHZ79I)

### 改进
- **Bundle ID 自动发现** — Phase 0.7 增加 App 名称模糊搜索真实 bundle ID，解决 App Store 推断 ID 与实际安装不一致的问题 (#IHZ79N)
- **付费策略评估** — Phase 0.9 分析 IAP 列表，向 PM 报告免费/付费层覆盖范围和最低测试成本 (#IHZ7A2)
- **Agent-PM 交互协议** — 标准化暂停-通知-恢复流程，适用于登录/拍照/付款等需要人工操作的步骤 (#IHZ7A2)
- **底部弹窗关闭策略** — 4 级降级方案（label→swipe→遮罩→PM 手动） (#IHZ7A2)
- **测试图片推送** — 支持通过 go-ios 推送测试照片到设备相册 (#IHZ7A2)
- **Onboarding 具体策略** — 评分弹窗跳过、付费墙找关闭、权限默认允许 (#IHZ7AU)
- **Phase 1.5 功能目录降级** — 找不到帮助入口时改为全面滚动各 Tab 发现功能 (#IHZ7AU)
- **截图精简规则** — 重复样式长列表只截首尾两屏 + 记录总数 (#IHZ7AU)
- **滚动到顶部** — 优先点击状态栏，不生效则多次上滑 (#IHZ7AU)
- **发现问题当场提 issue** — SKILL.md 核心原则 + CLAUDE.md 行为准则均内嵌规则 (#IHZ7B0)
- **MCP 可用性检查** — Phase 0.6 检测 mobile MCP 是否可用，不可用时自动切换 wda-cli.py (#IHZ79I)

## v0.18.1 (2026-04-05) — Feature Discovery by Reasoning `#IHZ400`

### 改进
- **Feature Discovery by Reasoning** — Phase 2 探索过程中，agent 主动推理发现 checklist 未列出的功能（按钮/设置开关/导航结构暗示的能力），新增 source="discovered" 标签区分来源 (#IHZ400)
- **coverage-stats.py** — 新增 discovered 来源统计和 by_source 分布 (#IHZ400)

## v0.18.0 (2026-04-05) — 探索流程全面脚本化 `#IHZ400`

### 新增能力
- **wda-start.sh** — WDA 环境一键启动，自动完成设备检测→tunnel→xcodebuild→端口转发→验证，替代 Phase 0 的 6 步手动操作 (#IHZ400)
- **screenshot-save.py** — 截图+元素树一键保存，内置黑屏检测重试，自动配对 `.png` + `.xml` (#IHZ400)
- **coverage-stats.py** — feature-checklist.md 覆盖率自动统计，支持阈值检查（core ≥ 80%, in-app ≥ 60%） (#IHZ400)

### 改进
- **SKILL.md 全面引用脚本** — Phase 0/2/2d/2e 的内联命令替换为脚本调用，agent 不再需要拼 curl/python3 一行流 (#IHZ400)
- **build.sh** — go role 新增 wda-start.sh + screenshot-save.py，mobile-agent 也能用 (#IHZ400)

## v0.17.0 (2026-04-05) — 截图隐私脱敏 + 元素树快照 `#IHZ400`

### 新增能力
- **privacy-mask.py** — 截图自动隐私脱敏脚本，基于 Apple Vision OCR 扫描 PII 关键词并自动马赛克 (#IHZ400)
  - 支持从 exploration-state.json 读取 PII 配置，也支持命令行传入关键词
  - 支持固定区域马赛克（如每页右上角头像）
  - dry-run 模式预览、JSON 输出报告
  - 预期效果：脱敏耗时从 ~30min 降至 <1min

### 改进
- **Phase 0.7: PII 关键词收集** — 环境就绪阶段即向 PM 收集姓名/设备名/ID 等隐私关键词，存入 exploration-state.json (#IHZ400)
- **Phase 2e: 隐私脱敏步骤** — Phase 2d 覆盖率检查通过后、Phase 3 生成前，强制执行 privacy-mask.py 脱敏 (#IHZ400)
- **截图保存同时 dump 元素树 XML** — 每张截图配对保存 WDA source XML，解决三套坐标系换算问题 (#IHZ400)

## v0.16.0 (2026-04-05) — ae-app-to-speckit 实战优化 `#IHZ400`

### 改进
- **Phase 0: WDA 环境启动** — 新增显式 Phase 0 六步环境就绪检查（tunnel→xcodebuild→forward→verify→screenshot→list_apps），替代原来的 3 步简单检查，解决每次新会话 ~20% 时间浪费在调试环境的问题 (#IHZ400)
- **Phase 1.5: App 内功能目录前置** — 在 Phase 2 系统遍历前先搜帮助页/全部功能入口，提前补全 feature-checklist，避免遍历中段才发现大量未知功能 (#IHZ400)
- **截图命名语义化** — 从 `{序号}-{名称}.png` 改为 `{phase}-{功能ID}-{描述}.png`，文件名即内容 (#IHZ400)
- **标准 tap 操作模板** — 新增元素树→rect→中心点→点击→verify 标准流程 + OCR 降级方案，杜绝凭视觉猜坐标（此前每次操作平均 2-3 次才成功） (#IHZ400)
- **Module 02 截图硬性规则** — 每个流程步骤必须引用真实截图，≥90% 覆盖率检查，不允许占位符 (#IHZ400)
- **中断恢复去掉 session ID** — 移除 exploration-state.json 中的 wda_session_id，恢复时通过 Phase 0 重建连接 (#IHZ400)

### 已修复（前版本）
- **Skill permissions 自动生效** — `ae link` 已自动合并 skill permissions 到 settings.local.json（ae-platform#e451a23, #IHY3Q7）

## v0.15.1 (2026-04-03) — ae-app-to-speckit 环境搭建解耦 `#IHXR0I`

### 改进
- **ae-app-to-speckit 环境搭建解耦** — 移除 skill 内嵌的 70 行环境搭建章节，改为前置条件指向 ae-go 的 `/ae-mobile-setup` (ae-platform#IHXR0I)
  - 搭建能力从 PM 专用提升为全员通用（ae-go），任何角色都能操控 iPhone
  - Phase 2 探索标注基于 `/ae-mobile-agent` 的 observe-think-act-verify 循环
  - 关联新增 #IHXR0I

## v0.15.0 (2026-04-02) — App-to-Speckit 逆向分析能力 `#IHWK3R`

### 新增能力
- **App 逆向提取 Speckit** — `/ae-app-to-speckit`，从已上架 App 逆向生成 speckit（无需源码）
  - Phase 1: App Store 信息采集（WebSearch/WebFetch）→ feature-checklist
  - Phase 2: iPhone 真机自动化探索（mobile-mcp + WDA）→ 截图 + 元素树
  - Phase 3: 逆向生成 speckit Module 01/02/04（带截图引用）
  - Phase 4: PM Review 清单 + 覆盖率报告
  - 前置条件：iPhone 真机 + USB + go-ios + WDA + mobile-mcp（SKILL.md 内含完整搭建步骤）
  - Checklist 驱动覆盖，Phase 2d 强制覆盖率 checkpoint
  - 中断恢复机制（feature-checklist + exploration-state.json + screenshots/）
  - 实跑验证：扫描全能王 38 张截图，Core 功能 100% 覆盖

### 重要说明
- 此 skill 需要额外硬件（iPhone + USB 线）和环境配置（go-ios/WDA/mobile-mcp），详见 skill 内环境搭建章节
- `mobile_save_screenshot` 在 iOS 真机上有黑屏 bug，skill 内已标注使用 WDA API 替代方案

## v0.14.1 (2026-04-02) — 飞书集成 + 求助引导机制

### 新增能力
- **飞书消息与会议 skill** — `/ae-lark-feishu`，支持搜索群聊、读取消息、搜索消息、下载图片/文件、读取私聊、发送消息、获取会议妙记/逐字稿、读取飞书文档 `#IHXG1V`
  - 前置条件：需安装 `lark-cli` 并完成飞书认证
  - 支持 8 项核心操作：群聊搜索、消息读取、消息搜索、图片下载、私聊读取、消息发送、会议妙记、文档读取

### 重要改进
- **新增「向 AE Team 求助」机制** — CLAUDE.md 新增独立章节，解决 agent 不知道什么时候该引导用户提 issue 的问题
  - 明确 AE Team 的定位：Agent 基础设施团队，不只是 speckit 工具
  - 列出已交付的通用能力范围（CLI、飞书集成、图片处理、MCP 等），让 agent 知道 AE Team 能做什么
  - 6 个具体触发场景：卡住了、重复手工活、skill 不好用、约束阻碍、缺外部服务集成、文档看不懂
  - 核心原则：「不要替用户忍耐」— 绕过问题 = 下次还会遇到，提 issue = AE Team 彻底解决
- **能力表新增飞书 skill 条目**

## v0.14.0 (2026-04-01) — Skill 命名规范化 + 目录格式

### 重要变更
- **所有 skill 文件统一加 `ae-` 前缀** — 与用户自建 skills 区分，输入 `/ae` 即可筛选出所有 ae-platform 提供的能力 `#IHWMM0`
  - `/demo-to-speckit` → `/ae-demo-to-speckit`
  - `/verify-app` → `/ae-verify-app`
  - `/submit-bug` → `/ae-submit-bug`
  - `/file-bugs` → `/ae-file-bugs`
  - `/submit-requirement` → `/ae-submit-requirement`
  - `/demo-to-figma` → `/ae-demo-to-figma`
  - `/image-decopyrighter` → `/ae-image-decopyrighter`
- **Skill 改用 folder/SKILL.md 格式** — 单文件 `.md` 在 Claude Code 的 `/` 搜索中不可见，改为 `ae-<name>/SKILL.md` 目录格式，附带 frontmatter description `#IHWNMY`
- **CLI 子命令不变** — `ae pm demo-to-speckit` 等 CLI 命令保持不变，内部自动映射到新文件名
- **CLAUDE.md / README 同步更新** — 所有文档中的 skill 引用已更新
- **link.sh 适配** — 软链接改为链接 skill 目录，`ae link pm .` 后 `/` 补全可见

## v0.13.0 (2026-03-31) — 交付完整性修复 + demo-to-figma 预处理管线

### 重大修复
- **PM 交付完整性修复** — ae-pm 之前只包含 skills 和文档，PM 拿到后无法使用任何 CLI 命令或预处理脚本 `#IHUYQ4`
  - build.sh 改造：构建 PM 包时自动打包 **完整 CLI**（ae 命令 + 9 个 lib 模块）和 **所有工具脚本**
  - ae-pm 从 10 个文件扩充到 26 个文件，PM 拿到后可完成全部自助安装和使用

### 新增能力
- **demo-to-figma 预处理管线** — 5 个脚本将确定性提取工作脚本化，LLM 只需读取 JSON `#IHUYQ4`
  - `demo-to-figma-prepare.sh` — 编排器，一键运行以下 4 个脚本
  - `discover-pages.sh` → pages.json（HTML + JS 路由扫描，过滤 action handler 噪音）
  - `extract-tokens.sh` → tokens.json（CSS :root 变量 → 分类 tokens，颜色自动转 rgb01）
  - `extract-images.sh` → images.json + *.b64（5 种图片引用模式 + 可选 base64 编码）
  - `extract-svgs.sh` → svgs.json（内联 SVG content 提取）
- **demo-to-figma skill 更新** — Step 1-2 改为调用预处理脚本，颜色直接用 tokens.json 的 rgb01

### 改进
- **setup.sh 新增 AI 工具链检查**（Step 2）— 检测 Claude Code 安装状态 + Figma MCP 连接状态，交互式引导安装
- **doctor.sh 新增 4 项检查** — Claude Code / Figma MCP / 预处理脚本就绪 / ae CLI 就绪
- **install.sh 改用 Gitee 源** — 从 GitHub 改为 Gitee，国内访问更稳定，错误提示人话化

### Figma MCP 调研结论
- `createImageAsync(url)` 在 MCP 沙箱中被明确禁用
- `generate_figma_design` 可截取简单页面（含图片），但复杂页面会 crash
- 最佳实践：**图片用色块占位 + SVG 图标通过 `createNodeFromSvg()` 完美还原**，设计师后续替换图片

## v0.12.0 (2026-03-31) — demo-to-figma skill + 图层组织规范

### 新增能力
- **`/demo-to-figma` skill** — PM demo 原型自动转 Figma 设计稿，供设计师精修 `#IHUYQ4`
- **demo-to-figma Agent Team 分工** — 页面拆分多 agent 并行处理，提升转换效率
- **CLI 工具脚本** — `figma-load-images.sh`（批量图片加载）+ `capture-demo-screenshots.sh`（自动截图）

### 改进
- **demo-to-figma 图层规范** — 嵌入 Figma 图层组织规范，解决设计师反馈的图层结构不规范问题 `#IHUYQ4`
  - 命名规范：斜杠分层命名（Card/Cover、Card/Content），禁止默认名
  - 语义分组：相关元素必须用父 Frame 包裹（Cover+Tag → CoverArea），禁止平级堆叠
  - Auto Layout 尺寸模式决策表（HUG/FILL/FIXED 何时使用）
  - Card 标准结构模板（Cover/Content/Footer 三段式）
  - SVG 图标必须 appendChild 到父容器，尺寸标准化 4 的倍数
  - Agent(80%) vs 设计师(20%) 职责边界明确
- **verify-app 完成后引导 /file-bugs** — 验证完成后主动提示用户使用 `/file-bugs` 批量提 bug
- **issue 必须填写验收标准** — `/submit-bug`、`/submit-requirement`、`/file-bugs` 强制要求验收标准字段，杜绝无法验证的 issue
- **查收更新验收反馈闭环** — PM 拉取更新后，agent 自动提取关联 issue，引导逐个验证并回写 comment 到 Gitee

## v0.11.0 (2026-03-26) — 图片去版权化工具

### 新增能力
- **图片去版权化** (`/image-decopyrighter`, `ae pm image-decopyright`) — 将有版权风险的图片通过 AI 重绘生成可商用替代图片 `#IHQQOZ`
  - Claude Vision 提取图片语义 → 图片生成 API 重绘 → 输出可商用替代
  - 默认使用 Google Imagen 4.0（免费层 50 张/天），支持切换 Together AI / DALL-E 3
  - 支持单张、批量处理，可指定风格（illustration, watercolor 等）和尺寸
  - 配置 `GEMINI_API_KEY` 即可使用

## v0.10.0 (2026-03-26) — Backlog 推进（validator + 数据发现 + 后端验证）

### 新增能力
- **Speckit Schema Validator** (`ae pm validate-speckit`) — 校验 speckit 目录是否符合 schema 标准，支持 JSON 输出，同义词 fuzzy match（解决章节名不完全一致的问题） `#IHQJFK`
- **后端编译验证 skill** (`/backend-build-verify`, `ae dev backend-build`) — 补齐后端验证链：gradle build → bootRun → smoke test，与 iOS 的 build/test 对等 `#IHQJFJ`

### 改进
- **demo-to-speckit 数据源发现** (Step 1.8) — 新增 CSV/JSON/SQLite/Plist/CoreData 文件扫描步骤，确保模块 05/06 完整描述数据层，避免成品遗漏真实数据源 `#IHQQC3`
- **Tab 双层重叠 bug 转 ae-dev** — 归因为 [GEN-BUG]，已转至 ae-dev#IHQR39 跟进 `#IHQQC8`

## v0.9.0 (2026-03-26) — 一键搭建 + 自动提 bug

### 新增能力
- **`ae setup` 命令** — 一键完成环境搭建：安装依赖 → 克隆仓库 → 配置 Token（交互式 + 自动验证）→ 环境检查 → 入驻确认
  - Token 配置改为必填（不再允许跳过），输入后立即验证有效性
  - 入驻确认自动完成（通过 API 发 comment），不再需要让 agent 代劳
  - 支持角色选择：`ae setup pm` / `ae setup dev` / `ae setup both`
- **`/file-bugs` skill + `ae pm file-bugs` CLI** — 从 verify-app diff report 自动生成 issue 草稿，PM 确认后批量提交

### 修正
- **doctor token 检查** — 修复 subshell 导致 token 无效时不影响最终检查结果的问题
- **curl 超时** — doctor 和 setup 的 API 调用统一加 `--max-time 10`

### 改进
- **README 快速开始重写** — 从 6 步手动操作简化为 `ae setup` + `ae link pm .` 两步

## v0.8.0 (2026-03-26) — verify-app → 自动提 bug

### 新增能力
- **`/file-bugs` skill** — 读取 verify-app 的 diff report，自动生成 issue 草稿（含归因前缀、验证级别、case ID），PM 确认后批量提交
- **`ae pm file-bugs` CLI 命令** — 解析 diff-report.json，交互式选择后批量调用 Gitee API 提交

### 改进
- **`/submit-bug` 前缀兼容** — 支持 `[GEN-BUG]`、`[SPECKIT-GAP]`、`[CONSTRAINT-GAP]`、`[DEMO-BUG]` 前缀，不再强制覆盖为 `[BUG]`

### 设计意图
PM 跑完 `/verify-app` 后说"提 bug"，agent 自动从 diff report 生成所有 issue，PM 只需确认。**PM 不做流程 QA。**

## v0.7.0 (2026-03-26) — Bug 反馈质量升级

### 重要变更
- **`/submit-bug` skill 重写** — 增加归因引导（5 个阶段前缀）、UI 截图要求、笼统描述拆分机制
  - 归因阶段：DEMO-BUG / SPECKIT-GAP / GEN-BUG / CONSTRAINT-GAP / BUG
  - UI 类 bug 必须附截图，否则标注 ⚠️ 需人工复现
  - 笼统描述（如"视觉差距大"）必须拆成 2-3 个可验证具体条目
- **批量提交规范** — 多个 bug 逐个独立提交，各自归因，禁止合并为一个 issue

## v0.6.0 (2026-03-26) — Bug 提交收归 CLI

### 新增能力
- **`/submit-bug` skill** — 引导 agent 收集 bug 信息后通过 `ae` CLI 自动提交到 Gitee，杜绝本地 issue 文件
- **`ae pm submit-bug` CLI 命令** — 直接调用 Gitee API 提交 bug 报告，支持 `--repo` 指定目标仓库

### 重要变更
- **Gitee API 调用收归 CLI** — CLAUDE.md 明确禁止 agent 创建本地 issue 文件或直接调用 curl/Gitee API，统一通过 `ae` CLI 完成
- **`_pm_gitee_create_issue()` 通用函数** — CLI 内部抽出 Gitee issue 创建的通用函数，后续 `submit-requirement` 可复用
- **curl 加固** — 增加 `--max-time 30` 超时防止代理未清除时挂死，token 通过 `os.environ` 安全传递

### 修正
- 修复 agent 按 README 提 bug 时 fallback 为创建本地 markdown 文件的问题

## v0.5.0 (2026-03-26) — Pipeline v0.2

### 机制升级（4 项同步升级）

- **Context Manifest (P0)** — `/demo-to-speckit` 新增 4 类上下文发现机制（codebase / product_doc / design_asset / strategic_context）+ 来源置信度标注（confirmed / extracted / inferred / missing）
- **Constraint Detection (P1)** — 约束文件新增可执行 Detection Rules，在 pipeline 3 个阶段自动触发（before:demo-to-speckit / after:speckit-receive / before:verify-app）
- **Verify Level System (P1)** — 测试用例分为 structural / behavioral / functional 三级，coverage 升级为三维报告
- **Speckit Schema (P2)** — 新增 `content/speckit-schema.yaml` 定义 6 模块格式标准（required_sections + quality_indicators）

### 改进

- `/demo-to-speckit` 新增 Step 0（约束合规预检）和 Step 1.5（上下文搜集），输出增加 `00-context-manifest.md`
- `/verify-app` 新增 Step 1.5（约束合规预检），输出增加 `constraint_violations` 和 `coverage_by_level`
- `/speckit-receive` Step 1 升级为 schema-based 深度验证，新增 Step 5.5 约束合规检查
- 约束文件 `content/constraints/{ios,backend,data}.md` 各增加 Detection Rules 节（共 16 条规则）

## v0.4.0 (2026-03-26)

### 重要变更
- **PM → Dev 衔接说明** — README 和 CLAUDE.md 新增完整的操作步骤：PM 生成 speckit 后如何调用 ae-dev 生成成品
  - 方式一：`ae dev speckit-receive <speckit_dir>`（推荐）
  - 方式二：手动创建项目 → `ae link dev .` → 打开 Claude Code 指定 speckit 路径

### 修正
- **能力清单更新** — CLAUDE.md "当前能力"表补全了 `/demo-to-speckit` 和 `/verify-app`，删除了已过时的"规划中的能力"段落（这些能力早已可用）

## v0.3.0 (2026-03-26)

### 重要变更
- **愿景声明** — CLAUDE.md 开头新增愿景与定位，明确反馈机制：凡与愿景有偏差的情况都应反馈给 AE Team
- **README 重写** — 从纯安装指引升级为完整产品介绍（理念、全链路、能力清单、反馈方式）

### 新增能力
- **iOS 编译验证 skill** (`/ios-build-verify`) — xcodebuild 编译 + 自动修复 loop
- **iOS UI 测试 skill** (`/ios-ui-test`) — AXe + simctl 自动化测试（Native/WebView 双模式）
- **Speckit 接收生成 skill** (`/speckit-receive`) — 从 speckit 生成 iOS + 后端项目

### 改进
- 跨平台说明：README 中增加 Claude Code / Codex / Cursor 三种工具的使用方式

## v0.2.0 (2026-03-26)

### 新增能力
- **App 差异比对验证 skill** (`/verify-app`) — E2E 对比 demo vs 成品，自动归因差异到 speckit 提取 / 代码生成 / 约束缺失

### 新增约束
- **技术选型约束** — CLAUDE.md 新增 iOS/后端/数据层技术约束，确保 PM vibe coding 产出符合后续流程要求
  - iOS: 必须 SwiftUI Native，禁止 WebView hybrid
  - 后端: Spring Boot 3.x + MyBatis + Flyway
  - 数据: 禁止硬编码，Mock 遵循 REST 契约

### 基础设施
- E2E verify 框架: 测试用例格式 (YAML) + 执行引擎 + baseline 报告格式 (JSON)
- ShoeLens 验证用例: 25 个 test cases，baseline coverage 72%

## v0.1.0 (2026-03-25)

首版发布。

### 新增能力
- **Issue 反馈提交** — 通过 Gitee API 向 ae-pm repo 提交 bug / 功能需求 / 使用疑问
- **查收更新** — 读取 CHANGELOG.md 了解最新版本更新内容
- **提需求 skill** — 标准化的需求提交流程，确保需求是可复用机制（reusable mechanism）

### 基础设施
- CLAUDE.md 核心指令
- README.md 安装指引
- 入驻确认流程（通过 comment 验证配置）
