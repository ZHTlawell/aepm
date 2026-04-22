# Changelog

## v0.50.1 (2026-04-22) — builder-kickoff 重构为 README 入口 + 子 prompt 结构 [`#IJDC46`](https://gitee.com/turningsyn/ae-pm/issues/IJDC46)

### 改动（docs/builder-kickoff/ 内部结构调整）

- **`README.md` 重写为入口 prompt** — 作为"入门教练"做分诊 + 路由，不再是目录导览文档。组织内部人员直接把 README 整个粘贴到 Claude Code，由 Claude 根据产品状态（A-E）和意图路由到对应子 prompt
- **`engineer-bootstrap-prompt.md` 格式统一** — 去掉外层 README 包装 + 内嵌代码块，与 `builder-cadence-prompt.md` 对齐为纯 prompt 格式
- **子 prompt 引用路径统一为绝对路径** `~/.ae/pm/docs/builder-kickoff/...`，避免工程师在任意 cwd 启动 Claude Code 时读不到

新结构：
```
README.md (入口 prompt，分诊+路由)
├── engineer-bootstrap-prompt.md  (技术流程子 prompt)
├── builder-cadence-prompt.md     (周期节奏子 prompt)
├── ae-pm-flow.md                 (资源：M0→M3 流程图)
└── issue-template.md             (资源：tracking issue 模板)
```

README Stage 2 定义了切换指令表（"切到节奏对齐" / "回到技术流程" / "建 repo 怎么做" / "TestFlight 前规范检查" 等），使用者过程中可随时跳转。

### 验证

- `bash scripts/build.sh pm` → `dist/pm/docs/builder-kickoff/` 五份文件齐备
- 三份 prompt 首行均直接进入 prompt 主体，无外层 README / 代码块包装

## v0.50.0 (2026-04-22) — 新增 docs/ 目录 + Builder 入门引导（内部文档） [`#IJDBZ3`](https://gitee.com/turningsyn/ae-pm/issues/IJDBZ3)

### 新增（内部文档，非用户运行时）

- **`docs/builder-kickoff/`** — 面向有 ae-pm repo 权限的组织内部人员（AE Team 成员 / 被授权 builder）的入门引导材料：
  - `README.md` — 目录定位 + 两份 prompt 场景区分
  - `engineer-bootstrap-prompt.md` — **技术流程引导**（8 Stage M0→M3 薄 orchestrator，顺序触发 `/ae-speckit-brainstorm` → `/ae-speckit-to-app` → `/ae-app-to-testflight`）
  - `builder-cadence-prompt.md` — **周期节奏对齐**（认领 → Demo → TestFlight → 打分 → 迭代 + TestFlight 前 Onboarding/Paywall/Survey/求好评/求评分规范硬关卡）
  - `ae-pm-flow.md` — M0→M3 流程图 + 工程师 7 步人话版
  - `issue-template.md` — 产品 tracking issue 模板（Part A body + Part B Wave 评论）

### 改动

- `scripts/build.sh` — 新增通用 `templates/<role>/docs/` 打包逻辑（以后任意角色新增 docs 自动打包）

### 打磨原则

- 去团队特指 / 去人名（用"产品负责人"/"签名负责人"等通用角色）
- 时间锚点相对化（周期节奏，具体日期由产品负责人在启动时告知）
- 黑话首次出现加解释（Route B / BCStoreKit / ATT / ASC 等）
- 卡点继续策略具体化（workaround → 并行 P0 阻塞项 → `[blocking]` 加急）
- 两份 prompt 定位互补（技术流程 vs 周期节奏），不重复

### 验证

- `bash scripts/build.sh pm` → `dist/pm/docs/builder-kickoff/` 五份文件齐备
- 人名 / 地域 / 内部黑话全量 grep 扫描无残留

## v0.49.1 (2026-04-22) — 修复 README 一键安装命令 [`#II8UYE`](https://gitee.com/turningsyn/ae-pm/issues/II8UYE)

### 修复

- **`templates/pm/README.md` "一键搭建" 段** — 原 `curl | sh` 一行安装命令的目标 URL 失效（HTTP 404），改为 `git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm && bash ~/.ae/pm/cli/install.sh` 两步流程：
  - 业务代码全程走 Gitee 企业版（turningsyn）内部，不依赖任何匿名公共 raw URL（Gitee 企业版天然禁用匿名 raw）
  - install.sh 已支持"pm 目录已存在则跳过 clone"逻辑，新老流程兼容
- 新增"首次 clone 需要 Gitee 企业版 git 凭证"前置条件说明

### 验证

- README "一键搭建" 段落替换后可被 PM 按新步骤跑通

## v0.49.0 (2026-04-22) — PM 产品线结构性重写：M0→M3 中间品流水线 [`#IJC8D4`](https://gitee.com/turningsyn/ae-platform/issues/IJC8D4) [`#II8UYE`](https://gitee.com/turningsyn/ae-pm/issues/II8UYE)

### 重大变更

整条 PM 产品线围绕 **4 个人类可确认中间品（M0 Idea → M1 Speckit → M2 本地可用程序 → M3 TestFlight）** 重新组织，替代原 Phase 0-7 结构。skill 职责按中间品边界重新切分，并明确"skill = 中间品之间的变换"这一设计原则。

### 新增 skill

- **`/ae-speckit-to-app`** 🆕 — M1→M2 核心段。承载 Route B 约束（CocoaPods + BCStoreKit + BCSensor + BCAdjust + BCNetwork + Work Chain 12 步）+ 代码模板包，作为薄 harness 透传给外部构建环境。内部 precheck 吸收自原 `/ae-preflight`。
- **`/ae-speckit-brainstorm`** 🆕 — M0→M1 集合。从零与 PM 对话共创 Speckit，填补"没有 demo、没有参考 App、只有想法"这一起点的入口缺口。

### 改名

- **`/ae-analytics-setup` → `/ae-analytics-integrate`** — M2→M3 段的埋点接入 skill 改名，命名与中间品变换语义对齐。
- **`/ae-testflight-publish` → `/ae-app-to-testflight`** — M2→M3 段的 TestFlight 分发 skill 改名，命名格式统一为"起点中间品→终点中间品"。

