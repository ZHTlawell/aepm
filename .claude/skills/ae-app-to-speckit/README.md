# ae-app-to-speckit

> 填补"没有源码时无法提取 speckit"的 gap，让 PM 可以从任意已上架 App 逆向生成结构化规格书。

## 问题陈述

PM 在复刻竞品或参考已上架 App 时，面临一个核心矛盾：demo-to-speckit 需要源码才能提取 speckit，但第三方 App 没有源码。

没有这个 skill 之前，PM 只能：
1. 手动截图 + 写文档描述功能（耗时数小时，且容易遗漏）
2. 凭记忆口述给 dev，导致还原度低
3. 从 App Store 页面获取有限信息，无法覆盖深层功能

痛点在于：App 的功能远比 App Store 描述要多（实战中帮助页发现的功能比 App Store 多 40%+），手动探索无法系统性覆盖，且截图中的隐私信息需要人工逐张处理。

## 解决方案

通过 iPhone 真机 + WDA（WebDriverAgent）自动化探索，系统性截图并生成 speckit：

1. **Phase 1: 信息采集** -- 从 App Store 页面 + App 内功能目录自动构建 feature-checklist
2. **Phase 2: 真机探索** -- 分三层遍历（Tab -> 子入口 -> 功能详情），每步截图 + 元素树配对保存，核心流程端到端走通
3. **Phase 3: 逆向生成** -- 从截图 + 探索记录填充 speckit Module 01/02/04（不输出 03/05/06，因为从 UI 反推准确率低）
4. **Phase 4: PM Review** -- 生成覆盖率报告和待补充清单

核心机制：
- **Checklist 驱动覆盖** -- feature-checklist.md 是全流程的进度条，每覆盖一个功能就更新状态
- **中断恢复** -- 三个状态文件（feature-checklist + screenshots/ + exploration-state.json）实现断点续传，长达数小时的探索可随时中断
- **Feature Discovery by Reasoning** -- agent 在探索过程中主动推理发现 checklist 未列出的功能

## 设计决策

| 决策 | 选择 | 原因 | 替代方案 |
|------|------|------|----------|
| 只输出 Module 01/02/04 | MVP 裁剪 | 03/05/06 从 UI 反推误导风险大于价值，宁可留空让 PM 补 | 全 6 模块输出（已放弃） |
| 视觉优先而非 Accessibility Tree 优先 | 截图 + VLM 为主，AXe 为辅 | 第三方 App 的 Accessibility Tree 不可控（Flutter/RN/WebView 可能返回空） | 纯 AXe 操作（不可行） |
| 环境搭建解耦到 ae-mobile-setup | 独立 skill | 搭建能力是全员通用的，不应嵌在 PM 专用 skill 里 | 内嵌 70 行搭建步骤（v0.15.0 原始方案） |
| 不保存 WDA session ID | 每次 Phase 0 重建 | session 在新会话中几乎必然已过期，保存反而误导 | 缓存 session ID 复用 |
| 截图使用 WDA API 而非 mobile_save_screenshot | curl 直接调 WDA | mobile_save_screenshot 在 iOS 真机上有黑屏 bug | MCP save_screenshot（已知有 bug） |
| 截图语义化命名 | `{phase}-{功能ID}-{描述}.png` | 文件名即内容，中断恢复时扫描目录即可知进度 | 序号命名 `001.png`（v0.15.0 原始方案） |
| 付费策略前置评估 | Phase 0.9 分析 IAP 成本 | PM 需要在探索前决定是否投入测试费用 | 遇到付费墙再问（打断探索流程） |
| 每步必须截图验证 | 操作后 take_screenshot 确认 | 手机自动化单步成功率 ~72%，盲操作 10 步后成功率降到 3.7% | 批量操作后统一检查 |

## 已放弃方案

### 方案 A: 全 6 模块输出
- **是什么：** 从 UI 截图反推技术架构（Module 03）、数据模型（Module 05）、API 规范（Module 06）
- **为什么放弃：** 准确率极低。从 UI 无法判断后端用 Spring Boot 还是 Node.js，数据模型只能猜。错误的 speckit 比没有更危险 -- dev agent 会按错误信息生成代码

### 方案 B: 内嵌环境搭建步骤
- **是什么：** v0.15.0 首版在 SKILL.md 中内嵌 70 行 go-ios + WDA 搭建步骤
- **为什么放弃：** v0.15.1 解耦到 ae-go 的 /ae-mobile-setup。搭建是通用能力，不应锁死在 PM skill 里；ae-go 的用户（如移动端测试）也需要同样的搭建流程

### 方案 C: 纯视觉猜坐标点击
- **是什么：** v0.15.0 版本中 agent 看截图估算坐标直接 tap
- **为什么放弃：** v0.16.0 引入标准 tap 模板（元素树 -> rect -> 中心点 -> 点击 -> verify）。猜坐标平均需要 2-3 次才成功，且无法复现

### 方案 D: 静态 feature-checklist
- **是什么：** Phase 1 生成 checklist 后固定不变
- **为什么放弃：** v0.18.1 引入 Feature Discovery by Reasoning。实战中 agent 在探索过程中通过推理发现了 checklist 未列出的功能（如设置页的开关暗示独立功能），这些功能往往是 App 的差异化卖点

