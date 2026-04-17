---
name: ae-app-to-speckit
description: "从已上架 App 逆向提取 speckit（无源码，通过 App Store + 真机 UI 探索）"
permissions:
  allow:
    - "mcp__mobile-mcp__*"
    - "WebSearch"
    - "WebFetch"
    - "Write({workdir}/speckit/**)"
    - "Edit({workdir}/speckit/**)"
    - "Bash(curl -s http://localhost:8100:*)"
    - "Bash(python3 -c:*)"
    - "Bash(cd {workdir}:*)"
    - "Bash(mkdir -p:*)"
    - "Bash(ls:*)"
    - "Bash(sleep:*)"
    - "Bash(ios forward:*)"
    - "Bash(ios list:*)"
    - "Bash(xcodebuild test-without-building:*)"
    - "Bash(python3 *privacy-mask.py:*)"
    - "Bash(python3 *ocr-screenshot.py:*)"
    - "Bash(python3 *screenshot-save.py:*)"
    - "Bash(python3 *coverage-stats.py:*)"
    - "Bash(bash *wda-start.sh:*)"
    - "Bash(python3 *wda-cli.py:*)"
dependencies:
  mcp:
    - mobile-mcp
  cli:
    - name: go-ios
      verify: "ios version"
    - name: python3
      verify: "python3 --version"
  api_keys: []
  scripts:
    - wda-start.sh
    - ocr-screenshot.py
    - privacy-mask.py
    - wda-cli.py
smoke_test:
  command: "ios version 2>/dev/null || which ios"
  expected_exit: 0
  description: "go-ios available for iPhone communication"
---

# Skill: App 逆向提取 Speckit (app-to-speckit)

## 触发条件

当 PM 希望复刻一款已上架 App 时，需要先系统性分析该 App，生成结构化 speckit，作为后续 vibe coding / dev agent 的输入。

## 与 demo-to-speckit 的区别

| 维度 | demo-to-speckit | app-to-speckit |
|------|----------------|----------------|
| 信息来源 | 源码（读 Swift/React 文件） | App Store + App 内功能目录 + 真机 UI 截图 + Accessibility Tree |
| 前置条件 | demo 项目目录 | App Store URL + iPhone 真机 USB 连接 |
| 模块置信度 | 大部分 `confirmed` | 01/02/04 为 `confirmed`/`extracted`，03/05/06 为 `[inferred]` |
| 输出范围 | 6 模块全量 | MVP 只输出 01 + 02 + 04，其余标注待补充 |

## 核心原则

1. **有比没有好，但错比没有更危险** — Module 03/05/06 从 UI 反推的准确率低，宁可留空让 PM 补充，也不输出误导性内容
2. **Checklist 驱动覆盖** — Phase 1 必须输出 feature-checklist，Phase 2 的每一步都对照 checklist 标记覆盖状态，结束前强制交叉验证
3. **视觉优先** — 第三方 App 的 Accessibility Tree 不可控，纯视觉（截图 + VLM 分析）是主要识别手段
4. **每步必看** — 每次操作后必须 `mobile_take_screenshot` 确认画面内容，不能盲操作。截图是证据，也是下游 vibe coding 的参照物
5. **广度 100% + 核心深度** — 先确保每个功能至少有一张入口截图（广度覆盖 100%），再对核心流程做端到端深度走通。不需要每个功能都端到端，但每个功能必须有"长什么样"的截图
6. **发现问题当场提 issue** — 探索过程中发现脚本 bug、流程缺陷、工具不好用时，**当场使用 `/ae-submit-bug` 提交 issue 再继续当前任务**。不要等到最后汇总。如果已有完整 bug 信息，可以用 `ae pm submit-bug "标题" "描述"` 跳过交互追问直接提交
7. **context 外溢一律落盘** — 大体积中间产物（元素树 XML / OCR 结果 / 截图 / 网页原文）必须 `--save` 到磁盘，再按需 `grep` / `head` 读取片段；**禁止让全量内容作为 stdout 进入 LLM context**。context 增长主要由截图驱动（已由 CP batch + `phase-summaries.md` + `autoCompact` 管控），不应再叠加可落盘的文本产物
8. **截图结论即时落盘（autoCompact 安全前提）**（#IJ864Z）— 每次 Read 一张截图后，**在下一次 tool call 之前**必须把"这张图证明了什么"写到磁盘：
   - 更新 `exploration-state.json.screenshot_to_feature["<文件名>"] = "<一句话结论，如 F07 入口在右上角齿轮图标>"`
   - 或追加一行到 `phase-summaries.md` 当前 CP 段落：`- {文件名}: {结论}`
   - **之后不再 Read 这张图**。需要再次引用时读结论文本，不重复 Read 图
   - 这是 autoCompact 自动触发的安全前提：结论已在磁盘，即使图被压缩清除也无损失

## 前置条件

| 条件 | 说明 |
|------|------|
| iPhone 真机自动化环境 | **必须先完成 `/ae-mobile-setup`**（go-ios + WDA + mobile-mcp 全套） |
| 目标 App 已安装 | 从 App Store 下载到真机 |
| **免打扰模式** | **必须：PM 开启 iPhone 免打扰（专注模式）。通知弹窗含他人 PII，截图入库前必须杜绝。screenshot-save.py 会自动尝试关闭弹窗，但 DND 是根本防线** |

### Phase 0: 环境就绪检查与启动（每次会话必须执行）

WDA 在新会话中几乎必然已断开。**Phase 0 是显式步骤，不可跳过。**

```
Step 0.1-0.5: 一键启动 WDA 环境
    bash ~/.ae/pm/scripts/wda-start.sh
    → 自动完成：设备检测 → tunnel → xcodebuild → 端口转发 → 验证
    如果失败 → 引导运行 /ae-mobile-setup

Step 0.6: 检查 MCP tools 可用性
    尝试调用 mobile_take_screenshot
    如果 MCP tools 不可用（MCP server 未连接）→ 全程使用 wda-cli.py 替代：
        python3 ~/.ae/pm/scripts/wda-cli.py screenshot --save /tmp/test.png
        python3 ~/.ae/pm/scripts/wda-cli.py tap X Y
        python3 ~/.ae/pm/scripts/wda-cli.py launch BUNDLE_ID
        python3 ~/.ae/pm/scripts/wda-cli.py source --format xml
        python3 ~/.ae/pm/scripts/wda-cli.py swipe X1 Y1 X2 Y2
    在 exploration-state.json 中标记 "mcp_available": true/false

Step 0.7: 确认屏幕 + 发现 Bundle ID
    截图确认屏幕未锁定
    用 App 名称模糊搜索真实 Bundle ID（App Store 推断的可能不一致）：
        python3 ~/.ae/pm/scripts/wda-cli.py apps | grep -i "<app_name>"
    如果搜到多个结果，列出让 PM 确认
    将确认后的 bundle_id 写入 exploration-state.json

Step 0.8: 收集 PII 关键词（隐私脱敏用）
    向 PM 确认以下信息，保存到 exploration-state.json 的 pii_patterns 字段：
    - 用户姓名及变体（如 "李根剑", "根剑", "lgj"）
    - 设备名称（如 "根剑的 AirPods Pro", "lgj iphone"）
    - 用户 ID / 手机号 / 邮箱（如出现在 App 中）
    如果 PM 不确定，先跳过，Phase 2 过程中发现再补充

Step 0.9: 付费策略评估（Phase 1 完成后、Phase 2 开始前回来补充）
    分析 app-profile.json 中的 iap_list，计算最低测试成本（通常是周订阅）
    向 PM 报告：
    - 免费层可覆盖的功能范围
    - 付费层额外可覆盖的功能范围
    - 最低测试成本（如 "¥6/周 可解锁全部功能"）
    PM 决定是否付费 → 记入 exploration-state.json 的 payment_strategy
```

**如果之前搭建过只是 WDA 断开**，`/ae-mobile-setup` 会自动检测并只执行快速重连（跳过 go-ios 安装等已完成步骤）。

## 输入

- **目标 App 标识**：App Store URL 或 App 名称
- **PM 补充指令**（可选）：重点功能、裁剪范围、差异化方向
- **技术栈约束**：iOS SwiftUI（默认）或 Web SPA

### 执行模式（#IJ84WI）

| 模式 | 触发方式 | Checkpoint 行为 |
|------|---------|----------------|
| **autonomous**（默认） | `/ae-app-to-speckit ...` | CP1-CP7 写完摘要后**自动继续**，不等 PM `continue`。仅在「物理操作节点」（见下）时暂停 |
| interactive | `/ae-app-to-speckit --interactive ...` | 每个 CP 写完摘要后输出消息给 PM，等 `continue` 再进入下一 batch（老行为，新用户/小心场景使用） |

**物理操作节点**（两种模式下均会暂停，请 PM 接管）：

