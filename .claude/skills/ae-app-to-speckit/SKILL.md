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

## 前置条件

| 条件 | 说明 |
|------|------|
| iPhone 真机自动化环境 | **必须先完成 `/ae-mobile-setup`**（go-ios + WDA + mobile-mcp 全套） |
| 目标 App 已安装 | 从 App Store 下载到真机 |
| **免打扰模式** | **建议 PM 开启 iPhone 免打扰（专注模式），避免通知遮挡界面干扰操作和截图** |

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

**截图命名规范**：采用语义化命名 `{phase}-{功能ID}-{描述}.png`，确保文件名即内容。

| Phase | 命名示例 | 说明 |
|-------|---------|------|
| 1.5 | `1.5-help-page-full.png` | 功能目录截图 |
| 2a | `2a-F01-scan-entry.png` | 广度遍历入口截图 |
| 2a | `2a-F03-ocr-subpage.png` | 子功能页面 |
| 2b | `2b-flow01-step03-confirm.png` | 端到端流程步骤 |
| 2c | `2c-empty-state.png` | 边界状态 |

speckit 文档中通过 `![描述](screenshots/xx.png)` 引用截图，确保下游 vibe coding 有精确的视觉参照。在 `exploration-state.json` 中维护截图到功能的映射关系。

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
```

**完成后**：带着完整的 feature-checklist 进入 Phase 2，避免遍历中途大面积补功能。

### 中断恢复机制

整个探索过程可能耗时很长（30 分钟 ~ 数小时），且随时可能因锁屏、WDA 断开、会话超时等原因中断。通过三个状态文件实现断点恢复：

**状态文件 1 — `feature-checklist.md`**（进度条）

每覆盖一个功能就更新覆盖状态。中断后读此文件即可知道哪些功能还未覆盖。

**状态文件 2 — `screenshots/` 目录**（已完成工作证据）

已保存的截图不需要重新截取。恢复时扫描目录即可知道哪些页面已有截图。

**状态文件 3 — `exploration-state.json`**（当前阶段状态）

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
  "notes": "工具箱-扫描类已完成，格式转换类进行中"
}
```

**恢复流程**（每次会话开始时执行）：

```
1. 检查 speckit/ 目录是否已存在
2. 如果存在：
   a. 执行 Phase 0 → 重新建立 WDA 连接（不依赖旧 session ID）
   b. 读取 exploration-state.json → 确定上次停在哪个阶段
   c. 读取 feature-checklist.md → 确定哪些功能还没覆盖
   d. 扫描 screenshots/ → 确认已有截图
   e. 检查 pending_paid_flows 是否非空：
      - 非空 → 向 PM 确认："上次因付费墙跳过了 N 个功能，是否已购买会员？"
      - PM 已付费 → 进入【增量补测模式】（见下方）
      - PM 未付费 → 跳过付费功能，从中断点继续
   f. 启动目标 App → 导航到中断位置或补测目标
   g. 从中断点继续，不重复已完成的工作
3. 如果不存在 → 从 Phase 0 开始
```

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

```
1. mobile_list_elements_on_screen → 获取页面元素树
2. 在元素树中找到目标元素 → 读取其 rect {x, y, width, height}
3. 计算中心点坐标：center_x = x + width/2, center_y = y + height/2
4. mobile_click_on_screen_at_coordinates(center_x, center_y)
5. mobile_take_screenshot → 确认点击成功

如果元素树不完整（Flutter/RN/WebView App）：
1. mobile_take_screenshot → 获取当前画面
2. python3 ocr-screenshot.py --wda --json → OCR 识别文字和坐标
   注意：OCR 返回的是像素坐标，需 ÷3 转换为逻辑点坐标
3. 用 OCR 文字坐标点击目标
4. mobile_take_screenshot → 确认点击成功
```

**绝对不要凭视觉猜坐标。** 每次点击都必须先获取元素/OCR 坐标，再计算中心点。

#### Phase 2a: 广度遍历（分层，确保 100% 功能覆盖）

**Level 1 — Tab 遍历**：

