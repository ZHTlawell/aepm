# ae-lark-feishu 评估报告

## 基本信息
- **Role**: shared
- **Skill**: ae-lark-feishu
- **依赖**: lark-cli (@larksuite/cli), Node.js (npm)

## Test Stories

### Story 1: 基础 happy path — 读取群聊消息
- **Prompt**: "帮我看一下 AE 群里最近的消息"
- **Expect**:
  1. 检查 lark-cli 安装（`which lark-cli`）
  2. 检查认证状态（`lark-cli auth status`），确认 tokenStatus 为 valid
  3. 搜索群聊（`lark-cli im +chat-search --query "AE" --format pretty`）获取 chat_id
  4. 用 chat_id 拉取消息（`lark-cli im +chat-messages-list --chat-id oc_xxx --format pretty`）
  5. 向用户展示消息内容摘要，格式清晰
  6. 如消息中有图片，告知用户可下载查看
- **Max Time**: 60s

### Story 2: 带参数的复杂查询 — 时间范围 + 关键词搜索
- **Prompt**: "搜一下上周三飞书群里谁提到了 speckit"
- **Expect**:
  1. 前置检查通过（lark-cli 已安装 + token 有效）
  2. 正确计算"上周三"的日期，生成 ISO 8601 时间范围参数
  3. 使用 `lark-cli im +messages-search --query "speckit" --start "..." --end "..." --format pretty` 搜索
  4. 展示匹配的消息列表，包含发送者和时间
  5. 如果需要更多上下文，能切换到 `--format json` 获取详情
- **Max Time**: 60s

### Story 3: 边界场景 — lark-cli 未安装时的引导
- **Prompt**: "帮我读一下飞书群消息"（在 lark-cli 未安装的环境下执行）
- **Expect**:
  1. `which lark-cli` 返回未找到
  2. 引导用户安装：`npm install -g @larksuite/cli`
  3. 安装后验证：`lark-cli --help | head -1`
  4. 检查认证状态，如未认证则引导 `lark-cli auth login --domain all`
  5. 说明 Device Flow 认证流程：浏览器打开 URL + 输入 user code
  6. 认证完成后做连通性验证（`lark-cli im +chat-search --query "test" --format pretty`）
  7. 全部通过后才执行用户原始请求
- **Max Time**: 180s

### Story 4: 核心输出验证 — 会议妙记与逐字稿获取
- **Prompt**: "帮我拉一下昨天下午那个产品评审会的会议纪要和逐字稿"
- **Expect**:
  1. 前置检查通过
  2. 用 `lark-cli vc +search --start "昨天日期" --end "昨天日期" --format pretty` 搜索会议
  3. 从搜索结果中匹配"产品评审会"，获取 meeting_id
  4. 用 `lark-cli vc +notes --meeting-ids <meeting_id> --format pretty` 获取 doc token
  5. 分别读取 AI 纪要（`lark-cli docs +fetch --doc <note_doc_token>`）和逐字稿（`lark-cli docs +fetch --doc <verbatim_doc_token>`）
  6. 展示 AI 纪要摘要（含总结、待办、关键决策）
  7. 展示逐字稿（含说话人、时间戳）
  8. 两部分内容结构清晰，不混淆
- **Max Time**: 90s

### Story 5: 集成与安全验证 — 发送消息前的确认机制
- **Prompt**: "帮我在 AE 群里发一条消息：明天下午 3 点开技术评审会"
- **Expect**:
  1. 前置检查通过
  2. 搜索群聊获取 chat_id
  3. 在执行发送前，必须先展示完整消息内容和目标群给用户确认
  4. 等待用户明确确认后才执行 `lark-cli im +messages-send --chat-id oc_xxx --text "..."`
  5. 如果用户说取消或修改，不发送原内容，按用户指示处理
  6. 发送成功后告知用户消息已发送
  7. 使用 `--format pretty` 展示给用户，需要提取详情时才用 `--format json`
- **Max Time**: 60s

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
| SKILL.md 完整性 | ✅ | 触发条件明确（飞书/Lark 相关关键词）；有 4 步前置条件检查流程（安装→认证→登录→连通性测试）；8 个核心能力分别有详细命令示例；有 2 个完整工作流示例；有 5 条重要规则；有输出格式指引（pretty vs json） |
| 依赖可达性 | ✅ | lark-cli 已安装（/usr/local/bin/lark-cli）；安装方式 `npm install -g @larksuite/cli` 合理；Node.js 为前置依赖但 macOS 通常已有 |
| 权限声明 | ⚠️ | frontmatter 缺少 `permissions.allow` 字段。实际大量使用 Bash 命令（lark-cli 各种子命令），应声明 `Bash(lark-cli:*)` 权限 |
| 注册一致性 | ✅ | templates/go/CLAUDE.md 第 15 行注册为"飞书消息读写、搜索、会议纪要获取（`/ae-lark-feishu`）"；templates/pm/CLAUDE.md 第 146 行注册为"飞书消息与会议 | `/ae-lark-feishu`"。共享 skill 在两个角色模板中均正确注册 |
| 逻辑健壮性 | ✅ | lark-cli 未安装有引导安装流程；token 过期有重新登录引导；有连通性验证步骤；发送消息前有必须确认规则；身份区分（user 读/bot 写）明确。前置检查失败时不执行后续操作 |

### 发现的问题

#### P0（阻断）
- 无

#### P1（影响体验）
- frontmatter 缺少 `permissions.allow` 字段。lark-cli 的 Bash 调用在 `ae link` 合并权限时不会被自动授权，用户可能需要手动批准每次调用

#### P2（可改进）
- SKILL.md 结构偏"参考手册"（命令列表），缺少 Phase 划分。建议增加简要的流程概览：前置检查 → 理解用户意图 → 选择能力 → 执行 → 展示结果
- 核心能力第 6 项"发送消息"中提到"bot 身份"但命令示例中没有 `--as bot` 参数。SKILL.md 描述说需要 bot 身份，但实际命令未体现，可能导致执行失败或身份混淆
- smoke_test 使用 `lark-cli --version` 但 SKILL.md Step 1 使用 `lark-cli --help | head -1` 验证安装，两者不一致。建议统一
- 会议妙记功能依赖用户有飞书视频会议权限和妙记功能开通。SKILL.md 未提及此前置条件，如果用户企业未开通妙记，`lark-cli vc +notes` 会失败但无降级提示
- 前置条件检查的 Step 4 连通性测试使用 `--query "test"` 搜索群聊，如果用户没有名称含"test"的群会返回空结果，可能被误判为连通性失败。建议改为不带 query 的列表命令
