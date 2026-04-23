# ae-abtest-integrate

> Scale Global 旗下 iOS 产品的 **AB 测试**全流程技能 —— 基于神策 `SensorsABTesting` + 内部 `BCSensor/BCABTest` + 项目 `ABTestType` 枚举四层架构，沉淀 bible-ios-template + plant-app 实战代码。

## 问题陈述

0.1 产品上 TestFlight 后要做付费墙方案 A/B、Welcome 变体、功能灰度，AB 测试是核心迭代工具。但 Scale Global 生态下有几个非直觉约束：

1. **BCABTest 不是独立 Pod，是 BCSensor 子模块**：
   - 很多人以为会有 `pod "BCABTest"`，实际定义在 `Pods/BCSensor/BCSensor/Classes/ABTest/BCABTest.swift`
   - 这意味着 `ae-analytics-integrate` 接完 BCSensor 后 BCABTest 自动可用，不需要额外 Pod
   - AI 容易搜 BCABTest 找不到就去自研或装其他库

2. **key 命名必须 `{productId}_{biz}_{version}`**：
   - Plant 的 `vippage_1` 和 Bible 的 `vippage_1` 如果不加产品前缀会跨产品污染
   - Version 是业务演进的手动游标（实验迭代不改旧 key）
   - AI 很容易漏掉 productId 前缀 or version 后缀

3. **同步读 vs 异步读的硬性区分**：
   - `syncFetchType<T>(_:defaultValue:)` 从缓存读 → 必须先 `preload`
   - `fetchType(_:) async -> BCABTestResult?` 会去服务端拉 → 首次读无需 preload
   - Welcome / Paywall 等启动路径都是同步读，必须 preload；业务内功能开关可以异步
   - AI 不分场景全用 syncFetch 会导致实验数据"永远是默认值"

4. **Work Chain 启动顺序约束**：
   - `ABTestLoadWork`（第 5 步）必须早于 `WelcomeWork`（第 10）+ `ConversionPageWork`（第 11）+ 任何读 AB 的 UserInit 逻辑
   - `ComponentConfigWork`（第 1 步）必须早于 ABTestLoadWork（否则 BCConfig productId 为 nil，key 无前缀）
   - 顺序错乱不会编译报错，runtime 拿默认值

5. **代码 defaultValue 必须和神策 control 组默认值对齐**：
   - 实验未 launch（或冷启未拉到）时走代码 default
   - 实验 launch 后的 control 组也应该返回同样的值（作为 A/B 对照的 A 组）
   - 不对齐 = 实验无意义（分不清是实验生效还是默认行为变了）

6. **BCABTestResult 枚举四类型严格对齐神策**：
   - int / bool / string / json 四种
   - 神策后台配成 string，代码写成 `.int`，强转崩溃
   - JSON 类型需要额外 Codable 定义（`ABTestModel`）

7. **`{biz}` 命名不能和其他产品冲突**：
   - 神策后台是跨产品账号共享的（productId 只是 key 前缀，不是后台隔离）
   - 通用业务名（如 `welcome`、`paywall`）必须配合 productId 才不冲突

这些约束散在 `Template/Core/StartupSequence/ABTestLoadWork.swift` + `Template/Core/AppConfig/ABTest/ABTestConfig.swift` + `Pods/BCSensor/.../BCABTest.swift` 多处，AI 新接产品时靠官方 SensorsABTesting 文档猜一定踩。

## 解决方案

这个 skill 把实战代码 + 神策生态约定沉淀成标准流程：

- **ABTestType 枚举四件套模板**：`case` / `key` / `defaultValue` / `shouldPreload`
- **Work Chain 位置约束**：明确要求 ABTestLoadWork 的 index 约束（第 5 步）
- **preload / syncFetch / async fetch 的决策矩阵**：按使用时机选 API
- **神策后台 vs 代码的对齐检查表**：每个实验 type / default / version 双边校验
- **7 条硬性规则 + 8 条反模式 + 7 条故障排查 + 10 条已验证约束**

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 技术栈 | BCSensor/BCABTest（Scale Global 封装）+ SensorsABTesting（底层）| 生态统一 + 和 BCTrack 埋点联动 + 神策后台 BI 一体 | Firebase Remote Config：脱离神策埋点生态 / LaunchDarkly：付费成本 |
| key 命名 | `{productId}_{biz}_{version}` | 跨产品隔离 + 版本演进 | 无前缀：跨产品污染 |
| 默认值 | 代码硬写 `defaultValue` + 神策 control 组对齐 | 冷启/断网兜底 | 只靠神策：网络错功能崩 |
| 启动读策略 | 核心路径（Welcome / Paywall）preload + sync，业务点 async fetch | 启动路径要确定性，业务点容忍延迟 | 全 async：启动路径不确定延迟 |
| 版本演进 | 改 version 常量，旧 key 自然下线 | 保护在跑实验的用户 | 改 key 名：老用户分组失效 |

