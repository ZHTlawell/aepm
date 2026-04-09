# ae-preflight 测试场景

## 场景 1：标准 TestFlight 前预检
- **用户说**："帮我检查一下这个项目能不能发 TestFlight"
- **预期行为**：agent 扫描项目目录，执行 xcodebuild build、grep 硬编码秘钥、检查 App Icon 等全量检查项
- **验证标准**：输出分类报告（pass/warn/block），每项都有实际执行的命令证据

## 场景 2：App Store 完整检查
- **用户说**："我要发到 App Store，不是 TestFlight，帮我全面扫一下"
- **预期行为**：agent 以 appstore 目标执行，比 testflight 多出隐私政策、评级、截图等检查项
- **验证标准**：输出包含 App Store 特有检查项

## 场景 3：项目编译失败
- **用户说**："跑一下预检"（项目实际编译不过）
- **预期行为**：agent 执行 xcodebuild build 发现失败，将编译错误作为 block 级问题报告
- **验证标准**：编译项为 BLOCK，包含具体错误信息

## 场景 4：缺少 Xcode 环境
- **用户说**："帮我预检一下项目"（未安装 Xcode）
- **预期行为**：smoke_test 阶段发现缺失，提示安装 Xcode
- **验证标准**：清晰告知需要安装 Xcode

## 场景 5：preflight 后衔接 testflight-publish
- **用户说**："预检通过了，直接帮我发 TestFlight"
- **预期行为**：确认无 block 项后，引导进入 ae-testflight-publish 流程
- **验证标准**：不重复执行已完成的检查项
