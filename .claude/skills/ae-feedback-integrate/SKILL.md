---
description: "iOS 用户反馈全流程 — BCFeedback 弹窗 + FeedbackSource 业务枚举 + 本地持久化 + BCTrack 埋点（Scale Global 生态）"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(pod *)"
    - "Bash(grep *)"
    - "Bash(find *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: pod
      verify: "pod --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version"
  expected_exit: 0
  description: "xcodebuild available"
---

# Skill: 用户反馈全流程 (ae-feedback-integrate)

> **经 bible-ios-template + loopcraft 实战验证。** 基于 Scale Global 内部 `BCFeedback` Pod + `Template/Feature/Feedback/` 业务薄封装，产出业务页嵌入反馈 UI + 弹窗式 survey + 本地持久化 + BCTrack 埋点全流程。

## 核心原则

> **你是反馈工程师。** 基于 PM 提供的反馈场景（业务结果页嵌反馈 / 关键路径弹 survey），产出：
> ① 产品特定 `FeedbackSource` 枚举；② `FeedbackSource+Ext` 扩展（source / parameters / feedbackData 映射）；③ 业务 View 嵌入 `FeedbackView(data:)`；④ 可选的关键路径 `BCFeedback.survey(...)` 弹窗。
>
> **关键约束：**
> 1. 业务代码不直接 `BCTrack.track("feedback", ...)`，必须走 `FeedbackHelper.feedback(data: yes:)`（否则漏持久化 + 漏 Thanks View）
> 2. `FeedbackSource` 每个 enum case 必须在 Ext 里补完 `source` / `parameters` / `feedbackData` 三个映射
> 3. `BCFeedbackData` 预定义（`.identifyResult` / `.diagnoseResult` / `.plantFinder`）只对应 Plant 类产品，其他产品必须自定义 static computed var（文案要和业务场景匹配）

## 触发条件

- PM 说"加反馈按钮"、"用户点 yes/no"、"NPS survey"、"我想知道用户觉得这个结果怎么样"
- preflight 报告标记"Template/Feature/Feedback/ 缺失" / "FeedbackSource 未定义"
- Demo 即将上 TestFlight，需要收集用户对核心功能结果的满意度

## 角色分工

| 事项 | 谁做 |
|------|------|
| Podfile 含 BCFeedback | **杭州团队（触发本 skill 前完成）** |
| 反馈场景定义（哪个业务结果页嵌反馈 / 关键路径触发 survey）| PM |
| FeedbackSource 枚举 case 命名 | PM + Agent（参考 Loopcraft 的 `.paint(PaintingSource)` 模式）|
| BCTrack 事件 parameters 约定 | PM + Agent（参考 Plant 类产品 parameters 模式）|
| `Template/Feature/Feedback/` 通用 4 文件（Helper/DataManager/ThanksView/View）copy | Agent |
| `FeedbackSource` + `FeedbackSource+Ext` 产品特定编写 | Agent |
| 业务页嵌入 `FeedbackView` 调用点 | Agent |
| 用户反馈数据后台查询 | PM 通过神策 / Firebase 查 `feedback` 事件 |

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 |
| ae-analytics-integrate 已完成 | `BCTrack.track()` 可用（反馈埋点必需）|
| Podfile 含 BCFeedback | `grep 'pod "BCFeedback"' Podfile` 有匹配 |
| `Template/Feature/Feedback/` 已存在 | `find Template/Feature/Feedback -name "*.swift"` 返回 ≥4 个文件（从 bible-ios-template / Loopcraft 复制）|
| `MLModelCacheManager` 可用 | 来自 AppImports，业务代码 `import AppImports` 即有 |

前置未就绪 → **停在这里**，向 PM 说明缺项，不继续。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "Loopcraft" / "WePray" |
| 反馈场景清单 | 是 | 每个场景：业务名 + 结果数据结构 + 预期埋点 parameters |
| 业务结果数据结构 | 是 | 如 Loopcraft 的 `PaintingSource`（含 capIds 或 prompt 等）|
| Survey 触发时机（可选）| 否 | 如"看完 paywall 关闭后"、"使用核心功能 N 次后"|
| Feedback 详情选项清单（可选）| 否 | 如"生成结果不满意" → 子选项（"不符合描述" / "质量差" / "太慢"）|

---

## Phase 1: 前置检查

### Step 1.1: Podfile

```bash
grep -E 'pod "BCFeedback"' Podfile
```

**预期：** 有匹配（通常 tag 固定，如 `1.6.0`）。缺失 → 联系杭州加 pod，本 skill 暂停。

