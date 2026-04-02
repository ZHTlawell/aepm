---
name: ae-lark-feishu
description: "飞书/Lark 消息读取、搜索、发送、会议妙记/逐字稿 — 当用户提到飞书、Lark、群消息、聊天记录、会议纪要、妙记时触发"
---

# Skill: 飞书消息与会议操作 (lark-feishu)

## 触发条件

当用户提到飞书、Lark、群消息、聊天记录、会议纪要、妙记、逐字稿，或要求读取/搜索/发送飞书消息时触发。

## 前置条件检查与自动安装

执行任何飞书操作前，必须先完成以下检查。如果检查不通过，按顺序引导用户完成安装和配置。

### Step 1: 检查 lark-cli 是否已安装

```bash
which lark-cli && lark-cli --help | head -1
```

如果未安装，引导用户安装：

```bash
# 需要 Node.js 环境
npm install -g @larksuite/cli
```

安装后验证：
```bash
lark-cli --help | head -1
# 预期输出: lark-cli — Lark/Feishu CLI tool.
```

### Step 2: 检查认证状态

```bash
lark-cli auth status
```

检查输出中的关键字段：
- `tokenStatus`: 如果是 `valid` 则直接可用；如果是 `needs_refresh` 会自动刷新；如果是 `expired` 或命令报错则需要重新登录
- `userName`: 确认是当前用户

### Step 3: 认证登录（如需要）

如果未认证或 token 已过期：

```bash
# 申请所有域的权限（推荐首次使用）
lark-cli auth login --domain all

# 或只申请特定域（最小权限）
lark-cli auth login --domain im,vc,docs,contact,calendar
```

这是 Device Flow 认证：
1. 命令会输出一个验证 URL 和 user code
2. **告诉用户**：在浏览器打开该 URL，输入 user code 完成授权
3. 命令会自动等待授权完成

授权完成后再次验证：
```bash
lark-cli auth status
# 确认 tokenStatus 为 valid，userName 正确
```

### Step 4: 确认可正常访问（快速测试）

```bash
# 搜索一个群聊来验证连通性
lark-cli im +chat-search --query "test" --format pretty
```

如果报错 `401` 或 `token expired`，重新执行 Step 3。

**以上检查全部通过后，方可执行后续操作。**

## 核心能力

### 1. 搜索群聊

根据关键词查找群聊，获取 `chat_id`：

```bash
lark-cli im +chat-search --query "群名关键词" --format pretty
```

### 2. 读取群消息

用 `chat_id` 拉取消息列表：

```bash
# 最近消息（默认50条，按时间倒序）
lark-cli im +chat-messages-list --chat-id oc_xxx --format pretty

# 指定时间范围
lark-cli im +chat-messages-list --chat-id oc_xxx --format pretty \
  --start "2026-03-31T00:00:00+08:00" --end "2026-03-31T23:59:59+08:00"

# 获取完整 JSON（含 message_id、file_key 等详情）
lark-cli im +chat-messages-list --chat-id oc_xxx --format json --page-size 50
```

### 3. 搜索消息

跨群搜索消息内容：

```bash
# 按关键词搜索
lark-cli im +messages-search --query "关键词" --format pretty

# 限定群聊 + 时间范围
lark-cli im +messages-search --query "关键词" \
  --chat-id oc_xxx \
  --start "2026-03-30T00:00:00+08:00" \
  --end "2026-03-31T23:59:59+08:00" \
  --format pretty

# 只看 @我 的消息
lark-cli im +messages-search --is-at-me --format pretty

# 按发送者筛选
lark-cli im +messages-search --sender ou_xxx --format pretty

# 按消息类型筛选（group 群聊 / p2p 私聊）
lark-cli im +messages-search --chat-type group --query "关键词" --format pretty
```

### 4. 下载图片/文件

消息中的图片/文件需通过 message_id + file_key 下载：

```bash
# Step 1: 从 JSON 格式的消息列表中提取 message_id 和 file_key
# 图片 file_key 格式: img_v3_xxx
# 文件 file_key 格式: file_xxx

# Step 2: 下载
mkdir -p /tmp/feishu-images
cd /tmp/feishu-images && lark-cli im +messages-resources-download \
  --message-id om_xxx \
  --file-key img_v3_xxx \
  --type image \
  --output filename.png

# Step 3: 用 Read 工具查看图片
# Read /tmp/feishu-images/filename.png
```

### 5. 读取私聊消息

