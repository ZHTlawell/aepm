# Builder Kickoff — 内部入门引导

> **定位**：本目录材料仅供有 `ae-pm` 仓库权限的组织内部人员参考（AE Team 成员 / 被授权的 product builder）。
> **不是**面向 PM 终端用户的运行时内容，ae-pm 主 README 不会引用本目录。

## 谁该看

- 新加入 AE Team 的成员：理解 M0→M3 流程 + 入门 Builder 角色
- 被授予 product builder 角色的组织内工程师：从零起一个产品走到 TestFlight

## 文件

| 文件 | 用途 |
|------|------|
| `engineer-bootstrap-prompt.md` | **技术流程引导** — 8 Stage prompt，粘贴进 Claude Code 使用（M0→M3 的薄 orchestrator，从 idea 到 TestFlight） |
| `builder-cadence-prompt.md` | **周期节奏对齐** — 粘贴进 Claude Code，帮你对齐当前阶段 / 下一个时点 / 必交付物（认领 → Demo → TestFlight → 打分 → 迭代） |
| `ae-pm-flow.md` | M0→M3 流程图 + 工程师 7 步人话版 |
| `issue-template.md` | 产品 tracking issue 模板（Part A body + Part B Wave 评论） |

## 如何使用

两份 prompt 定位互补，按场景选：

- **完全空白起步（没 idea 落地、没 repo、没 speckit）** → 用 `engineer-bootstrap-prompt.md`，从头走 M0→M3 技术流程
- **已经在推进产品、要对齐周期节奏和交付物** → 用 `builder-cadence-prompt.md`，每进入新阶段或新周重新跑一次

通用步骤：

1. 本机装好 ae-pm：
   ```bash
   git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
   bash ~/.ae/pm/cli/install.sh
   ae setup
   ```
2. 建空目录 / 打开产品目录 → 启动 Claude Code
3. 打开对应的 prompt 文件，把代码块整段粘贴进对话框
4. Claude 从 Stage 0 开始引导你作答

全程：Claude 负责追问 + 触发对应 skill（`/ae-speckit-brainstorm` / `/ae-speckit-to-app` / `/ae-app-to-testflight` / `/ae-onboarding-design` / `/ae-paywall-design` 等）；你负责回答 + 在每个中间品处停下让产品负责人 review；遇到卡点按 `builder-cadence-prompt.md` Stage 3 的路由提 issue。

## 相关

- `~/.ae/pm/CLAUDE.md` — ae-pm 的完整 agent 指令（用户运行时）
- `~/.ae/pm/README.md` — ae-pm 的面向 PM 用户说明
- `~/.ae/pm/constraints/` — 技术选型约束、评审流程、升级指引（用户运行时）
