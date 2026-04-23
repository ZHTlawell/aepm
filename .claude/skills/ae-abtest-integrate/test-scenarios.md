# ae-abtest-integrate 用户场景验收清单

## 场景 1: 新产品首次接 AB 测试（典型路径）

- **前置**：ae-analytics-integrate 已完成（BCSensor setup OK），Podfile 含 BCSensor，PM 提供 3 个实验需求（Paywall 方案 A/B、Welcome 变体、功能开关）+ 神策后台已创建对应 key
- **用户说**："加 3 个 AB 实验：paywall 方案、welcome 变体、新功能开关"
- **预期行为**：
  1. Phase 1 前置检查通过
  2. Phase 2 生成 / 更新 `ABTestConfig.swift`：3 个 case + key + defaultValue + shouldPreload + BCABTest extension
  3. Phase 3 `ABTestLoadWork` 在 startupSequence 第 5 位置
  4. Phase 4 业务层 `syncFetchVip()` / `syncFetchWecome()` / async `fetchType(.featureFlagX)` 调用点接入
  5. Phase 5 和 PM 确认神策后台 key 格式 + control 组默认值对齐
  6. Phase 6 启动日志验证 preload 顺序 + 白名单设备验证变体切换
- **验收标准**：
  - [ ] 所有 ABTestType case 都有 defaultValue（无 case 漏）
  - [ ] 所有 shouldPreload=true 的 case 在 preloadTypes 里
  - [ ] key 格式 `{productId}_{biz}_{version}` 严格符合
  - [ ] ABTestLoadWork 在 WelcomeWork / ConversionPageWork 之前
  - [ ] 编译 BUILD SUCCEEDED
- **状态**：⏳ 未测试

## 场景 2: 前置条件缺失（BCSensor 未接）

- **前置**：项目 Podfile 没 BCSensor（未完成 ae-analytics-integrate）
- **用户说**："加 paywall AB 测试"
- **预期行为**：Phase 1 Step 1.1 grep 无 BCSensor，Agent abort：
  > 本 skill 依赖 BCSensor（含 BCABTest 子模块）。请先完成 `/ae-analytics-integrate`。
  > BCABTest **不是独立 Pod**，是 BCSensor Pod 的一部分（`Pods/BCSensor/BCSensor/Classes/ABTest/BCABTest.swift`）。
- **验收标准**：
  - [ ] Agent 不直接加 `pod "BCABTest"`（错误认知）
  - [ ] 正确指向先做 ae-analytics-integrate
  - [ ] 说明 BCABTest 是 BCSensor 子模块的事实
- **状态**：⏳ 未测试

## 场景 3: 启动顺序错乱（反模式识别）

- **前置**：PM 手动调整了 startupSequence，把 ABTestLoadWork 放到了 WelcomeWork 之后
- **用户说**：真机测试发现 Welcome 永远显示变体 "01"（默认值）
- **预期行为**：Agent 读 AppDelegate.swift startupSequence，识别顺序错乱：
  > 当前顺序：
  > 1. ComponentConfig / 2. Adjust / 3. Debug / 4. Legal / 5. UserInit / 6. AppUpgrade / 7. **Welcome** / 8. **ABTestLoad** / ...
  >
  > ❌ WelcomeWork 第 7 位读 `syncFetchWecome()` 时，ABTestLoad（第 8 位）还没 preload，value 走默认值 "01"。
  > ✅ 修复：ABTestLoad 必须放到第 5 位（Legal 后，UserInit 前），确保所有读 AB 的 Work 之前已 preload。
- **验收标准**：
  - [ ] Agent 能看懂 startupSequence 数组顺序
  - [ ] 识别 Welcome / ConversionPage / UserInit 对 AB 的依赖
  - [ ] 给出正确的顺序（ABTestLoad 在依赖方之前）
- **状态**：⏳ 未测试

## 场景 4: syncFetch 没 preload（反模式识别）

- **前置**：PM 新加 feature flag `.featureFlagX`，`shouldPreload = false`（默认），业务代码用 `BCABTest.shared.syncFetchType(.featureFlagX, defaultValue: false)`
- **用户说**："这个开关打开了但客户端没生效"
- **预期行为**：Agent 识别矛盾：
  > ❌ `.featureFlagX` 在 `shouldPreload` switch 里返回 false，没加入 preloadTypes。
  > `syncFetchType` 从本地缓存读，没预加载 = 永远取默认值（false）。
  > 
  > 修复选 1：`shouldPreload = true`（启动时预加载，延长启动 0~200ms）
  > 修复选 2：业务代码改用 `await BCABTest.shared.fetchType(.featureFlagX)` 异步读（第一次进入 feature 时拉，延迟几秒）
- **验收标准**：
  - [ ] Agent 给出两种修复方案 + tradeoff
  - [ ] 说明 sync vs async 的使用时机
  - [ ] 不误导用户"没 preload 也能 sync 读"
- **状态**：⏳ 未测试

## 场景 5: key 版本冲突（反模式识别）

- **前置**：PM 改 Paywall 方案（加新变体 `paywall_v3`），在 ABTestConfig 里把 `vippage` case 的 version 从 1 改成 2，但神策后台没创建 `bible_vippage_2` key
- **用户说**：改完上线后 Paywall 全部走默认（没实验效果）
- **预期行为**：Agent 识别是 key 不一致：
  > 代码生成的 key：`bible_vippage_2`
  > 神策后台 key：`bible_vippage_1`（旧）
  > 结果：神策找不到匹配 key，返回"实验未 launch"，代码走 defaultValue。
  > 
  > 修复：
  > - 选 A：让 PM 在神策后台创建 `bible_vippage_2` 新实验（配 variant 和分流）
  > - 选 B：代码回滚 version = 1，等神策后台新 key 准备好再改
