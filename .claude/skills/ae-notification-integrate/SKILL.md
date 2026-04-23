---
description: "iOS 本地通知全流程 — BCUserNotification + BCPermission 封装下的调度、权限、点击追踪（Scale Global 生态）"
last_updated: "2026-04-23"
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

# Skill: 本地通知全流程 (ae-notification-integrate)

> **经 WePray (bible-app) 实战验证。** 基于 Scale Global 内部 `BCUserNotification` + `BCPermission` 生态，产出本地通知 schedule 封装 + 权限请求 + 点击追踪 pattern。
>
> **本 skill 只覆盖本地通知**（`UNUserNotificationCenter` local scheduling）。远程推送（APNs + 服务端推送）目前 Scale Global 生态无封装，不在本 skill 范围，未来由独立 skill `ae-remote-push-integrate` 处理。

## 核心原则

> **你是通知工程师。** 基于 PM 提供的提醒场景（daily reminder / trial cancel reminder / care reminder 等），产出：
> ① 业务层 `NotificationService` 薄封装；② Identifier 前缀约定 + 点击 dispatch；③ 权限请求时机；④ 触发埋点。
>
> **关键约束：**
> 1. 通知调度必须通过 `BCUserNotificationManager`，不直接 `UNUserNotificationCenter.current().add`
> 2. 权限请求必须通过 `BCPermission.requestNotificationPermission`，不直接 `center.requestAuthorization`
> 3. 权限请求时机 = **用户主动点 toggle 时弹**，禁止在 Onboarding 强制弹（影响审核 + 拒授率飙升）

## 触发条件

- PM 说"加一个每日提醒"、"接通知"、"试用到期前提醒"
- preflight 报告标记"无 NotificationService / BCPermission 未使用"
- Demo 即将上 TestFlight，需要日活/召回通道

## 角色分工

| 事项 | 谁做 |
|------|------|
| Apple 推送证书（仅远程推送需要）| **本 skill 不涉及**（本地通知不需要证书）|
| Podfile 含 BCUserNotification + BCPermission | **杭州团队（触发本 skill 前完成）** |
| 提醒场景定义（什么时机触发 / 文案 / 频次）| PM |
| identifier 前缀域命名 | PM + Agent（参考 WePray 约定）|
| 业务层 NotificationService 封装 | Agent |
| AppDelegate 点击 dispatch | Agent |
| 设置页 toggle UI（用户开关）| Agent |
| 真机权限授予 + 定时触发验证 | PM |

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 |
| ae-analytics-integrate 已完成 | `BCTrack.track()` 可用（点击事件要打 BCTrack）|
| Podfile 含 BCUserNotification + BCPermission | `grep 'pod "BCUserNotification\|pod "BCPermission"' Podfile` 有匹配 |
| Info.plist 有 NSUserNotificationsUsageDescription（iOS 15+ 无需，但 iOS 12 向下兼容建议有）| plutil 查看 |
| AppDelegate 已设 `UNUserNotificationCenter.current().delegate = self` | grep |

前置未就绪 → **停在这里**，向 PM 说明缺项，不继续。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "WePray" |
| 提醒场景清单 | 是 | 如：每日提醒 8:00 / 试用到期前 24h / 关怀提醒每 3 天 |
| identifier 前缀域 | 是 | 如 `daily_verse_reminder` / `vip_cancel_reminder_` / `care_reminder_` |
| 文案 | 是 | title + body（如需多语言依赖 ae-i18n-integrate）|
| 权限请求入口 | 是 | 设置页 toggle / Onboarding 某页 / 功能首次使用时 |

---

## Phase 1: 前置检查

### Step 1.1: Podfile

```bash
grep -E 'pod "(BCUserNotification|BCPermission)"' Podfile
```

**预期：** 两行都存在（通常 tag 固定）。缺失 → 联系杭州加 pod，本 skill 暂停。

### Step 1.2: AppImports 已 re-export

```bash
grep -n "BCUserNotification\|BCPermission" Locals/AppImports/AppImports/Classes/AppImports.swift
```

**预期：** 有 `@_exported import BCUserNotification` + `@_exported import BCPermission`（或在业务代码里按需 `import BCUserNotification`）。

### Step 1.3: AppDelegate UNUserNotificationCenterDelegate