通过对方的 open_id 读取 P2P 对话：

```bash
# 先搜索用户获取 open_id
lark-cli contact +search-user --query "姓名" --format pretty

# 用 user-id 读取私聊
lark-cli im +chat-messages-list --user-id ou_xxx --format pretty
```

### 6. 发送消息（Bot 身份）

发送消息需要 bot 身份（`--as bot`）：

```bash
# 发送文本到群聊
lark-cli im +messages-send --chat-id oc_xxx --text "消息内容"

# 发送 markdown 到群聊
lark-cli im +messages-send --chat-id oc_xxx --markdown "**加粗** 内容"

# 发送私聊
lark-cli im +messages-send --user-id ou_xxx --text "消息内容"

# 发送图片
lark-cli im +messages-send --chat-id oc_xxx --image /path/to/image.png

# 回复某条消息
lark-cli im +messages-reply --message-id om_xxx --text "回复内容"

# 在 thread 中回复
lark-cli im +messages-reply --message-id om_xxx --text "回复内容" --reply-in-thread
```

### 7. 会议妙记与逐字稿

从飞书视频会议中获取 AI 纪要和完整逐字稿：

```bash
# Step 1: 按日期搜索会议
lark-cli vc +search --start "2026-04-02" --end "2026-04-02" --format pretty

# Step 2: 用 meeting_id 获取文档 token
# 返回 note_doc（AI 纪要）和 verbatim_doc（逐字稿）两个 doc token
lark-cli vc +notes --meeting-ids <meeting_id> --format pretty

# Step 3a: 读取 AI 纪要（含总结、待办、关键决策）
lark-cli docs +fetch --doc <note_doc_token> --format pretty

# Step 3b: 读取逐字稿（含说话人、时间戳的完整转写）
lark-cli docs +fetch --doc <verbatim_doc_token> --format pretty
```

也可以通过 minute_token 或日历事件查询：

```bash
# 通过 minute_token 查询（从飞书妙记 URL 提取：feishu.cn/minutes/<token>）
lark-cli vc +notes --minute-tokens obcnxxxxx --format pretty

# 通过日历事件查询
lark-cli vc +notes --calendar-event-ids <event_id> --format pretty
```

### 8. 读取飞书文档

```bash
# 通过 doc token 或 URL 读取文档内容
lark-cli docs +fetch --doc <doc_token_or_url> --format pretty

# 搜索文档
lark-cli docs +search --query "关键词" --format pretty
```

## 完整工作流示例

### 示例 A: 读取群消息

1. **搜索群聊**: `lark-cli im +chat-search --query "XX" --format pretty` → 获取 chat_id
2. **拉取消息**: `lark-cli im +chat-messages-list --chat-id oc_xxx --format pretty` → 展示概览
3. **如需图片**: 用 `--format json` 重新拉取 → 提取 file_key → 下载 → 用 Read 查看
4. **总结**: 向用户汇报消息内容和关键信息

### 示例 B: 获取会议纪要/逐字稿

1. **搜索会议**: `lark-cli vc +search --start "日期" --end "日期"` → 获取 meeting_id
2. **获取 doc token**: `lark-cli vc +notes --meeting-ids <id>` → 获取 note_doc + verbatim_doc
3. **读 AI 纪要**: `lark-cli docs +fetch --doc <note_doc> --format pretty`
4. **读逐字稿**: `lark-cli docs +fetch --doc <verbatim_doc> --format pretty`

## 其他常用命令

```bash
# 查看认证状态
lark-cli auth status

# 搜索群聊（按更新时间排序）
lark-cli im +chat-search --query "关键词" --sort-by update_time_desc --format pretty

# 批量获取消息详情
lark-cli im +messages-mget --message-ids "om_xxx,om_yyy" --format pretty

# 查看 thread 消息
lark-cli im +threads-messages-list --message-id om_xxx --format pretty
```

## 重要规则

1. **发送消息前必须确认** — 发送/回复消息会被其他人看到，必须先让用户确认内容
2. **优先用 pretty 格式** — 展示给用户时用 `--format pretty`，需要提取详情时用 `--format json`
3. **图片必须下载后查看** — 消息列表只显示 file_key 引用，需下载到本地后用 Read 工具查看
4. **注意身份区分** — 读取消息用 user 身份（默认），发送消息用 bot 身份
5. **时间格式** — ISO 8601 带时区：`2026-03-31T00:00:00+08:00`
