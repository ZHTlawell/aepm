# ae-submit-bug 评估报告

## 基本信息
- **Role**: shared (go/pm)
- **Skill**: ae-submit-bug
- **依赖**: ae CLI (ae git), GITEE_TOKEN

## Test Stories

### Story 1: 完整 bug 提交 happy path
- **Prompt**: "帮我提个 bug，ae update pm 执行后报 permission denied 错误，在 macOS 上执行 ae update pm 时出现的，修好后应该能正常执行 ae update pm 并看到 '已更新到最新版本' 的提示"
- **Expect**:
  1. 识别用户已提供问题描述、复现步骤线索、验证标准，跳过已知项的追问
  2. 执行查重：调用 `ae git issues list --repo <目标仓库> --state open --pretty`，扫描是否有类似 issue
  3. 格式化 issue body，包含完整的：描述、具体表现、复现步骤、期望行为、验证标准
  4. 标题格式为 `[BUG] ae update pm — permission denied 错误`（或类似）
  5. 将格式化后的标题和正文展示给用户确认，等待用户说"确认"后才提交
  6. 调用 `ae git issues create --repo <仓库> --title "[BUG] ..." --body "..."`
  7. 提交后调用 `ae git issues list` 验证 issue 存在，向用户展示 issue 编号
- **Max Time**: 120s

### Story 2: 笼统描述的追问流程
- **Prompt**: "ae 有个 bug，用不了"
- **Expect**:
  1. 识别描述笼统（"用不了"），不直接提交
  2. 追问具体化："能具体说说是哪个环节出了问题吗？比如点了什么按钮、看到了什么错误？"
  3. 追问复现步骤：具体的可执行步骤
  4. 追问验证标准："修好之后应该是什么样的？怎么确认修好了？"
  5. 不会在验证标准为空的情况下尝试提交
  6. 整个过程逐项推进，不一次问完所有问题
- **Max Time**: 60s

### Story 3: 查重命中已有 issue
- **Prompt**: "帮我提一个 bug，Playwright MCP 导航超时，飞书页面要等 40 秒"
- **Expect**:
  1. 执行查重：调用 `ae git issues list --repo <目标仓库> --state open --pretty`
  2. 如果存在标题或描述中包含 "Playwright" + "超时" 的已有 issue，告知用户：
     "已有一个类似的 issue #XXXX，要在上面补充评论还是新开一个？"
  3. 等待用户选择后再决定下一步（comment 已有 issue 或新建）
  4. 如果用户选择新开，在新 issue body 中引用相似 issue 编号
  5. 不会跳过查重直接创建
- **Max Time**: 120s

### Story 4: issue 格式和验证标准质量检查
- **Prompt**: "帮我提个 bug：ae git issues list 命令返回空列表，但 Gitee 网页上能看到 5 个 open issue。在 ae-platform 仓库上操作的。修好后执行 ae git issues list --repo ae-platform --state open --pretty 应该返回所有 open issue 的列表。"
- **Expect**:
  1. 格式化后的 issue body 严格遵循模板结构，包含 5 个段落：描述、具体表现、复现步骤、期望行为、验证标准
  2. 验证标准段不为空，且包含具体可执行的命令（`ae git issues list --repo ae-platform --state open --pretty`）和预期输出（返回所有 open issue）
  3. 复现步骤是可执行的编号列表（1. 执行 xxx 2. 观察 xxx），不是描述性文字
  4. 标题符合 `[BUG] 产品名 — 问题简述` 格式
  5. 目标仓库通过读取 `~/.ae/<role>/CLAUDE.md` 中的 Issue 路由表确定，不是读当前 workspace 的 CLAUDE.md
- **Max Time**: 120s

### Story 5: 多 bug 拆分 + ae git CLI 集成验证
- **Prompt**: "帮我提两个 bug：1) ae update 执行报错 network timeout 2) ae git issues list 返回乱码"
- **Expect**:
  1. 识别用户报告了 2 个独立 bug，不合并为一个 issue
  2. 对每个 bug 分别收集信息、查重、格式化、确认、提交
  3. 第一个 bug 提交完成后，再处理第二个
  4. 每次提交都调用 `ae git issues create`（共 2 次）
  5. 每次提交后都调用 `ae git issues list` 验证（共 2 次）
  6. 向用户展示两个 issue 的编号
  7. 整个流程使用 ae git CLI，不使用 curl 或直接调用 ae-git.py
- **Max Time**: 300s

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

## 质量审计

### 审计日期
2026-04-13

### 审计结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| SKILL.md 完整性 | ✅ | 触发条件明确；Step 1-6 流程完整（收集→查重→格式化→确认→提交→验证）；有 issue body 模板；有用户确认点（Step 4）；有硬规则和 Anti-Patterns；有 Troubleshooting 表 |
| 依赖可达性 | ✅ | ae CLI 已安装（/Users/kenchy/.ae/bin/ae）；GITEE_TOKEN 声明在 api_keys 中；无脚本依赖，所有操作通过 ae git 命令完成 |
| 权限声明 | ⚠️ | frontmatter 缺少 `permissions.allow` 字段。实际使用了 `Bash(ae git:*)` 命令，应显式声明权限。对比 ae-web-browse 和 ae-podcast-learn 都有权限声明 |
| 注册一致性 | ✅ | templates/go/CLAUDE.md 第 24 行注册为"向 AE Team 提交 bug 或需求（`/ae-submit-bug` / `/ae-submit-requirement`）"；templates/pm/CLAUDE.md 第 142 行注册为"提 Bug | `/ae-submit-bug`"。共享 skill 在两个角色模板中均正确注册，名称一致 |
| 逻辑健壮性 | ✅ | 查重保护避免重复 issue；验证标准必填兜底了"修好后怎么验证"；提交后有 list 验证；笼统描述有追问机制；多 bug 强制逐个处理。401 报错有 Troubleshooting 指引 |

### 发现的问题

#### P0（阻断）
- 无

#### P1（影响体验）
- frontmatter 缺少 `permissions.allow` 字段。ae git Bash 调用在 `ae link` 合并权限时可能不会被自动授权

#### P2（可改进）
- Step 2 查重使用 `ae git issues list --state open` 获取所有 open issue，然后靠 agent 文本匹配判断相似度。当 issue 数量多时可能遗漏或误判。建议补充按关键词搜索的策略（如果 ae git 支持）
- Step 5 中目标仓库路由需要读取 `~/.ae/<role>/CLAUDE.md`，但没有说明如何判断当前是 go 还是 pm 角色。SKILL.md 应补充角色判断逻辑（如检查哪个 CLAUDE.md 存在/当前 workspace 关联的角色）
- 标题格式 `[BUG] 产品名 — 问题简述` 中的"产品名"没有枚举合法值，可能导致命名不一致