```bash
grep -nE "UNUserNotificationCenterDelegate|UNUserNotificationCenter.current\(\).delegate" Template/App/AppDelegate.swift
```

**预期：** AppDelegate 已实现 `UNUserNotificationCenterDelegate` 且在 `configNotification()` 里设 `delegate = self`。缺失 → 按 Step 3.2 模板补齐。

### Step 1.4: 向 PM 确认场景 + 前缀域

口头问 PM：

> 1. 要几个提醒场景？每个场景什么时机触发（UNCalendar 定时 / UNTimeInterval 相对时间 / 业务事件触发）？
> 2. 每个场景的 identifier 前缀域命名（如 `daily_verse_reminder` / `vip_cancel_reminder_`，后面可附时间戳/用户 ID）
> 3. 权限请求入口：用户主动 toggle？Onboarding 某页？功能首次使用时？

**回答完整才进入 Phase 2。**

---

## Phase 2: 代码生成

### Step 2.1: 业务层 NotificationService.swift

路径：`<Project>/Classes/Services/NotificationService.swift`

```swift
import Foundation
import BCUserNotification
import BCPermission
import UserNotifications

private let kReminderEnabled = "notif_<scene>_enabled"   // 按场景替换
private let kReminderIdPrefix = "<scene>_reminder"       // 按 PM 确认的前缀域

@MainActor
public class NotificationService: ObservableObject {
    public static let shared = NotificationService()

    @Published public private(set) var isEnabled: Bool

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: kReminderEnabled)
        if isEnabled {
            Task { await self.syncWithSystem() }
        }
    }

    /// 开启提醒：请求权限 → schedule
    /// 返回 true 表示已成功 schedule，false 表示权限被拒或 schedule 失败
    public func enableReminders() async -> Bool {
        let granted = await BCPermission.requestNotificationPermission(force: false)
        if !granted {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: kReminderEnabled)
            return false
        }
        await schedule()
        isEnabled = true
        UserDefaults.standard.set(true, forKey: kReminderEnabled)
        return true
    }

    /// 关闭提醒：移除 schedule（不撤销系统权限）
    public func disableReminders() {
        BCUserNotificationManager.shared.removePendingNotificationRequests(
            withIdentifiers: [kReminderIdPrefix]
        )
        isEnabled = false
        UserDefaults.standard.set(false, forKey: kReminderEnabled)
    }

    /// App 冷启动后同步：若用户在系统设置关了通知权限，本地 flag 也要同步
    private func syncWithSystem() async {
        let settings = await BCUserNotificationPermission.shared.getSettings()
        if settings.authorizationStatus != .authorized {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: kReminderEnabled)
        }
    }

    /// 实际 schedule 逻辑（按场景改）
    private func schedule() async {
        // 去重：先清掉同前缀域的待发通知
        await BCUserNotificationManager.shared.removeNotificationRequestGroups([kReminderIdPrefix])

        let content = UNMutableNotificationContent()
        content.title = "<PM 提供的标题>"
        content.body = "<PM 提供的正文>"
        content.sound = .default

        // 示例：每日 8:00
        var comps = DateComponents()
        comps.hour = 8
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let identifier = "\(kReminderIdPrefix)_\(<业务后缀，如日期/userId>)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        await BCUserNotificationManager.shared.addNotification(request)
    }
}
```

**多场景时** 每个场景一个 `NotificationService` 子类或 `static func scheduleXxx()`（不要把多场景塞同一个类，identifier 前缀要区分）。

### Step 2.2: AppDelegate 点击 dispatch + delegate 注册

路径：`Template/App/AppDelegate.swift`

```swift
// 在 didFinishLaunchingWithOptions 里调
private func configNotification() {
    UNUserNotificationCenter.current().delegate = self
    UIApplication.shared.applicationIconBadgeNumber = 0
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// 远程推送 deviceToken → BCAdjust（本地通知不触发此回调，保留为后续 ae-remote-push-integrate 铺垫）
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        BCAdjust.appDidRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    /// App 前台时收到通知的展示方式
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .badge])
    }

    /// 点击通知时的 dispatch：**按前缀域打 BCTrack 埋点**
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier

        if identifier.hasPrefix("vip_cancel_reminder_") {
            BCTrack.track("notification_trailvipreminder", type: .click)
        } else if identifier.hasPrefix("daily_verse_reminder") {
            BCTrack.track("notification_daily_reminder", type: .click)
        } else if identifier.hasPrefix("care_reminder_") {
            BCTrack.track("notification_carereminder", type: .click)
        }
        // 新增场景 → 添加 else if 分支，不要依赖 default

        completionHandler()
    }
}
```

