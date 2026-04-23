# ae-pm 端到端路径 — 从 idea 到 TestFlight

> **基于 ae-pm v0.49.0 结构性重写。** 核心范式：**Skill = 人类可确认中间品之间的变换**。整条流水线拆成 4 个人类可审阅的中间品 M0→M3，每个 skill 负责把一个中间品变成下一个。PM / 工程师在每个中间品处可以停下检查。

---

## 对内（AE Team / 产品负责人）技术语言

```
M0  Idea ─────────────── 产品想法 / demo 雏形 / 参考 App
 │
 │  [M0 → M1]  PM 工具箱（5 选 1，按起点）
 │             • /ae-speckit-brainstorm  (从零对话共创)  🆕
 │             • /ae-app-to-speckit      (从已上架 App 逆向)
 │             • /ae-demo-to-speckit     (从 demo 源码提取)
 │             • /ae-onboarding-design   (生成 Onboarding 规格)
 │             • /ae-paywall-design      (生成 Paywall 规格)
 │
M1  Speckit ──────────── 6 模块标准规格书 (产品/场景/架构/设计/数据/API)
 │
 │  [M1 → M2]  /ae-speckit-to-app  🆕（核心段，Route B 约束）
 │             • CocoaPods + BCStoreKit + BCSensor + BCAdjust + BCNetwork
 │             • Work Chain 12 步构建流水线
 │             • 内置 precheck（原 ae-preflight 已融入）
 │
M2  本地可用程序 ──────── Route B 代码骨架 + E2E 跑通
 │
 │  [M2 → M3]  发布段
 │             • /ae-analytics-integrate  (埋点双轨接入, optional)
 │             • /ae-app-to-testflight    (签名 → Archive → Upload)
 │
M3  TestFlight ───────── 可测 Build 已分发
```

---

## 对外（工程师）人话版本

```
┌──────────────────────────────────────────────────────────┐
│  Step 1  从产品方向清单里认领一个方向                     │
│  Step 2  跑 /ae-speckit-brainstorm → 对话产出 speckit/    │
│  Step 3  让产品负责人 review speckit，确认再往下           │
│  Step 4  跑 /ae-speckit-to-app → 生成可跑的 iOS 工程       │
│  Step 5  本地跑通，核心场景能 demo                        │
│  Step 6  跑 /ae-analytics-integrate（可选，时间紧先跳）   │
│  Step 7  跑 /ae-app-to-testflight → 交 TestFlight         │
│  Step 8  周期 review，讲卡点 + AE Team 采集需求           │
└──────────────────────────────────────────────────────────┘
```

**核心原则（工程师必须记住）**：
- 每跑完一段 skill，得到一个**人类可审阅的中间品**（speckit / 工程 / TestFlight Build）
- 中间品不对就停下来 fix，不要硬推下一段
- 跑不通就喊人（产品负责人 / AE Team），不要自己绕

---

## 每段详解

### M0 → M1：PM 工具箱（5 选 1）

| 起点是... | 用这个 | 输出 |
|---------|--------|------|
| 只有想法，没 demo 没参考 | `/ae-speckit-brainstorm` 🆕 | `speckit/` |
| 已有 demo 源码 | `/ae-demo-to-speckit` | `speckit/` |
| 参考某已上架 App | `/ae-app-to-speckit`（需连真机） | `speckit/` |
| 要补 Onboarding 设计 | `/ae-onboarding-design` | HTML/CSS/JS 幻灯片 |
| 要补 Paywall 设计 | `/ae-paywall-design` | HTML 或 Native StoreKit 2 |

**从空 idea 起步时默认走 `/ae-speckit-brainstorm`**（清单给的是方向，不是 demo，也不是参考 App）。

👥 involve：产品负责人（speckit review + 方向偏离预警）

### M1 → M2：核心段 `/ae-speckit-to-app`

这是技术约束最密集的一段。skill 本身是**薄 harness**，只做约束透传 + 模板装配 + precheck，具体构建由外部 harness（Claude Code / Codex）驱动。

输出：可在模拟器 / 真机本地运行的 iOS 工程（含后端骨架）。

**Route B 约束**（skill 内置，工程师不用手动配）：
- CocoaPods 依赖管理（不用 SPM）
- BCStoreKit（支付）+ BCSensor（埋点）+ BCAdjust（归因）+ BCNetwork（网络）
- Work Chain 12 步构建流水线

👥 involve：AE Team（skill 卡点反馈，每次卡点都提 issue 到 `turningsyn/ae-pm`）

### M2 → M3：发布段

| Skill | 作用 | 标记 |
|-------|------|------|
| `/ae-analytics-integrate` | Firebase + Adjust 双轨埋点 | optional（首版可跳过） |
| `/ae-app-to-testflight` | 签名 → Archive → Upload → TestFlight | 必做 |

👥 involve：签名负责人（DEVELOPMENT_TEAM / Bundle ID）+ 运营（ASC / Adjust token / Privacy URL）

---

## 工程师视角的三句话

1. **按顺序跑 3 段 skill**：`/ae-speckit-brainstorm` → `/ae-speckit-to-app` → `/ae-app-to-testflight`。埋点可选。
2. **每段跑完都有人类可审阅的中间品**。不对就停，不要硬推。
3. **卡在哪里就喊对应 owner**：产品/方向问题 → 产品负责人；skill 不顺 → AE Team（同时提 issue）。

## 中台 builder 视角的三句话

1. **使用这套流程的工程师是 ae-pm v0.49+ 的第一批真实用户**，他们的卡点就是 M0→M3 流水线的真实痛点。
2. **周期 review = 中台 backlog 刷新日**。需求 / 提升点直接进下一 sprint。
3. **能力缺失不是"以后再说"**。工程师提 issue → 当周内响应（workaround 或 commit）。

---

## 安装前置

工程师本机第一次用：

```bash
# 1. 克隆 + 装 CLI
git clone https://gitee.com/turningsyn/ae-pm.git ~/.ae/pm
bash ~/.ae/pm/cli/install.sh

# 2. 一键搭环境（配 Gitee Token + 装依赖 + 入驻确认）
ae setup
```

前置：Gitee 企业版 git 凭证已配好（SSH key 或 token 已有 turningsyn 组织读权限）。clone 403 去 `turningsyn/ae-pm` 提 issue 找 AE Team 开权限。
