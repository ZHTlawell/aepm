# ae-demo-to-speckit 测试场景

## 场景 1：标准 iOS demo 提取 speckit
- **用户说**："帮我把这个 demo 提取成 speckit"
- **预期行为**：agent 识别项目类型，执行 Context Manifest 搜集，逐步提取 6 模块，每个字段标注置信度
- **验证标准**：speckit/ 目录包含 00-06 共 7 个 md 文件，置信度标注完整

## 场景 2：项目目录不存在
- **用户说**："提取 /path/to/nonexistent 的 speckit"
- **预期行为**：检测到目录不存在，提示用户提供正确路径
- **验证标准**：不尝试在空目录上提取

## 场景 3：违反约束的 demo
- **用户说**："提取 speckit"（demo 使用了 WebView 作为主 UI）
- **预期行为**：约束合规预检发现违规，报告 block 级问题并建议 PM 先修复
- **验证标准**：违规在提取开始前就被识别

## 场景 4：缺少产品文档的项目
- **用户说**："这个项目没有 README，直接从代码提取"
- **预期行为**：Context Manifest 发现 product_doc 缺失，仅从代码推断，标注 [inferred]
- **验证标准**：推断字段都标注了 [inferred]

## 场景 5：提取后衔接 verify-app
- **用户说**："speckit 提取好了，帮我验一下成品差异"
- **预期行为**：识别衔接意图，引导进入 ae-verify-app 流程
- **验证标准**：将 speckit 路径传递给 verify-app
