# ae-verify-app 测试场景

## 场景 1：标准 demo vs 成品对比
- **用户说**："帮我对比 demo 和成品的差异"
- **预期行为**：从 speckit/02 提取测试用例，在模拟器上分别运行 demo 和 prod，逐项对比截图和行为，产出 diff report
- **验证标准**：diff report 包含每个 case 的 status 和归因

## 场景 2：缺少 speckit
- **用户说**："验一下成品"（项目无 speckit 目录）
- **预期行为**：检测到 speckit 缺失，提示先跑 /ae-demo-to-speckit
- **验证标准**：不尝试无 speckit 的验证

## 场景 3：单 app baseline 模式
- **用户说**："我只有成品，没有 demo，帮我做功能验证"
- **预期行为**：切换到 baseline 模式，只验证 prod app 是否实现了 speckit 中的功能
- **验证标准**：diff report 中只有 pass/missing/not_tested

## 场景 4：模拟器未启动
- **用户说**："开始验证"（无已启动的模拟器）
- **预期行为**：使用 xcrun simctl 自动启动合适的模拟器
- **验证标准**：自动启动并安装 app

## 场景 5：验证后衔接 file-bugs
- **用户说**："验证完了，把差异提 bug"
- **预期行为**：将最新 diff report 路径传递给 ae-file-bugs
- **验证标准**：无缝衔接，diff report 路径自动传递