## 已放弃方案

### 方案 A: Firebase Remote Config
- **是什么**：用 Google Firebase 的 Remote Config 做实验配置
- **为什么放弃**：(1) BCSensor 已经走神策生态，付费数据 / 埋点聚合都在神策后台；换 Firebase 会让 AB 实验结果和付费转化数据对不上 (2) Firebase Remote Config 在国内可用性差

### 方案 B: 全异步读（不做 preload）
- **是什么**：所有 AB 实验都走 `async fetch`，首次启动慢一点但简单
- **为什么放弃**：启动路径的 Welcome 选择 / Paywall 方案必须立刻知道，不能等网络。等 fetch 会让启动体验变差（白屏 500ms+），且服务端不稳定时启动流程不确定。

### 方案 C: key 不带 productId 前缀
- **是什么**：神策 key 直接 `vippage_1`，简化配置
- **为什么放弃**：Plant 和 Bible 都有 `vippage` 业务场景，共用后台会冲突。除非专门为每个产品开神策项目（成本太高）。

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| SensorsABTesting | 神策数据开源 | 100% — 底层 SDK + 后台对接 | 通过 BCSensor 包装 |
| BCSensor / BCABTest | Scale Global 内部 GitLab | 70% — Swift 封装 + 缓存 + preload API | 业务层 `ABTestType` enum 模式 + key 命名约定 + Work Chain 位置 |
| ABTestModel | 项目级 Codable | 100% — JSON 实验解析 | Paywall 配置的具体结构 |

## FAQ

**Q: 我们不用神策，想用 Firebase Remote Config 可以吗？**
A: 技术上可以（BCABTest 换成 FirebaseRemoteConfig），但会让 AB 实验结果和神策付费埋点聚合不上（无法跨系统 join）。不推荐。

**Q: `shouldPreload = true` 的 type 太多会让启动变慢吗？**
A: `BCABTest.shared.preload` 批量请求，通常 1 次 HTTP 拉所有 preload keys。体积小（JSON 配置），延迟通常 < 200ms。但如果 preload 的 type 超过 20+，建议拆分按模块分批。

**Q: 实验结束后 key 怎么处理？**
A: 三步：(1) 神策后台把实验状态改为"已结束"，默认返回 winning 变体值 (2) 代码中 `defaultValue` 改为 winning 变体值（保持 AB 未 launch 时行为一致）(3) 几个版本后（确认没残留用户在老版本）删除 `ABTestType` case 或改用单一值。

**Q: 怎么确保新加的实验不影响已有的？**
A: 每个 ABTestType case 独立，神策后台每个 key 独立分流。新加 case 不会影响已有 case 的 preload / syncFetch 逻辑。但 **Work Chain 顺序**和 **BCConfig productId** 是全局依赖，改这些要小心。

**Q: 白名单设备怎么配？**
A: 神策后台 → A/B Testing → 实验详情 → 白名单 → 加设备 ID（SDK 读 `CT().BCSensor_GetDistinctId()` 或 IDFV）。白名单强制进指定变体，忽略分流规则。用于开发/QA 验证不同变体。

**Q: 实验 metric 怎么和 AB 对齐？**
A: 神策后台创建实验时要定义 primary metric（如"7 日付费率"）和 secondary metrics（如"留存"/"DAU"）。BCTrack 打的埋点事件（如 `purchase_success` / `login`）会和实验变体自动 join 分析。不需要额外代码。

## 生命周期

- **填补的 gap**：Scale Global 旗下 iOS 项目接 AB 测试的 AI 自动化能力。ABTestType 枚举定义 + key 命名 + Work Chain 位置是反复要写的机械活，应沉淀成模板。
- **什么会让它过时**：
  - Scale Global 换 AB 平台（如神策 → Optimizely）→ 重写
  - BCABTest API 升级（如引入 typed API 替代 string key）→ 模板更新
  - 多实验互相依赖（如"实验 A 的 variant 决定实验 B 的分流"）需求出现 → 需要 dependency 建模

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0（草稿） | 2026-04-23 | 初版草稿，基于 bible-ios-template + plant-app 审计 |

## 文件清单

| 文件 | 用途 |
|------|------|
| SKILL.md | Agent 操作指南 |
| README.md | 人类设计文档（本文件）|
| test-scenarios.md | 用户场景验收清单 |