### Step 1.2: Template/Feature/Feedback 4 通用文件已在

```bash
find Template/Feature/Feedback -name "*.swift" -type f
```

**预期：** 至少包含 `Helper/FeedbackHelper.swift` + `DataManager/FeedbackDataManager.swift` + `Views/FeedbackThanksView.swift` + `Views/FeedbackView.swift`（`Model/FeedbackSource.swift` + `Extension/FeedbackSource+Ext.swift` 可能是产品特定的旧 case，后续 Phase 2 重写）。

缺失 → 从 bible-ios-template 或 Loopcraft 复制 4 通用文件（内容稳定，通用可抄）。

### Step 1.3: 向 PM 确认场景

口头问 PM：

> 1. 要在哪些业务结果页嵌反馈按钮？每个结果的数据结构长什么样（字段）？
> 2. 每个场景的 BCTrack parameters 要带什么（产品 ID / source 类型 / 结果类型 / 错误码等）？
> 3. 要不要弹窗式 survey？如要，触发时机 + 详情反馈选项清单
> 4. 感谢文案用默认（`Language.ctext_feedback_text_thanks`）还是自定义？

**回答完整才进入 Phase 2。**

---

## Phase 2: 代码生成

### Step 2.1: 通用 4 文件 copy（若缺失）

从 bible-ios-template 或 Loopcraft 复制：

| 源路径 | 目标路径 |
|--------|---------|
| `Template/Feature/Feedback/Helper/FeedbackHelper.swift` | 同 |
| `Template/Feature/Feedback/DataManager/FeedbackDataManager.swift` | 同 |
| `Template/Feature/Feedback/Views/FeedbackThanksView.swift` | 同 |
| `Template/Feature/Feedback/Views/FeedbackView.swift` | 同 |

这 4 个文件通常不需改（FeedbackDataManager 的 `append(_ ids: PaintingSource, yes:)` 里的 `PaintingSource` 是 Loopcraft 特定，目标产品可删此方法，保留 `append(data: FeedbackResult)` 通用版）。

### Step 2.2: FeedbackSource 枚举（产品特定）

路径：`Template/Feature/Feedback/Model/FeedbackSource.swift`

```swift
import AppImports

enum FeedbackSource: Codable, Equatable {
    // 按 PM 提供的场景定义 case
    // 示例（Loopcraft）：
    // case paint(_ data: PaintingSource)

    // 示例（WePray 假设场景）：
    // case chatResponse(_ data: ChatResponseSource)
    // case bibleStudy(_ data: BibleStudySource)

    // 示例（Plant 识别）：
    // case identify(_ data: IdentifyResult)
    // case diagnose(_ data: DiagnoseResult)

    case <按 PM 需求填>
}

struct FeedbackResult: Codable {
    let data: FeedbackSource
    let yes: Bool
}
```

**⚠️ 每个 case 必须对应一个产品业务数据结构**（如 `PaintingSource` / `ChatResponseSource`），数据结构本身由业务代码定义（不在本 skill 范围）。

### Step 2.3: FeedbackSource+Ext 扩展（产品特定）

路径：`Template/Feature/Feedback/Extension/FeedbackSource+Ext.swift`

```swift
import AppImports
import BCFeedback

extension FeedbackSource {
    /// 埋点 source 字段（每个 case 必须返回非空字符串）
    var source: String {
        switch self {
        case .chatResponse(let data):
            return data.source      // "chat_response" 或更细分
        case .bibleStudy(let data):
            return data.source
        // 其他 case ...
        }
    }

    /// 埋点 parameters（每个 case 返回 BCJson，含 source 字段）
    var parameters: BCJson {
        var parameters: BCJson
        switch self {
        case .chatResponse(let data):
            parameters = data.parameters
        case .bibleStudy(let data):
            parameters = data.parameters
        // 其他 case ...
        }
        parameters[.KeyResource] = self.source
        return parameters
    }

    /// 弹窗式 feedback 的详情选项（BCFeedback.feedback 详情页展示）
    ///
    /// 🔒 `BCFeedbackData` 预定义只有 Plant 类产品的 `.identifyResult` / `.diagnoseResult` / `.plantFinder`，
    /// 其他产品必须自定义 static computed var（参考 Step 2.4）。
    var feedbackData: BCFeedbackData {
        switch self {
        case .chatResponse:
            return .chatResponse       // 见 Step 2.4 自定义
        case .bibleStudy:
            return .bibleStudy
        // 其他 case ...
        }
    }
}
```

