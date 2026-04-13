# ae-skill-creator 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-skill-creator

## Test Stories

### Story 1: 从零创建一个简单 skill（Happy Path）
- **Prompt**: "帮我创建一个新 skill，用来自动检查 iOS 项目的 Info.plist 是否包含必需的隐私声明。目标角色是 pm。"
- **Expect**: Agent 进入 Phase 0 需求澄清，向用户确认触发条件、输入输出、是否有已有 skill 可复用；进行开源采购调研（搜索相关 MCP/CLI）；做出 Build vs Buy 决策；然后进入 Phase 1 用裸命令（如 plutil、grep）跑通核心链路——实际读取一个 Info.plist 并检查隐私 key；跑通后进入 Phase 2 编写符合六段标准的 SKILL.md（含 YAML frontmatter、Core Principle、Operational Workflow、Mandatory Rules、Anti-Patterns、Troubleshooting）。
- **Max Time**: 300s

### Story 2: 指定 issue 编号 + 审计已有 skill
- **Prompt**: "审计一下 ae-verify-app 这个 skill，看看是否符合标准。关联 issue #ITEST01。"
- **Expect**: Agent 进入审计模式，读取 skills/pm/ae-verify-app/SKILL.md，用 8 项审计清单逐项检查（YAML frontmatter、Core Principle、Operational Workflow、Mandatory Rules、Anti-Patterns、Troubleshooting、README.md、test-scenarios.md），输出审计报告，包含得分 X/8、每项状态（pass/warn/fail）和改进建议列表，按优先级排序。不进入创建流程。
- **Max Time**: 120s

### Story 3: 核心依赖不存在时的阻塞处理
- **Prompt**: "帮我创建一个 skill，用来自动在 Figma 中标注设计稿的间距尺寸。角色 dev。"
- **Expect**: Agent 在 Phase 0 开源调研后发现需要 Figma MCP 或 API；进入 Phase 1 尝试验证核心链路时，如果 Figma MCP 未连接或 API Key 未配置，Agent 应停在 Phase 1，明确报告阻塞项（"Figma MCP 未安装"或"缺少 FIGMA_ACCESS_TOKEN"），不继续写 SKILL.md，不进入 Phase 2。输出包含阻塞原因和恢复建议。
- **Max Time**: 180s

### Story 4: SKILL.md 六段标准完整性验证
- **Prompt**: "创建一个 skill：自动从 App Store 评论中提取用户反馈，按正面/负面分类汇总。角色 pm。"
- **Expect**: 最终产出的 SKILL.md 必须包含完整六段：(1) YAML frontmatter 含 name、description、permissions.allow、dependencies（mcp/cli/api_keys/scripts）、smoke_test；(2) blockquote 格式的 Core Principle 锚定 agent 身份；(3) 分 Phase 的 Operational Workflow，每个 Phase 有目标和 bash 命令；(4) 3-7 条编号加粗的 Mandatory Rules；(5) 至少 3 个 Anti-Patterns（用 "X" 前缀 + 正确做法）；(6) Troubleshooting 症状-方案表格。此外还应产出 test-scenarios.md（5+ 场景）和 README.md（全中文）。
- **Max Time**: 360s

### Story 5: 与 publish.sh 门禁的集成验证
- **Prompt**: "我刚用 ae-skill-creator 创建了一个新 skill ae-store-assets，请帮我走完 Phase 6 发布流程。"
- **Expect**: Agent 按 Phase 6 流程操作：(1) 更新 templates/pm/CHANGELOG.md 顶部新增版本条目（含版本号、日期、issue 编号、改动描述）；(2) 同步更新 templates/pm/README.md 中的版本号；(3) git add + commit + push；(4) 执行 `bash scripts/publish.sh pm`，publish.sh 应能成功构建并通过版本号一致性校验；(5) 通过 `ae git issues comment` 在 issue 上发 comment 包含版本号、改动摘要、验证结果、更新命令。
- **Max Time**: 240s

## 最近一次评估
（待执行）

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
（待执行）

## 瓶颈分析
（待执行）

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
