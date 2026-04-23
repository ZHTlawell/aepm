# ae-app-to-speckit 测试场景

## 场景 1：标准 App 逆向提取
- **用户说**："帮我分析一下 App Store 上的 CamScanner，提取 speckit"
- **预期行为**：agent 执行环境检查 + App Store 调研 + 真机 UI 探索 + 截图 + OCR，产出 speckit 三个模块
- **验证标准**：speckit/ 目录包含 01/02/04 三个 md 文件，feature-checklist 覆盖率 > 80%

## 场景 2：iPhone 未连接
- **用户说**："帮我逆向提取这个 App 的 speckit"（iPhone 未 USB 连接）
- **预期行为**：环境检查检测到无设备，提示用户连接 iPhone 并信任电脑
- **验证标准**：明确提示连接要求，不尝试继续操作

## 场景 3：目标 App 未安装
- **用户说**："分析一下 Bevel 这个 App"（真机上未安装）
- **预期行为**：agent 尝试启动 App 发现未安装，引导用户从 App Store 下载
- **验证标准**：提供搜索引导，等用户确认安装后再继续

## 场景 4：通知遮挡截图
- **用户说**："继续分析"（探索过程中有通知弹窗遮挡）
- **预期行为**：截图后识别到遮挡，尝试关闭或提醒用户开启免打扰
- **验证标准**：最终保存的截图无遮挡

## 场景 5：与 verify-app 的衔接
- **用户说**："我已经有 demo speckit 了，现在想对比线上 App"
- **预期行为**：识别衔接意图，建议使用 ae-verify-app 做 E2E 对比
- **验证标准**：正确引导到 ae-verify-app

## 场景 6：autonomous 模式默认行为（#IJ84WI）
- **用户说**："/ae-app-to-speckit 分析 LoopCraft"
- **预期行为**：CP1-CP7 每个 checkpoint 写 phase-summaries.md + 更新 exploration-state.json 后，输出一行 `[CP{n}] ...` 日志直接进入下一阶段；只在 Phase 0.7（PII）、0.8（付费决策）、2b（拍照/上传）、首次 paywall/登录墙、CP7 后（建议 /compact）才暂停请 PM
- **验证标准**：从 Phase 1.5 到 Phase 3 期间 PM 输入 `continue` 次数 = 0（除非遇到物理操作节点）；phase-summaries.md 每个 CP 的摘要仍然完整写入

## 场景 7：interactive 模式回退
- **用户说**："/ae-app-to-speckit --interactive 分析 CamScanner"
- **预期行为**：每个 CP 输出完整 Checkpoint 消息并等待 PM 回复 `continue`（恢复 v0.42 老行为）
- **验证标准**：CP1/2/3/4/5/6/7 每次都暂停等 PM 输入