**每个 case 的 3 个映射（source / parameters / feedbackData）必须全补**，否则 switch exhaustive 编译挂 or runtime `feedbackData` crash。

### Step 2.4: 自定义 BCFeedbackData（非 Plant 类产品）

路径：`Template/Feature/Feedback/Model/BCFeedbackData+Product.swift`（或同等位置）

```swift
import BCFeedback
import CL10nKit

public extension BCFeedbackData {
    /// 例：WePray 聊天结果反馈
    static var chatResponse: BCFeedbackData {
        .init(title: nil, items: .chatResponse)
    }

    /// 例：WePray 圣经学习反馈
    static var bibleStudy: BCFeedbackData {
        .init(title: nil, items: .bibleStudy)
    }
}

public extension Array where Element == BCFeedbackItemData {
    /// 对应 chatResponse 的详情选项（每组 title + subTexts）
    static var chatResponse: [BCFeedbackItemData] {
        [
            .init(title: .init(key: "feedback_chat_irrelevant"),
                  subTexts: .withKeys(["feedback_chat_offtopic", "feedback_chat_factwrong"])),
            .init(title: .init(key: "feedback_chat_tone"),
                  subTexts: .withKeys(["feedback_chat_too_preachy", "feedback_chat_too_casual"])),
            .init(title: .init(key: "feedback_feature_notmeet"),
                  subTexts: nil,
                  other: Language.feedback_please_tell_us_more)
        ]
    }

    static var bibleStudy: [BCFeedbackItemData] {
        [ /* 按产品场景填 */ ]
    }
}
```

**所有 `feedback_xxx` 文案 key 必须在 `Localizable.strings` / `Localizable.xcstrings` 中定义**（依赖 `ae-i18n-integrate` 后续 skill 保证多语言）。

### Step 2.5: 业务页嵌入 FeedbackView

在业务结果展示页（如 ChatResponseView / BibleStudyResultView）末尾嵌入：

```swift
import AppImports

struct ChatResponseView: View {
    let response: ChatResponseSource

    var body: some View {
        VStack(spacing: 16.fx) {
            // ... 结果内容 ...

            // 反馈按钮区域（复用 Template/Feature/Feedback/Views/FeedbackView）
            FeedbackView(data: .chatResponse(response))
        }
    }
}
```

**触发后自动流程：** `FeedbackHelper.feedback` → `FeedbackDataManager.append`（持久化）→ `BCTrack.track("feedback", parameters: ...)` → `FeedbackThanksView.show()`（3 秒自动消失）

### Step 2.6: 关键路径弹窗 survey（可选）

在关键路径（如 paywall 关闭、付费成功、连续使用 N 次）触发 NPS survey：

```swift
import BCFeedback

// 简单二值 survey
Task {
    let isYes = await BCFeedback.survey(
        source: "paywall_close",
        data: .default,                 // 用默认文案 "Are you satisfied?"
        feedbackData: nil,              // nil = 只做 survey，不追问详情
        parameters: ["paywall_id": "onboarding"]
    )
    // isYes 可以打业务埋点，或不处理
}

// survey + 详情反馈链路（选 No 会自动弹 feedback 详情页）
Task {
    let isYes = await BCFeedback.survey(
        source: "chat_satisfaction",
        data: .default,
        feedbackData: .chatResponse,    // 选 No 会自动弹 chatResponse 详情
        parameters: ["session_id": sessionId]
    )
}
```

---

## Phase 3: 集成验证

### Step 3.1: 编译通过

```bash
xcodebuild build \
  -workspace <ProjectName>.xcworkspace \
  -scheme <SchemeName> \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15
```

### Step 3.2: 模拟器行为验证

1. 走到嵌入 FeedbackView 的结果页 → 看到 👍 / 👎 两个按钮
2. 点 👍 → 按钮变高亮（selected 态）+ 顶层弹 FeedbackThanksView（3 秒自动消失）
3. 冷启 App 回到同一结果页 → 👍 仍高亮（`FeedbackDataManager` 持久化生效）
4. 点 👎 → 👍 变未选中，👎 变高亮（单选行为）

### Step 3.3: 埋点验证

Firebase DebugView / 神策 Debug 看 `feedback` 事件：

```json
{
  "event": "feedback",
  "type": "click",
  "parameters": {
    "resource": "chat_response",  // 来自 FeedbackSource.source
    "eparam1": "yes",              // FeedbackHelper 追加的 yes/no
    // ... 其他业务 parameters
  }
}
```

