---
description: "iOS AB 测试全流程 — BCABTest + 神策 SensorsABTesting + ABTestType 枚举 + Work Chain preload（Scale Global 生态）"
permissions:
  allow:
    - "Bash(xcodebuild *)"
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

# Skill: AB 测试全流程 (ae-abtest-integrate)

> **经 bible-ios-template + plant-app 实战验证。** 基于神策 `SensorsABTesting` + Scale Global `BCSensor/BCABTest` 封装 + 项目 `ABTestType` 枚举四层架构，产出实验定义、默认值兜底、preload 策略、业务读取 pattern。

## 核心原则

> **你是 AB 测试工程师。** 基于 PM 提供的实验需求（付费墙方案 A/B / Welcome 变体 / 功能开关），产出：① `ABTestType` 枚举 case + key 命名（`{productId}_{biz}_{version}`）；② 默认值兜底（BCABTestResult 四类型）；③ preload 决策（同步读 vs 异步读）；④ `BCABTest.shared.syncFetchXxx` 业务调用 pattern。
>
> **关键约束：**
> 1. **每个 ABTestType 必须有 defaultValue** — 实验配置拉取失败（首次冷启 / 网络错 / 服务端问题）时走默认值保证功能能跑
> 2. **同步读（`syncFetchType`）必须先 preload** — 否则取到默认值而非真实配置
> 3. **key 命名 `{productId}_{biz}_{version}`** — 产品间隔离 + 版本演进支持
> 4. **神策后台配置 + 代码默认值要严格对齐** — 缺失的话实验"生效了但没人知道"

## 触发条件

- PM 说"做个 paywall 的 A/B"、"welcome 页换一版"、"加个开关先小流量"
- 新产品需要 AB 测试基础设施（Welcome AB 变体 / Paywall AB 方案）
- preflight 报告标记"ABTestType 未定义"
- ae-speckit-to-app TS-025 约束要求实现

## 角色分工

| 事项 | 谁做 |
|------|------|
| 神策后台实验创建 + key 配置 | **PM + 数据团队**（需神策权限）|
| Podfile 含 BCSensor（含 BCABTest）+ SensorsABTesting | **杭州团队（触发本 skill 前完成）** |
| 实验需求（目标 / 变体 / 分流） | PM |
| ABTestType enum case 定义 | Agent |
| 默认值（safe default）选择 | PM + Agent（PM 定业务兜底，Agent 写代码）|
| preload 决策（sync vs async） | Agent（根据使用时机判断）|
| 业务调用点集成 | Agent |
| 实验数据分析 | PM + 数据团队（神策后台看结果）|

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 |
| ae-analytics-integrate 已完成 | BCSensor / BCTrack 已 setup（BCABTest 是 BCSensor 的子模块）|
| Podfile 含 BCSensor + SensorsABTesting | `grep -E 'pod "(BCSensor\|SensorsABTesting)"' Podfile` |
| AppDelegate 已调 `BCABTest.shared.setup()` | `grep "BCABTest.shared.setup" Template/App/AppDelegate.swift` |
| Work Chain 含 ABTestLoadWork 步骤 | `find Template/Core/StartupSequence -name "ABTestLoadWork.swift"` |
| `Template/Core/AppConfig/ABTest/ABTestConfig.swift` 存在 | 从 bible-ios-template / plant-app copy 或本 skill 生成 |
| BCConfig `productId` 已配置非空 | ABTestType.key 依赖 `CT().BCConfig_GetDataReceiverProductId()` 生成带前缀的 key |

前置未就绪 → **停在这里**。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "WePray" |
| Product ID | 是 | BCConfig 中的 dataReceiverProductId（key 前缀）|
| 实验清单 | 是 | 每个实验：业务名 + 变体 + 默认值 + 是否同步读 |
| 神策后台 key（PM 提前配置）| 是 | 格式 `{productId}_{biz}_{version}` |

---

## Phase 1: 前置检查

### Step 1.1: Podfile + BCSensor 含 BCABTest

```bash
grep -E 'pod "(BCSensor|SensorsABTesting)"' Podfile
find Pods/BCSensor -name "BCABTest.swift" 2>/dev/null
```