### Step 2.3: 设置页 toggle UI

路径：`Locals/AppSettings/.../SettingsViewModel.swift` 或业务页

```swift
import BCPermission

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isReminderEnabled = false

    func toggleReminder(_ newValue: Bool) {
        Task {
            if newValue {
                let ok = await NotificationService.shared.enableReminders()
                isReminderEnabled = ok
                if !ok {
                    // 用户拒绝授权 → 引导去系统设置
                    // BCPermission.openSystemSettings() 或自行跳 UIApplication.openSettingsURLString
                }
            } else {
                NotificationService.shared.disableReminders()
                isReminderEnabled = false
            }
        }
    }
}
```

**toggle 的关键行为：**
- 用户**主动**点开关 → 才请求权限（`BCPermission.requestNotificationPermission(force: false)`）
- 已授权 → 直接 schedule
- 已拒绝 → 返回 false，引导用户去系统设置自行开启（不重复弹系统弹窗，iOS 会静默忽略重复请求）

### Step 2.4: 业务触发点 schedule

在具体业务事件发生时 schedule 通知。例：试用期激活后 schedule 到期前 24h 提醒：

```swift
extension NotificationService {
    /// 试用期激活 → schedule 到期前 24h 通知
    public func scheduleTrialCancelReminder(expireDate: Date) async {
        let reminderDate = expireDate.addingTimeInterval(-24 * 3600)
        guard reminderDate > Date() else { return }

        let granted = await BCPermission.requestNotificationPermission(force: false)
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Trial ending soon"
        content.body = "Cancel anytime before \(expireDate.formatted()) to avoid charge."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "vip_cancel_reminder_\(Int(expireDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        await BCUserNotificationManager.shared.addNotification(request)
    }

    /// 订阅成功 / 取消订阅 → 撤销所有试用提醒
    public func cancelTrialReminders() async {
        await BCUserNotificationManager.shared.removeNotificationRequestGroups(["vip_cancel_reminder_"])
    }
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

### Step 3.2: 真机权限授予测试

1. 首次安装，打开设置页点 toggle → 系统弹授权弹窗 → 选允许 → toggle 保持开
2. 关闭 App，去系统设置关掉本 App 通知权限 → 打开 App → toggle 自动变关（`syncWithSystem()` 生效）
3. Toggle 再次点开 → 因系统拒绝，`requestAuthorization` 静默 return false → 提示用户去系统设置

### Step 3.3: 定时触发验证

1. Schedule 每日 8:00 提醒（或为了测试改为 1 分钟后）
2. 退出 App 到后台
3. 等待触发时刻 → 系统显示通知
4. 点击通知 → App 启动 → Xcode Console 应打出 `BCTrack.track("notification_xxxreminder")` 日志
5. 进神策后台/Firebase DebugView 确认事件到达

### Step 3.4: Group remove 验证

1. Schedule 多个 `vip_cancel_reminder_<timestamp>` 通知（模拟多次试用）
2. 调用 `cancelTrialReminders()` → `removeNotificationRequestGroups(["vip_cancel_reminder_"])`
3. `UNUserNotificationCenter.current().getPendingNotificationRequests()` 确认前缀匹配的全部清除，其他前缀保留

---

## Phase 4: 输出

```
═══════════════════════════════════════════
  本地通知集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}

代码产出：
  - NotificationService.swift（{行数} 行，{场景数} 个场景）
  - AppDelegate extension（点击 dispatch + {前缀域数} 个前缀域）
  - SettingsViewModel toggle（{toggle 数} 个开关）

场景配置：
  - daily_verse_reminder：每日 08:00 循环
  - vip_cancel_reminder_：试用到期前 24h
  - care_reminder_：按需

权限请求入口：
  - 设置页 toggle（首次点击弹权限）
  - 禁止在 Onboarding 强制弹

