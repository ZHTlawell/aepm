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

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 2/5 (40%)
- **平均耗时**: 49.1s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 从零创建简单 skill (Happy Path) | 3/5 | 23.5s | 仅完成 Phase 0 澄清，未进入 Phase 1/2 | Phase 0 质量高：5 项澄清全覆盖，识别了 ae-preflight 复用可能；但作为 Happy Path 测试，期望至少跑到 Phase 2，实际只输出一轮问答即停 |
| 审计已有 skill | 4/5 | 131.6s | 耗时略超 120s 上限 | 审计结论正确（0/8，目录缺失），表格格式规范，逐项给出 ❌ 状态；扣分点：输出截断、耗时超限 |
| 核心依赖不存在阻塞 | 2/5 | 21.4s | 未进入 Phase 1 验证即停 | 仅做 Phase 0 澄清就停下等用户输入，未触达测试核心点——Phase 1 发现 Figma MCP/API 缺失后阻塞上报 |
| SKILL.md 六段完整性 | 0/5 | 64.6s | API 速率限制 | 输出 "You've hit your limit"，无任何实质内容 |
| publish.sh 门禁集成 | 0/5 | 4.5s | API 速率限制 | 输出 "You've hit your limit"，无任何实质内容 |

## 瓶颈分析
- **Phase 0 阻塞问题（Story 1 & 3）**：skill 设计为交互式多轮对话，但测试以单轮 prompt 执行。Agent 严格遵守"先问再做"，导致 Happy Path 和阻塞检测两个场景都卡在 Phase 0 等用户回复。建议在 SKILL.md 中增加"当用户 prompt 已包含足够信息时，可跳过已回答的澄清项直接推进"的规则，或测试框架支持多轮交互。
- **API 速率限制（Story 4 & 5）**：两个场景因 rate limit 完全失败，占总用例 40%。这是基础设施问题而非 skill 质量问题，但严重拉低通过率。建议测试排期避开配额耗尽时段，或在测试编排层加 rate-limit 预检。
- **审计模式耗时偏高（Story 2）**：131.6s 略超 120s 上限，主要时间花在遍历多个可能路径查找 skill 文件。建议在 SKILL.md 审计流程中明确 skill 目录约定路径（`~/.ae/<role>/.claude/skills/<name>/`），减少盲搜。

## 结论
Skill 的 Phase 0 澄清和审计模式基本可用，但核心创建流程（Phase 1→2→6）在单轮测试中从未被触达；建议优先解决"信息充分时自动推进"的流程判断逻辑，并在基础设施稳定后补测 Story 4 & 5。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 2/5 (40%) | 49.1s |