**预期：** BCSensor 有匹配 + `Pods/BCSensor/BCSensor/Classes/ABTest/BCABTest.swift` 存在。SensorsABTesting 可能通过 BCSensor 依赖引入（不需要显式声明）。

### Step 1.2: AppDelegate setup

```bash
grep "BCABTest.shared.setup\|BCABTest.shared.config" Template/App/AppDelegate.swift
```

**预期：** `configSensor` 或 `preAppLaunch` 里有调用（WePray 当前在 `configSensor(_:)` 方法末尾）。

### Step 1.3: Work Chain ABTestLoadWork

```bash
cat Template/Core/StartupSequence/ABTestLoadWork.swift
grep "ABTestLoadWork" Template/App/AppDelegate.swift
```

**预期：** `ABTestLoadWork()` 在 `startupSequence` 数组中（通常第 5 步，ComponentConfig → Adjust → Debug → Legal → **ABTest** → UserInit → ...）。

### Step 1.4: ABTestConfig 存在性

```bash
ls Template/Core/AppConfig/ABTest/
```

**预期：** 至少 `ABTestConfig.swift`（含 ABTestType enum）+ `Model/ABTestModel.swift`（Paywall JSON 解析）+ `Model/BCABTestResult+Ext.swift`。缺失 → Phase 2 从 bible-ios-template / plant-app copy 并改产品特定字段。

### Step 1.5: 向 PM 确认实验需求

口头问 PM：

> 1. 列出实验：业务名 + 变体（如 paywall_v1 vs paywall_v2）+ 分流（如 50/50）
> 2. 每个实验的 **safe default**（配置失败时的 fallback 行为）
> 3. 同步读还是异步读？
>    - 同步：启动时必须立刻知道（如 Welcome / Paywall 变体），要 preload
>    - 异步：用户进入某功能时再拉（如后加的 feature flag）
> 4. 神策后台 key 已创建？key 格式 `{productId}_{biz}_{version}`

**回答完整才进入 Phase 2。**

---

## Phase 2: ABTestType 枚举定义

### Step 2.1: ABTestConfig.swift 基础结构

路径：`Template/Core/AppConfig/ABTest/ABTestConfig.swift`

```swift
import AppImports

public enum ABTestType: CaseIterable {
    // ⚠️ 每个 case = 一个实验。按业务命名，不要和神策 key 混淆
    case vip                          // Paywall 方案
    case welcome                      // Welcome Pod 变体（TS-027 动态加载）
    case launchvipShowtimesPerday     // 首启 Paywall 每日频次
    case resultSurvey                 // 结果页 Survey 开关
    // ... 按 PM 需求追加

    /// 神策后台 key：{productId}_{biz}_{version}
    public var key: String {
        let biz: String
        switch self {
        case .vip:                       biz = "vippage"
        case .welcome:                   biz = "welcome"
        case .launchvipShowtimesPerday:  biz = "launchvip_showtimes_perday"
        case .resultSurvey:              biz = "resultsurvey"
        }

        let version = 1  // 业务改配置时递增（旧 key 继续生效，新 key 单独管）
        if let productId = CT().BCConfig_GetDataReceiverProductId()?.lowercased() {
            return "\(productId)_\(biz)_\(version)"
        }
        return biz  // productId 未配置时降级（本地开发 / 调试）
    }

    /// 默认值（配置失败或未拉到时使用）
    public var defaultValue: BCABTestResult {
        switch self {
        case .vip:
            return .json(value: ABTestModel.defaultVip.json)
        case .welcome:
            return .string(value: "01")  // 默认 Welcome_01 Pod
        case .launchvipShowtimesPerday:
            return .int(value: 1)
        case .resultSurvey:
            return .bool(value: true)
        }
    }

    /// 是否启动时预加载（同步读必须 preload）
    var shouldPreload: Bool {
        switch self {
        case .launchvipShowtimesPerday: return true   // ConversionPageWork 启动后读
        case .welcome:                  return true   // WelcomeWork 启动时读
        case .vip:                      return true   // PurchaseUI 首次展示读
        default:                        return false  // 业务页进入时再读
        }
    }

    public static var preloadTypes: [ABTestType] {
        ABTestType.allCases.filter { $0.shouldPreload }
    }

    public var requestData: BCABTestRequestData {
        .init(key: self.key, defaultValue: defaultValue.anyValue)
    }
}
```