真机验证：
  - [x] 权限授予流程（首次 / 系统设置关闭 / 重新开启）
  - [x] 定时触发
  - [x] 点击打 BCTrack 埋点
  - [x] Group remove

待确认（上线前）：
  - [ ] Info.plist 通知描述文案（iOS 12 兼容）
  - [ ] 所有文案多语言化（依赖 ae-i18n-integrate）
  - [ ] ASC 截图不展示待授权通知弹窗（审核 Guideline 2.5.1）
═══════════════════════════════════════════
```

---

## 硬性规则

1. **schedule 必须通过 `BCUserNotificationManager`** — 业务代码不直接 `UNUserNotificationCenter.current().add(_:)`。**Add 去重语义（杭州审计 P0-5）**：`addNotification` 内部先检查系统是否已注册对应的推送服务，存在则跳过添加，**可放心多次调用**不会重复注册。
2. **权限请求必须通过 `BCPermission.requestNotificationPermission`** — 不直接 `center.requestAuthorization`。**`force` 参数语义（杭州审计 P0-6，作用于"用户首次拒绝后再次申请"场景）**：`force: true` → 跳转系统 Settings 页面让用户直接打开权限开关；`force: false` → 不跳转仅静默处理。新项目**统一使用 `BCUserNotificationPermission`**（P0-4 确认，原 `NotificationService.swift` 是历史遗留代码）。
3. **Identifier 必须有前缀域 + 业务后缀** — 如 `vip_cancel_reminder_<timestamp>`、`daily_verse_reminder_<userId>`。前缀域用于点击 dispatch + Group remove，不能用 UUID 或无前缀。
4. **点击 dispatch 必须在 AppDelegate `didReceive` 里按前缀打 BCTrack** — 新增场景 → 在 extension 加 `else if` 分支，不依赖 `default` 兜底。
5. **权限请求时机 = 用户主动触发（toggle / 功能首次使用）** — 禁止在 Onboarding 强制弹。Apple 审核 Guideline 4.5.4 + iOS 投放转化率反指标（拒授率 > 50%）。
6. **本 skill 不激活远程推送 + 无 deep link 路由**（杭州审计 P0-7）— 当前阶段 Scale Global 生态**不支持通知落地 deep link**，作为未来扩展点注明，不在本 skill 范围内实现。AppDelegate 已有的 `didRegisterForRemoteNotificationsWithDeviceToken → BCAdjust` 回调保留（为后续 `ae-remote-push-integrate` 铺垫）。

---

## 反模式

❌ **业务代码直接 `UNUserNotificationCenter.current().add(request)`**
→ 绕开 BCUserNotificationManager 的去重逻辑。用 `BCUserNotificationManager.shared.addNotification(_:)`（已内置"已注册跳过"保护，可放心多次调用）。

❌ **业务代码直接 `center.requestAuthorization(options: [.alert, .badge, .sound])`**
→ 绕开 BCPermission 的统一埋点和 force 策略。用 `BCPermission.requestNotificationPermission(force: false)` 替代。

❌ **Identifier 用 UUID 或无前缀**（如 `UUID().uuidString`）
→ 无法按组清理（订阅取消后想清所有试用提醒就清不了）+ AppDelegate dispatch 无法识别点击来源打不了埋点。必须 `{前缀域}_{业务后缀}`。

❌ **Onboarding 某页强制弹通知权限**
→ 用户还没理解产品就要求通知权限，拒授率 > 50%（行业基准）。iOS 权限被拒后再请求会被系统静默忽略（仅能引导去系统设置），等于永久损失通道。应在设置页 toggle 或功能首次使用时（用户已感知价值）再请求。

❌ **Schedule 前不先 removePending 同前缀域**
→ 同 identifier 不同内容会按 BCUserNotification 的 dedup 被忽略（保留旧的）；不同 identifier 堆积会变成"多个同场景通知全部触发"。schedule 前先 `removeNotificationRequestGroups([前缀])`。

❌ **App 冷启动不同步系统权限状态**
→ 用户在系统设置关了通知权限，App 里 UserDefault 的 `isEnabled` 仍为 true，toggle 显示开但实际不触发。必须在 `init` 里 `syncWithSystem()` 反向同步。

❌ **点击 dispatch 漏埋点** / 把埋点放在 willPresent（前台展示时）
→ 点击事件（click）和展示事件（impression）语义不同。埋点必须在 `didReceive`（用户点击）里，不是 `willPresent`（前台弹出）。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| 通知不触发 | (1) 权限未授权 (2) 真机 Do Not Disturb / Focus Mode 过滤 (3) `UNCalendarNotificationTrigger` 时间已过 (4) repeats=false 且已触发过一次 | (1) 设置 → 本 App → 通知权限 (2) 关 Focus Mode (3) 用 future 时间 (4) repeats=true 或新 identifier |
| `Product.products(for:)` 等价问题：`getPendingNotificationRequests` 返回空 | schedule 时 `await` 被忽略 / BCUserNotificationManager.addNotification 内部 try? 吞异常 | 加 log 打印 addNotification 前后 pending 数；BCUserNotification 源码（1.0.2）`await try? center.add(data)` 会吞错 |
| 点击不打埋点 | (1) identifier 前缀不匹配 dispatch 分支 (2) AppDelegate 没注册 `UNUserNotificationCenterDelegate` | (1) 打印 identifier 确认 prefix (2) `configNotification()` 必须调且在 didFinishLaunching 之前 |
| Badge 不清零 | `applicationIconBadgeNumber = 0` 未调 | `preAppLaunch` 或 `configNotification()` 里必须清零 |
| Toggle 状态和系统权限不同步 | `syncWithSystem()` 未在 `init` 或 `viewWillAppear` 触发 | 冷启动时 `Task { await self.syncWithSystem() }` |
| 同场景多个通知堆积 | schedule 前没 `removeNotificationRequestGroups([前缀])` | schedule 模板第一步必须是 group remove |
| 首次 toggle 弹权限后拒绝，第二次点击 toggle 没反应 | iOS 对拒绝后的 `requestAuthorization` 静默忽略（系统行为，非 bug） | 检测 `requestAuthorization` return false 时，引导 `UIApplication.openSettingsURLString` |

---

## 与其他 skill 的关系

```
/ae-preflight ───────────────────→ 编译通过
       │
       ▼
