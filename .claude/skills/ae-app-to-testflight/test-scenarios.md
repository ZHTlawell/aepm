# ae-app-to-testflight 测试场景

## 场景 1：首次 TestFlight 发布
- **用户说**："这个 App 从来没发过，帮我发到 TestFlight"
- **预期行为**：Phase 0 扫描 → Phase 1 注册 App ID + 创建 App → Phase 2 配置签名 → Phase 3 Archive + Upload → Phase 4 分发
- **验证标准**：App 出现在 TestFlight 中

## 场景 2：Playwright MCP 未注册
- **用户说**："帮我发 TestFlight"（无 Playwright MCP）
- **预期行为**：检测到 browser_navigate 不存在，给出注册命令
- **验证标准**：给出完整命令（含 --browser chrome），说明须重开对话

## 场景 3：签名证书问题
- **用户说**："Archive 失败了，说签名有问题"
- **预期行为**：执行 security find-identity 检查证书，识别问题并引导修复
- **验证标准**：给出具体的证书问题和修复步骤

## 场景 4：项目编译失败无法 Archive
- **用户说**："帮我发 TestFlight"（项目有编译错误）
- **预期行为**：Phase 0 发现编译失败，建议先用 ae-preflight 修复
- **验证标准**：不尝试 Archive，前置阻塞项明确

## 场景 5：更新已有 App 的新版本
- **用户说**："发一个新版本到 TestFlight，版本号 1.2.0"
- **预期行为**：跳过 App ID 注册，更新版本号和 build number，执行 Archive + Upload
- **验证标准**：新版本出现在 TestFlight，版本号正确