**关键字段：**
- `resource` 必须非空（否则 source map 缺失）
- `eparam1` 严格 "yes" / "no"

### Step 3.4: Survey 弹窗验证（如接入）

1. 触发 `BCFeedback.survey(...)` → 弹出 SurveyPopCenter
2. 选 Yes → completion 返回 `true`，无后续
3. 选 No → 若传了 `feedbackData`，弹 FeedbackPopUp 详情页；否则 completion 返回 `false`
4. FeedbackPopUp 中选具体原因 / 输入"其他"文字 → 完成后 completion 返回 `false`

---

## Phase 4: 输出

```
═══════════════════════════════════════════
  用户反馈集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}

代码产出：
  - Template/Feature/Feedback/Model/FeedbackSource.swift（{case 数} 个场景）
  - Template/Feature/Feedback/Extension/FeedbackSource+Ext.swift
  - Template/Feature/Feedback/Model/BCFeedbackData+Product.swift（{自定义 feedbackData 数} 个）
  - 业务页嵌入：{嵌入页面数} 个
  - Survey 弹窗入口：{触发点数} 个

埋点：
  - 事件名：feedback
  - type：click
  - parameters：resource + eparam1 + 业务特定字段

持久化：
  - FeedbackDataManager.shared（MLModelCache）
  - 用户同一 source 反复表态：保留最新一次

待确认（上线前）：
  - [ ] 所有 feedback_xxx 文案 key 已补 Localizable.strings（依赖 ae-i18n-integrate）
  - [ ] 神策后台 / Firebase 可见 feedback 事件
  - [ ] FeedbackSource 新加 case 后 Ext 三映射已全补
═══════════════════════════════════════════
```

---

## 硬性规则

1. **业务代码不直接 `BCTrack.track("feedback", ...)`** — 必须走 `FeedbackHelper.feedback(data:yes:)`。原因：直接 BCTrack 会漏持久化（FeedbackDataManager）+ 漏 Thanks UI 展示。
2. **FeedbackSource 每个 case 必须在 Ext 补完 3 个映射** — `source` / `parameters` / `feedbackData`。漏补 `feedbackData` 会在 survey+feedback 链路 runtime crash。
3. **非 Plant 类产品必须自定义 `BCFeedbackData` static var** — Pod 预定义的 `.identifyResult` / `.diagnoseResult` / `.plantFinder` 只适用 Plant 类。用错会让选项文案和业务场景不匹配。
4. **所有 feedback_xxx 文案 key 必须在 Localizable 中** — `BCFeedbackOption(key:)` 内部用 `Language.text(for: key)` 查表，key 缺失会显示裸 key 串。
5. **FeedbackView 嵌入位置 = 业务结果展示之后** — 不是按钮旁 / 页面顶部。典型模式：ScrollView 最底部"用这个结果有用吗？"。
6. **同一 source 不重复展示 Thanks View** — FeedbackHelper 每次调用都会 `FeedbackThanksView.show()`，业务侧如有防抖需求自行控制（或接受"快速多次点击 yes/no 时会弹多次 thanks"这一行为）。

---

## 反模式

❌ **业务代码 `BCTrack.track("feedback", parameters: [...])`（不过 FeedbackHelper）**
→ 数据会进埋点但不进 FeedbackDataManager，下次用户回来看不到"已反馈"状态；且没有 Thanks View 引导。用 `FeedbackHelper.feedback(data: yes:)`。

❌ **FeedbackSource 新加 case 但没补 Ext switch 分支**
→ Swift 编译器会报 "Switch must be exhaustive"，但如果用了 `@unknown default` 兜底会骗过编译器，runtime 取 `feedbackData` 就 crash。禁止 `@unknown default`。

❌ **用 `BCFeedbackData.identifyResult` 给非 Plant 产品**
→ 选项文案是"识别错了 / 照片不清 / 名字不对" — 对 Chat / Bible / Paint 等产品完全不对应。必须自定义。

❌ **feedback_xxx 文案 key 直接写英文字符串，不走 Localizable**
→ `BCFeedbackOption.init(key:)` 不做兜底，查不到 key 会显示裸 key（如屏幕上出现"feedback_chat_irrelevant"这种字面量）。多语言也失效。

❌ **FeedbackThanksView 在 App 后台 / TabBar 切换时展示**
→ `UIViewController.bc_top` 可能返回 nil 或错 VC，全局变量 `g_popView` 保不住，导致重复叠加或不可 dismiss。必须在前台 + 主 VC 上展示。