### Step 2.2: BCABTest+ABTestType 扩展（业务便捷 API）

路径：`Template/Core/AppConfig/ABTest/BCABTest+ABTestType.swift`（或合并到 ABTestConfig.swift 底部）

```swift
public extension BCABTest {
    /// 批量 preload
    func preload(types: [ABTestType], force: Bool) async {
        let datas = types.map { $0.requestData }
        await self.preload(datas: datas, force: force)
    }

    /// 异步读（首次读会拉服务端，后续从缓存）
    func fetchType(_ type: ABTestType, force: Bool = false) async -> BCABTestResult? {
        await self.fetch(type.requestData, force: force)
    }

    /// 同步读（必须先 preload，否则取默认值）
    func syncFetchType<T>(_ type: ABTestType, defaultValue: T) -> T {
        self.value(for: type.key, defaultValue: defaultValue)
    }

    /// Paywall 专用：读 JSON 配置
    func syncFetchVip() -> ABTestModel {
        let defaultValue: BCJson = ABTestModel.defaultVip.json
        let value = self.syncFetchType(.vip, defaultValue: defaultValue)
        return .init(json: value) ?? .defaultVip
    }

    /// Welcome 专用：读变体 string
    func syncFetchWecome() -> String {
        let defaultValue: String = ABTestType.welcome.defaultValue.stringValue ?? "01"
        return self.syncFetchType(.welcome, defaultValue: defaultValue)
    }

    /// Codable 结构体 JSON 读
    func syncFetchModel<T: Codable>(_ type: ABTestType, defaultValue: T) -> T {
        let json = defaultValue.json ?? [:]
        let value = self.syncFetchType(type, defaultValue: json)
        guard let jsonString = value.bc_jsonString() else {
            return defaultValue
        }
        return .init(jsonString: jsonString) ?? defaultValue
    }
}
```

### Step 2.3: Model（按需）

对于 JSON 类型实验（如 Paywall 方案），定义对应 Codable struct：

```swift
// Template/Core/AppConfig/ABTest/Model/ABTestModel.swift
public struct ABTestModel: Codable {
    public let value: String
    // ... 其他字段

    public static var defaultVip: ABTestModel {
        .init(value: "19")  // 默认 Paywall 方案 id
    }

    public var json: BCJson {
        return self.bc_json() ?? [:]
    }
}
```

---

## Phase 3: Work Chain 集成

### Step 3.1: ABTestLoadWork（应已存在）

路径：`Template/Core/StartupSequence/ABTestLoadWork.swift`

```swift
import AppImports

class ABTestLoadWork: WorkVoidCallbackTask {
    func work(_ callback: @escaping VoidCallback) {
        Task {
            await BCABTest.shared.preload(types: ABTestType.preloadTypes, force: true)
            await MainActor.run {
                callback()
            }
        }
    }
}
```

**⚠️ `force: true` 强制刷新**，保证首次冷启后每次启动都拉最新配置。网络错会静默失败走缓存/默认值。

### Step 3.2: startupSequence 位置约束

`AppDelegate.swift` 的 `startupSequence` 必须：

```swift
private lazy var startupSequence: [WorkVoidCallbackTask] = {
    [
        ComponentConfigWork(),   // 1. 先跑（BCConfig 初始化，providers productId）
        AdjustConfigWork(),      // 2.
        DebugToolsConfigWork(),  // 3.
        LegalPromptWork(),       // 4.
        ABTestLoadWork(),        // 5. ⚠️ 必须在需要读 AB 的 Work 之前
        UserInitWork(),          // 6.（如需要根据 AB 决定是否登录某种账号）
        AppUpgradeWork(),        // 7.
        AfterLoginWork(),        // 8.
        DataPreloadWork(),       // 9.
        WelcomeWork(),           // 10. 读 ABTestType.welcome
        ConversionPageWork(),    // 11. 读 ABTestType.launchvipShowtimesPerday + .vip
        MainPageLoadWork(),      // 12.
    ]
}()
```