1. **Phase 0.7** — PII 关键词收集（必须 PM 提供）
2. **Phase 0.8/0.9** — 付费策略决策（是否订阅解锁 paid 功能）
3. **Phase 2b 核心流程中的物理输入** — 拍照扫描、上传 PDF、绑定邮箱/手机号等需要真实环境的步骤
4. **首次遇到付费墙 / 登录墙** — 决策「跳过标记 ⛔/🔒」还是「PM 立即付费/登录后补测」

> **取消 CP7 停顿**（#IJ864Z，v0.45.0）：之前 Phase 2e 脱敏后会建议 PM 手动 `/compact` 再进 Phase 3，
> 现已改为直接进入 Phase 3（不阻塞）。autoCompact 会在 context 真触顶时自动压缩；
> 恢复依赖 `phase-summaries.md` + `exploration-state.json` + `feature-checklist.md` 三文件，无需手动 compact。
> **前提保证**：核心原则 #8 要求每张截图结论即时落盘，即使 autoCompact 清掉图，磁盘结论不丢。

**为什么默认 autonomous**：1M context + `autoCompact: true` 的组合下，CP1/CP2/CP5/CP6/CP7 这类单 batch CP 的截图占用远未触顶，强制 PM 手动 `continue` 是纯浪费；PM 需要介入的是物理操作，不是 context 管理。Checkpoint 的**持久化价值**（phase-summaries.md + exploration-state.json）与**阻塞行为**解耦——摘要照写，但不阻塞。

**v0.45.0 进一步**（#IJ864Z）：CP7 也取消了"建议 /compact"的提示。skill 从 Phase 0 到 Phase 3 **全程不停 context 管理的点**，只在物理操作节点（PII/付费/拍照/付费墙/登录墙）暂停。前提是核心原则 #8 的"截图结论即时落盘"被严格执行——只要每张读过的图结论都在磁盘，autoCompact 随时自动触发都安全。

## 输出

写入 `speckit/` 目录：

| 模块 | 文件 | 信息来源 | 置信度 |
|------|------|---------|--------|
| -- | `app-profile.json` | App Store + App 内功能目录 | 高 |
| -- | `feature-checklist.md` | App Store + App 内功能目录 + 引导页，含覆盖状态 | -- |
| 01 | `01-project-positioning.md` | App Store 页面 + 探索观察 | 高（大部分 `confirmed`） |
| 02 | `02-user-scenarios.md` | 状态机 + 完整流程录制 + 每步截图 | 高（直接观察） |
| 04 | `04-design-spec.md` | 截图 → Vision 提取颜色/字体/间距，每项引用来源截图 | 中（`[extracted]`） |
| -- | `00-context-manifest.md` | 上下文来源追溯 | -- |
| -- | `review-checklist.md` | PM Review 清单 | -- |
| -- | `screenshots/` | 每个页面 + 每步操作的截图证据 | -- |
| -- | `exploration-state.json` | 探索进度状态（用于中断恢复） | -- |
| -- | `phase-summaries.md` | 每个 batch checkpoint 的结构化摘要（`/compact` 后重建 context 的权威） | -- |

**截图命名规范**：采用语义化命名 `{phase}-{功能ID}-{描述}.png`，确保文件名即内容。

| Phase | 命名示例 | 说明 |
|-------|---------|------|
| 1.5 | `1.5-help-page-full.png` | 功能目录截图 |
| 2a | `2a-F01-scan-entry.png` | 广度遍历入口截图 |
| 2a | `2a-F03-ocr-subpage.png` | 子功能页面 |
| 2b | `2b-flow01-step03-confirm.png` | 端到端流程步骤 |
| 2c | `2c-empty-state.png` | 边界状态 |

speckit 文档中引用截图时**必须使用 HTML img 标签限制显示宽度**，避免在 Gitee/GitHub 上撑满全屏：
- 表格内截图：`<img src="screenshots/xx.png" width="280">`
- 独立段落截图（组件展示）：`<img src="screenshots/xx.png" width="375">`
- **禁止使用** `![](screenshots/xx.png)` 格式（原始分辨率渲染，阅读体验差）

在 `exploration-state.json` 中维护截图到功能的映射关系。

**MVP 不输出**：03（技术架构）、05（数据模型）、06（API 规范）— 从 UI 反推这三个模块误导风险 > 价值。PM 需要时在 review 阶段手动补充。

## 执行流程

### Phase 1: App Store 信息采集 + Feature Checklist

**方法**：WebSearch + WebFetch

**步骤**：
1. WebSearch 搜索 App Store 页面，获取产品描述、截图、评分
2. WebSearch 补充竞品评测、用户评价
3. 提取结构化信息并 **写入 `app-profile.json` 文件**：

```json
{
  "name": "产品名",
  "tagline": "副标题",
  "category": "分类",
  "price_model": "免费/付费/订阅",
  "iap_list": ["内购项目列表"],
  "description": "完整描述文案",
  "features": [
    {"id": "F01", "name": "功能名", "source": "app_store", "priority": "core/secondary"},
    ...
  ],
  "rating": "评分 + 评论数",
  "version": "版本号",
  "developer": "开发者",
  "bundle_id": "com.xxx.xxx"
}
```

4. 从 `features` 列表生成 **`feature-checklist.md`**：

```markdown
# Feature Checklist

| ID | 功能 | 来源 | 优先级 | 覆盖状态 | 截图 | 备注 |
|----|------|------|--------|---------|------|------|
| F01 | 文档扫描 | app_store | core | ⬜ | — | |
| F02 | OCR 文字识别 | app_store | core | ⬜ | — | |
| ... | | | | | | |
```

覆盖状态定义（状态间有明确语义区分）：

| 状态 | 含义 | 下一步 |
|------|------|--------|
| ⬜ | 未覆盖（未发现或未操作） | 需要截图 |
| ✅ | 有入口截图（功能已发现） | 核心功能需要端到端 |
| 🔄 | 端到端走通（流程已验证） | 完成 |
| ⛔ | 付费墙阻断（有入口截图但核心流程未验证） | PM 付费后可回来补测 |
| 🔒 | 需登录/注册（未测试） | PM 登录后可回来补测 |

**Phase 1 的 feature-checklist 是后续所有 Phase 的驱动核心。**

### Phase 1.5: App 内功能目录补充（Phase 2 前必须执行）

**为什么不能等到 Phase 2a 再做**：ideaShell 实战中，在 Phase 2a 中段偶然发现帮助页，额外找到了 9 个 Phase 1 未发现的功能。如果一开始就做，整个遍历计划会更完整、效率更高。

**步骤**：
```
1. 启动目标 App
2. 处理 Onboarding（如有）：
   - 评分请求弹窗 → 点"以后再说" / "Not Now"
   - 付费墙弹窗 → 找关闭按钮（通常右上角 X）
   - 权限请求 → 默认点"允许"（相机/相册/通知等）
   - 引导页 → 逐页截图，找 "跳过" / "Skip" / 最后的 "开始使用"
3. 到达 Home 后，主动寻找功能目录入口（按优先级）：
   - "帮助" / "Help" / "?" 入口
   - "全部功能" / "更多工具" / "All Features" 入口
   - 设置页中的功能列表
   - 侧边栏/汉堡菜单中的完整功能目录
   如果以上都找不到（部分 App 无功能目录）→ 全面滚动各 Tab 页面发现功能
4. 截图完整功能列表（可能需要多次滚动）
5. 用发现的功能更新 feature-checklist：
   - 新增 Phase 1 未发现的功能，source 标记为 "in_app"
   - 已有功能如果 App 内有更详细分类，更新描述
6. 更新 exploration-state.json，标记 Phase 1.5 完成
7. **(CP1) 执行 Phase 1.5 Checkpoint**：
   - 创建 phase-summaries.md（如不存在），追加 "## CP1 — Phase 1.5 功能目录补充"
   - 记录：新增功能 ID 列表 + 功能目录入口位置 + 截图文件名
   - 更新 exploration-state.json.checkpoints
   - **autonomous 模式（默认）**：输出一行日志 `[CP1] Phase 1.5 完成，新增 N 个功能，继续 Phase 2a`，直接继续
   - **interactive 模式**：输出 CP1 Checkpoint 消息给 PM，等待 "continue" 进入 Phase 2a
```

**完成后**：带着完整的 feature-checklist 进入 Phase 2，避免遍历中途大面积补功能。

### Context 管理 / Phase Checkpoint 机制（#IJ809A + #IJ84WI）

WDA 截图单张 1125×2436px，**超过 Claude API "many-image requests" 的 2000px 单边上限**，且单图 token 消耗极高。连续 10-15 张截图累积进 context，会出现：

```
An image in the conversation exceeds the dimension limit for many-image requests (2000px).
Run /compact to remove old images from context, or start a new session.
```

