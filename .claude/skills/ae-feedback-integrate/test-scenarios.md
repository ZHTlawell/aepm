# ae-feedback-integrate 用户场景验收清单

本清单由龙哥审计阶段逐条跑通。每个场景在真实 Scale Global 项目（优先 Loopcraft / WePray / Plant 类）上验证，通过后标记 ✅。

## 场景 1: 新产品首次接反馈（业务嵌入路径）

- **前置**：Podfile 已含 BCFeedback，Template/Feature/Feedback 4 通用文件已有，ae-analytics-integrate 已完成。PM 提供 2 个反馈场景（如 chatResponse + bibleStudy）+ 业务数据结构（ChatResponseSource / BibleStudySource）。
- **用户说**："在结果页加个 yes/no 反馈按钮，两个业务：聊天结果和圣经学习"
- **预期行为**：
  1. Phase 1 前置检查通过
  2. Phase 2 生成：FeedbackSource.swift（2 case）+ FeedbackSource+Ext.swift（2 case 完整映射）+ BCFeedbackData+Product.swift（2 个自定义 computed var）
  3. 在 ChatResponseView / BibleStudyResultView 嵌入 `FeedbackView(data: .xxx(source))`
  4. Phase 3 编译 + 模拟器验证
- **验收标准**：
  - [ ] FeedbackSource 每个 case 都在 Ext 补齐 source / parameters / feedbackData 三个映射
  - [ ] 新 enum case 不使用 `@unknown default`
  - [ ] 非 Plant 产品必须有自定义 `BCFeedbackData` computed var
  - [ ] 业务 View 用 `FeedbackView(data:)` 嵌入，不自己 Button + BCTrack
  - [ ] 编译 BUILD SUCCEEDED
- **状态**：⏳ 未测试

## 场景 2: 前置条件缺失（Podfile 无 BCFeedback）

- **前置**：项目 Podfile 没有 BCFeedback
- **用户说**："加反馈"
- **预期行为**：Phase 1 Step 1.1 grep 无匹配，Agent abort：
  > 本 skill 依赖 Scale Global 内部 BCFeedback，当前 Podfile 未引入。联系杭州加 pod（tag 示例：`BCFeedback 1.6.0`）后重试。
  > 非 Scale Global 项目不适用本 skill，需自研或用开源 survey 库。
- **验收标准**：
  - [ ] Agent 不继续 Phase 2
  - [ ] 给出 pod 引入路径 + 非 Scale Global 项目的 fallback 建议
- **状态**：⏳ 未测试

## 场景 3: Ext 漏补 feedbackData（反模式识别）

- **前置**：PM 在 FeedbackSource 加了新 case `.paywallSatisfaction`，Ext 补了 source + parameters，忘了 feedbackData
- **用户说**：审计代码 / "这个 switch 补齐了吗？"
- **预期行为**：Agent grep 比对 enum case 数 vs Ext 各 switch 的 case 数，发现 feedbackData switch 漏补：
  > ❌ Ext 的 `feedbackData` switch 漏了 `.paywallSatisfaction` case。
  > Swift 编译器会在 `var feedbackData: BCFeedbackData { switch self { ... } }` 处报 "Switch must be exhaustive"。
  > 修复：补一个分支，返回该场景对应的 BCFeedbackData（如果没有详情反馈需求，可以返回一个空 items 的 static var 或放弃 survey+feedback 链式调用）。
- **验收标准**：
  - [ ] Agent 发现漏补的具体 case
  - [ ] 禁止用 `@unknown default` 兜底
  - [ ] 给出修复模板（自定义 BCFeedbackData 或补空 default）
- **状态**：⏳ 未测试

## 场景 4: 非 Plant 产品误用 Plant 预定义（反模式识别）

- **前置**：WePray（Bible 类）的 Ext 里写 `return .identifyResult`
- **用户说**：审计 / "这个 feedbackData 对吗？"
- **预期行为**：Agent 识别产品类型（Bible / Chat / Paint / Bible）不是 Plant，指出：
  > ❌ `.identifyResult` 是 BCFeedback Pod 为 Plant 类产品预定义的反馈数据，subTexts 是"识别错了 / 照片不清 / 名字不对"。
  > 给 WePray（Bible 类）用户看到这些选项完全不对应业务场景。
  > ✅ 必须自定义：`BCFeedbackData.bibleStudy` + `[BCFeedbackItemData].bibleStudy`，选项文案贴合"经文解读"/"应用提示"等业务语境。
- **验收标准**：
  - [ ] Agent 按产品类型判断是否应复用 Plant 预定义
  - [ ] 给出自定义模板的代码框架
  - [ ] Plant 类产品（有 identify/diagnose/plantFinder 业务）可以直接用预定义
- **状态**：⏳ 未测试

## 场景 5: 业务代码直接调 BCTrack 跳过 FeedbackHelper（反模式识别）

- **前置**：业务代码：
  ```swift
  Button("Good") {
      BCTrack.track("feedback", parameters: [.KeyResource: "chat_response", .KeyEparam1: "yes"])
  }
  ```