**先 ABTestLoad，后 WelcomeWork / ConversionPageWork**，否则同步读拿默认值。

---

## Phase 4: 业务调用

### Step 4.1: 同步读示例（Welcome 变体动态加载）

```swift
class WelcomeWork: WorkVoidCallbackTask {
    func work(_ callback: @escaping VoidCallback) {
        let memo = BCABTest.shared.syncFetchWecome()  // "01" 或 "02"
        // 动态加载 Welcome_{memo} Pod 的 class（TS-027 机制）
        let className = "Welcome_\(memo).WelcomeViewController"
        // ... 用 NSClassFromString + perform 加载
    }
}
```

### Step 4.2: 异步读示例（功能开关）

```swift
// 非启动路径，用户进入某功能时再读
func enterFeature() async {
    let isEnabled: Bool = await {
        guard let result = await BCABTest.shared.fetchType(.featureFlagX) else {
            return ABTestType.featureFlagX.defaultValue.boolValue ?? false
        }
        return result.boolValue ?? false
    }()

    if isEnabled {
        // 新版本 flow
    } else {
        // 旧版本 flow
    }
}
```

### Step 4.3: Paywall JSON 读示例

```swift
// PurchaseUI.swift
class PurchaseUI {
    func presentPaywall() {
        let data = BCABTest.shared.syncFetchVip()  // ABTestModel
        let paywallId = data.value  // "19"
        let viewController = PurchaseUIBase(paywallId: paywallId)
        // ... present
    }
}
```

---

## Phase 5: 神策后台配置协同

### Step 5.1: PM 在神策后台创建实验

前置要求（PM 操作）：
1. 登录神策（参考 `reference_sensors_analytics.md`）
2. 到"A/B Testing"模块
3. 创建实验，key 用 `{productId}_{biz}_{version}`（如 `bible_vippage_1`）
4. 配置变体（如 control / variant_a）+ 分流（如 50/50）
5. 值类型：int / bool / string / json（和代码中 `BCABTestResult` 严格对齐）
6. 对齐 **metrics**（转化率 / 留存 / 付费），用于实验分析

### Step 5.2: 代码 default vs 神策 default 对齐

**如果神策实验未生效（冷启未拉、网络错、实验未 launch），代码走 `defaultValue`。** 两边必须一致：

| ABTestType | 代码 defaultValue | 神策后台默认值（control 组）| 对齐要求 |
|-----------|------------------|--------------------------|---------|
| `.vip` | `.json(ABTestModel.defaultVip.json)` | control 组的 JSON（同结构）| JSON 结构一致 |
| `.welcome` | `.string("01")` | control 组返回 "01" | string 值一致 |
| `.launchvipShowtimesPerday` | `.int(1)` | control 组返回 1 | int 值一致 |

**不一致会怎样：** 实验未 launch 时 UI 行为和实验 launch 的 control 组不同，AB 对照失真。

### Step 5.3: 版本演进

改实验配置（加新变体、改默认）时：
- 旧 key（如 `bible_vippage_1`）保持不动（有用户在试验中）
- 新 key 版本递增（`bible_vippage_2`）
- `ABTestType` 里修改 `version` 常量（但旧实验结果要等窗口期结束再下线）

---

## Phase 6: 集成验证

### Step 6.1: 编译通过

```bash
xcodebuild build -workspace <Name>.xcworkspace -scheme <Scheme> \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15
```

### Step 6.2: 启动顺序验证

Xcode Console 打日志：

```swift
// ABTestLoadWork.swift 加调试
print("🔬 [ABTest] preload start, types=\(ABTestType.preloadTypes.map { $0.key })")
await BCABTest.shared.preload(types: ABTestType.preloadTypes, force: true)
print("🔬 [ABTest] preload done")

// WelcomeWork 前加
print("🔬 [ABTest] syncFetchWecome=\(BCABTest.shared.syncFetchWecome())")
```

**预期日志顺序：**
```
🔬 [ABTest] preload start, types=["bible_welcome_1", "bible_vippage_1", "bible_launchvip_showtimes_perday_1"]
🔬 [ABTest] preload done
🔬 [ABTest] syncFetchWecome=01  (或 02，视神策分流结果)
```