**skill 无法自己触发 `/compact`**（这是 Claude Code 用户命令）。所以 skill 的 context 管理策略是：**把工作拆成 batch + 每 batch 结束写持久化摘要到磁盘**。这样即使 autoCompact 触发清理，摘要仍然留在磁盘上，Phase 0 恢复流程能无损接续。

**autonomous 与 interactive 的区别**（#IJ84WI）：
- **batch 化 + 写摘要**：两种模式都执行，不可跳过（持久化价值独立于阻塞）
- **是否阻塞等 PM `continue`**：autonomous 模式不阻塞（写完日志直接进入下一 batch），interactive 模式阻塞
- 过去版本把两者绑在一起导致 PM 每次扫描手动 `continue` 10+ 次（见 #IJ84WI），现已解耦

**Batch 边界**（下列每一处完成后，必须写 `phase-summaries.md` + 更新 `exploration-state.json.checkpoints`）：

| Checkpoint | 位置 | 每 batch 截图预算 |
|-----------|------|-------------------|
| CP1 | Phase 1.5 完成后 | ~3 张功能目录截图 |
| CP2 | Phase 2a Level 1 完成后（全部 Tab 遍历完） | 每 5 个 Tab 为 1 batch |
| CP3 | Phase 2a Level 2 完成后（子入口遍历） | **每 8 个子入口为 1 batch** |
| CP4 | 每一条核心流程（Phase 2b）走通后 | 每条流程独立 checkpoint |
| CP5 | Phase 2c 边界探索完成后 | ~5 张边界态截图 |
| CP6 | Phase 2d 覆盖率 checkpoint 通过后 | — |
| CP7 | Phase 2e 脱敏完成后 | — |

**关键原则**：**预算上限 = 8 张截图 / batch**。接近上限时主动收口写摘要，不要跨越。

**v0.46.0 起**（#IJ864Z）：CP3（Phase 2a Level 2）和 CP4（Phase 2b flow）默认由 **subagent 执行**，即每 batch 的 8 张截图只进子 agent context，main agent context 只吃 ≤200 字摘要。CP1/CP2/CP5/CP6/CP7 仍由 main agent 直接执行（截图数少，batch 隔离成本不划算）。`autoCompact: true` 作为最后兜底。

**autonomous 模式 CP 日志格式**（默认，向 PM 输出一行）：

```
[CP{编号}] {阶段名} — 本 batch {k} 张截图（累计 {n}），覆盖 {m}/{total}；已写 phase-summaries.md，继续 {下一阶段/batch}
```

**interactive 模式 CP 消息模板**（仅 `--interactive` 时使用）：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Context Checkpoint — {CP编号}】{阶段名}

✅ 本 batch 完成：{摘要 3-5 条}
📸 累计截图：{n} 张（本 batch {k} 张）
📁 已写入：phase-summaries.md §{CP编号}
📋 feature-checklist 覆盖率：{m}/{total}

⚠️ Context 管理建议：
  如果当前 context 使用率已高，请执行 /compact 后输入 "continue"；
  否则直接输入 "continue" 进入下一 batch。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**为什么 autonomous 是默认**：1M context + `autoCompact: true` 下，CP1/2/5/6/7 这类单 batch 远未触顶，强制 `continue` 纯浪费 PM 时间。CP3/CP4 累计 8 张截图时，autoCompact 会在真正压力来临时自动处理，skill 不需要预先停顿。持久化摘要保证即使被 autoCompact 清掉历史，恢复仍然无损。

### 子 agent 隔离执行架构（#IJ864Z v0.46.0）

Phase 2a Level 2 每 batch / Phase 2b 每条 flow 默认由 **子 agent（`subagent_type=general-purpose`）独立执行**，main agent 只接收 ≤200 字摘要。

**为什么**：截图仍然线性进 context，但**只进子 agent 的 context**。子 agent 结束即销毁，它吃的 8 张截图 + 元素树对 main agent 完全不可见。main agent 的 context 增长从"N batch × 8 图"降为"N batch × 200 字摘要"，本质消除了图累积。

**同时配合核心原则 #8 的落盘纪律**：子 agent 每看一张图必须立即写 `screenshot_to_feature` / `phase-summaries.md`，写完再回报摘要。这样即使子 agent context 满或异常退出，磁盘结论已存盘，main agent 接管补救。

**子 agent prompt 模板**（Phase 2a Level 2 batch 版）：

```
你是 ae-app-to-speckit skill 的子 agent，负责一个 batch 的子入口探索。

## 上下文
- workdir: {workdir 绝对路径}
- 目标 App: {name} (bundle_id: {bundle_id})
- 本 batch 要探索的子入口（{k} 个）：
  - F01 扫描文档（入口 Tab：工具箱）
  - F02 OCR 识别（入口 Tab：工具箱）
  - ... [8 个最多]
- feature-checklist 路径: {workdir}/speckit/feature-checklist.md
- exploration-state.json 路径: {workdir}/speckit/exploration-state.json
- phase-summaries.md 路径: {workdir}/speckit/phase-summaries.md

## 执行规则（必须遵守）
1. 每个子入口：`wda-cli.py tap-element` 进入 → `screenshot-save.py 2a-F{id}-{desc}` 存盘 →
   返回上一级（iOS 手势 swipe from left-edge 或 tap 返回按钮）
2. 每张 Read 过的截图**立刻**把一句话结论写到 `exploration-state.json.screenshot_to_feature`
3. 发现未列入的功能（Feature Discovery by Reasoning）→ 新增一行到 feature-checklist，source="discovered"
4. 识别到静态资源（插画/图标）→ 记一条到 `exploration-state.json.asset_inventory`
5. 记录页面跳转 → 追加一条到 `exploration-state.json.transitions`
6. 遇到 alert/付费墙/登录墙 → 标记 ⛔ 或 🔒，不纠缠，继续下一入口

## 落盘动作（全部完成再返回）
- `phase-summaries.md` 追加 `## CP3 — Phase 2a Level 2 Batch {n}（子入口 {start}-{end}）` 段落
- `exploration-state.json` 更新：
  - `screenshot_to_feature` 追加映射
  - `checkpoints.last_written = "CP3-batch{n}"`
  - `checkpoints.batches_completed` 追加
  - `feature_coverage.covered` 递增
- feature-checklist.md 对应行 ⬜ → ✅

## 返回格式（严格 ≤200 字）
Batch {n} 完成（F{start}-F{end}）
- F{id}: 一句话结论（入口位置 + 关键元素）
- F{id}: ...
截图 {k} 张已存盘，发现 discovered: [列表或"无"]
状态：phase-summaries.md + exploration-state.json + feature-checklist.md 已更新
⛔/🔒: 若有，列出被标记的 ID

**禁止**在回复里贴文件内容、复述截图细节、解释过程——main agent 只需要摘要。
```

**子 agent prompt 模板**（Phase 2b flow 版）：

```
你是 ae-app-to-speckit skill 的子 agent，负责一条核心流程的端到端走通。

## 上下文
- workdir: {workdir 绝对路径}
- 流程：{flow_name}（feature: F{id}, priority: core）
- 入口：{entry 描述，如 "工具箱 → F01 扫描"}
- 预期终点：{end 描述，如 "OCR 结果页显示识别文字"}
- 状态文件路径同上（feature-checklist / exploration-state.json / phase-summaries.md）

## 执行规则
1. 每一步：`wda-cli.py tap-element` → `screenshot-save.py 2b-flow{n}-step{k}-{desc}` 存盘
2. 每步结论立刻写 `screenshot_to_feature`
3. 遇到需要物理输入（拍照/上传/输入手机号）→ 返回摘要并在摘要中标注 `[需 PM 物理操作]`，main agent 会接管
4. 走到终点或 PAYWALL → 停止，进入 CP4 落盘

## 落盘动作
- `phase-summaries.md` 追加 `## CP4 — Phase 2b Flow {n}: {flow_name}` 段落
  每步一行：步骤名 + 截图文件名 + 关键观察
- `feature-checklist.md` 对应功能覆盖状态 ✅ → 🔄
- `exploration-state.json` 更新 `checkpoints` + `completed_flows`

