# ae-submit-requirement 评估报告

## 基本信息
- **Role**: shared (go/pm)
- **Skill**: ae-submit-requirement
- **依赖**: ae CLI (ae git), GITEE_TOKEN

## Test Stories

### Story 1: 完整需求提交 happy path
- **Prompt**: "我想提一个需求：希望 ae 能自动生成周报。现在我每周五手动从 Gitee 汇总本周的 issue 进展写周报，希望 agent 能自动拉取本周关闭的 issue 和 comment，生成一份周报草稿。验证方式：我说'生成本周周报'，agent 输出一份包含本周已关闭 issue 列表和关键进展摘要的 markdown 文档。"
- **Expect**:
  1. 识别用户已提供核心诉求、当前做法、自动化程度、验证标准，跳过已知项追问
  2. 执行查重：调用 `ae git issues list --repo <目标仓库> --state open --pretty`
  3. 格式化 issue body 包含 5 个段落：需求描述、使用场景、当前做法、期望效果、验证标准
  4. 标题格式为 `[FEAT] 自动生成周报`（或类似）
  5. 验证标准段包含至少 2 个可执行的验证场景
  6. 展示给用户确认后才调用 `ae git issues create`
  7. 提交后调用 `ae git issues list` 验证 issue 存在，展示编号
- **Max Time**: 120s

### Story 2: 参数化需求 — 用户指定目标仓库
- **Prompt**: "帮我提一个需求到 ae-platform 仓库：希望 ae link 命令支持 --dry-run 参数，只显示会做什么改动但不实际修改文件"
- **Expect**:
  1. 识别用户指定了目标仓库（ae-platform），不需要从路由表推断
  2. 追问使用场景和验证标准（用户未提供）
  3. 不替用户做技术方案设计（不在 issue 中写实现细节）
  4. issue body 的验证标准段描述具体场景：执行 `ae link --dry-run` 后看到输出列表但文件未修改
  5. 提交时 `--repo` 参数使用用户指定的 ae-platform
- **Max Time**: 120s

### Story 3: 模糊需求的追问和草拟
- **Prompt**: "我觉得 ae 应该更智能一点"
- **Expect**:
  1. 识别需求过于模糊，不直接提交
  2. 追问核心诉求："你想解决什么问题？"
  3. 追问当前做法："现在是怎么做的？"
  4. 追问自动化程度："你希望 AI 帮你做到什么程度？"
  5. 追问验证标准："做好之后怎么验证？能描述一个具体场景吗？"
  6. 如果用户仍说不清验证标准，agent 根据已收集的诉求草拟 2-3 个验证场景让用户确认
  7. 整个过程不一次问完所有问题，逐项推进
  8. 验证标准为空时拒绝提交
- **Max Time**: 60s

### Story 4: 输出格式和内容质量验证
- **Prompt**: "我想提个需求：希望 ae 能帮我自动做竞品分析。现在我手动去 App Store 搜索竞品、逐个看评分和评论。希望我说一个关键词，agent 自动搜索 top 10 竞品并生成对比表格。验证：1) 我说'分析跑步类 App 竞品'，agent 返回包含 App 名称、评分、下载量、核心功能的表格 2) 表格至少包含 5 个 App"
- **Expect**:
  1. 格式化后的 issue body 严格遵循模板：
     - `## 需求描述` — 一段话说清能力
     - `## 使用场景` — 具体到什么时候用
     - `## 当前做法` — 手动流程描述
     - `## 期望效果` — AI 辅助后的理想状态
     - `## 验证标准` — 至少 2 个可执行场景，格式为"用户说 X，agent 做 Y，输出 Z"
  2. 验证标准不使用"功能可用"等模糊表述，每条都是具体场景
  3. issue body 中不包含技术实现方案（不替用户做架构设计）
  4. 标题符合 `[FEAT] 能力简述` 格式，简洁不超过 30 字
- **Max Time**: 120s

### Story 5: 查重命中 + ae git CLI 集成验证
- **Prompt**: "帮我提个需求：希望 agent 能自动帮我提 bug 到 Gitee"
- **Expect**:
  1. 执行查重：调用 `ae git issues list --repo <目标仓库> --state open --pretty`
  2. 由于 ae-submit-bug skill 已存在，大概率找到相似 issue（关于 bug 提交能力的需求或已有实现）
  3. 如果找到相似 issue，告知用户："已有一个类似的需求 #XXXX，要在上面补充还是新开？"
  4. 等待用户选择，不自作主张
  5. 如果用户选择补充，调用 `ae git issues comment --repo <仓库> --number <编号> --body "补充内容"`
  6. 如果用户选择新开，在新 issue 中引用相似 issue
  7. 全程使用 ae git CLI，不使用 curl 或直接调用 python3 ae-git.py
- **Max Time**: 120s

You've hit your limit · resets 2am (Asia/Shanghai)

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