**如果顺序错乱**（WelcomeWork 在 preload done 之前跑）→ 检查 `startupSequence` 数组顺序。

### Step 6.3: 神策后台验证

1. 在神策后台把当前设备 ID 加入白名单（强制进入特定变体）
2. 重启 App
3. Console 看 `syncFetchWecome` 返回的 variant 是否和白名单一致

---

## Phase 7: 输出

```
═══════════════════════════════════════════
  AB 测试集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}
Product ID：{product_id}

实验清单：{N} 个
  - vip: JSON / preload / 默认 {defaultVip.value}
  - welcome: String / preload / 默认 "01"
  - launchvipShowtimesPerday: Int / preload / 默认 1
  - resultSurvey: Bool / 异步 / 默认 true

神策后台 key 格式：{productId}_{biz}_{version}

Work Chain 位置：第 5 步 ABTestLoadWork
  ⚠️ WelcomeWork (第 10) + ConversionPageWork (第 11) 依赖 preload

待 PM 处理：
  - [ ] 神策后台所有 key 已创建
  - [ ] 每个实验的 control 组默认值和代码 defaultValue 对齐
  - [ ] 分流配置（如 50/50 / 分批放量）
  - [ ] 实验 metrics 设置（转化/留存/付费）
  - [ ] 白名单设备验证变体可切换
═══════════════════════════════════════════
```

---

## 硬性规则

1. **每个 ABTestType 必须有 defaultValue** — 冷启 / 断网 / 神策未 launch 时走默认值保证功能能跑。不能只 case 无默认。
2. **同步读 = 必须 preload** — `syncFetchType` 从缓存读，没 preload 就取默认值。启动路径读的 type 必须 `shouldPreload = true`。
3. **key 命名 `{productId}_{biz}_{version}`** — 多产品隔离 + 版本演进。不带前缀会和其他产品 key 冲突。
4. **代码 defaultValue 和神策 control 组默认值必须严格一致** — 实验未 launch 时的行为等于 control 组行为。不一致 = 无法 AB 对照。
5. **ABTestLoadWork 在 startupSequence 中必须早于所有依赖 AB 的 Work** — WelcomeWork / ConversionPageWork / PurchaseUI 之前。
6. **版本演进加版本号不改旧 key** — 旧 `{biz}_1` 保持不动（还有用户在旧实验），新变体用 `{biz}_2`。
7. **BCABTestResult 类型要和神策后台值类型严格对齐** — int / bool / string / json 四种，代码和神策同步。

---

## 反模式

❌ **`ABTestType.xxx` 没有 defaultValue 就上线**
→ 神策服务端挂了 / 断网 / 实验未 launch，功能走到 crash 或空状态。每个 case 必须有默认值。

❌ **同步读没 preload**
→ `syncFetchType(.xxx, defaultValue: ...)` 永远返回默认值，实验形同虚设。`shouldPreload = true` + ABTestLoadWork 保证 preload。

❌ **key 不带 productId 前缀（跨产品 key 冲突）**
→ Plant 的 `vippage_1` 和 Bible 的 `vippage_1` 会互相干扰。必须 `{productId}_{biz}_{version}`。

❌ **代码 defaultValue 和神策 control 组不一致**
→ 实验 vs 非实验行为漂移，BI 无法判断是"实验生效了"还是"默认行为变了"。

❌ **ABTestLoadWork 放在 UserInit 之后**
→ UserInit 如依赖 AB 结果（如"AB 决定新用户走哪套 onboarding"），会用默认值而非实际变体。

❌ **`BCABTestResult` 类型错配**
→ 神策后台配成 string，代码 defaultValue 写成 `.int`，`syncFetchType<Int>` 拿到 string 强转崩溃。两边类型必须对齐。

❌ **实验 key 版本递增但 `ABTestType.key` 没改 version**
→ 神策后台新建了 v2 实验，代码还在读 v1 key，新实验永远拿不到。