- **验收标准**：
  - [ ] Agent 能排查 key 版本对齐
  - [ ] 说明正确的版本演进流程（先后台创建，再代码切换）
  - [ ] 不推荐代码先改 version 等用户再补后台
- **状态**：⏳ 未测试

## 场景 6: defaultValue 和神策 control 组不一致（反模式识别）

- **前置**：代码 `.vip` 的 defaultValue 是 `ABTestModel.defaultVip.json`（value = "19"），神策后台 control 组 JSON 是 `{"value": "20"}`
- **用户说**："实验数据看起来不对，control 组和没开实验的用户行为完全不一样"
- **预期行为**：Agent 识别两边默认值不对齐：
  > 代码 defaultValue（未 launch / 冷启未拉到时使用）：value = "19"
  > 神策 control 组值（实验 launch 后 control 分组用户使用）：value = "20"
  > 
  > 结果：
  > - 实验未 launch 的用户：显示方案 19
  > - 实验 launch 后 control 组用户：显示方案 20
  > - BI 对比 control vs variant，实际在对比方案 20 vs 方案 20-alt，而不是"实验前 vs 实验后"
  > 
  > 修复：PM 在神策后台把 control 组默认值改成 "19"（和代码一致），或代码 defaultValue 改成 "20"（和神策一致）。以 PM 业务决策为准。
- **验收标准**：
  - [ ] Agent 能精确定位两边 default 值
  - [ ] 解释不一致的业务影响（AB 对照失真）
  - [ ] 让 PM 做最终决策（不擅自改哪边）
- **状态**：⏳ 未测试

## 场景 7: JSON 实验的 Codable 反序列化失败

- **前置**：代码加了新 JSON 实验 `.onboardingFlow`，PM 在神策后台配了 JSON `{"steps": 5, "skipButton": true}`，但代码 `OnboardingFlowModel` 只有 `steps: Int`（忘了加 `skipButton`）
- **用户说**：实验启动了但 skipButton 一直没显示
- **预期行为**：Agent 排查：
  1. 先打印 `BCABTest.shared.syncFetchType(.onboardingFlow, defaultValue: ...)` 拿到的 raw 值 — 确认从神策拉到了
  2. 检查 `OnboardingFlowModel` 的 Codable 字段是否完整覆盖 JSON 结构
  3. `syncFetchModel<T: Codable>` 的行为：反序列化失败会返回 `defaultValue`，不报错
  4. 修复：补全 `OnboardingFlowModel` 字段
- **验收标准**：
  - [ ] Agent 不直接猜是后端问题
  - [ ] 先打日志看 raw 值，再排查反序列化
  - [ ] 说明 `syncFetchModel` 反序列化失败会静默走 default
- **状态**：⏳ 未测试

## 场景 8: BCConfig productId 为 nil（环境错误）

- **前置**：在测试环境（stage）跑，BCConfig 的 dataReceiverProductId 配置漏了，`CT().BCConfig_GetDataReceiverProductId()` 返回 nil
- **用户说**：测试环境实验永远不生效
- **预期行为**：Agent 识别 key 降级：
  > `ABTestConfig.swift:56` 的 fallback：如果 productId 为 nil，key 从 `{productId}_{biz}_{version}` 降级为 `{biz}` 无前缀。
  > 神策后台创建的是 `bible_vippage_1`，代码生成的是 `vippage`，不匹配。
  > 
  > 修复：
  > 1. 检查 `Locals/BCConfig/BCConfig/BCConfig.swift` 的 dataReceiverProductId 字段
  > 2. 确保 stage 环境配置了 productId（BCConfig env 切换机制）
  > 3. ComponentConfigWork 是否在 ABTestLoadWork 之前执行（否则读到 nil）
- **验收标准**：
  - [ ] Agent 识别降级行为
  - [ ] 指向 BCConfig 配置问题，不是 AB 平台问题
  - [ ] 检查 Work Chain 启动顺序（ComponentConfig 必须在 ABTestLoad 之前）
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-8 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确阻塞原因和修复 PR
- 龙哥审计通过：
  - 4 层架构（SensorsABTesting → BCSensor/BCABTest → ABTestType → Work Chain）正确
  - key 命名 `{productId}_{biz}_{version}` 是否是 Scale Global 统一标准
  - defaultValue 和神策 control 组对齐策略合理
  - Work Chain 顺序约束（ABTestLoadWork 第 5 步）是否硬编码 OK，还是应该给更灵活的约束

## 已知阻塞项（等龙哥审计）

- [ ] `ABTestType` 枚举的通用性 —— 每个产品都要定义自己的枚举，AE Team 是否应该提供基类 / 通用工具
- [ ] 神策白名单设备的 ID 格式（IDFV / distinctId / 其他）+ PM 怎么获取
- [ ] 实验结束后的代码清理流程（case 删除 / defaultValue 切 winning / 影响其他 case index 问题）
- [ ] 多实验依赖（如 experiment B 的变体取决于 experiment A 的结果）的建模方式
- [ ] Work Chain preload 在弱网 / 断网时的 timeout 策略（当前 `force: true` 可能长时间卡住）
