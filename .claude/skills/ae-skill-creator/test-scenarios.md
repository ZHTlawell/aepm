# ae-skill-creator 测试场景

## 场景 1：从零创建新 skill
- **用户说**："我想创建一个自动生成 App Store 截图的 skill"
- **预期行为**：agent 进入需求澄清，确认目标角色、核心流程、外部依赖，然后先裸命令跑通核心链路，再包装为标准 SKILL.md + README.md + test-scenarios.md
- **验证标准**：产出的 skill 目录结构完整，SKILL.md frontmatter 含 dependencies/smoke_test

## 场景 2：审计已有 skill
- **用户说**："帮我审计一下 ae-preflight 这个 skill"
- **预期行为**：agent 读取现有 SKILL.md，按标准逐项检查，输出审计报告
- **验证标准**：报告列出所有不符合项及修复建议

## 场景 3：补充缺失文档
- **用户说**："这个 skill 缺 README，帮我补上"
- **预期行为**：agent 读取 SKILL.md，生成标准格式 README.md
- **验证标准**：README.md 内容与 SKILL.md 一致，格式符合标准

## 场景 4：需求不明确时的澄清
- **用户说**："帮我写个 skill"（无具体需求）
- **预期行为**：agent 主动追问 skill 做什么、目标角色、有无参考 issue
- **验证标准**：至少获得需求描述和目标角色后才开始

## 场景 5：从 issue 创建 skill
- **用户说**："把 #IHRNO3 这个 issue 做成一个 skill"
- **预期行为**：agent 用 ae git 读取 issue 内容，按标准流程创建 skill，完成后 comment 回 issue
- **验证标准**：skill 内容与 issue 需求一致，issue 上有完成 comment