### 废弃

- **`/ae-superwall-setup`** — Route A 遗产，目录已删除。Route B 下支付集成收敛至 BCStoreKit，由 `/ae-speckit-to-app` 内置约束。

### 归档为 utility

下列 skill 不在主线 M0→M3 流水线上，但保留为按需使用的 utility，源码仍在 `skills/pm/`：

- `/ae-verify-app` — E2E 对比 demo vs 成品
- `/ae-file-bugs` — 从 verify 报告批量提 bug
- `/ae-demo-to-figma` — 原型转 Figma
- `/ae-image-decopyrighter` — 图片去版权化
- `/ae-prod-to-local` — 线上代码转本地原型

### 移出主线（另议）

下列能力暂时移出 M0→M3 主线，源码保留供参考，路线和需求另议：

- `/ae-app-review-check` — App Store 审核自检（M3 之后另议）
- `/ae-asc-submit` — ASC 元数据提交审核（M3 之后另议）
- `/ae-prod-data-feedback-report` — 产品数据反馈报告（Stage 5 另议）
- `/ae-preflight` — 已融入 `/ae-speckit-to-app` 内部 precheck，不再独立触发；目录暂保留供参考。

### 路线定调

- **Route B**（唯一维护路线）：CocoaPods 依赖管理 + BCStoreKit + BCSensor + BCAdjust + BCNetwork + Work Chain 12 步构建流水线。所有约束内置在 `/ae-speckit-to-app` 中，由 skill 透传给外部 harness。
- **Route A** 不再维护（`/ae-superwall-setup` 随之废弃）。

### 设计原则

1. **Skill = 人类可确认中间品之间的变换** — 每段 skill 有明确输入输出中间品（M0/M1/M2/M3），PM 可在中间品处停检。
2. **Harness 薄，透传约束** — skill 不重复造轮子，把 Route B 约束和代码模板打包交给外部 harness（ae-dev / Claude Code）执行。
3. **一次通过率为核心度量** — 每段 skill 的目标都是 first-pass yield，失败通过 `/ae-report-fix` 回流修复。

### 验证

经 agent team 三层验证全部通过：

- **V1 构建**：`scripts/build.sh pm` 退出码 0；`dist/pm/.claude/skills/` 含 ae-speckit-to-app / ae-speckit-brainstorm / ae-analytics-integrate / ae-app-to-testflight；不含废弃 skill；README M0/M3 出现 16 次，Phase 0-7 零出现
- **V2 元数据**：4 个新/改名 skill frontmatter 全部合法；18 个 skill 目录清单正确；交叉引用命中全部属于豁免（CHANGELOG 改名说明 / README 过渡对照）
- **V3 Dogfood 编译**：
  - L1 模板语法：16/16 `.swift.tmpl` `swiftc -parse` 零 error（Swift 6.2.1）
  - L2 对比 `bible-ios-template` 真实代码：13 个 Work 模板 + BCConfig.swift.tmpl 与真实源**结构完全对齐**，diff 10-36% 全部来自注释本地化/格式优化/增值防御（如 06_UserInitWork 加 `DEBUG_SKIP_USERINIT` 逃逸）
  - L3 真实工程编译：`xcodebuild -workspace Template.xcworkspace ... build` **BUILD SUCCEEDED**，所有私有源 Pod 框架成功编译

### 关联