```
Step 1: mobile_launch_app → 启动目标 App
Step 2: mobile_take_screenshot → 确认画面内容 → 保存截图
Step 3: 如有 onboarding → 逐步完成，每步截图 + 记录
Step 4: 到达 Home → mobile_list_elements_on_screen 识别所有 Tab/导航入口
Step 5: 逐 Tab 截图：
    for each tab:
        mobile_click → mobile_take_screenshot（确认到达）→ 保存截图
        mobile_list_elements_on_screen → 记录元素
        如有滚动内容 → swipe + 再次截图
        滚动回顶部：优先点击状态栏（屏幕最顶部 y=0 区域），如不生效则多次上滑
```

**截图精简规则**：如果一个页面是重复样式的长列表（如 50+ 风格/模板/滤镜），不需要逐屏截图。只截首尾两屏 + 在 feature-checklist 备注中记录总数量（如 "52 种风格"）。

**Level 2 — 子入口遍历**：

```
Step 6: 对每个 Tab 内的子功能卡片/入口：
    for each sub_entry in tab:
        mobile_click → mobile_take_screenshot → 保存截图
        记录该功能的入口页面样式
        返回上级
```

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

**Level 2 结束后**：对照 feature-checklist，确认每个功能至少有一张入口截图。未覆盖的功能立即补截图。

#### Phase 2b: 核心流程深度走通（每步截图）

从 feature-checklist 中 priority=core 的功能，挑选 3-5 条核心用户流程，端到端走通：

```
for each core_flow:
    1. 从入口开始操作
    2. 每一步：操作 → take_screenshot（确认）→ 保存截图 → 记录步骤
    3. 遇到需要真实输入的步骤（拍照/扫描）→ 告知 PM 操作
    4. 走到流程终点或遇到 PAYWALL → 记录并截图
    5. 返回起点，开始下一条流程
    6. 更新 feature-checklist 中对应功能的覆盖状态为 🔄
```

#### Phase 2c: 边界探索

```
- 空状态页面截图
- 权限弹窗截图
- 付费墙/会员引导截图（遇到时截图，标记 ⛔）
- 未保存确认弹窗等交互细节
- 错误状态（如无网络）截图
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
```

#### Phase 2e: 隐私脱敏（Phase 2d 通过后、Phase 3 之前）

截图中可能包含用户真实姓名、头像、设备名、用户 ID 等个人信息。**截图会被提交到 git 仓库，必须在进入 Phase 3 之前完成脱敏。**

```
1. 确认 exploration-state.json 中有 pii_patterns（Phase 0.7 收���的）
   如果没有 → 此时向 PM 补充收集
2. 运行脱敏脚本：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json \
     --dry-run
3. 审核报告 → 确认检测结果合理
4. 去掉 --dry-run 执行实际脱敏：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json
5. 如有固定位置的头像（如每个页面右上角），追加 --avatar-region：
   python3 ~/.ae/pm/scripts/privacy-mask.py speckit/screenshots/ \
     --pii-config speckit/exploration-state.json \
     --avatar-region 330,44,60,60
6. 快速浏览脱敏后的截图确认无遗漏
```

**常见泄露点**：设置/个人资料页（姓名+头像+ID）、蓝牙设备名（含姓名）、页面角落头像、笔记/内容区域。

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
- 导航图 → 从 transitions 生成（`confirmed`）
- Toast/弹窗 → 从探索过程中实际遇到的弹窗记录，引用截图（`confirmed`）
- 未端到端走通但有入口截图的功能 → 标注 `[extracted]`，引用入口截图

**硬性规则：Module 02 不允许截图占位符。** 每个流程步骤的截图列必须引用真实截图文件（`screenshots/*.png`），不得为空或写"无截图"。Phase 3 生成 Module 02 前，先检查所有 core flow 步骤的截图引用完整度 ≥ 90%；不达标则回到 Phase 2b 补截图。

**Module 04 — 设计规范**（置信度：中）
- 颜色系统 → 从截图 Vision 分析提取，**每个颜色值必须标注来源截图和元素位置**（`[extracted from xx.png: 元素描述]`）
- 字体 → 从截图推断大小层级，标注来源（`[extracted]`）
- 间距/圆角 → 从截图推断，标注来源（`[extracted]`）
- 组件模式 → 从截图识别，引用对应截图（`[extracted]`）

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
| 通知/弹窗干扰 | 遮挡界面，误触 | 前置条件要求 PM 开启免打扰模式 |
| 广度覆盖不足（只遍历 Tab 不深入） | 大量功能无截图，下游缺参照 | Phase 2a 分三层（Tab→子入口→功能目录），Phase 2d 强制 checkpoint |

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
