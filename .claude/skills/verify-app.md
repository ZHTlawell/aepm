# Skill: App 差异比对验证 (verify-app)

## 触发条件

当 PM 需要对比两个 app（demo 原型 vs 生成成品）的功能差异时触发。也可用于单 app 的功能验证（baseline 模式）。

## 核心原则

**E2E 对比是整条 demo→speckit→prod 链路的质量闭环。** 每一个差异都能反向归因到具体环节：
- 功能缺失 + speckit 有描述 → 生成环节问题
- 功能缺失 + speckit 无描述 → 提取环节问题
- 功能不同 + 约束未定义 → CLAUDE.md 约束缺失

## 输入

- **speckit 目录**：标准 6 模块 speckit（功能清单 = 测试用例来源）
- **demo app**：已构建的 demo .app 文件 + bundle ID
- **prod app**（可选）：已构建的成品 .app 文件 + bundle ID
- **模拟器**：已启动的 iOS 模拟器

## 输出

- **verify-cases.yaml**：从 speckit 提取的结构化测试用例
- **diff report (JSON)**：每个 case 的 pass/missing/different 状态 + 归因 + 截图路径
- **coverage %**：通过率 = pass / total

## 执行流程

### Step 1: 提取测试用例

从 speckit/02-user-scenarios.md 提取功能点，生成 verify-cases.yaml：

```yaml
- id: unique_case_id
  source: speckit/02#场景X
  description: "功能描述"
  precondition: at_which_page
  steps:
    - action: tap/swipe/type
      target: "元素描述"
  checks:
    - expect: "预期看到的内容"
```

### Step 2: 执行验证（交互式 Vision-guided）

对每个 test case，执行以下 loop：

```
1. 截图当前页面 (simctl screenshot)
2. Claude Vision 看图 → 确认当前在哪个页面
3. 如果需要导航：
   a. Vision 识别目标元素的位置
   b. AXe tap 该坐标
   c. 等待 1-2 秒
   d. 再截图验证
4. 对照 checks 列表逐条判断
5. 记录 status: pass / missing / different
```

**关键**：不使用硬编码坐标。每次 tap 前必须先截图，用 Vision 定位目标元素。

### Step 3: 双 app 对比（有 prod 时）

同一套 test cases 分别对 demo 和 prod 执行，生成两份截图序列，然后：

- **结构对比**：逐 case 比较 status
- **视觉对比**：Claude Vision 看两张截图描述差异
- **归因**：对每个 diff 判断属于哪个环节的问题

### Step 4: 生成 Diff Report

```json
{
  "iteration": N,
  "summary": { "total_cases": 25, "pass": 18, "missing": 4, "different": 3 },
  "coverage": "72%",
  "cases": [...],
  "constraint_discoveries": [...]
}
```

### Step 5: 归因与建议

对每个非 pass 的 case，按规则归因：

| 差异类型 | speckit 有描述？ | 归因 |
|---------|----------------|------|
| prod 缺少功能 | 是 | generation（Step 2 生成不足）|
| prod 缺少功能 | 否 | extraction（Step 1 提取遗漏）|
| prod 功能不同 | 约束有定义 | generation |
| prod 功能不同 | 约束无定义 | constraint（CLAUDE.md 缺失）|

## 验证标准

- demo baseline: coverage ≥ 70% 即表示 verify 工具可用
- prod vs demo: coverage ≥ 80% 即表示生成质量基本可接受
- coverage ≥ 90% 为生产可用标准

## 工具依赖

| 工具 | 用途 | 安装 |
|------|------|------|
| Xcode CLI (xcodebuild) | 编译 iOS 项目 | Xcode |
| xcrun simctl | 模拟器管理 + 截图 | Xcode |
| AXe | UI 交互（tap/swipe）| `brew tap cameroncooke/axe && brew install axe` |
| Claude Vision | 截图理解 + 元素定位 | CC agent 内置 |

## 已知限制

- **WebView hybrid app**：AXe describe-ui 不可用，只能用坐标 tap + Vision 定位（不稳定）
- **Native SwiftUI app**：AXe 全功能可用，accessibilityIdentifier 精确定位（稳定）
- **Camera/AR 功能**：模拟器无法测试，需标记为 not_tested
- **坐标校准**：不同设备/模拟器的 tab bar 位置不同（iPhone 17 Pro: y≈840）

## 复用说明

所有 PM 在生成成品后都需要此能力进行最终验收。这是 demo→成品流水线的第三步（验证环节）。也可用于 demo 自身的功能回归测试。