- 主 issue: [`#IJC8D4`](https://gitee.com/turningsyn/ae-platform/issues/IJC8D4)（PM 产品线结构性重写）
- Route B 路线: [`#II8UYE`](https://gitee.com/turningsyn/ae-pm/issues/II8UYE)
- 埋点与支付整合: [`#II8RAE`](https://gitee.com/turningsyn/ae-pm/issues/II8RAE)

## v0.48.2 (2026-04-21) — ae git CLI 升级 Bearer header 鉴权 [`#IJC7PK`](https://gitee.com/turningsyn/ae-go/issues/IJC7PK)

### 修复

- **scripts/ae-git.py** — Gitee 网关已停用 `?access_token=xxx` query param 鉴权方式（请求直接 drop → 所有命令 timeout）。统一改走标准 `Authorization: Bearer <token>` HTTP header：
  - `api_request()` 接收 `token` 参数后注入 Authorization header，URL 和 body 不再带 `access_token`
  - 覆盖所有命令：`issues create/comment/get/list/list-comments/close/edit/edit-comment` + `upload-image` + `auth validate/user`
  - 401/403 错误信息从"认证失败"改为"Token 无效或已过期"，附带重新生成 token 的链接，减少误判为网络问题
- 移除 URL 中的 token → 规避 URL 日志/Referer 泄露风险

### 验证

- `python3 scripts/ae-git.py auth user` → 返回 login/name/id（HTTP 200）
- `python3 scripts/ae-git.py issues list --repo ae-go` → 正常返回 issue 列表
- `python3 scripts/ae-git.py issues list --repo ae-go --token invalid_xyz` → exit 2 + "Token 无效或已过期 (HTTP 401)"
- 抓包确认：请求头含 `Authorization: Bearer …`，URL 中无 `access_token`

## v0.48.1 (2026-04-20) — ae-app-to-speckit 修复图片上传测试失效 [`#IJB5M5`](https://gitee.com/turningsyn/ae-pm/issues/IJB5M5)

### 修复

- **SKILL.md line 614** — 删除虚构命令 `ios push-photo`（go-ios v1.0.188 实测无此子命令），改为三层可执行策略：
  1. **真机 agent 自动（主选）** — Safari 下载路径：`~/.ae/pm/test-assets/` 起本地 http.server + `ios forward` + `mobile_open_url` + 长按 + 点"添加到照片"
  2. **Simulator 专用** — `xcrun simctl addmedia`
  3. **PM 兜底** — 明确 AirDrop / iMessage 可执行话术（不再只写"请手动"）
- 新增成功后写入 `exploration-state.json.test_assets[]`，复用已推送素材避免重复
- 标注"Safari 长按菜单在不同 iOS 版本可靠性不一"的已知风险，失败即降级

### 触发场景

任何"用户上传图片"型功能（AI 图像生成 / OCR / 头像 / 票据扫描 / Photo→Tutorial 等）都依赖此路径。LoopCraft F07 Photo→Tutorial 末端补测即为本次触发案例。

## v0.48.0 (2026-04-17) — ae-app-to-speckit 增加 App 健康度检测 [`#IJ87FB`](https://gitee.com/turningsyn/ae-pm/issues/IJ87FB)

### 新功能

- **wda-cli.py 新增 3 个原子能力**：
  - `wda-cli.py active-app [--json]` — 返回当前前台 bundle id / pid / name（crash 检测用：bundle 变化 = App 被踢出前台）
  - `wda-cli.py terminate BUNDLE_ID` — 强制 kill 指定 App（freeze 时配合 launch 做彻底重启）
  - `wda-cli.py page-hash [--json] [--save PATH] [--rect-tolerance N]` — 页面**结构指纹**：取 `/source?format=json`，递归提取 `(type, name, label, value, bucketed_rect)` → sha1。rect 默认按 2px 桶化忽略动画 jitter，但捕获真实布局变化
- **SKILL.md 新增「App 健康度检测 + 归因决策树」段落**：
  - 核心规则：**单次失败怀疑自己，连续 2+ 次切换假设**
  - crash 检测：`active-app` bundleId 不等于目标 → `app_crashed` → launch + 留档
  - freeze 检测：连续两次 `page-hash` 不变 → `app_frozen` → terminate + launch + 重试 1 次
  - 阈值暂停：单 Phase `app_health_events.length >= 3` → 暂停并请 PM 介入
- **exploration-state.json 新增 `app_health_events` 字段**（含 timestamp / phase / step / type / detected_by / expected_bundle / actual_bundle / last_screenshot / recovery）
- **subagent prompt 模板**（Phase 2a L2 batch 版 / Phase 2b flow 版）均加入健康度检测规则，摘要中用 `[app_health_event: {type} at F{id}]` 显式标注
- **Phase 3 Module 04** 若 `app_health_events.length >= 3`，报告顶部自动加「⚠ 探索期间 App 健康警告」块，标注受影响功能
- **技术风险表**新增一行：「App 卡死/闪退被 agent 误判为自身错误」

### 解决痛点

历史行为：操作后「页面不变 / 回到主屏」时 agent 默认归因到「按钮坐标不对/元素未就绪」→ 换元素 + 微调坐标 + 加 sleep 的重试循环 → context 膨胀 5-10 倍、探索叙事完全偏离。

修复后：给 agent 清晰的 tradeoff 二分（自己错 vs App 挂了）+ 低成本诊断信号（2 次 WDA 调用）+ 阈值暂停请 PM 介入。

## v0.47.0 (2026-04-17) — WDA 工具链支持多 session 并行 [`#IJ86QM`](https://gitee.com/turningsyn/ae-pm/issues/IJ86QM)

### 新功能

- **wda-start.sh** — 新增 `--port PORT` 参数，支持多 session 各自占用不同 WDA 端口
- **多 session 隔离**：
  - `pkill` 精确按 UDID 匹配（`xcodebuild.*WebDriverAgentRunner.*$UDID` / `ios forward $PORT $PORT --udid=$UDID`），不再误杀其他 session 的 WDA/forward
  - `ios tunnel` 已存在则复用（tunnel 是 per-machine 共享资源）
  - xcodebuild 日志按端口隔离 `/tmp/wda-xcodebuild-${PORT}.log`
- **wda-cli.py / screenshot-save.py / ocr-screenshot.py** — 统一读取 `WDA_URL` 环境变量（默认 `http://localhost:8100`），支持多 session 各自 `export WDA_URL=http://localhost:8101`
- **ocr-screenshot.py** 新增 `--wda-url` 显式参数（覆盖环境变量）

### 使用场景

```bash
# Session A (iPhone XS)
bash wda-start.sh --udid 00008020-... --port 8100
export WDA_URL=http://localhost:8100

# Session B (iPhone 15) — 并行，不打断 A
bash wda-start.sh --udid 00008120-... --port 8101
export WDA_URL=http://localhost:8101
```

### 放弃 scope（PM 确认 2026-04-17）

issue 原 P2-P4（exploration-state.json 多 device 字段 / SKILL.md 多设备流程 / 跨设备对照报告）全部放弃 — 不同设备 = 不同 session，不需要单 session 内管理多设备状态。

## v0.46.0 (2026-04-17) — ae-app-to-speckit 子 agent 隔离执行（CP3/CP4 由 subagent 托管） [`#IJ864Z`](https://gitee.com/turningsyn/ae-pm/issues/IJ864Z)

### 新功能

- **P1 — Phase 2a Level 2 / Phase 2b 默认用 subagent 执行**（[`#IJ864Z`](https://gitee.com/turningsyn/ae-pm/issues/IJ864Z)）
  - CP3 每 batch（8 个子入口）/ CP4 每条 flow 由 `Agent(subagent_type=general-purpose)` 独立跑
  - 子 agent 吃截图 + 元素树 + 更新状态文件，结束时返回 **≤200 字摘要** 给 main agent
  - main agent context 增长：20-40 张子入口截图 → 3-5 段 ≤200 字摘要（降幅约 98%）
  - 子 agent 销毁时它吃的全部图像蒸发，main agent 从不接触这些图
- **Fallback 机制保留 inline 路径**：subagent 调用异常 / 磁盘状态断言失败 / 连续 2 次失败 → 降级为 v0.45.0 inline 执行方式，`exploration-state.json.notes` 记录原因
- **SKILL.md 新增章节**：
  - 「子 agent 隔离执行架构」— 包含 Phase 2a L2 batch 版 + Phase 2b flow 版两个 prompt 模板
  - 物理操作节点融入 subagent 流程：子 agent 遇到拍照/上传/登录时在摘要标 `[需 PM 物理操作]`，main agent 接管补写，不重跑整条 flow
- **技术风险表**新增 subagent 线性累积对策条目

### 架构意义

v0.44.1 → v0.45.0 → v0.46.0 三连：
- **v0.44.1**：机制性约束（`tap-element` CLI 禁止裸坐标）
- **v0.45.0**：截图结论即时落盘 + 取消 CP7 停顿
- **v0.46.0**：subagent 隔离 Phase 2a L2 / 2b 的 context 增长

组合效果：skill 从"每次 tap 都累积 context，到 CP7 需要 PM 介入 /compact"变成"main agent 全程看摘要、subagent 吞吐截图、autoCompact 兜底、全程无 PM context 管理停顿"。

### 验证

- **Sanity test**（不依赖 WDA）：spawn 一个 general-purpose 子 agent 模拟 batch 1（F01-F03），子 agent 成功 Write 3 张截图占位 + 追加 phase-summaries.md + JSON merge exploration-state.json + 返回 ~150 字摘要
- **真机 E2E**：延后到首次 LoopCraft 或下一次实战运行时观察——改动面大但有 fallback 兜底
- SKILL.md YAML frontmatter 解析通过

### 延后

- **v0.47.0 — P3 screenshot 默认落盘**：统一 `wda-cli.py screenshot --save` 替代 `mobile_take_screenshot`

### 关联

- 主 issue: [`#IJ864Z`](https://gitee.com/turningsyn/ae-pm/issues/IJ864Z)（P1 完成后关闭）
- 前置：v0.45.0 P0+P2（落盘纪律 + 取消 CP7 停顿）

## v0.45.0 (2026-04-17) — ae-app-to-speckit 全程自主推进（取消 CP7 停顿 + 截图结论即时落盘） [`#IJ864Z`](https://gitee.com/turningsyn/ae-pm/issues/IJ864Z)

### 新功能

- **P0 — 核心原则 #8「截图结论即时落盘」**（[`#IJ864Z`](https://gitee.com/turningsyn/ae-pm/issues/IJ864Z)）
  - 每次 Read 一张截图后，**下一次 tool call 之前**必须把"这张图证明了什么"写到磁盘
  - 两种落盘位置任选其一：`exploration-state.json.screenshot_to_feature["<文件名>"]` 或 `phase-summaries.md` 当前 CP 段落
  - 写完后**不再 Read 同一张图**，需要引用时读结论文本
  - 这是 autoCompact 自动触发后结论不丢失的必要条件
- **P2 — 取消 CP7 的 `/compact` 停顿提示**（#IJ864Z）
  - Phase 2e 脱敏后 skill 直接进入 Phase 3，不再建议 PM 手动 /compact
  - 物理操作节点从 5 个降为 4 个（PII/付费/拍照/付费墙+登录墙），CP7 移出该列表
  - autonomous CP7 日志改为 `[CP7] 脱敏完成（{n} 张截图），直接进入 Phase 3（autoCompact 会在压力大时自处理）`
  - 依赖：P0 落盘纪律到位后，autoCompact 任意时刻自动触发都无损

### 意义

skill 从 Phase 0 到 Phase 3 **全程不再需要为 context 管理停下来等 PM**。只在"必须物理世界介入"的场景才暂停（PM 提供 PII、决策付费、拍照上传、登录墙/付费墙决策）。

### 关联与延后

- 完成：P0 落盘纪律 + P2 取消 CP7 停顿
- 延后到 v0.46.0：**P1 subagent 隔离** — 把 Phase 2a Level 2 每 batch / Phase 2b 每条 flow 改为子 agent 执行，main agent context 只吃摘要不吃截图
- 延后到 v0.47.0：**P3 screenshot 默认落盘** — 统一用 `wda-cli.py screenshot --save` 替代 `mobile_take_screenshot`
- 前置：[`#IJ85I0`](https://gitee.com/turningsyn/ae-pm/issues/IJ85I0) v0.44.1 已完成的机制性约束改造

## v0.44.1 (2026-04-17) — ae-app-to-speckit 机制性约束替代文档约束 [`#IJ85I0`](https://gitee.com/turningsyn/ae-pm/issues/IJ85I0)

### Bug Fix

- **wda-cli.py 新增 `tap-element` 子命令**（[`#IJ85I0`](https://gitee.com/turningsyn/ae-pm/issues/IJ85I0) P0）— 物理上禁止裸坐标 tap
  - 支持 `--by accessibility_id|name|label|xpath|predicate|class_chain` 定位元素
  - 内置 alert 前置检查（有 iOS 系统弹窗直接退出码 2，不允许 tap 下穿）
  - 找不到元素 fail-fast 退出码 3，并提示 `wda-cli.py source` 排查
  - 解决历史问题：长会话下 agent 图省事直接拍脑袋坐标（LoopCraft 实战复现 3 次）
- **wda-cli.py 新增 `scroll-to-top` 子命令**（#IJ85I0 P1）— status-bar tap 降级为 fallback
  - 默认先尝试 status-bar tap（best-effort），再 swipe-down × N（默认 6 次）
  - 解决历史问题：SKILL.md 写的"优先点击状态栏 y=0"在多 App 完全无响应
- **wda-cli.py 新增 `alert` / `alert-safe-tap` 子命令**（#IJ85I0 P1）— alert 检查前置化
  - `alert --action text|buttons|accept|dismiss [--button-label LABEL]` 统一弹窗操作
  - `alert-safe-tap` 在无弹窗时才 tap（有 alert 退出码 2），替代"先 tap 再查 alert"弯路
  - 解决历史问题：agent 遇新页面仍先 tap 再查 alert，浪费 1-2 张截图
- **SKILL.md 标准 tap 模板升级为强制流程**（#IJ85I0）— 从"建议"改为 CLI 强制
  - Step 0 alert 前置检查；Step 1 强制 `wda-cli.py tap-element`；Step 3 裸坐标降级为最后手段
  - 滚动回顶部默认 `wda-cli.py scroll-to-top`；不再把 y=0 tap 作为"优先"方案
  - 持久化状态页面引入幂等性检查 + `exploration-state.json.dirty_state_pages` 字段（Counter/草稿残留防污染）
  - 技术风险表新增 4 条对应 #IJ85I0 的机制性对策

### 根因与对策

历史修复（#IHZ400 第 5 项 / #IIS1I0 第 1、4 项）都是"在 SKILL.md 加一段说明"，但 LoopCraft 实战验证长会话下 agent 会绕过文档约束。v0.44.1 改为**机制性约束**：把规则下沉到 `wda-cli.py` CLI 层，用退出码和参数约束替代文档提醒，从路径上堵住回归。

### 验证

- `wda-cli.py tap-element --by name --value "Profile"` 在 WePray 真机成功跳转 Profile 页（元素中心点 320,800，rect 272,773,96,54）
- `wda-cli.py tap-element --by name --value "NonExistentButton"` 返回退出码 3 + 排查提示
- `wda-cli.py alert --action text` 在无弹窗时正确返回 "(no alert)"（404 已兼容）
- `wda-cli.py scroll-to-top --max-swipes 2` 端到端执行通过

## v0.44.0 (2026-04-17) — ae-app-to-speckit 默认 autonomous 模式 [`#IJ84WI`](https://gitee.com/turningsyn/ae-pm/issues/IJ84WI)

### 新功能
- **ae-app-to-speckit 引入 autonomous 执行模式**（[`#IJ84WI`](https://gitee.com/turningsyn/ae-pm/issues/IJ84WI)）— 解决单次扫描 PM 手动输入 10+ 次 "continue" 的可用性问题
  - **默认 autonomous**：CP1-CP7 写完 `phase-summaries.md` + 更新 `exploration-state.json` 后输出一行日志直接继续，不再阻塞等 PM `continue`
  - **物理操作节点仍暂停**：Phase 0.7 PII 收集 / 0.8 付费决策 / 2b 拍照+上传 / 首次 paywall+登录墙 / CP7 脱敏后建议 /compact — 这些节点仍请 PM 接管
  - **`--interactive` 回退**：`/ae-app-to-speckit --interactive` 恢复 v0.43 老行为（每 CP 等 PM `continue`），向下兼容
  - **根因澄清**：过去版本把「持久化摘要（磁盘写入）」与「阻塞等待（PM continue）」绑在一起；实际上图片维度 2000px 上限由 batch 化 + `autoCompact: true` 自动处理，token 在 1M context 下远未触顶，CP 阻塞纯浪费 PM 时间
  - 风险表新增 #IJ84WI 对策条目；test-scenarios.md 新增场景 6/7 覆盖 autonomous/interactive 两种模式

## v0.43.1 (2026-04-17) — ae-git 补齐 edit / edit-comment 能力 [`#IJ83B3`](https://gitee.com/turningsyn/ae-platform/issues/IJ83B3)

### 新功能
- **`ae git issues edit`** — 修改 issue 标题或正文（企业版 PATCH 端点）
- **`ae git issues edit-comment`** — 修改已发 comment 正文（标准 API PATCH 端点）
- 补齐基础 CRUD，支持事后修订（错别字、敏感 URL、补充信息）
- 实测通过：两个端点均成功 PATCH（#IJ83B3 验证评论 + IJ83ER 测试 issue）

## v0.43.0 (2026-04-17) — ae-preflight 新增 SwiftUI 代码质量扫描 + iOS 上架硬约束文档 [`#IJ7XIY`](https://gitee.com/turningsyn/ae-pm/issues/IJ7XIY) [`#IJ7XIS`](https://gitee.com/turningsyn/ae-pm/issues/IJ7XIS)

### 新功能
- **ae-preflight Phase 4.5 SwiftUI 代码质量扫描**（[`#IJ7XIY`](https://gitee.com/turningsyn/ae-pm/issues/IJ7XIY) + [`#IJ7XIS`](https://gitee.com/turningsyn/ae-pm/issues/IJ7XIS)）
  - 基于 **swift-syntax AST** 解析（不是正则），精确识别 SwiftUI 交互模式与闭包结构
  - `ios-pub-010` — 交互元素触控区域 < 44pt（Button / NavigationLink / onTapGesture 链上的 `.frame(width/height:)`）
  - `ios-pub-011` — Button / onTapGesture 的 action 闭包为空或仅 `print(...)` 占位
  - 支持人类可读报告 + `--json` 机器可读输出
  - 首次运行自动编译（~30-60s），后续 < 1s 启动
- **iOS 上架硬约束文档**（`templates/pm/constraints/ios-publish-constraints.md`）
  - 代码级硬约束，含 10 条 Blocker + 5 条 Warning，每条带错误/正确 SwiftUI 示例
  - 作为 linter 规则的**单一真源**，规则 ID `ios-pub-xxx` 贯穿约束文档 + SKILL.md + linter 报告
  - PM vibe coding 时可直接作为上下文喂给 AI 编程工具

### 架构
- 新增 `scripts/preflight-swiftui-lint/`（SwiftPM 工具）+ `scripts/preflight-swiftui-lint.sh`（一键 wrapper，自动 build + 运行）
- `build.sh` pm role 打包 SwiftPM 源码到 `dist/pm/scripts/preflight-swiftui-lint/`（排除 `.build/` 等产物）
- ae-preflight SKILL.md 新增 permissions：`Bash(bash ~/.ae/pm/scripts/preflight-swiftui-lint.sh:*)` + `Bash(swift build:*)`

## v0.42.0 (2026-04-17) — app-to-speckit context 管理 / Phase Checkpoint 机制 [`#IJ809A`](https://gitee.com/turningsyn/ae-pm/issues/IJ809A)

### 新功能
- **Phase Checkpoint 机制**（[`#IJ809A`](https://gitee.com/turningsyn/ae-pm/issues/IJ809A)）— 解决 WDA 截图 1125×2436 超过 Claude API many-image 2000px 上限、累积 10-15 张触发 context 溢出被迫中断的问题
  - **Batch 化执行**：Phase 2a Level 2 每 8 个子入口 1 batch；Phase 2a Level 1 / 2b 每条流程 / 2c / 2d / 2e 各自独立 Checkpoint（CP1-CP7）
  - **phase-summaries.md 状态文件**：每个 Checkpoint 必须追加结构化摘要到磁盘，成为 `/compact` 后重建 context 的权威来源——截图从 context 清除也不会丢失探索成果
  - **Checkpoint 消息协议**：skill 在 batch 边界向 PM 输出标准消息（进度 / 截图累计 / /compact 建议），PM 回复 "continue" 后进入下一 batch；配合 `autoCompact: true` 可实现 30+ 页 App 无人值守跑完
  - **恢复流程升级**：会话开始 / `/compact` 后的恢复通过读 phase-summaries.md + exploration-state.json + feature-checklist.md 三个纯文本文件重建工作记忆，**不重新 Read 历史截图**
  - **exploration-state.json** 新增 `checkpoints` 对象追踪 batch 进度
  - **技术风险表**补一条 "截图累积触发 many-image 2000px 上限" 及对策

## v0.41.0 (2026-04-16) — app-to-speckit 补充页面跳转采集 + 静态资源清单 `#IJ2OZ7` `#IJ2OZX`

### 新功能
- **页面跳转关系采集** (`#IJ2OZ7`) — Phase 2a/2b 探索过程中实时记录 transitions（from/to/trigger/nav_type），exploration-state.json 新增 `transitions` 数组；Module 02 从 transitions 生成 Mermaid 导航图 + 结构化表格，替代原来的空承诺
- **静态资源清单** (`#IJ2OZX`) — Phase 2a/2b 探索过程中识别并记录页面内的静态资源（插画/图标/角色/纹理/动画/徽章），exploration-state.json 新增 `asset_inventory` 数组；Module 04 设计规范新增资源清单表（ID/类型/描述/参考截图/数量/生成建议），衔接下游 ae-asset-gen

## v0.40.0 (2026-04-16) — ae-lark-feishu 新增 Markdown 报告上传飞书文档 `#IIYHAA`

### 新功能
- **lark-doc-upload.py** — Markdown + 本地图片一键上传为精美排版飞书文档
  - **Grid 分栏并排**：同行多张图片使用飞书原生 Grid 布局（block type 24+25），真正并排显示，每张独立可点击放大
  - **原图上传**：保留完整分辨率，通过 PATCH API 设置合理的显示尺寸（单图 ≈ 140px 宽）
  - **Markdown 渲染**：文本通过 lark-cli stdin 传入，标题/表格/粗体/列表/代码块正确渲染
  - **双 token 架构**：app_access_token 操作 Block API + 图片上传，lark-cli user token 渲染 Markdown
  - **表格内图片**：自动替换为 `[文件名]` 文字（飞书表格不支持嵌入图片）
- **ae-lark-feishu SKILL.md** — 新增 Phase 9「上传 Markdown 报告到飞书文档」，含前置条件、用法、图片语法支持说明

## v0.39.0 (2026-04-15) — 截图自动关闭通知弹窗 + 通知横幅脱敏 `#IIYF6O`

### 新功能
- **screenshot-save.py** — 截图前自动关闭系统弹窗 + 上滑关闭通知横幅（`dismiss_notifications`），默认开启，`--no-dismiss` 可跳过
- **privacy-mask.py** — 新增 `--mask-notifications` 模式，基于 OCR 启发式检测 iOS 通知横幅（Messages/FaceTime/微信等关键词 + 屏幕顶部区域）并自动马赛克
- **ae-app-to-speckit SKILL.md** — DND 从"建议"升级为前置条件必须项；Phase 2e 脱敏命令默认加 `--mask-notifications`

## v0.38.2 (2026-04-15) — wda-cli.py 支持 VLM Grounding 像素坐标自动缩放 `#IIS3R0`

### 更新
- **wda-cli.py** — `tap` / `swipe` 新增 `--pixel` 标志，自动检测 Retina scale factor 并将截图像素坐标转换为 WDA 逻辑点坐标，解决 VLM Grounding 输出坐标直传 WDA 点击无效的问题

## v0.38.1 (2026-04-14) — ae-app-to-speckit 补充 5 个 iOS WDA 真机探索通用陷阱 `#IIS1I0`

### 更新
- **ae-app-to-speckit** — 补充 5 个 iOS WDA 真机探索的通用陷阱文档（来自 Freeletics 实战）
  - 标准 tap 模板增加系统弹窗（ATT/权限）检测 + WDA Alert API 处理流程
  - Phase 2 操作规则新增 swipe 安全距离（起始 x ≥ 屏幕宽度 1/3）
  - Phase 2 操作规则新增 App relaunch 后必须截图确认状态
  - Webview 自定义控件限制警告（`<select>`/`<input range>`/JS 按钮对 WDA 不透明）
  - 技术风险表新增 5 条：系统弹窗拦截、边缘 swipe 返回、Webview 不透明、relaunch 状态不一致、W3C Actions INFINITY 崩溃

## v0.38.0 (2026-04-14) — Phase 6 App Store 提审 + README 端到端流水线重写 `#II8UYE`

### 新功能
- **`/ae-app-review-check`** — App Store 审核自检 skill（#IIREUW）
  - 对照 Guideline 2.1/2.3/3.1/4.3/5.1 扫描项目
  - Apple AI 自动审核已知规则检测（归因 SDK 误判、Firebase Auth demo account）
  - 输出结构化报告（fail/warn/pass）+ Review Notes 建议
- **`/ae-asc-submit`** — App Store 提审 skill（#IIREV0）
  - 从 speckit 自动提取元数据（名称/描述/关键词/分类）
  - 截图获取与验证（模拟器/真机/已有截图）
  - Review Notes 自动生成
  - 通过 fastlane deliver 上传元数据和截图
  - PM 确认后提交审核

### 更新
- **README** — 按 Phase 0-7 端到端流水线重写（#IIREUQ）
  - 从 `demo→speckit→dev→verify` 扩展到完整 8 Phase 上架流程
  - 每个 Phase 列出对应 skill、输入输出、示例命令
  - 标注 Phase 6 建设中状态
- **CLAUDE.md** — 能力表新增 ae-app-review-check 和 ae-asc-submit

## v0.37.1 (2026-04-13) — ae update 自动发现未追踪的旧项目 `#IIOV9S`

### 修复
- **ae update** — 新增 `_discover_untracked_projects`，自动扫描已有 ae skill symlink 但未注册到 `.linked-projects` 的项目（#IIOV9S）
- 修复了追踪机制引入前已链接的项目在 `ae update` 后新增 skill 不到达的问题

## v0.37.0 (2026-04-13) — ae asc subscription 命令组 `#IIOSOG`

### 新功能
- **`ae asc subscription list/create-group/create`** — ASC 订阅商品管理 CLI 化（#IIOSOG）
  - `subscription list --app-id X` — 列出订阅组及其订阅商品
  - `subscription create-group --app-id X --name X` — 创建订阅组
  - `subscription create --group-id X --product-id X --name X --duration X` — 创建订阅（含本地化）

### 更新
- **`/ae-superwall-setup`** — Step 1.3 从 Web UI 操作迁移至 `ae asc subscription` 命令（#IIOSOG）

## v0.36.0 (2026-04-13) — Skill 迁移至 ae asc CLI `#IIOOTZ`

### 更新
- **`/ae-testflight-publish`** — Phase 1 + Phase 3.5 + Phase 4 全面从 Playwright 浏览器自动化迁移至 `ae asc` CLI（#IIOOTZ）
  - 移除 Playwright MCP 依赖，改用 ASC API Key 认证
  - Bundle ID 注册 / App 创建 / Build 状态查询 / 出口合规 / 测试组创建 / 测试员添加全部 CLI 化
- **`/ae-superwall-setup`** — Step 1.3 ASC 订阅商品创建标注为 Web UI 操作，移除 Playwright 依赖（#IIOOTZ）

## v0.35.1 (2026-04-13) — ae update 自动刷新已链接项目的 skill 软链接 `#IIOQ0R`

### 修复
- **ae link** — 提取 `_sync_skill_symlinks` 公共函数，新增失效链接自动修复（#IIOQ0R）
- **ae update** — 拉取新 skill 后自动刷新所有已链接项目的软链接，无需手动 re-link（#IIOQ0R）
- **已链接项目追踪** — `ae link` 时记录 (role, project_dir) 到 `~/.ae/.linked-projects`，`ae update` 据此定位需要刷新的项目（#IIOQ0R）

## v0.35.0 (2026-04-13) — App Store Connect CLI 封装 `#IIOOTZ`

### 新功能
- **`ae asc` CLI** — App Store Connect REST API 封装，替代 Playwright 浏览器自动化（#IIOOTZ）
  - `ae asc auth validate` — JWT 凭据验证
  - `ae asc app list/create` — App 管理
  - `ae asc bundle-id list/register` — Bundle ID 管理
  - `ae asc testflight list-builds/create-group/add-tester/set-compliance` — TestFlight 全流程
- 依赖 PyJWT + cryptography，通过 ASC API Key（.p8）认证，无需 2FA

## v0.34.0 (2026-04-13) — 埋点 skill 新建 + 供应链 skill 实战更新 `#II8RAE` `#II8UYE`

### 新功能
- **`/ae-analytics-setup` skill** — Firebase Analytics + Adjust SDK 双轨埋点全流程，含杭州团队协作步骤、AnalyticsService 封装层、核心漏斗事件模板 (#II8RAE)

### 更新
- **`/ae-superwall-setup`** — 基于 WePray 实战完全重写：融入文龙确认的 Superwall + StoreKit 2 方案，增加 ASC 订阅商品创建 (Playwright)、Adjust 付费事件联动、Sandbox 测试流程、杭州团队协助项 (#II8RAE)
- **`/ae-testflight-publish`** — 增加埋点作为推荐前置条件 (约束 ios-pub-027)；新增 4 条约束 (ios-pub-024~027)：账号迁移、DPLA 协议、Adjust Connection、盲测警告；管线关系图增加 ae-analytics-setup 节点 (#II8RAE)
- **`/ae-preflight`** — 增加 Phase 3.5 埋点 SDK 检查（Firebase/Adjust 缺失警告）；增加 DPLA 协议提示；管线关系图更新 (#II8RAE)

## v0.33.1 (2026-04-10) — Playwright MCP browser_click 超时修复 `#IIB4Y3`

### Bug 修复
- **Playwright MCP `--timeout-action 15000`** — 安装命令增加 action 超时参数，从默认 5s 提升到 15s，修复 Apple 重型 SPA 上 `browser_click` / `browser_fill_form` 频繁超时 (#IIB4Y3)
- **ae-testflight-publish 故障排查表** — 新增 3 条 Playwright 超时场景（click 超时 / 元素已 visible 仍超时 / page.reload 超时）及 `force: true` workaround (#IIB4Y3)
- **ae-testflight-publish ASC 操作指引** — 将 `browser_evaluate` PointerEvent workaround 升级为 `browser_run_code` + `force: true` 方案，更可靠 (#IIB4Y3)

## v0.33.0 (2026-04-10) — TestFlight 发布 skill 实战重写 `#II8RAE`

### 重写
- **`/ae-testflight-publish` skill** — 基于 bible-app (Faithful Guide) 端到端实跑踩坑记录完全重写；融入 23 条已验证约束 (ios-pub-001~023)；覆盖 Apple 身份注册→签名配置→Archive→Upload→TestFlight 分发全流程 (#II8RAE, #II8UYE)
  - 新增：多 Apple ID 权限分裂识别与处理（Developer Portal vs ASC 权限边界）
  - 新增：Playwright 操作 Apple 站点的反爬对策（PointerEvent dispatch、TLS 指纹绕过）
  - 新增：iPad 方向声明、出口合规预配置、ExportOptions.plist 模板
  - 新增：内部测试 vs 外部测试 vs 公开链接分发路径指引
  - 新增：constraint_candidates 收集 + publish-state.yaml 状态持久化

## v0.32.0 (2026-04-10) — 修复回流机制 `#IIAV9O`

### 新功能
- **`/ae-report-fix` skill** — 用户/agent 本地修复成功后，结构化回流修复方案给 AE Team（采集→格式化→提交 issue comment→确认） (#IIAV9O)

### 原则更新
- **"不要替用户忍耐" → "不要让修复经验沉没"** — 鼓励用户先尝试自行修复，修复成功后回流方案；AE Team 角色从"全栈修复者"变为"质量守门人 + 分发者" (#IIAV9O)
- **escalation-guide 新增场景 7** — 自行修复成功 → 建议 `/ae-report-fix` 回流 (#IIAV9O)
- **场景 3 更新** — Skill 不好用时先尝试自行修复，不再直接跳到提 bug (#IIAV9O)

## v0.31.3 (2026-04-10) — Playwright MCP 持久化登录态 `#IIAV52`

### Bug 修复
- **ae-testflight-publish Playwright 安装命令** — 增加 `--user-data-dir ~/.config/playwright-profile`，解决每次重启丢失 Apple Developer Portal 登录态的问题 (#IIAV52)

## v0.31.2 (2026-04-10) — VISION 审计：质量门禁全面补齐 `#II9DON`

### 质量基础设施
- **smoke_test 100% 覆盖** — 13 个 pm skill 全部补齐 smoke_test frontmatter（从 2/13 → 13/13）
- **test-scenarios.md 100% 覆盖** — 13 个 pm skill 全部创建 test-scenarios.md，每个 5 场景（L2 用户视角验收）
- **publish.sh manifest 集成** — generate-manifest.sh 接入发布流水线，manifest.yml 作为构建产物
- **publish.sh 门禁强化** — smoke test 失败从 warn 改为 exit 1（--skip-doctor 可跳过）

### CLAUDE.md 改进
- **overrides/ 引用** — 补充用户覆盖段落，agent 执行 skill 前会检查 .claude/overrides/ 目录
- **能力表补齐** — 补充 ae-preflight、ae-prod-to-local、ae-demo-to-figma 的能力描述

## v0.31.1 (2026-04-09) — WDA 启动验证修复 `#II9E5P`

### Bug 修复
- **wda-start.sh verify 逻辑修复** — iOS 26 上 WDA 返回 `sessionId: null` + `ready: true`，旧逻辑仅检查 sessionId 导致验证永远失败；改为同时接受 ready/state/sessionId 三种判断 (#II9E5P)
- **端口转发竞态修复** — Attempt 1→2 切换时未杀旧 `ios forward`，新 forward 绑定失败；增加端口释放等待和重试 (#II9E5P)

## v0.31.0 (2026-04-09) — 全量 skill README 设计文档 `#II99OK`

### 新功能
- **12 个 PM skill 补齐 README.md** — 按 ae-skill-creator 标准为所有 PM skill 编写人类设计文档（问题陈述/设计决策/已放弃方案/开源供应链/生命周期），从 CHANGELOG 和 SKILL.md 还原设计要素 (#II99OK)
- **3 个跨角色 skill 补齐 README.md** — ae-submit-bug / ae-submit-requirement / ae-lark-feishu (#II99OK)

## v0.30.0 (2026-04-09) — ae-skill-creator：标准化 skill 构建 skill `#II99OK`

### 新功能
- **ae-skill-creator skill** — 标准化 skill 构建全流程引导（需求澄清→核心链路跑通→SKILL.md 六段标准→场景验收→README 设计文档→发布），含审计模式可对已有 skill 进行标准化检查 (#II99OK)
- **Skill 目录结构标准** — 每个 skill 推荐包含 SKILL.md（必须）+ README.md（人类设计文档）+ test-scenarios.md（用户场景验收清单） (#II99OK)
- **SKILL.md 六段标准** — frontmatter / 身份锚定 / 操作流程 / 硬性规则(3-7条) / 反模式(❌→) / 故障排查表 (#II99OK)
- **已有 skill 审计基线** — 对 ae-preflight(4/8)、ae-image-decopyrighter(3/8)、ae-file-bugs(3/8) 完成首次审计 (#II99OK)

## v0.29.0 (2026-04-09) — Skill 供应链 Wave 4：用户覆盖 + 冒烟测试 `#II96KG`

### 新功能
- **用户 overrides 机制** — `ae link` 自动创建 `project/.claude/overrides/` 目录，用户定制不被 `ae update` 覆盖 (#II96KG)
- **冒烟测试框架** — SKILL.md 可声明 `smoke_test`，`publish.sh` Step 3.6 自动执行 (#II96KG)
- **ae doctor 显示 overrides** — 检测并列出项目中的用户覆盖文件 (#II96KG)

## v0.28.0 (2026-04-09) — Skill 供应链 Wave 3：manifest.yml + CLAUDE.md 模块化 `#II96KG`

### 新功能
- **manifest.yml 生成** — `ae manifest generate pm` 自动从 SKILL.md 生成能力注册表（含依赖、废弃状态） (#II96KG)
- **CLAUDE.md 模块化** — 从 381→186 行（-51%），拆分技术约束/评审流程/求助指引/更新反馈到 `constraints/` 目录 (#II96KG)

## v0.27.0 (2026-04-09) — Skill 供应链 Wave 2：发布门禁 + 首批瘦身 `#II96KG`

### 新功能
- **publish.sh doctor 门禁** — 发布前自动检查 skill 依赖，缺失时 warn（可用 `--skip-doctor` 跳过） (#II96KG)

### 改进
- **ae-lark-feishu 标记废弃** — 迁移到 larksuite/cli + Lark OpenAPI MCP，附迁移指引 (#II96KG)

## v0.26.0 (2026-04-09) — Skill 供应链基础设施：依赖声明 + doctor 增强 `#II96KG`

### 新功能
- **Skill 依赖声明** — 所有 15 个 PM skill 的 SKILL.md frontmatter 新增 `dependencies` 块，声明 MCP/CLI/API Key/脚本依赖 (#II96KG)
- **`ae doctor` 依赖检查** — doctor 命令自动解析 SKILL.md dependencies 并逐项验证（MCP 连接、CLI 可用、API Key 已配置、脚本存在），输出 ✅/❌ 报告 (#II96KG)

### 改进
- **供应链设计论文** — 提交 `content/research/skill-ecosystem-design.md`，包含 5 波施工计划、开源替代方案全景、8 条设计原则 (#II96KG)

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