## 返回格式（严格 ≤200 字）
Flow {n} {flow_name} 完成（{步数}步）
- Step 1: 一句话
- ...
- Step N: 终点/PAYWALL
状态：phase-summaries.md + feature-checklist + exploration-state.json 已更新
[需 PM 物理操作]: 若有，列出步骤
```

**Main agent 职责**（spawn 后）：
1. 用 `Agent(subagent_type=general-purpose, prompt=<上述模板填充>)` 调用
2. 接收摘要，写一行 CP 日志：`[CP3-batch{n}] {摘要首行}，继续 batch{n+1}`
3. **不 Read** 子 agent 写入的截图
4. 更新自己的 working memory（batch_counter++）然后进入下一个 batch

**Fallback 条件**（subagent 失败时降级 inline 执行）：
- subagent 调用异常 / 超时 / 返回空
- subagent 返回摘要明确说"状态文件更新失败"
- 连续 2 次 subagent 调用失败

Fallback 时 main agent 自己执行该 batch（老 v0.45.0 inline 方式），在 `exploration-state.json.notes` 记录"batch{n} fallback 到 inline"。

**恢复兼容**：状态文件结构不变，v0.45.0 产生的 speckit 目录可以无缝被 v0.46.0 恢复流程接续，反之亦然。

### 中断恢复机制

整个探索过程可能耗时很长（30 分钟 ~ 数小时），且随时可能因锁屏、WDA 断开、会话超时、`/compact` 清理等原因中断。通过四个状态文件实现断点恢复：

**状态文件 1 — `feature-checklist.md`**（进度条）

每覆盖一个功能就更新覆盖状态。中断后读此文件即可知道哪些功能还未覆盖。

**状态文件 2 — `screenshots/` 目录**（已完成工作证据）

已保存的截图不需要重新截取。恢复时扫描目录即可知道哪些页面已有截图。

**状态文件 3 — `phase-summaries.md`**（batch 级工作摘要，/compact 后重建 context）

每个 Checkpoint 结束时 **必须追加**一段摘要。格式：

```markdown
# Phase Summaries

## CP1 — Phase 1.5 功能目录补充
- 帮助页发现 9 个 Phase 1 未列出的功能：F11-F19
- 功能目录入口：设置 → 帮助中心
- 截图：1.5-help-page-full.png, 1.5-help-scroll-1.png

## CP2 — Phase 2a Level 1 Tab 遍历（5 tabs）
- Tab1「首页」：最近文档列表 + 5 个快捷操作
- Tab2「工具箱」：22 个工具卡片，3 个分类
- Tab3「...」：...
- 新发现功能：F23「夜间模式」（discovered，Tab3 右上角）
- 截图：2a-home.png, 2a-toolbox.png, ...

## CP3 — Phase 2a Level 2 Batch 1（子入口 1-8）
- F01 扫描：入口在工具箱顶部，点击进入相机页
- F02 OCR：入口在扫描结果页「识别文字」按钮
- ...
- 截图：2a-F01-entry.png, 2a-F02-entry.png, ...

## CP3 — Phase 2a Level 2 Batch 2（子入口 9-16）
- ...
```

**`phase-summaries.md` 是 /compact 后重建 context 的唯一权威**。恢复时 Claude 读这个文件即可知道每个 Phase 发现了什么，无需重看截图。

**状态文件 4 — `exploration-state.json`**（当前阶段状态）

```json
{
  "phase": "2a",
  "sub_phase": "level_2",
  "current_tab": "工具箱",
  "current_function": "拍照翻译",
  "completed_tabs": ["首页", "全部文档"],
  "completed_flows": ["扫描文档", "OCR提取文字"],
  "screenshot_count": 24,
  "feature_coverage": {
    "total": 22,
    "covered": 9,
    "paywall": 2,
    "pending": 11
  },
  "last_updated": "2026-04-02T21:10:00+08:00",
  "screenshot_to_feature": {
    "2a-F01-scan-entry.png": "F01",
    "2b-flow01-step03-confirm.png": "F01"
  },
  "speckit_generated": false,
  "pending_paid_flows": [
    {"id": "F04", "name": "风格迁移", "reason": "paywall", "entry_screenshot": "2a-F04-style-entry.png"},
    {"id": "F05", "name": "替换物体", "reason": "paywall", "entry_screenshot": "2a-F05-replace-entry.png"}
  ],
  "payment_strategy": "free_only | paid_weekly | paid_confirmed",
  "mcp_available": true,
  "bundle_id": "com.example.app",
  "dirty_state_pages": [
    {"page": "Counter", "reason": "计数器残留值", "reset_action": "长按清零按钮 或 调用 F06 Reset"},
    {"page": "DraftEditor", "reason": "草稿自动保存", "reset_action": "清空文本框"}
  ],
  "asset_inventory": [
    {"id": "A01", "type": "illustration", "description": "树种插画", "ref_screenshot": "2b-flow01-step03.png", "quantity": "5态×6种", "gen_hint": "AI 生图，需种间风格一致"}
  ],
  "transitions": [
    {"from": "Home", "to": "FocusSession", "trigger": "点击开始专注", "nav_type": "fullScreenCover"},
    {"from": "FocusSession", "to": "Result", "trigger": "专注完成", "nav_type": "replace"},
    {"from": "Home", "to": "TreePicker", "trigger": "点击树种选择", "nav_type": "sheet"}
  ],
  "checkpoints": {
    "last_written": "CP3-batch2",
    "summary_file": "phase-summaries.md",
    "batches_completed": ["CP1", "CP2", "CP3-batch1", "CP3-batch2"],
    "next_batch": "CP3-batch3",
    "images_in_current_batch": 5
  },
  "notes": "工具箱-扫描类已完成，格式转换类进行中"
}
```

**恢复流程**（每次会话开始时 **或 autoCompact / PM 手动 /compact 后** 执行）：

```
1. 检查 speckit/ 目录是否已存在
2. 如果存在：
   a. 执行 Phase 0 → 重新建立 WDA 连接（不依赖旧 session ID）
   b. 读取 exploration-state.json → 确定上次停在哪个阶段 + checkpoints.next_batch
   c. **读取 phase-summaries.md → 重建"之前发现了什么"的工作记忆**
      （这是 /compact 后最关键的一步：截图已从 context 清除，
       但摘要文件保留了所有结构化发现，等价于把上下文从磁盘恢复回来）
   d. 读取 feature-checklist.md → 确定哪些功能还没覆盖
   e. 扫描 screenshots/ → 确认已有截图（仅记文件名列表，不 Read 截图内容）
   f. 检查 pending_paid_flows 是否非空：
      - 非空 → 向 PM 确认："上次因付费墙跳过了 N 个功能，是否已购买会员？"
      - PM 已付费 → 进入【增量补测模式】（见下方）
      - PM 未付费 → 跳过付费功能，从中断点继续
   g. 启动目标 App → 导航到中断位置或补测目标
   h. 从 checkpoints.next_batch 继续，不重复已完成的工作
3. 如果不存在 → 从 Phase 0 开始
```

**/compact 后的恢复要诀**：**不要**重新 Read 历史截图去"找回记忆"——那会立刻把 context 再次打爆。只读 `phase-summaries.md` + `exploration-state.json` + `feature-checklist.md` 三个纯文本文件。如果某一步确实需要回看某张具体截图（如 Phase 3 生成 Module 04 需要提取颜色），按需单图 Read，不批量加载。

**增量补测模式**（付费后回来继续）：

```
1. 从 pending_paid_flows 逐个取出待测功能
2. 导航到该功能入口 → 端到端走通 → 每步截图
3. 更新 feature-checklist：⛔ → 🔄
4. 更新 exploration-state.json：从 pending_paid_flows 中移除已完成项
5. 全部补测完成后：
   - 如果 speckit_generated=true → 进入 Phase 3 增量更新模式
   - 如果 speckit_generated=false → 正常进入 Phase 3
```

**注意**：不保存也不依赖 WDA session ID。每次恢复都通过 Phase 0 重新创建 session。

**状态更新规则**：
- 每完成一个功能截图 → 更新 `feature-checklist.md` + `exploration-state.json`
- 每完成一条端到端流程 → 更新 `exploration-state.json` 的 `completed_flows`
- 每完成一个 Phase 阶段 → 更新 `exploration-state.json` 的 `phase`
- **状态文件必须写入磁盘，不能只存在对话上下文中**

### Phase 2: 真机 App 探索

**基础能力**：本 Phase 使用 `/ae-mobile-agent` 的 observe → think → act → verify 循环进行手机操控。以下规则是在 mobile-agent 基础上的**领域特化**（针对 App 系统化探索场景）。

**关键规则**（继承自 mobile-agent + 探索特化）：
- **每次操作后必须 `mobile_take_screenshot` 看到画面内容**，确认操作成功。不能盲目连续操作
- `mobile_save_screenshot` 在 iOS 真机上可能返回黑屏，**不要使用**。改用 WDA API 直接存：`curl -s http://localhost:8100/screenshot` → base64 decode → 写文件
- 需要实际拍摄文档的步骤（扫描、OCR 等），让 PM 手动操作，Agent 负责截图和记录
- 手机锁屏后截图会变黑屏，每次操作前先确认屏幕状态
- **需要上传照片测试时**，先推送测试图片到设备相册：`ios push-photo test.jpg --udid=<udid>`（需 go-ios 支持），或告知 PM 手动将测试图片存到相册
- **Swipe 安全距离**：所有 swipe 的起始 x 坐标必须 ≥ 屏幕宽度 1/3（至少 130pt），建议用屏幕中心。起始 x < ~80pt 会触发 iOS 系统「边缘滑动返回」手势，App 直接退出到上一级甚至回到主屏幕
- **App relaunch 后必须截图确认状态**：不要假设回到退出前的页面。常见变化：促销弹窗、评价请求、what's new、session 过期、interstitial 广告。先截图判断当前状态再继续操作
- **有持久化状态的页面必须做幂等性检查**（#IJ85I0）：进入 Counter / 表单 / 草稿 / 任何会被持久化的值展示页时，**先观察当前值是否为默认值**——非默认值意味着"上次会话残留"，必须先 reset 到 0 / 清空 / 默认状态再演示流程。历史反面教材：LoopCraft Counter 残留 1 未 reset，直接 +1×3 → 4，叙事失真。把此类页面记入 `exploration-state.json.dirty_state_pages`（数组），恢复时优先 reset
- **每张 Read 过的截图必须当场写结论到磁盘**（#IJ864Z）：这是 autoCompact 不会造成结论丢失的前提。规则：
  ```
  Read(screenshots/2a-F07-scan.png)   # 读图
  → 立刻更新 exploration-state.json.screenshot_to_feature 或 phase-summaries.md
     记录：{"2a-F07-scan.png": "F07 扫描入口在工具箱顶部，按钮 label='扫描'"}
  → 之后该图的信息**只通过磁盘文本引用**，不再 Read
  ```
  违反此规则的后果：autoCompact 触发后该图被清除，但结论只在"LLM 记忆"里也一并丢失，
  恢复时发现 feature-checklist 说已覆盖但没有可追溯的结论 → 返工

