# ae-demo-to-speckit 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-demo-to-speckit

## Test Stories

### Story 1: 基础 Happy Path — iOS SwiftUI Demo 提取 speckit
- **Prompt**: "帮我把 ~/Projects/ShoeLens 这个 demo 提取 speckit"
- **Expect**: 
  - Step 0: 执行约束合规预检，检查 ios-001（SwiftUI Native）、ios-002（无 WebView）、ios-003（accessibilityIdentifier）等，汇总违规项
  - Step 1: 识别项目类型为 iOS Native (SwiftUI)（检测到 .xcodeproj + .swift 文件）
  - Step 1.5: 系统性搜集 4 类上下文（codebase/product_doc/design_asset/strategic_context），生成 00-context-manifest.md
  - Step 1.8: 扫描项目中的数据源文件（CSV/JSON/SQLite），记录行数和字段摘要
  - Step 2: 完整读取所有 Swift/CSS/配置文件，不遗漏
  - Step 3: 逐模块提取，生成 01~06 共 6 个 speckit 文件
  - Step 5: 功能自检清单全部通过 + Schema 质量校验通过 + 置信度检查（[inferred] 不超 30%）
  - 输出目录为 speckit/，含 00-context-manifest.md + 01~06 六个模块文件
- **Max Time**: 600s

### Story 2: 带产品文档的项目（README + PRD 存在）
- **Prompt**: "提取 speckit，项目在 ~/Projects/WePray，项目根目录有 README.md 和 docs/PRD.md"
- **Expect**: 
  - Step 1.5 搜集上下文时发现 README.md 和 docs/PRD.md，状态标记为 found
  - Module 01 从 PRD 提取产品名、定位、目标用户（置信度 confirmed，无 [inferred] 标注）
  - Module 02 的用户场景从 PRD 补充叙事上下文，而非仅从代码推断
  - 00-context-manifest.md 正确记录所有上下文源的发现状态
  - 与纯代码提取相比，[inferred] 标注比例显著降低
  - 如果存在 CLAUDE.md / .cursor/rules/，也被识别为 strategic_context
- **Max Time**: 480s

### Story 3: 项目中有 WebView 包装（block 级违规）
- **Prompt**: "提取 speckit，项目在 ~/Projects/hybrid-app，这个 demo 用了 WKWebView"
- **Expect**: 
  - Step 0 约束合规预检检测到 ios-002 违规（WebView 包装为主 UI）
  - 判定为 block 级违规，建议 PM 先修复再提取
  - 不直接跳过违规继续提取
  - 告知 PM 违规的具体位置和修复建议
  - 如果 PM 明确表示继续，则标注违规并继续，但在 speckit 中醒目标注
  - warn 级违规（如个别缺少 accessibilityIdentifier）则记录并继续
- **Max Time**: 120s

### Story 4: 数据模型和 API 提取质量验证
- **Prompt**: "提取 speckit，~/Projects/ShoeLens，项目里有一个 ShoeLens_Final_Database.csv（2486 行）和 mock/shoes.json（10 条）"
- **Expect**: 
  - Step 1.8 数据源发现：识别 CSV 文件（2486 行，行数 > 100）标记为主数据源，JSON 文件标记为 mock
  - Module 05 中 CSV 标注为 `[PRIMARY DATA SOURCE]`，含文件路径、行数、字段列表
  - Module 05 中 mock JSON 标注为 `[MOCK]`，说明与真实数据的差异
  - Module 05 明确说明成品应使用哪个数据源
  - Module 06 包含数据导入方式说明（CSV -> DB 导入 / API 返回等）
  - Module 06 列出所有 fetch/API 调用 + mock 实现 + AI prompt 模板
  - 00-context-manifest.md 的数据源部分完整记录
- **Max Time**: 480s

### Story 5: 与 ae-verify-app 的集成验证
- **Prompt**: "提取完 speckit 后，帮我跑一下验证看覆盖率"
- **Expect**: 
  - 提取完成后输出功能自检清单结果（所有 tab 描述 / Toast 消息 / 导航路径 / CSS 变量 / 数据 schema / API Mock）
  - 对照 content/speckit-schema.yaml 逐模块校验 required_sections 和 quality_indicators
  - 置信度统计：[inferred] 字段 / 总字段的比例，[NEEDS INPUT] 字段汇总列出
  - speckit 可直接被 /ae-verify-app 消费：从 speckit 提取的 test cases coverage >= 90%
  - 提取结果可直接进入下游 demo-to-figma / dev agent 流水线
  - 如果 iOS 模拟器可用，Step 4 可选运行 demo 截图补充验证
- **Max Time**: 600s

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 48.1s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| S1: 基础 Happy Path | 1/5 | 35.0s | 目录不存在即终止，未展示任何提取能力 | 仅返回"目录不存在"，0 个 step 执行 |
| S2: 带产品文档项目 | 1/5 | 54.1s | 同 S1，目录不存在即终止 | 未尝试任何上下文搜集或降级策略 |
| S3: WebView block 违规 | 3/5 | 76.3s | 基于用户提示而非代码扫描做出判断 | 正确识别 ios-002 block 违规并给出修复建议，但未实际扫描代码验证 |
| S4: 数据模型+API 质量 | 1/5 | 48.7s | 同 S1，目录不存在即终止 | 用户已明确告知文件名和行数，skill 仍未尝试任何提取 |
| S5: verify-app 集成 | 0/5 | 26.3s | API rate limit | 触发配额限制，无任何输出 |

## 瓶颈分析
- **P0 — 测试环境缺失项目目录**: 4/5 个 story 因 `~/Projects/*` 不存在而直接终止。Skill 缺乏对测试环境的适配能力，也未尝试在当前工作目录下寻找替代项目或提示用户将文件放到可达路径。建议：测试前应在环境中准备 fixture 项目，或 skill 应支持 `--path` 参数指向实际存在的目录。
- **P1 — Skill 遇到路径不存在时过早放弃**: SKILL.md 定义了完整的 Step 0→5 流程，但实际执行时在 "目录不存在" 就完全停止，未展示任何核心能力（约束预检、上下文搜集、模块提取、自检）。唯一例外是 S3，因为用户在 prompt 中显式提到了 WKWebView，skill 才执行了 Step 0 的一部分。建议：即使目录不存在，S3 的做法（利用用户提供的信息尽可能执行流程）应推广到其他 step。
- **P2 — Rate limit 导致 S5 完全失败**: S5 触发 API 配额限制，属于基础设施问题而非 skill 逻辑问题，但暴露了测试编排需要考虑配额管理（如 story 间加冷却期或使用独立配额）。

## 结论
Skill 核心提取流程在真实环境中 **未得到有效验证**——80% 的 story 因测试 fixture 缺失而在入口处失败，唯一部分通过的 S3 也仅验证了约束预检的表层逻辑。**最高优先级是搭建包含真实 demo 项目的测试 fixture 环境**，否则无法评估 skill 的实际提取质量。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 1/5 (20%) | 48.1s |
