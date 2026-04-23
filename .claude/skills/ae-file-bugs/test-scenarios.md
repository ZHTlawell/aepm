# ae-file-bugs 测试场景

## 场景 1：标准批量提 bug
- **用户说**："把差异报告里的问题都提成 bug"
- **预期行为**：agent 找到最近的 diff report JSON，筛选 different/missing 的 case，生成 issue 草稿（含归因前缀），展示给 PM 确认后批量创建
- **验证标准**：每个 issue 标题含正确前缀，正文包含截图路径和归因信息

## 场景 2：找不到 diff report
- **用户说**："提 bug"（当前项目无 diff report）
- **预期行为**：搜索 diff report 文件未找到，提示用户先跑 /ae-verify-app
- **验证标准**：明确提示先运行验证

## 场景 3：指定特定 diff report
- **用户说**："用 verify/reports/diff-iter2.json 提 bug"
- **预期行为**：直接读取指定文件，不搜索其他 report
- **验证标准**：只处理用户指定的文件

## 场景 4：全部 case 都是 pass
- **用户说**："把验证结果提 bug"（diff report 中全部 pass）
- **预期行为**：告知 PM 所有功能验证通过，无需提 bug
- **验证标准**：不创建任何 issue

## 场景 5：Gitee Token 缺失
- **用户说**："批量提 bug"（GITEE_TOKEN 未配置）
- **预期行为**：创建 issue 时发现认证失败，提示配置 GITEE_TOKEN
- **验证标准**：给出配置方法
