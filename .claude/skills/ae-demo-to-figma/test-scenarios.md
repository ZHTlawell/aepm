# ae-demo-to-figma 测试场景

## 场景 1：标准 HTML demo 转 Figma
- **用户说**："把这个 demo 转成 Figma 设计稿"
- **预期行为**：agent 运行预处理脚本提取 pages/tokens/images/svgs，展示页面清单让 PM 确认，通过 Figma MCP 创建文件并逐页构建
- **验证标准**：返回 Figma 文件 URL，每个页面有对应 Figma Page

## 场景 2：Figma MCP 未连接
- **用户说**："帮我把 demo 转 Figma"（Figma MCP 未注册）
- **预期行为**：检测到 figma MCP 不存在，引导用户注册并完成 OAuth
- **验证标准**：给出完整的注册命令和 OAuth 步骤

## 场景 3：只转部分页面
- **用户说**："只转首页和设置页就行"
- **预期行为**：展示页面清单后，只选择用户指定的页面进行转换
- **验证标准**：Figma 文件中只包含用户选择的页面

## 场景 4：iOS Xcode 项目（非 HTML）
- **用户说**："这是一个 SwiftUI 项目，帮我转 Figma"
- **预期行为**：识别项目类型为 iOS，调整提取策略（从 SwiftUI 代码提取颜色/字体/布局）
- **验证标准**：正确提取 SwiftUI 的 Color/Font 定义

## 场景 5：Figma 席位权限不足
- **用户说**："转好了吗？"（用户只有 View 席位）
- **预期行为**：调用 create_new_file 时收到权限错误，解释需要 Full 席位
- **验证标准**：明确告知权限要求