**Agent-PM 交互协议**（遇到需要人工操作的步骤时）：

```
1. Agent 暂停 → 告知 PM："请在手机上完成 XX 操作（如登录/拍照/付款），完成后告诉我"
2. PM 操作完成 → 回复 "好了" / "done"
3. Agent 截图确认 → 确认操作结果符合预期
4. 继续后续步骤
```

适用场景：登录/注册、付款确认、拍照/扫描、权限授权等需要物理操作的步骤。

**底部弹出面板（Bottom Sheet）关闭策略**：

iOS bottom sheet 的关闭按钮通常是 `XCUIElementTypeOther`，无 name/label。按以下优先级尝试关闭：
1. 元素树中找带 "close"/"dismiss"/"cancel" label 的按钮
2. 向下 swipe（从面板中部向屏幕底部）
3. 点击面板外的灰色遮罩区域（通常是屏幕最上方 100px）
4. 如果都不行，告知 PM 手动关闭

**标准 tap 操作模板**（避免反复猜坐标，每次点击都用此流程）：

> **机制性约束（#IJ85I0）**：历史 SKILL.md 只写"规则"不足以约束 agent 在长会话下图省事裸坐标 tap。当前模板已升级为**强制走 `wda-cli.py tap-element`**——该子命令内置 alert 前置检查 + 按元素定位，从机制上堵住"拍脑袋坐标"路径。

```
Step 0（前置，一次 tap 内必查）: 系统弹窗检查
    python3 wda-cli.py alert --action text
    如果非 "(no alert)" → 用 Alert API 处理（见「iOS 系统弹窗处理」），
      处理完再回到 Step 1；**不要先 tap 再观察**（历史反面教材：F07 相机权限浪费 1-2 张截图）

Step 1（首选）: 按元素 tap —— 禁止裸坐标
    python3 wda-cli.py tap-element --by name --value "按钮 label"
    支持的 --by：accessibility_id / name / label / xpath / predicate / class_chain
    该命令会自动：
      - 先做 alert 前置检查（有弹窗直接失败退出码 2）
      - 通过 WDA /element 找到元素 → 取 rect → 计算中心点 tap
      - 找不到元素退出码 3，并提示 `wda-cli.py source` 排查

Step 2: mobile_take_screenshot（或 wda-cli.py screenshot --save ...）→ 确认点击成功

Step 3（仅当 Step 1 失败）: 降级到 OCR / 裸坐标
    仅当元素树不完整（Flutter/RN/WebView）或目标无 name/label 时允许：
      python3 ocr-screenshot.py --wda --json → 获取 OCR 坐标（像素坐标需 ÷3）
      python3 wda-cli.py alert-safe-tap X Y  # 仍会前置检查 alert，杜绝 alert 下裸 tap
    绝对禁止直接用 mobile_click_on_screen_at_coordinates(X, Y) 裸坐标——
      这条路径没有 alert 前置检查，且容易在"长会话累积疲劳"下被 agent 滥用。
```

⚠️ **Webview 自定义控件限制**：Webview 内的 `<select>` 下拉框、
`<input type="range">` 滑块、自定义 JS 按钮等控件，WDA 的 touch 事件
**不会传递给 Webview 内部的 JS 事件处理器**。OCR 能找到元素位置，但
tap/swipe/W3C Actions 全部无效。**第一次交互失败后直接请 PM 手动操作，
不要反复尝试不同的 WDA 交互方式**（WDA tap、W3C Actions、element click、
swipe drag、element value 设值均已验证无效）。

**绝对不要凭视觉猜坐标。** 每次点击必须走 `tap-element`（首选）或
`alert-safe-tap`（OCR 回退），两者都内置 alert 前置检查。

**iOS 系统弹窗处理**（ATT / 权限请求 / 系统 Alert）：

iOS 系统级弹窗（App Tracking Transparency、权限请求等）是 overlay，拦截所有 touch 事件。**用坐标 tap 完全无效**，必须用 WDA Alert API：

```bash
# 1. 检测弹窗
curl -s http://localhost:8100/session/{sid}/alert/text
# 2. 获取按钮列表
curl -s http://localhost:8100/session/{sid}/wda/alert/buttons
# 3. 点击指定按钮（如"允许"/"Allow"/"不允许"）
curl -s -X POST -d '{"action":"accept","buttonLabel":"允许"}' \
  http://localhost:8100/session/{sid}/alert/accept
```

**规则**：如果 tap 后截图未变化，第一反应是检查系统 alert，不要反复重试坐标 tap。

#### Phase 2a: 广度遍历（分层，确保 100% 功能覆盖）

**Level 1 — Tab 遍历**：

```
Step 1: mobile_launch_app → 启动目标 App
Step 2: mobile_take_screenshot → 确认画面内容 → 保存截图
Step 3: 如有 onboarding → 逐步完成，每步截图 + 记录
Step 4: 到达 Home → mobile_list_elements_on_screen 识别所有 Tab/导航入口
Step 5: 逐 Tab 截图（**完成所有 Tab 后执行 CP2 Checkpoint**）：
    for each tab:
        mobile_click → mobile_take_screenshot（确认到达）→ 保存截图
        mobile_list_elements_on_screen → 记录元素
        如有滚动内容 → swipe + 再次截图
        滚动回顶部：**默认 `wda-cli.py scroll-to-top`**（内置 status-bar tap + swipe×6 fallback）
          历史验证（#IJ85I0）：纯 tap (y=0) 在 LoopCraft 多个场景完全无效，不再作为推荐路径

Step 6 (CP2): 全部 Tab 遍历完成后，Checkpoint：
    1. 追加 "## CP2 — Phase 2a Level 1 Tab 遍历" 到 phase-summaries.md
       内容：每个 Tab 的名称 + 页面主要元素 + 新发现的 discovered 功能
    2. 更新 exploration-state.json.checkpoints
    3. autonomous（默认）：输出一行 `[CP2] Level 1 Tab 遍历完成...` 后直接进入 Level 2
       interactive：输出 CP2 Checkpoint 消息给 PM，等待 "continue"
```

**Tab 数量 > 5 时**：若 App 有 6+ 个 Tab（含更多/设置），按每 5 个为一 batch 拆分，避免单 batch 超过 8 张截图（每 Tab 通常 1-2 张）。

**截图精简规则**：如果一个页面是重复样式的长列表（如 50+ 风格/模板/滤镜），不需要逐屏截图。只截首尾两屏 + 在 feature-checklist 备注中记录总数量（如 "52 种风格"）。

**Level 2 — 子入口遍历**（**默认 subagent 分发，每 8 个入口为 1 个 subagent 任务**）：

从 v0.46.0（#IJ864Z）起，Level 2 默认用 subagent 隔离执行——main agent 不直接 tap/截图，而是把每 batch 8 个子入口打包给 subagent，只接收 ≤200 字摘要。见「子 agent 隔离执行架构」章节的 prompt 模板。

