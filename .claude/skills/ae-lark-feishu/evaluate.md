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

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 0/5 (0%)
- **平均耗时**: 34.2s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 基础 happy path — 读取群聊消息 | 2/5 | 31.0s | 依赖未安装，权限被拒后阻塞 | 正确检测缺失依赖并尝试安装，但被 permission 拒绝后仅给出手动指引，未继续流程 |
| 带参数的复杂查询 | 1/5 | 21.4s | 同上，且未展示日期计算能力 | 未尝试计算"上周三"日期，核心搜索逻辑完全未触及 |
| 边界场景 — 未安装引导 | 1/5 | 40.2s | 触发 max turns (10)，陷入重试循环 | 这恰好是该 story 要测的场景，却是表现最差的——应优雅降级而非死循环 |
| 会议妙记与逐字稿 | 2/5 | 37.7s | 依赖未安装 | 正确推算"昨天"为 2026-04-12，说明日期逻辑可用；但核心 vc 命令链完全未执行 |
| 发送消息确认机制 | 2/5 | 40.6s | 依赖未安装 | 输出中列出了完整的后续计划（搜索→确认→发送），意图正确但从未执行 |

## 瓶颈分析
- **测试环境缺少 lark-cli 且 permission 策略阻止自动安装**：所有 5 个 story 均卡在 `npm install -g @larksuite/cli` 这一步。Skill 尝试运行安装命令但被测试 harness 的权限机制拒绝，之后未能自动恢复。建议：① 测试环境预装 lark-cli（哪怕是 stub/mock 版本）；② Skill 内部增加"安装被拒后的降级路径"——明确告知用户手动安装后说"已装好"即可继续，而非等待或重试。
- **Story 3 max turns 死循环**：唯一专门测试"未安装引导"的 story 反而因重复尝试安装耗尽 10 轮 turn。说明 Skill 缺少**重试上限 / 状态记忆**逻辑——被拒一次后应切换策略（纯文本引导），而非反复调用同一被拒命令。
- **核心业务逻辑零覆盖**：由于全部卡在安装阶段，消息读取、跨群搜索、日期参数计算、会议妙记拉取、发送前确认等核心能力均未被验证。当前测试结果无法反映 Skill 的真实业务能力。

## 结论
Skill 的前置检查逻辑基本正确（能检测缺失依赖、尝试自动安装），但缺少安装被拒后的优雅降级和重试熔断机制，导致在无 lark-cli 环境下 0% 通过。**最高优先级：修复 Story 3 的死循环问题并在测试环境预装 lark-cli stub，才能开始验证核心业务能力。**

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 0/5 (0%) | 34.2s |