/ae-analytics-integrate ─────────→ BCTrack / BCSensor 就绪（点击埋点必需）
       │
       ▼
/ae-notification-integrate ──────→ BCUserNotification + BCPermission（本 skill）
       │
       ├──> /ae-i18n-integrate ──→ 多语言文案（通知 content 本地化）
       │
       ├──> /ae-paywall-integrate → 试用到期前提醒（schedule trial cancel reminder）
       │
       └──> /ae-remote-push-integrate（未来）──→ APNs + 服务端推送（补齐远程推送）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| notif-001 | BCUserNotification 1.0.2 `addNotification` 有 identifier dedup，多次 add 同 id 会自动跳过 | Pods/BCUserNotification 源码审计 |
| notif-002 | BCUserNotification 1.0.2 `await try? center.add(data)` 吞 error，失败需外部加 log | 同上，第 42 行 |
| notif-003 | BCPermission 1.1.0 `requestNotificationPermission(force:)` 对已拒绝用户静默 return false | Pods/BCPermission/Notification/BCUserNotificationPermission.swift |
| notif-004 | iOS 对已拒绝用户的 `requestAuthorization` 静默忽略，仅系统设置可重新授权 | Apple UserNotifications 文档 |
| notif-005 | `UNUserNotificationCenterDelegate.didReceive` 是点击回调，`willPresent` 是前台展示回调，不要混用打埋点 | WePray AppDelegate 已区分 |
| notif-006 | Identifier 前缀约定 `{domain}_reminder_{suffix}`（WePray 示例：vip_cancel_reminder_ / daily_verse_reminder / care_reminder_）| WePray AppDelegate dispatch |
| notif-007 | Onboarding 强制弹通知权限拒授率 > 50%，Apple 审核 Guideline 4.5.4 风险 | iOS 投放常识 |
| notif-008 | WePray `NotificationService.swift` 当前直接用 `UNUserNotificationCenter.current()`，未迁移到 `BCUserNotificationManager` | WePray 代码审计（待龙哥确认是否迁移）|

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 BCUserNotification + BCPermission 生态做本地通知。非 Scale Global 项目（无内部库）不适用，需用原生 UN*API。远程推送不在本 skill 范围，等 `ae-remote-push-integrate`（未来 B 类 skill）。