❌ **在单次会话中多次 `force: true` preload**
→ preload 本来是启动一次的，多次强制刷新会让变体在同一会话中切换，用户体验崩（半路切 paywall 方案）。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| 实验始终返回默认值 | (1) `shouldPreload = false` 但用了 syncFetch (2) Work Chain 顺序错 (3) 神策 key 不匹配 | (1) 改 true + 加 preloadTypes (2) 检查 startupSequence (3) 对齐 key 格式 |
| 不同设备变体分流不均 | 神策分流未配 / 白名单误触发 | 神策后台检查分流配置，removing 白名单 |
| App 启动卡顿变长 | preload 同步等服务端 | 检查 Work Chain `callback()` 是否在 preload 完成后 call；必要时 preload 改非阻塞（但 sync 读会失真）|
| `BCConfig_GetDataReceiverProductId()` 为 nil | BCConfig 初始化在 ABTestLoadWork 之后 | ComponentConfigWork（第 1 步）必须在 ABTestLoadWork（第 5 步）之前，确认顺序 |
| JSON 类型 defaultValue 反序列化失败 | `ABTestModel.defaultVip.json` 返回空或结构不对 | `ABTestModel` 定义 `defaultVip` 时必须是可序列化的完整对象 |
| 神策后台看得到实验数据但代码走默认值 | key 版本不一致（神策 v2，代码 v1） | 同步 `ABTestType.key` 里的 version |
| 白名单设备重启后仍走默认组 | BCSensor 没识别白名单 ID / 未 launch | 确认 `BCSensor.shared.config` 已调 + 神策后台实验状态是"进行中"|

---

## 与其他 skill 的关系

```
/ae-analytics-integrate ─────────→ BCSensor + BCTrack（AB 是 BCSensor 的子模块）
       │
       ▼
/ae-abtest-integrate ────────────→ BCABTest + ABTestType（本 skill）
       │
       ├──> /ae-onboarding-integrate → Welcome_XX AB 变体（syncFetchWecome）
       │
       ├──> /ae-paywall-integrate ──→ Paywall JSON 方案 AB（syncFetchVip）
       │
       └──> /ae-feedback-integrate ─→ Survey 开关（resultSurvey / diagnoseSurvey）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| abtest-001 | `BCABTest` 定义在 `Pods/BCSensor/BCSensor/Classes/ABTest/BCABTest.swift`，是 BCSensor Pod 的子模块（非独立 Pod）| Pod 结构审计 |
| abtest-002 | 底层 SDK 是神策 `SensorsABTesting`（`SABManager`），Scale Global 在 BCSensor 里做 Swift 封装 | Pods/SensorsABTesting |
| abtest-003 | `BCABTestResult` 支持 int / bool / string / json 四种类型，和神策后台值类型严格对齐 | ABTestConfig.swift 的 `defaultValue` switch |
| abtest-004 | key 约定 `{productId}_{biz}_{version}`，productId 从 `CT().BCConfig_GetDataReceiverProductId()` 读，version 手动管 | ABTestConfig.swift:52-57 |
| abtest-005 | productId 为 nil 时 key 降级为 `{biz}` 无前缀（本地开发场景），生产不应发生 | ABTestConfig.swift:56 |
| abtest-006 | `shouldPreload = true` 的 type 在 Work Chain `ABTestLoadWork` 第 5 步预加载，同步读必须 preload | Template/Core/StartupSequence/ABTestLoadWork.swift |
| abtest-007 | `ABTestLoadWork` 用 `force: true` 每次启动都刷新配置（不只靠缓存）| 同上 |
| abtest-008 | `syncFetchVip` / `syncFetchWecome` 是 WePray/Plant 场景化封装，其他业务用 `syncFetchType<T>(_:defaultValue:)` 通用版 | ABTestConfig.swift:131-150 |
| abtest-009 | `syncFetchModel<T: Codable>` 支持任意 Codable 结构体反序列化（JSON 类实验的便捷 API）| 同上 |
| abtest-010 | Work Chain 启动顺序约束：`ABTestLoadWork` (5) < `UserInit` (6) < `Welcome` (10) < `ConversionPage` (11)，违反会用默认值而非实际变体 | AppDelegate startupSequence |

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 BCABTest + 神策生态做 AB 测试。非 Scale Global 项目无此封装，需直接用 SensorsABTesting 或其他 AB 平台（Firebase Remote Config / LaunchDarkly）。Welcome / Paywall 变体是 TS-027 / TS-024 硬约束要求的标配实验。