❌ **把 `BCFeedback.survey` 放在 Onboarding 中间**
→ 和 `ae-notification-integrate` 反模式第 4 条同理：用户还没感知价值就被 survey 打扰，拒答率高 + 产品印象差。应放在用户完成一次核心路径后触发（如付费成功、识别成功、生成成功）。

❌ **FeedbackDataManager 直接操作 `dataCache.data`**
→ 绕开 `append(data:)` 的去重逻辑（相同 source 旧记录要先移除再插入最新）。统一走 `append(data:)`。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `FeedbackView` 点击 yes/no 无反应 | (1) `FeedbackHelper.feedback` 报错被吞 (2) `FeedbackSource.parameters` runtime crash | (1) 打断点看是否进入 helper (2) 检查 Ext 是否所有 case 都补齐了 parameters |
| Thanks View 不展示 | (1) `UIViewController.bc_top` 返回 nil（App 后台）(2) `g_popView` 未清，重复 show 被忽略 | (1) 检查当前 App 状态 (2) 打印 `g_popView`，手动 nil 再 show |
| Thanks View 一直不消失 | `timer` 被 Timer 锁引用 / `closeHandler` 没正确 dismiss | 检查 `FeedbackThanksView.onDisappeared` 是否被调用 |
| 用户 yes/no 按钮状态不持久 | FeedbackDataManager `dataCache` 未正常写入 | 检查 `MLModelCacheManager` key 是否冲突；确认 `setDatas` 在 MainActor |
| 神策 / Firebase 看不到 feedback 事件 | (1) `ae-analytics-integrate` 未完成 (2) BCTrack 未 setup | 先确认 `BCTrack.setup()` 已在 AppDelegate 调用 |
| BCFeedback.survey 弹窗不显示 | Source view controller 无法确定（Pod 内部 bc_top 策略） | 触发时机避免放在 App 启动早期（启动动画未完 rootVC 为 splash） |
| Feedback 详情页选项文案是裸 key | Localizable 未定义对应 key | 补 `Localizable.strings` 或等 `ae-i18n-integrate` 介入 |

---

## 与其他 skill 的关系

```
/ae-preflight ───────────────────→ 编译通过
       │
       ▼
/ae-analytics-integrate ─────────→ BCTrack 就绪（feedback 埋点必需）
       │
       ▼
/ae-feedback-integrate ──────────→ BCFeedback + Template/Feature/Feedback（本 skill）
       │
       ├──> /ae-i18n-integrate ──→ feedback_xxx 文案 key 本地化
       │
       └──> /ae-abtest-integrate → 可对 survey 触发时机做 AB 测试
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| feedback-001 | `BCFeedback.feedback` 可嵌入 `BCFeedback.survey` 之后（选 No 自动弹详情）| Pods/BCFeedback/BCFeedback.swift:18-26 |
| feedback-002 | `FeedbackHelper.feedback` 三件事：持久化 + 埋点 + Thanks UI，缺一会让反馈不完整 | Template/Feature/Feedback/Helper/FeedbackHelper.swift |
| feedback-003 | `FeedbackDataManager` 同一 source 取最新一次（先 removeAll 再 insert at 0）| Template/.../FeedbackDataManager.swift:27 |
| feedback-004 | `BCFeedbackData` 预定义 3 个（identifyResult / diagnoseResult / plantFinder）全是 Plant 类产品，其他产品必须自定义 | Pods/BCFeedback/BCFeedback/Classes/Model/Models.swift:67-77 |
| feedback-005 | `BCFeedbackOption.init(key:)` 用 `Language.text(for: key)`，key 缺失显示裸 key | Pods/BCFeedback/BCFeedback/Classes/Model/Models.swift:37-39 |
| feedback-006 | `FeedbackThanksView` 3 秒自动消失（Timer.scheduledTimer(withTimeInterval: 3)）| Template/.../FeedbackThanksView.swift:44 |
| feedback-007 | `FeedbackThanksView` 全局单例 `g_popView`，同时展示多个会被覆盖 | Template/.../FeedbackThanksView.swift:63 |
| feedback-008 | `BCFeedback.survey` 可选链式调用 feedback（`feedbackData` 非 nil 且选 No）| Pods/BCFeedback/.../BCFeedback.swift:19-21 |

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 BCFeedback + Template/Feature/Feedback 组合。非 Scale Global 项目（无 BCFeedback Pod）不适用。Plant 类产品可直接复用预定义 `BCFeedbackData`，其他产品需自定义（参考 Step 2.4 模板）。
