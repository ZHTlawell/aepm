# AE PM Agent 安装指引

## 前置要求

- [Claude Code](https://claude.ai/code) 已安装
- Gitee 账号及 access token（在 [Gitee 设置 > 私人令牌](https://gitee.com/profile/personal_access_tokens) 中生成，需要 `issues` 和 `repo` 权限）

## 安装步骤

### 1. 克隆本 repo

```bash
git clone https://gitee.com/turningsyn/ae-pm.git
cd ae-pm
```

### 2. 配置 Gitee Token

```bash
mkdir -p ~/.config/ae-pm
cat > ~/.config/ae-pm/credentials.env << 'EOF'
GITEE_TOKEN=你的gitee_access_token
EOF
chmod 600 ~/.config/ae-pm/credentials.env
```

### 3. 配置 Claude Code

将本 repo 的 CLAUDE.md 链接到你的项目：

```bash
# 方式一：直接在 ae-pm 目录下使用 Claude Code
cd ae-pm
claude

# 方式二：将 CLAUDE.md 拷贝到你的工作目录
cp ae-pm/CLAUDE.md 你的工作目录/CLAUDE.md
```

## 验证

启动 Claude Code 后，告诉 agent：

> "帮我完成入驻确认"

Agent 会在入驻确认 issue（IHQ4H7）下方发 comment，确认你的配置成功。

## 更新

```bash
cd ae-pm
git pull origin main
```
