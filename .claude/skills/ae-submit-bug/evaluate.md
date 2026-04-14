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

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 34.1s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 完整 bug 提交 happy path | 1/5 | 54.4s | 10 轮对话耗尽仍未完成 | 用户已提供完整信息（描述+复现+验证标准），agent 仍无法在 10 turns 内走完流程，说明 tool call 效率极低或存在冗余追问 |
| 笼统描述的追问流程 | 4/5 | 16.7s | — | 正确识别"用不了"为笼统描述，追问具体化；未一次问完所有问题；未尝试在信息不全时提交。扣 1 分：一次列了 3 个子问题，未严格逐项推进 |
| 查重命中已有 issue | 1/5 | 24.6s | 未执行查重就开始追问 | 核心测试点是查重，agent 完全跳过 `ae git issues list` 查重步骤，直接进入追问环节。用户已提供足够信息启动查重，违反硬规则"提交前必须查重" |
| issue 格式和验证标准质量检查 | 3/5 | 53.5s | 查重命令被拒绝 3 次；未读 `~/.ae/<role>/CLAUDE.md` 做路由 | 格式化质量较好：标题符合 `[BUG] 产品名 — 问题简述`，body 包含 5 段结构。扣分：1) 输出被截断，验证标准不完整；2) 未读 `~/.ae/go/CLAUDE.md` 的 Issue 路由表确定目标仓库（anti-pattern）；3) 未展示给用户确认即停止 |
| 多 bug 拆分 + ae git CLI 集成 | 0/5 | 21.5s | API 速率限制 | 完全未执行，触发 rate limit。无法评估拆分逻辑和 CLI 集成 |

## 瓶颈分析
- **Turn 效率低（Story 1）**: 用户一次性提供了完整信息（问题描述、复现线索、验证标准），agent 应跳过已知项直接进入查重→格式化→确认流程，但 10 轮仍未完成。根因可能是：agent 对"已知项跳过"的判断不准，仍逐项追问；或 tool call 链过长（读 CLAUDE.md→查重→格式化→确认 每步一轮）。**建议**: 在 SKILL.md 中增加明确的"信息充分性检查清单"，让 agent 一次性判断哪些已提供、哪些需追问，减少不必要的轮次。
- **查重步骤被跳过（Story 3）**: agent 优先追问而非查重，违反硬规则。SKILL.md 的流程是 Step 1（收集）→ Step 2（查重），但 agent 理解为"必须所有信息收集完毕才能查重"。**建议**: 在 SKILL.md 中明确"当用户提供了足够的关键词（产品名+问题类型）时，可在追问的同时并行执行查重"，或将查重提前到 Step 1 之后立即执行。
- **Issue 路由缺失（Story 4）**: agent 未读取 `~/.ae/go/CLAUDE.md` 中的 Issue 路由表来确定目标仓库，这是 anti-pattern 中明确列出的。**建议**: 在 SKILL.md Step 5 中将"读取路由表"作为第一个动作加粗标注，并在 Step 2 查重时也要求先确定目标仓库。

## 结论
Skill 当前质量较差（20% 通过率），仅笼统追问场景表现合格。**优先修复**: 1) 查重步骤的执行时机和强制性；2) happy path 的 turn 效率（信息充分时应 3-4 轮完成）；3) Issue 路由表读取的显式提示。建议在 SKILL.md 中增加"信息充分性快速判断"指引和"查重可与追问并行"的说明。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 1/5 (20%) | 34.1s |