## 开源供应链

| 组件 | 来源 | 覆盖度 | 我们的增量 |
|------|------|--------|-----------|
| go-ios | danielpaulus/go-ios | 设备通信、tunnel、app 管理 | 无修改，直接使用 |
| WebDriverAgent | appium/WebDriverAgent | UI 自动化核心（截图、元素树、tap/swipe） | 无修改，通过 xcodebuild 编译安装 |
| mobile-mcp | anthropics/mobile-mcp | Claude Code 调用 WDA 的 MCP 桥接 | 无修改，作为首选通道 |
| Apple Vision OCR | macOS 内置 | 截图文字识别 | ocr-screenshot.py 封装调用 |
| wda-start.sh | 自研 | 无 | WDA 一键启动（设备检测 -> tunnel -> xcodebuild -> 端口转发 -> 验证） |
| wda-cli.py | 自研 | 无 | WDA HTTP API CLI，mobile-mcp 不可用时的 fallback |
| screenshot-save.py | 自研 | 无 | 截图 + 元素树配对保存，内置黑屏检测重试 |
| coverage-stats.py | 自研 | 无 | feature-checklist 覆盖率统计 + 阈值检查 |
| privacy-mask.py | 自研 | 无 | 截图隐私脱敏（OCR 扫描 PII + 自动马赛克） |

## FAQ

**Q: 为什么不直接用模拟器而要用真机？**
A: 第三方 App 只能安装到真机（通过 App Store），模拟器只能运行自己编译的项目。这是与 demo-to-speckit / verify-app 的根本区别。

**Q: 探索一个 App 大概需要多长时间？**
A: 取决于 App 复杂度。简单 App（5-10 个功能）约 30 分钟，复杂 App（30+ 功能，如扫描全能王）需要 1-2 小时。中断恢复机制允许分多次会话完成。

**Q: 遇到付费墙怎么办？**
A: Phase 0.9 会评估最低测试成本并向 PM 报告。PM 决定是否付费。未付费的功能标记为 ⛔，付费后可通过增量补测模式回来补测。

**Q: mobile-mcp 不可用时怎么办？**
A: Phase 0.6 自动检测 MCP 可用性，不可用时全程切换到 wda-cli.py 作为 fallback，功能完全对等。

**Q: 截图中的个人信息怎么处理？**
A: Phase 2e 使用 privacy-mask.py 自动脱敏。基于 Apple Vision OCR 扫描 PII 关键词（姓名、设备名、ID 等），自动马赛克处理，耗时从手动 ~30 分钟降到 <1 分钟。

## 生命周期

- **填补的 gap：** 没有源码时无法提取 speckit -- PM 无法系统性分析竞品 App
- **什么会让它过时：** 如果出现通用的 App 逆向工程工具（如直接从 IPA 提取 UI 结构和数据模型），Phase 2 的真机探索可以被替代。但 Phase 1（App Store 信息采集）和 Phase 3（speckit 生成）的逻辑仍然有价值

## 演进历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.15.0 | 2026-04-02 | 首版。4 Phase 流程 + checklist 驱动 + 中断恢复。实跑验证：扫描全能王 38 张截图 |
| v0.15.1 | 2026-04-03 | 环境搭建解耦到 ae-go /ae-mobile-setup，SKILL.md 减 70 行 |
| v0.16.0 | 2026-04-05 | 实战优化：Phase 0 六步环境就绪、Phase 1.5 功能目录前置、语义化截图命名、标准 tap 模板、覆盖率 checkpoint |
| v0.17.0 | 2026-04-05 | 截图隐私脱敏 privacy-mask.py + 元素树 XML 快照配对保存 |
| v0.18.0 | 2026-04-05 | 探索流程全面脚本化：wda-start.sh / screenshot-save.py / coverage-stats.py |
| v0.18.1 | 2026-04-05 | Feature Discovery by Reasoning -- agent 探索时主动推理发现未知功能 |
| v0.19.0 | 2026-04-05 | Interior AI 实战 6 issue 修复：WDA CLI fallback + Bundle ID 发现 + 付费策略评估 + 交互协议 |
| v0.19.1 | 2026-04-05 | 中断恢复支持付费后增量补测 |
| v0.19.2 | 2026-04-05 | wda-start.sh 路径查找 + wda-cli.py W3C Actions API 兼容修复 |

## 文件清单

| 文件 | 用途 |
|------|------|
| `SKILL.md` | Agent 操作指南（Phase 0-4 完整流程 + 所有规则） |
| `scripts/wda-start.sh` | WDA 环境一键启动（设备检测 -> tunnel -> xcodebuild -> 端口转发 -> 验证） |
| `scripts/wda-cli.py` | WDA HTTP API CLI（mobile-mcp 不可用时的 fallback） |
| `scripts/screenshot-save.py` | 截图 + 元素树 XML 配对保存（内置黑屏检测重试） |
| `scripts/coverage-stats.py` | feature-checklist.md 覆盖率统计 + 阈值检查 |
| `scripts/privacy-mask.py` | 截图隐私脱敏（Apple Vision OCR + 自动马赛克） |
| `scripts/ocr-screenshot.py` | 截图文字识别（元素树不可用时的降级方案） |
