# AE 工具链全员实战 — 第一轮

## 为什么做这件事

过去做一个 App，流程是：产品出需求 → 设计画图 → 开发写代码 → 测试 → 上线。每个环节依赖专人，链路长，迭代慢。

现在 AI Agent 正在改变这个链路。从选题调研、竞品拆解、原型构建、代码生成到发布上架，越来越多的环节可以由 Agent 完成或辅助完成。这不是未来的事，是正在发生的事 — AE Team 过去几周已经用这套方式跑通了从 App 选型到成品生成的完整链路。

**这意味着什么？** 意味着团队中每个人 — 不只是开发 — 都有机会直接参与到产品构建的完整过程中。PM 可以自己出可运行的原型，开发可以用 Agent 加速从规格书到工程代码的转化，每个人对「一个 App 是怎么从零到一做出来的」都会有更完整的理解。

这是我们后续要逐步切入的方向。第一轮实战，就是让大家亲手体验一次这个完整路径。

---

## 你要做什么

**选一个你感兴趣的垂直 App，用 AE 工具链完整走一遍「研究 → 拆解 → 复刻 → 跑起来」的流程。**

每个人选不同方向的 App，等于同时探索多个垂直场景。走完一圈之后，你对 AI Native App 从选型到成品的完整路径会有自己的判断和手感。

---

## 学习资源

在开始之前，建议先了解以下内容：

| 资源 | 说明 |
|------|------|
| [Issue Driven 的课题与任务分解](https://t0agh1do4ba.feishu.cn/docx/AuegdRVTCoXdLsxBsRYcTGVjnpf) | AE Team 的协作方式 — 如何用 Issue 驱动任务推进，而不是传统的任务板。实战过程中的问题反馈、进展同步都会通过 Issue 进行 |
| [ae-pm README](https://gitee.com/turningsyn/ae-pm) | 产品经理工具包 — 覆盖从 App 研究、规格书提取到发布准备的完整流程，本次实战的核心工具 |
| [ae-go README](https://gitee.com/turningsyn/ae-go) | 全员通用助手 — 网页浏览、播客学习、飞书消息、多视角辩论、iPhone 操控、Mac 桌面操控等通用能力 |

---

## 你会经历的四个阶段

### 第一步：选题（30 分钟）

从 [research-targets.md](https://gitee.com/turningsyn/ae-speckit-examples/blob/master/research-targets.md) 里挑一个你感兴趣的 App。80+ 个方向覆盖健康、冥想、植物识别、食谱、习惯养成、专注力、穿搭、星座等。

选题标准就一条：**你自己觉得有意思、愿意花时间研究。**

建议挑功能聚焦的单场景 App（冥想、打卡、白噪音这类），不建议选音视频处理、强社交、金融交易。

选好后去 App Store 下载到手机上，自己先用一用，建立直觉。

### 第二步：研究 — 把目标 App 变成 Speckit

这一步你要让 AI Agent 帮你系统性地「拆解」这个 App，产出一份结构化的规格书（我们叫它 Speckit）。

Speckit 包含 6 个模块：产品定位、用户场景、技术架构、设计规范、数据模型、API 接口。相当于把一个 App 从外到内翻译成文档。

**有 iPhone 真机（推荐）：**

把目标 App 装到 iPhone 上，USB 连到 Mac，在 Claude Code 中：
```
/ae-app-to-speckit
```
Agent 会自动操控你的 iPhone — 打开 App、逐屏截图、分析 UI、构建功能清单、生成 speckit。你只需要在旁边看着，偶尔回答 Agent 的提问。

**没有 iPhone 真机：**

先用 Claude Code 做一个简易版 demo（Vibe Coding），然后提取：
```
/ae-demo-to-speckit
```
Agent 会从源码中提取 speckit。demo 不用做得很完美，功能覆盖 60-70% 就够。

**这一步结束后，你的项目目录下会多一个 `speckit/` 文件夹。** 打开看看，这就是你对目标 App 的结构化理解。

### 第三步：复刻 — 基于 Speckit 做自己的版本

有了 speckit，你已经对目标 App 的功能、设计、架构有了完整的拆解。现在用 AI 工具（Claude Code / Cursor / 其他）基于这份规格书，做一个你自己的版本。

可以加功能、改设计、换定位 — 随你发挥。

在 Xcode 模拟器或真机上跑起来，感受一下从零到成品的完整体验。

### 第四步：分享你的发现

走完一圈之后，准备一次分享。没有固定模板，从你感兴趣的角度切入就好：

- **产品视角**：这个产品哪里可以做得更好？有什么差异化的机会？
- **工程视角**：生成的代码哪些地方不够专业？架构上有什么可以改进的？
- **工具反馈**：工具链哪个环节卡住了？哪个 skill 不好用？哪里体验超预期？

说真实感受就好。

---

## 环境准备

宣讲结束后，请先完成环境搭建。全部在**终端**中执行（不是 Claude Code 对话中）：

```bash
# 1. 安装 ae-pm（产品研究 + App 拆解）
git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
cd ~/.ae/pm && bash cli/install.sh
source ~/.zshrc

# 2. 安装 ae-go（网页浏览 / 播客 / 飞书 / 辩论 等通用能力）
git clone https://gitee.com/turningsyn/ae-go.git ~/.ae/go
cd ~/.ae/go && bash cli/install.sh
source ~/.zshrc

# 3. 配置 Gitee Token（找管理员要）
mkdir -p ~/.config/ae
echo 'GITEE_TOKEN=你的token' > ~/.config/ae/credentials.env

# 4. 检查环境
ae doctor
```

然后为你的项目启用 ae-pm：

```bash
mkdir -p ~/Projects/my-app && cd ~/Projects/my-app
ae link pm .
```

**搞定了？** 运行 `ae doctor`，全绿就说明一切就绪。

**有 iPhone 真机的同学**，还需要搭建 iPhone 自动化环境。先为项目挂载 ae-go（移动自动化工具链）：

```bash
ae link go .
```

然后在 Claude Code 中说 `/ae-mobile-setup`，Agent 会引导你完成（一次性设置）。

---

## 遇到问题

环境搭建或使用过程中卡住了：
1. 先跑 `ae doctor` 看哪里报红，按提示修
2. 飞书群里直接问 AE Team
3. 或者在 Claude Code 中说"帮我提个 bug"，会自动提交到 Gitee

AE Team 在实战期间会优先响应大家的问题。

---

## 时间线

| 日期 | 事项 |
|------|------|
| 4/16 - 4/17 | 完成环境搭建，选题 |
| 4/17 - 4/25 | 各自探索 |
| 4/25 左右 | 分享会 |