```
Step 6: 对每个 Tab 内的子功能卡片/入口，按 batch 分发给 subagent：

    collect all sub_entries across tabs → 按 tab 和 8 个一组切片 → List[batch]

    for n, batch in enumerate(batches):
        # 1. 构造 subagent prompt（用"Phase 2a Level 2 batch 版"模板填充）
        prompt = fill_template(
            workdir=<绝对路径>,
            bundle_id=<from exploration-state.json>,
            sub_entries=batch,
            batch_n=n+1,
        )

        # 2. 调用 subagent
        summary = Agent(
            subagent_type="general-purpose",
            description=f"Phase 2a L2 batch{n+1}",
            prompt=prompt,
        )

        # 3. Main agent 只写一行 CP 日志（不 Read 截图）
        print(f"[CP3-batch{n+1}] {summary.第一行}，继续 batch{n+2}")

        # 4. 验证磁盘状态（不读截图，只 grep）
        assert 子 agent 已在 phase-summaries.md 追加 "CP3-batch{n+1}" 段
        assert exploration-state.json.checkpoints.last_written == f"CP3-batch{n+1}"
        若断言失败 → fallback 到 inline 模式重做本 batch

        # 5. interactive 模式才阻塞等 "continue"；autonomous 直接进入下一 batch
```

**Fallback（subagent 异常时降级 inline）**：

```
for sub_entry in batch:
    wda-cli.py tap-element --by name --value "<entry label>"
    screenshot-save.py <name>
    立刻更新 screenshot_to_feature
    返回上级
# 完成后按老 v0.45.0 方式写 CP3 段落
```

Fallback 触发条件：
- Agent 调用返回空 / 异常
- 摘要中明确包含"状态文件更新失败" / "WDA 断连" 等关键字
- 磁盘状态断言失败（phase-summaries.md / exploration-state.json 未更新）

连续 2 次 subagent fallback → 提示 PM 检查 WDA 环境，之后整个 Phase 2a Level 2 退回 inline 模式，`exploration-state.json.notes` 标记原因。

**为什么 subagent 是默认**：截图单张 ~700-1500 tokens，batch=8 即 8-12K tokens 纯图像占用。**inline 执行时这些图全进 main agent context；subagent 执行时只进 subagent 的临时 context，随其销毁一起蒸发。** 一次 20-40 子入口的 Phase 2a Level 2，main agent context 从"20-40 × 8-12K tokens"降到"3-5 × ≤200 字"。

**为什么 batch=8 仍然保留**：subagent 内部还是会吃图，如果单次 batch > 8 图，subagent 自己可能触发 dimension limit。batch=8 保障子 agent 也安全。

**注意**：App 内功能目录已在 Phase 1.5 提前完成，此处不再重复。如遇到引导弹窗/功能推广，截图并更新 feature-checklist。

**Feature Discovery by Reasoning（探索过程中持续扩展 checklist）**：

feature-checklist 不是静态文档。Phase 2 探索过程中，每次看到截图或元素树时，都要主动判断：**我看到的内容是否暗示了 checklist 上没有的功能？**

触发条件（任意一条命中就新增功能）：
- 看到 checklist 未记录的按钮/入口/图标（如「导出为 Word」但 checklist 只有「导出为 PDF」）
- 设置页中的开关/选项暗示了独立功能（如「iCloud 同步」「深色模式」「手势密码」）
- 元素树中出现 checklist 未覆盖的 accessibility label
- OCR 识别出功能名称关键词不在 checklist 中
- 导航结构暗示存在未列出的子模块（如 Tab 内有多层嵌套）

发现新功能时的操作：
```
1. 截图当前页面作为证据
2. 在 feature-checklist.md 中新增一行：
   ID: 按序号递增（如 F33）
   source: "discovered"（区别于 app_store / in_app）
   priority: 根据位置判断（主 Tab 入口 = core，深层子页面 = secondary）
   覆盖状态: ✅（因为发现时就已经截图了）
3. 在 exploration-state.json 的 notes 中记录发现理由
```

**source="discovered" 表示该功能不是来自 App Store 或帮助页的枚举，而是 agent 在探索中通过推理发现的。** 这类功能容易被遗漏，但往往是 App 的差异化卖点。

**静态资源识别（Phase 2a/2b 全程执行）**：

探索过程中，每次看到截图时同步识别页面中的静态资源（插画、图标、动画、纹理、角色形象等）。在 `exploration-state.json` 中维护 `asset_inventory` 数组：

```json
"asset_inventory": [
  {"id": "A01", "type": "illustration", "description": "树种插画（种子→成熟→枯萎）", "ref_screenshot": "2b-flow01-step03.png", "quantity": "5态×6种", "gen_hint": "AI 生图，需种间风格一致"},
  {"id": "A02", "type": "icon", "description": "底部 Tab 图标", "ref_screenshot": "2a-home-tabs.png", "quantity": "5个×2态", "gen_hint": "SF Symbols 风格，线条+填充两态"}
]
```

资源类型枚举：`illustration`（插画）、`icon`（图标）、`character`（角色/吉祥物）、`texture`（纹理/背景）、`animation`（动画/Lottie）、`badge`（徽章/成就）、`photo`（实拍素材）

**不需要逐个截图裁剪**——只需记录"在哪张截图上看到了什么资源"。裁剪和生成是下游 `ae-asset-gen` 的职责。

**页面跳转记录（Phase 2a/2b 全程执行）**：

每次操作导致页面跳转时，除了截图，额外记录一条 transition 到 `exploration-state.json` 的 `transitions` 数组：

```json
{"from": "来源页面", "to": "目标页面", "trigger": "触发操作描述", "nav_type": "push|sheet|fullScreenCover|replace|tab"}
```

`nav_type` 判断方法：
- `push`：新页面从右滑入，左上角有返回箭头
- `sheet`：新页面从底部弹出，可手势下滑关闭，上方有拖拽条
- `fullScreenCover`：全屏覆盖，无手势关闭，必须用按钮退出
- `replace`：当前页面内容原地替换（无动画或淡入淡出）
- `tab`：底部 Tab 切换

**不要等到 Phase 3 再回忆跳转关系——操作时实时记录，准确率远高于事后推断。**

**Level 2 结束后**：对照 feature-checklist，确认每个功能至少有一张入口截图。未覆盖的功能立即补截图。

#### Phase 2b: 核心流程深度走通（**每条流程默认 subagent 执行**）

从 feature-checklist 中 priority=core 的功能，挑选 3-5 条核心用户流程，每条由 subagent 端到端走通：

```
for n, flow in enumerate(core_flows):
    prompt = fill_template(  # "Phase 2b flow 版" 模板
        workdir=<绝对路径>,
        flow_name=flow.name,
        feature_id=flow.feature_id,
        entry=flow.entry_description,
        expected_end=flow.expected_end,
        flow_n=n+1,
    )

    summary = Agent(
        subagent_type="general-purpose",
        description=f"Phase 2b flow{n+1} {flow.name}",
        prompt=prompt,
    )

    # Main agent 只写一行 CP4 日志
    print(f"[CP4] Flow {n+1} {flow.name} 完成，进入下一条流程")

    # 检查摘要是否含 [需 PM 物理操作] 标记
    if "[需 PM 物理操作]" in summary:
        # 子 agent 走到需要拍照/扫描/付款的步骤时已停下
        提示 PM 接管该步骤，完成后 main agent 单步补截图 + 补写 phase-summaries.md
        # 不再整条 flow 重跑

    # 验证磁盘状态
    assert phase-summaries.md 含 "CP4 — Phase 2b Flow {n+1}"
    assert feature-checklist 对应行 ✅ → 🔄
```

**Fallback（subagent 异常时）**：同 Phase 2a Level 2 的 fallback 规则——降级为 main agent inline 走一遍老 v0.45.0 流程。

**为什么每条 flow 独立 subagent**：单条流程 5-8 步 = 5-8 张截图，恰好接近单 batch 上限。每条 flow 一个 subagent = 每条 flow 后 main agent context 完全干净（只留 200 字摘要），下一条 flow 的子 agent 又是全新 context。3-5 条 flow 的 Phase 2b，main agent 最多累积 ~1000 字文本摘要，截图完全不进 main context。

**物理操作节点**（拍照/上传/登录）依然由 PM 接管，但子 agent 会在摘要中显式标注 `[需 PM 物理操作]`，main agent 看到后提示 PM，而不是整条 flow 回退 inline。

#### Phase 2c: 边界探索（**结束后 CP5 Checkpoint**）

```
- 空状态页面截图
- 权限弹窗截图
- 付费墙/会员引导截图（遇到时截图，标记 ⛔）
- 未保存确认弹窗等交互细节
- 错误状态（如无网络）截图

CP5: 边界探索完成后，追加 "## CP5 — Phase 2c 边界态" 到 phase-summaries.md，
     更新 checkpoints。
     autonomous（默认）：输出 `[CP5] 边界探索完成，进入 Phase 2d 覆盖率 checkpoint`，直接继续
     interactive：输出 CP5 Checkpoint 消息给 PM，等待 "continue"
```

#### Phase 2d: 覆盖率 Checkpoint（强制执行）

**Phase 2 结束前必须执行此 checkpoint，不可跳过。**