- **用户说**：代码审计
- **预期行为**：Agent 识别反模式第 1 条：
  > ❌ 直接 `BCTrack.track("feedback", ...)` 跳过 FeedbackHelper，会导致：
  > 1. FeedbackDataManager 不持久化 → 下次打开同一结果页，yes/no 按钮状态丢失
  > 2. FeedbackThanksView 不展示 → 用户不知道反馈被收到
  > ✅ 修复：改为 `FeedbackHelper.feedback(data: .chatResponse(source), yes: true)`。
- **验收标准**：
  - [ ] Agent 定位到具体文件行号
  - [ ] 说明两个具体后果
  - [ ] 给出完整修复 diff
- **状态**：⏳ 未测试

## 场景 6: Localizable key 缺失（裸 key 显示）

- **前置**：自定义 `BCFeedbackData.chatResponse` 用了 `feedback_chat_irrelevant` key，但 Localizable.strings 未定义
- **用户说**：真机测试"打开 feedback 详情页，看到 'feedback_chat_irrelevant' 这种乱码"
- **预期行为**：Agent 定位到 `BCFeedbackOption(key:)` 的查表机制：
  > `BCFeedbackOption.init(key: String)` 内部调 `Language.text(for: key)`，该方法不做兜底，key 缺失会返回原 key 字符串。
  > 修复：补 `Localizable.strings`（或 `.xcstrings`）：
  > ```
  > "feedback_chat_irrelevant" = "Not relevant to my question";
  > ```
  > 完整多语言支持依赖 `ae-i18n-integrate`（下一个待做 skill）。
- **验收标准**：
  - [ ] Agent 直接定位 `Language.text(for: key)` 机制
  - [ ] 不误判为 BCFeedback Pod bug
  - [ ] 给出英文 + 至少一个其他语言的示例文案
- **状态**：⏳ 未测试

## 场景 7: Survey 弹窗 + 详情反馈链路

- **前置**：PM 想在 paywall 关闭后弹 NPS survey，选 No 后追问详情
- **用户说**："用户关闭 paywall 后弹 survey，选不满意的话问详情"
- **预期行为**：Agent 生成：
  ```swift
  Task {
      let isYes = await BCFeedback.survey(
          source: "paywall_close",
          data: .default,
          feedbackData: .paywallSatisfaction,  // 选 No 会自动弹详情
          parameters: ["paywall_id": "onboarding", "plan_shown": "yearly"]
      )
      // isYes 可选打额外埋点
  }
  ```
  同时在 FeedbackSource 和 Ext 补齐 `.paywallSatisfaction` case + 自定义 `BCFeedbackData.paywallSatisfaction`（options 含"价格太贵"/"功能不够"/"已有类似产品"等）
- **验收标准**：
  - [ ] 触发时机放在关键路径末尾（paywall 关闭后），不放 Onboarding 中间
  - [ ] feedbackData 参数传了自定义 `BCFeedbackData`，不是 nil
  - [ ] survey 选 No 后自动弹详情页不需额外代码
- **状态**：⏳ 未测试

## 场景 8: FeedbackThanksView 层级异常（故障排查）

- **前置**：Tab 切换过程中快速点 yes，结果 Thanks View 出现在了其他 Tab 上
- **用户说**：真机复现 / 报 bug
- **预期行为**：Agent 定位到 `UIViewController.bc_top` + `g_popView` 全局：
  > 1. `UIViewController.bc_top` 返回当前最顶层 VC，Tab 切换时返回的是目标 Tab 的根 VC，而非触发 feedback 的页面。
  > 2. `g_popView` 是全局单例，并发 show 会被覆盖。
  > 修复：业务层防抖 —— 点击 yes/no 后立即禁用按钮（如 `.disabled(true)`），或用 throttle 保证 3 秒内同一 source 只响应一次。
- **验收标准**：
  - [ ] Agent 能分析并发 show 的问题
  - [ ] 给出业务层防抖的具体方案（disabled / throttle / 状态锁）
  - [ ] 不修改 BCFeedback Pod 源码，只改业务层
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-8 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确阻塞原因和修复 PR
- 龙哥审计通过，确认：
  - 技术路线（BCFeedback + Template 薄封装）正确
  - 非 Plant 产品自定义 BCFeedbackData 模板是否合理
  - 通用 4 文件 copy 模式是否 OK（还是应该做成 Template Pod）

## 已解决阻塞项（杭州 Martinlehb 审计 2026-04-23，IJD7GE #note_49775397）

- [x] **P0-8 BCFeedbackTemplate Pod 可行但需单独设计**：能力可行，现有组件不直接覆盖，**需单独出方案**。SKILL.md 标注"按需接入、设计先行"，本 skill 当前保持 `Template/Feature/Feedback/` 4 通用文件 copy 模式。
- [x] **P0-9 BCFeedbackData 完全可定制**：展示内容数据可定制，**各项目按需配置文案、选项、结构**。硬性规则 3 已改写为"Pod 预定义只是 Plant 样例，各项目按业务自定义"。
- [x] **P0-10 解析失败不崩溃**：字段缺失或类型不匹配时整个数据对象返回 **nil**，调用方按 optional 处理。硬性规则 4 已声明"nil 兜底"。
- [x] **P0-11 survey 不在启动早期**：调用链由**用户行为驱动**，不纳入启动流程。硬性规则 5 已声明。
