# ae-verify-app

> 填补"demo 到成品之间没有自动化质量闭环"的 gap，让 PM 可以 E2E 对比两个 App 的功能差异并自动归因。

## 问题陈述

PM 用 demo-to-speckit 提取规格书，dev agent 据此生成成品项目。但"成品是否完整还原了 demo"这个问题没有自动化答案：

1. PM 手动逐功能对比 demo 和成品 -- 耗时且容易遗漏
2. 发现差异后不知道归因：是 speckit 提取遗漏？还是 dev agent 生成不足？还是约束文件缺失？
3. 验证结果无法量化，PM 说"差距大"但没有具体 coverage 数字
4. 差异描述模糊，dev 无法定位修复

没有这个 skill 之前，整条 demo -> speckit -> prod 流水线缺少质量闭环：做完了但不知道做得好不好，出了问题也不知道问题在哪个环节。

## 解决方案

从 speckit 自动提取测试用例，在 iOS 模拟器上逐 case 执行并截图对比，生成带归因的 diff report：

1. **提取测试用例** -- 从 speckit/02-user-scenarios.md 提取功能点，生成 verify-cases.yaml，每个 case 标注验证级别（structural / behavioral / functional）
2. **交互式 Vision-guided 验证** -- 对每个 case 执行截图 -> Vision 定位 -> AXe tap -> 再截图确认的循环，不使用硬编码坐标
3. **双 App 对比** -- 同一套 case 分别对 demo 和 prod 执行，逐 case 比较 status + Vision 看截图描述差异
4. **归因与建议** -- 对每个非 pass 的 case，根据 speckit 有无描述 + 约束有无定义，自动归因到具体环节

核心机制：
- **三级验证体系** -- structural（UI 元素存在）、behavioral（操作产生正确变更）、functional（业务逻辑正确），三维 coverage 分别计算
- **自动归因** -- 功能缺失 + speckit 有 = 生成问题；功能缺失 + speckit 无 = 提取问题；功能不同 + 约束无 = 约束缺失
- **下游衔接** -- diff report 直接供 /ae-file-bugs 消费，自动生成 issue 批量提交

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 三级验证体系 | structural / behavioral / functional | 不同级别的通过率含义不同：structural 100% 但 functional 0% 说明 UI 到位但逻辑没接 | 单一 pass/fail（无法区分问题层次） |
| Vision-guided 而非硬编码坐标 | 每次 tap 前截图 + Vision 定位 | 不同设备/模拟器的元素位置不同，硬编码坐标不可移植 | 固定坐标表（换设备就失效） |
| 从 speckit 提取 case 而非手写 | 自动提取 + 人工确认 | speckit 已经包含完整功能描述，手写会遗漏且与 speckit 不同步 | PM 手写测试用例 |
| diff report 用 JSON | 结构化输出 | 下游 /ae-file-bugs 需要程序化读取 case ID、归因前缀、截图路径 | Markdown 报告（下游无法程序化消费） |
| 约束合规预检 | Step 1.5 独立步骤 | WebView hybrid App 的 AXe 不可用，需提前标注所有 tap case 可靠性 degraded | 遇到问题再标注 |
| coverage 阈值分层 | demo >= 70% 工具可用，prod >= 80% 基本可接受，>= 90% 生产可用 | 不同阶段对质量的要求不同 | 统一阈值 |

## 已放弃方案

### 方案 A: 纯截图像素对比
- **是什么：** 用 SSIM/perceptual hash 比较 demo 和 prod 的截图像素差异
- **为什么放弃：** 像素差异无法归因。颜色差 1% 和功能完全缺失在像素对比中难以区分。且 layout 微调（如间距从 16 变 20）会被误报为差异

### 方案 B: 单一 pass/fail 不分级
- **是什么：** 所有测试用例只有通过/不通过两种状态
- **为什么放弃：** v0.5.0 引入三级验证体系。structural 100% + functional 0% 和 structural 50% + functional 50% 是完全不同的问题，前者说明 UI 到位但缺少后端逻辑，后者说明生成全面不足

### 方案 C: 手动归因
- **是什么：** PM 看 diff report 后自己判断问题出在哪个环节
- **为什么放弃：** PM 不了解 speckit 提取、代码生成、约束文件的内部逻辑。自动归因规则明确（speckit 有无描述 x 约束有无定义 = 4 种归因），PM 只需确认

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| Xcode CLI (xcodebuild) | Apple | iOS 编译和模拟器管理 | 无修改 |
| xcrun simctl | Apple | 模拟器截图 + App 安装 | 无修改 |
| AXe | cameroncooke/axe (Homebrew) | UI 元素交互（tap/swipe/describe-ui） | 无修改 |
| mobile-mcp | anthropics/mobile-mcp | Claude Code 调用模拟器的 MCP 桥接 | 无修改 |
| Claude Vision | Anthropic 内置 | 截图理解 + 元素定位 | 无修改，作为 Vision-guided 验证核心 |
| ocr-screenshot.py | 自研 | 无 | Apple Vision OCR 封装（AXe 不可用时的降级方案） |

## FAQ

**Q: 只有 demo 没有 prod 可以用吗？**
A: 可以。baseline 模式下只对 demo 运行测试用例，验证 verify 工具本身是否可用（coverage >= 70% 即工具可用）。

**Q: WebView hybrid App 能验证吗？**
A: 能，但可靠性降级。AXe describe-ui 在 WebView 中不可用，只能用坐标 tap + Vision 定位。Step 1.5 约束合规预检会自动检测并标注 degraded。

**Q: 验证完发现很多 diff 怎么办？**
A: 执行 `/ae-file-bugs`，自动从 diff report 生成 issue 草稿（含归因前缀和 case ID），PM 确认后批量提交到 Gitee。

**Q: Camera/AR 功能怎么验证？**
A: 模拟器无法测试，自动标记为 not_tested。这类功能需要真机手动验证。

**Q: functional 级别的 case 通过率为什么通常很低？**
A: functional 级别需要真实后端服务/AI 接口返回正确结果，不可 mock。demo 阶段通常使用 mock 数据，functional coverage 低是预期行为。

## 生命周期

- **填补的 gap：** demo -> speckit -> prod 流水线缺少自动化质量闭环
- **什么会让它过时：** 如果 dev agent 生成代码时自带单元测试和集成测试（即生成过程本身就保证质量），E2E 对比的价值会降低。但归因能力（问题出在提取还是生成）仍然有价值，因为这是跨环节的质量追溯

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.2.0 | 2026-03-26 | 首版。基础 E2E 对比 + 自动归因 + verify-cases.yaml 格式 + baseline coverage 72%（ShoeLens 25 case） |
| v0.5.0 | 2026-03-26 | 三级验证体系（structural / behavioral / functional） + 约束合规预检 + 三维 coverage 报告 |
| v0.8.0 | 2026-03-26 | 完成后自动引导 /ae-file-bugs，diff report -> issue 草稿 -> 批量提交 |
| v0.12.0 | 2026-03-31 | 验证完成后主动引导 /file-bugs（推送式引导而非等 PM 主动问） |
| v0.14.0 | 2026-04-01 | 重命名 verify-app -> ae-verify-app，改为 folder/SKILL.md 格式 |

## 文件清单

| 文件 | 用途 |
|------|------|
| `SKILL.md` | Agent 操作指南（Step 1-5 完整流程 + 三级验证标准 + 归因规则） |
| `scripts/ocr-screenshot.py` | Apple Vision OCR 封装（AXe 不可用时的降级方案） |