```bash
# 1. 运行覆盖率统计脚本
python3 ~/.ae/pm/scripts/coverage-stats.py speckit/feature-checklist.md

# 2. 自动检查阈值（core ≥ 80%, in-app ≥ 60%，不达标 exit 1）
python3 ~/.ae/pm/scripts/coverage-stats.py speckit/feature-checklist.md \
  --check --core-min 80 --in-app-min 60

# 3. 如果不达标，对未覆盖的功能逐个判断：
#    能进入的 → 立即补截图
#    需要登录/付费的 → 标记原因
#    需要实物（证件/发票）的 → 标记 [需PM协助]

# 4. (CP6) 覆盖率达标后 Checkpoint：
#    追加 "## CP6 — Phase 2d 覆盖率达标" 到 phase-summaries.md
#    记录最终覆盖率数字 + 未覆盖功能清单及原因
#    autonomous（默认）：输出 `[CP6] 覆盖率达标（core {x}%, in-app {y}%），进入 Phase 2e 脱敏`，直接继续
#    interactive：输出 CP6 Checkpoint 消息给 PM，等待 "continue"
```

#### Phase 2e: 隐私脱敏（Phase 2d 通过后、Phase 3 之前）

截图中可能包含用户真实姓名、头像、设备名、用户 ID 等个人信息。**截图会被提交到 git 仓库，必须在进入 Phase 3 之前完成脱敏。**

```
1. 确认 exploration-state.json 中有 pii_patterns（Phase 0.7 收集的）
   如果没有 → 此时向 PM 补充收集
2. 运行脱敏脚本（含通知横幅检测）：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json \
     --mask-notifications \
     --dry-run
3. 审核报告 → 确认检测结果合理（注意 [notification] 类型的检测项）
4. 去掉 --dry-run 执行实际脱敏：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json \
     --mask-notifications
5. 如有固定位置的头像（如每个页面右上角），追加 --avatar-region：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json \
     --mask-notifications \
     --avatar-region 330,44,60,60
6. 快速浏览脱敏后的截图确认无遗漏
7. (CP7) 脱敏完成后 Checkpoint：
   追加 "## CP7 — Phase 2e 脱敏完成" 到 phase-summaries.md
   记录脱敏覆盖截图数 + 特殊处理项（avatar-region 等）
   **CP7 特殊性**（#IJ864Z，v0.45.0 更新）：Phase 3 是纯文本生成，理论上此处是 /compact 零成本的好时机，
   **但 skill 不再建议 PM 手动 /compact**——依赖 autoCompact 自动处理，skill 直接进入 Phase 3。
   autonomous（默认）：输出 `[CP7] 脱敏完成（{n} 张截图），直接进入 Phase 3（autoCompact 会在压力大时自处理）`，然后继续进入 Phase 3（不阻塞）
   interactive：输出 CP7 Checkpoint 消息给 PM，等待 "continue"
```

> **注意**：`--mask-notifications` 基于 OCR 启发式检测通知横幅（Messages/FaceTime/微信等关键词 + 屏幕顶部区域），作为 DND 的安全网。screenshot-save.py 截图前也会自动尝试关闭弹窗（`--auto-dismiss`），双保险。

**常见泄露点**：设置/个人资料页（姓名+头像+ID）、蓝牙设备名（含姓名）、页面角落头像、笔记/内容区域、**系统通知横幅（含联系人姓名+聊天内容+邮箱）**。

**探索终止条件**：
- Phase 2d checkpoint 通过
- Phase 2e 隐私脱敏完成
- 至少 3 条核心流程端到端走通（每步有截图）
- 遇到付费墙 → 标记 `[PAYWALL]`，截图后跳过
- `exploration-state.json` 的 `phase` 更新为 `"3"`

**截图保存方法**（WDA 直接 API，绕过 mobile_save_screenshot 黑屏 bug）：

```bash
python3 ~/.ae/pm/scripts/screenshot-save.py screenshots/{name}
# → 自动保存 screenshots/{name}.png + screenshots/{name}.xml
# → 内置黑屏检测和重试
# → 元素树 XML 用于事后坐标定位（WDA point × 3 = 像素坐标）
```

**产出**：`screenshots/` 目录（每页面 `.png` + `.xml` 配对）+ 更新后的 `feature-checklist.md`

### Phase 3: 逆向 Speckit 生成

**增量更新模式判断**：如果 `exploration-state.json` 中 `speckit_generated=true`（说明之前已生成过 speckit，这次是付费后补测回来的），则 Phase 3 改为增量模式：
- Module 01：检查功能边界是否需要更新（新验证的付费功能），追加而非重写
- Module 02：只追加新验证的流程到 `02-user-scenarios.md` 末尾，不覆盖已有内容
- Module 04：检查新截图是否有新的设计元素（付费功能可能有不同的 UI），追加差异
- 完成后标记 `speckit_generated=true`（保持不变）

如果 `speckit_generated=false` 或字段不存在 → 正常全量生成：

从 Phase 1 + Phase 2 产出，填充 speckit 模块：

**Module 01 — 项目定位**（置信度：高）
- 产品名/定位/副标题 → 直接从 App Store 提取（`confirmed`）
- 目标用户 → 从 App Store 描述 + 评论推断（`extracted`）
- 商业模式 → 从 IAP 列表 + 付费墙观察提取（`confirmed`）
- 功能边界 → 从 feature-checklist 完整功能列表生成（`confirmed` — 基于 App 内功能目录）

**Module 02 — 用户场景**（置信度：高）
- 页面清单 → 从 screenshots 目录直接列出，每行引用截图（`confirmed`）
- 用户流程 → 从 Phase 2b 端到端流程直接转换为场景叙事，**每步必须引用至少一张截图**（`confirmed`）
- 导航图 → 从 `exploration-state.json` 的 `transitions` 数组生成，输出两种格式：
  1. **Mermaid flowchart**（嵌入 Module 02，Gitee/GitHub 可直接渲染）：
     ```mermaid
     graph LR
       Home -->|点击开始专注<br/>fullScreenCover| FocusSession
       FocusSession -->|专注完成<br/>replace| Result
       Result -->|点击完成<br/>dismiss| Home
       Home -->|点击树种选择<br/>sheet| TreePicker
     ```
  2. **结构化表格**（供下游 dev agent 解析）：
     | From | To | Trigger | Nav Type |
     |------|----|---------|----------|
     | Home | FocusSession | 点击开始专注 | fullScreenCover |
     如果 transitions 数组为空（Phase 2 未记录），标注 `[NEEDS INPUT]` 并在 review-checklist 中提醒 PM 补充
- Toast/弹窗 → 从探索过程中实际遇到的弹窗记录，引用截图（`confirmed`）
- 未端到端走通但有入口截图的功能 → 标注 `[extracted]`，引用入口截图

**硬性规则：Module 02 不允许截图占位符。** 每个流程步骤的截图列必须引用真实截图文件（`screenshots/*.png`），不得为空或写"无截图"。Phase 3 生成 Module 02 前，先检查所有 core flow 步骤的截图引用完整度 ≥ 90%；不达标则回到 Phase 2b 补截图。

**Module 04 — 设计规范**（置信度：中）
- 颜色系统 → 从截图 Vision 分析提取，**每个颜色值必须标注来源截图和元素位置**（`[extracted from xx.png: 元素描述]`）
- 字体 → 从截图推断大小层级，标注来源（`[extracted]`）
- 间距/圆角 → 从截图推断，标注来源（`[extracted]`）
- 组件模式 → 从截图识别，引用对应截图（`[extracted]`）
- **静态资源清单** → 从 `exploration-state.json` 的 `asset_inventory` 生成结构化表格：

  | ID | 类型 | 描述 | 参考截图 | 数量 | 生成建议 |
  |----|------|------|---------|------|---------|
  | A01 | illustration | 树种插画（种子→成熟→枯萎） | 2b-flow01-step03.png | 5态×6种 | AI 生图，需种间风格一致 |
  | A02 | icon | 底部 Tab 图标 | 2a-home-tabs.png | 5个×2态 | SF Symbols 风格 |

  每行必须引用参考截图。如果 `asset_inventory` 为空（工具类 App 视觉依赖低），在 Module 04 标注"本产品无显著静态资源依赖"。
  资源清单是下游素材生成（`ae-asset-gen`）的输入，缺少此清单 = 开发者只能用灰色占位框

### Phase 4: PM Review 清单

生成 `review-checklist.md`，必须包含：

