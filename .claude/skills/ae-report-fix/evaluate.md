# ae-report-fix 评估报告

## 基本信息
- **Role**: shared
- **Skill**: ae-report-fix
- **依赖**: ae git CLI, GITEE_TOKEN, ~/.ae/<role>/CLAUDE.md (Issue 路由表)

## Test Stories

### Story 1: 基础 happy path — 当前对话中刚解决的问题回流
- **Prompt**: "刚才那个 MCP 配置问题帮我提交给 AE Team 吧"（在对话上下文中有已解决的 MCP 配置问题）
- **Expect**:
  1. 从当前对话上下文自动提取修复信息（不让用户重新描述）
  2. 生成修复标题（agent 拟，展示给用户确认）
  3. 格式化修复方案，包含完整结构：标题、修复前（问题）、修复后（方案）、验证结果、影响范围、用户清理提示
  4. 展示格式化内容让用户确认，不跳过确认步骤
  5. 读取 `~/.ae/<role>/CLAUDE.md` 确定目标仓库
  6. 检查是否已有相同/相似的 fix report（查重）
  7. 用 `ae git issues create --repo <repo> --title "[FIX-REPORT] ..." --body "..."` 创建新 issue
  8. 用 `ae git issues list` 验证 issue 创建成功
  9. 向用户展示提交确认信息（含 issue 编号）
- **Max Time**: 90s

### Story 2: 有关联 issue 的修复追加
- **Prompt**: "这个修复跟 #IHXOHI 相关，帮我追加到那个 issue 上"
- **Expect**:
  1. 从对话上下文提取修复信息
  2. 格式化修复方案（同 Story 1 的完整结构）
  3. 用户确认后，使用 `ae git issues comment --repo <repo> --number IHXOHI --body "..."` 追加 comment
  4. 不创建新 issue，而是 comment 到已有 issue
  5. 验证 comment 创建成功
- **Max Time**: 60s

### Story 3: 边界场景 — 未验证的修复拒绝提交
- **Prompt**: "我觉得把 timeout 改成 30s 应该能解决那个超时问题，帮我提交这个 fix"（对话中没有实际执行验证的证据）
- **Expect**:
  1. 检测到修复方案缺少验证结果（对话中没有实际执行命令和确认输出的记录）
  2. 拒绝提交，明确告知用户：没有验证过的修复不允许提交
  3. 建议用户先实际验证修复方案，验证通过后再回流
  4. 不生成修复方案模板，不调用 ae git 创建 issue
- **Max Time**: 30s

### Story 4: 输出质量验证 — 修复方案的完整性和格式
- **Prompt**: "把这个 fix 反馈给 AE Team"（对话中有完整的问题→诊断→修复→验证过程）
- **Expect**:
  1. 修复方案包含所有必填段落：标题、修复前、修复后、验证结果、影响范围、用户清理提示
  2. "修复前"段准确描述问题表现（含错误信息或异常行为）
  3. "修复后"段包含具体命令/配置/代码变更（可复现的修复步骤）
  4. "验证结果"段包含当前对话中实际的命令输出或截图引用
  5. "影响范围"段说明修复是否通用
  6. 末尾有 `/ae-report-fix` 自动生成标注
  7. issue title 格式为 `[FIX-REPORT] {title}`
- **Max Time**: 90s

### Story 5: 依赖集成验证 — ae git CLI 和 Issue 路由
- **Prompt**: "帮我提交这个修复"（修复涉及 ae-go 的 skill）
- **Expect**:
  1. 读取 `~/.ae/go/CLAUDE.md`（不是当前 workspace 的 CLAUDE.md）获取 Issue 路由表
  2. 根据路由表判断目标仓库（ae-go 相关应路由到正确仓库）
  3. 使用 `ae git` 命令（不是 curl、不是 python3 ae-git.py）执行 issue 操作
  4. 如果 `ae git` 命令失败（如 GITEE_TOKEN 无效），报告具体错误，不 silent fail
  5. 提交后使用 `ae git issues list` 验证，确认 issue 存在并展示给用户
- **Max Time**: 90s

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
| SKILL.md 完整性 | ✅ | 触发条件丰富（5 种场景 + 主动触发规则）；Step 1-5 流程完整（采集→格式化→确认→提交→验证）；有修复方案模板（6 段式）；有用户确认点；有硬规则和 Anti-Patterns；与 submit-bug/submit-requirement 的关系图清晰 |
| 依赖可达性 | ✅ | ae CLI 已安装；GITEE_TOKEN 声明在 api_keys 中；无脚本依赖 |
| 权限声明 | ⚠️ | frontmatter 缺少 `permissions.allow` 字段。与 ae-submit-bug、ae-submit-requirement 同样的问题 |
| 注册一致性 | ✅ | templates/go/CLAUDE.md 第 23 行注册为"修复回流（`/ae-report-fix`）"；templates/pm/CLAUDE.md 第 143 行注册为"修复回流 | `/ae-report-fix`"。共享 skill 在两个角色模板中均正确注册 |
| 逻辑健壮性 | ✅ | 验证结果段必填（拒绝未验证的修复）；有关联 issue 走 comment、无关联走新建 issue 的分支处理；从对话上下文自动提取信息减少用户负担；"不碰本地 skill 文件"明确职责边界；提交后有 list 验证 |

### 发现的问题

#### P0（阻断）
- 无

#### P1（影响体验）
- frontmatter 缺少 `permissions.allow` 字段。与其他共享 skill 一致的问题

#### P2（可改进）
- Step 1 中"信息提取策略"区分了"当前对话中刚解决的"和"用户描述之前解决过的"两种场景，但后者的采集流程缺少具体引导问题列表（相比 ae-submit-bug 的 1a-1e 逐项引导）
- 硬规则第 3 条"提交前必须查重"在执行流程的 Step 1-5 中没有对应步骤。查重应该在 Step 2（格式化）之后、Step 3（确认）之前插入
- "用户清理提示"段落是一个很好的设计，但可能很多修复场景下用户不确定是否需要清理。建议增加默认值引导：如果 agent 无法判断，默认写"请等待 AE Team 确认更新后的清理建议"
- 主动触发规则列出了 6 种场景，但没有说明 agent 如何判断"修复成功"。建议补充：只有命令执行后输出正常且问题不再复现，才算修复成功