```markdown
# PM Review 清单

## 覆盖率报告
（从 Phase 2d checkpoint 直接引用）
- App Store 核心功能覆盖率: XX%
- App 内功能目录覆盖率: XX%
- 端到端走通的流程: X 条

## 已覆盖的功能（附截图引用）
[从 feature-checklist 中 ✅ 和 🔄 的功能]

## 未覆盖的功能及原因
[从 feature-checklist 中 ⬜ ⛔ 🔒 的功能，含原因]

## 设计精度
- [ ] 提取的颜色值是否准确？（参考截图 xx.png）
- [ ] 组件样式是否需要调整？

## 补充模块
- [ ] 是否需要补充 Module 03（技术架构）？
- [ ] 是否需要补充 Module 05（数据模型）？
- [ ] 是否需要补充 Module 06（API 规范）？

## 差异化
- [ ] 复刻时需要做哪些差异化调整？
- [ ] 哪些功能可以裁剪？
```

## 置信度标注体系

复用 demo-to-speckit 的标注规范：

| 置信度 | 含义 | 标注方式 |
|--------|------|---------|
| `confirmed` | 从 App Store 描述或直接 UI 观察确认 | 无标注（默认） |
| `extracted` | 从截图/UI 结构提取，未有文档确认 | 字段后标注 `[extracted from xx.png]` |
| `inferred` | 无直接证据，从上下文推断 | 字段后标注 `[inferred]` |
| `missing` | 无法提取，需 PM 补充 | 字段后标注 `[NEEDS INPUT]` |
| `paywall` | 被付费墙阻断，无法验证 | 字段后标注 `[PAYWALL]` |

## Schema 校验

输出的 speckit 必须通过 `content/speckit-schema.yaml` 校验（使用 `verify/engine/speckit_validator.py`）。

由于只输出 01/02/04 三个模块，校验时跳过 03/05/06 的 required_sections 检查，但已输出模块必须满足 quality_indicators。

## 技术风险

| 风险 | 影响 | 对策 |
|------|------|------|
| 第三方 App 非 Native（Flutter/RN/WebView） | Accessibility Tree 返回空或不完整 | 以截图 Vision 分析为主，Accessibility 为辅 |
| 多步操作可靠性衰减（单步 72% → 10 步 3.7%） | 长流程可能中断 | 每步截图校验，失败时回退重试或 PM 接管 |
| 付费墙阻断核心功能 | 无法探索付费功能 | 标记 [PAYWALL]，从 App Store 截图 + 评论补充 |
| 登录/注册墙 | 无法进入主功能 | PM 预先登录，或 Agent 辅助完成注册 |
| 隐藏功能（长按、3D Touch、状态触发） | 无法自动发现 | 通过 App 内功能目录补全，而非仅依赖 App Store 描述 |
| mobile_save_screenshot 返回黑屏 | 截图全部丢失 | **不使用 save_screenshot**，改用 WDA API 直接保存 |
| 手机自动锁屏 | 截图变黑、操作失败 | 每次操作前先 take_screenshot 确认屏幕亮着；锁屏后请 PM 解锁 |
| WDA 进程断开（会话切换/超时） | 所有 MCP tool 失效 | 重新执行 Phase 0（tunnel + xcodebuild + forward + verify），不依赖旧 session ID |
| 盲操作连续多步不验证 | 操作可能偏离预期但不自知 | **每次操作后必须 take_screenshot 看到内容**，确认成功后再继续 |
| 通知/弹窗干扰 | 遮挡界面，误触，泄露他人 PII | 前置条件**必须**开启免打扰；screenshot-save.py 自动 dismiss；Phase 2e 加 `--mask-notifications` 兜底 |
| 广度覆盖不足（只遍历 Tab 不深入） | 大量功能无截图，下游缺参照 | Phase 2a 分三层（Tab→子入口→功能目录），Phase 2d 强制 checkpoint |
| iOS 系统弹窗（ATT/权限）拦截 touch | 坐标 tap 完全无效，反复重试浪费时间 | tap 无响应时先检查 `GET .../alert/text`，用 WDA Alert API 处理（见标准 tap 模板） |
| iOS 左边缘 swipe 触发系统返回 | App 退出到上一级或主屏幕，需重新导航 | 所有 swipe 起始 x ≥ 屏幕宽度 1/3（至少 130pt），用屏幕中心最安全 |
| Webview 自定义控件对 WDA 不透明 | `<select>`/`<input range>`/JS 按钮无法自动化 | 第一次交互失败后直接请 PM 手动操作，不要反复尝试不同 WDA 方式 |
| App relaunch 后 UI 状态不一致 | 促销弹窗/interstitial/session 过期打乱流程 | relaunch 后必须截图确认状态，不假设回到退出前页面 |
| WDA W3C Actions API 偶发 INFINITY 崩溃 | `point.x != INFINITY` 错误，整个 action chain 失败 | fallback 到简单 WDA endpoint（`/wda/tap`、swipe），不要连续重试 W3C Actions |
| **截图累积触发 many-image 2000px 上限**（#IJ809A） | 10-15 张截图后出现 "dimension limit" 错误，skill 中断需人工 `/compact` | **batch 化 + Checkpoint**：Phase 2a Level 2 每 8 个子入口、Phase 2b 每条流程、Phase 2c/2d/2e 各自一个 Checkpoint。每 Checkpoint 必写 `phase-summaries.md` 持久化摘要；依赖 `autoCompact: true` 自动压缩。恢复时只读纯文本摘要，不批量 Read 历史截图 |
| **每 CP 强制等 PM `continue` 阻断自动化**（#IJ84WI） | 单次扫描 10+ 次手动 `continue`，严重降低可用性；混淆了图片维度约束与 token 上限 | **默认 autonomous 模式**：CP 写摘要+更新状态后直接继续；仅在「物理操作节点」（PII 收集/付费决策/拍照/付费墙/登录墙）暂停请 PM 接管。CP7 从 v0.45.0 起也不再建议 /compact，依赖 autoCompact。`--interactive` 保留老行为回退 |
| **autoCompact 触发时截图结论丢失**（#IJ864Z） | Agent 读了截图但结论只在 "LLM 记忆"，autoCompact 清掉图后结论也丢，feature-checklist 说已覆盖但无可追溯结论 → 返工 | 核心原则 #8 硬规则：每张 Read 过的截图**在下次 tool call 前**必须把结论写到 `exploration-state.json.screenshot_to_feature` 或 `phase-summaries.md`；之后不再 Read 同一张图 |
| **Phase 2a L2/2b 截图线性累积 main context**（#IJ864Z v0.46.0） | inline 执行时 20-40 张子入口截图 + 3-5 条 flow × 5-8 步截图全进 main agent context，即使有 batch+CP 机制也是 "间隔压缩不消除" | **subagent 隔离执行**：CP3 每 batch / CP4 每条 flow 由 `Agent(subagent_type=general-purpose)` 独立跑，子 agent 吃截图、落盘、返回 ≤200 字摘要后销毁。main agent context 从"N × 8 图"降为"N × 200 字"。失败时 fallback 到 inline（保留老路径） |
| **文档约束在长会话下失效 / 裸坐标 tap 复现**（#IJ85I0） | 长会话后 agent 跳过元素树直接拍坐标，历史已在 SKILL.md 写明的 tap 模板被忽略 | **机制性约束取代文档约束**：强制走 `wda-cli.py tap-element --by ... --value ...`，该命令内置 alert 前置 + 找不到元素 fail-fast（退出码 3），物理上阻断裸坐标 tap 路径 |
| **状态栏 tap 滚顶在真机上不稳定**（#IJ85I0） | tap (200, 0/5/10) 在多个 App 完全无响应（自定义 nav bar 拦截系统手势） | 封装 `wda-cli.py scroll-to-top`：先尝试 status-bar tap（best-effort），再 swipe-down × N 默认回退。SKILL.md 不再把 status bar 作为"优先"方案 |
| **alert 检测写在 tap 失败分支导致弯路**（#IJ85I0） | 历史模板"if 截图无变化再查 alert"——agent 默认先 tap 再回头查，浪费 1-2 张截图 | 把 alert 检查前置到 Step 0；`tap-element` / `alert-safe-tap` 在 CLI 层自动前置检查，有 alert 则退出码 2 |
| **持久化状态页面 relaunch 后污染叙事**（#IJ85I0） | Counter / 草稿页残留上一会话值，agent 继续操作产生错误演示（如 Counter 残留 1 → +3 → 显示 4） | 进入"可持久化状态"页面时必做幂等性检查；`exploration-state.json.dirty_state_pages` 记录已知污染页 + reset 动作，恢复时优先 reset |

## 复用说明

所有 PM 在复刻已上架 App 时都需要此能力。产出的 speckit 可直接进入下游流水线：
- `speckit` → vibe coding → demo
- `speckit` + Figma → dev agent → 成品

## 关联

- 前置：`/ae-mobile-setup`（环境搭建，首次使用前必须完成）
- 基础能力：`/ae-mobile-agent`（手机操控的 observe-think-act-verify 循环）
- 上游：PM 选定目标 App
- 下游：demo-to-speckit（如果先 vibe coding 再提取）、demo-to-figma、verify-app
- 父任务：IHWK3R、IHXR0I、IHVABC
