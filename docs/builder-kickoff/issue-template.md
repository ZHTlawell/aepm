# 产品推进 Issue 模板

> **纪律**：每个产品一个主 tracking issue 开在 `turningsyn/ae-pm`（AE Team 中央看板，所有 builder 的迭代记录集中在这里），body 定范围，**评论按 Wave 记录进度**。每次 push 回写一条评论到主 issue，不是"做完再写"。

---

## Part A — Issue Body 模板

复制下面的骨架，首次建 issue 时填入：

```markdown
## 目标

把 {产品名} 从 idea → 可上架 TestFlight 状态。本 issue 是该产品的主 tracking issue（开在 `turningsyn/ae-pm`，AE Team 中央看板）。

## 背景

- **产品方向**: {从产品方向清单认领的方向编号 + 名称}
- **参考 App**: {借场景/交互的对标，不是抄}
- **上架判定信号**: {留存 X% / 订阅转化 Y% / 或其他最小信号；没基线可先留空}
- **代码仓库**: {owner}/product-{name}
- **Bundle ID**: {待确认}
- **路线**: Route B（CocoaPods + BCStoreKit + BCSensor + BCAdjust + BCNetwork + Work Chain 12 步）

## 推进状态（M0 → M3 milestones）

### M0 Idea

- [ ] idea 一页纸（产品名 / 核心场景 / 参考 App / 目标用户 / 上架信号）
- [ ] 产品负责人 GO

### M1 Speckit

- [ ] `/ae-speckit-brainstorm` 跑完，`speckit/` 已生成（6 模块）
- [ ] 产品负责人 review speckit 通过

### M2 本地可用程序

- [ ] `/ae-speckit-to-app` 跑完，工程能 build
- [ ] 模拟器 / 真机 E2E 跑通核心场景
- [ ] API Key 安全化（不能明文，红线）

### M3 TestFlight（约定截止日由产品负责人告知）

**P0 — 不做无法提交**

- [ ] 签名配置（DEVELOPMENT_TEAM + Bundle ID）— 找签名负责人
- [ ] ASC 建 App + 订阅商品（BCStoreKit 对接）— 找运营
- [ ] 隐私弹窗 + ATT
- [ ] Privacy Policy / Terms 公开 URL — 找运营 / 法务
- [ ] App Icon 1024x1024
- [ ] `/ae-app-to-testflight` 跑完，Build N 已分发

**P1 — 可 M3 后补（不挡 TestFlight）**

- [ ] `/ae-analytics-integrate` 跑完（Firebase + Adjust 双轨）
- [ ] App Store 截图（6.7" / 6.5" / 5.5"）
- [ ] ASO 文案（描述 + 关键词）

### P2 — 上架后迭代

- [ ] {按产品补充}

## 关键技术决策（Route B 默认）

| 决策点 | 方案 | 备注 |
|--------|------|------|
| 支付 | BCStoreKit | Route B 统一，不再用 Superwall |
| 埋点 | BCSensor（聚合 Sensors + Firebase + Adjust） | `/ae-analytics-integrate` 接入 |
| 归因 | BCAdjust | 同上 skill |
| 网络 | BCNetwork | Route B 强制 |
| 依赖管理 | CocoaPods | 不用 SPM |
| 构建流程 | Work Chain 12 步 | `/ae-speckit-to-app` 内置 |
| 用户体系 | 默认 0.1 跳过本地存储 / 需跨设备同步再接 BCAccount | 按产品定 |
| 后端 | 默认零后端 / 需要时 Spring Boot | 按产品定 |

## 待确认事项（阻塞项）

| # | 问题 | 找谁 |
|---|------|------|
| 1 | DEVELOPMENT_TEAM 复用哪个？ | 签名负责人 |
| 2 | ASC 权限 | 签名负责人 / 运营 |
| 3 | Adjust app token | 运营 |
| 4 | Privacy Policy URL | 运营 / 法务 |

## 最简路径（M0 → M3）

```
M0 Idea
  └─ /ae-speckit-brainstorm  （产品负责人 review）
M1 Speckit
  └─ /ae-speckit-to-app       （Route B 约束内置）
M2 本地可用程序
  ├─ /ae-analytics-integrate  （可选，时间紧先跳）
  └─ /ae-app-to-testflight
M3 TestFlight ─── 周期 review

开发侧并行事项         运营侧（有阻塞）
──────────            ──────────
签名 + Bundle ID       ASC 新建 App
隐私弹窗 + ATT         配订阅商品
App Icon               Privacy Policy 网页
API Key 安全化         Adjust token
                       App Store 截图
```

## 关联

- {父级主线 issue，例如 #IHVABC}
- {相关产品 issue}
```

---

## Part B — Wave 进度评论模板

每轮修复 / 迭代完成后（建议每次 push 都回写），按这个骨架评论：

```markdown
## Build {N} — Wave {N} {本轮主题}

commit `{hash}`, push 到 main/{branch}。{TestFlight 状态，例如 EXPORT SUCCEEDED / ASC 处理中}

### Wave {N} 修复（{X} 项）

**{分组 1}（{项数}）**
- {编号}: {修复描述} → {影响}
- {编号}: {修复描述} → {影响}

**{分组 2}（{项数}）**
- {编号}: {修复描述}

### 累计进展

| Wave | Commit | 修复 | 独立验证 |
|---|---|---|---|
| 1 | `{hash}` | {N} ({主题}) | {状态} |
| 2 | `{hash}` | {N} ({主题}) | {状态} |
| ... | ... | ... | ... |

### QA 复测重点（build {N}）

1. **{最关键流程}** —— {要验证的点}
2. **{次关键}** —— {要验证的点}
3. **日志抓取**: 关键字 `{tag}`，遇到失败贴 log

### 已知遗留（不挡 build {N}）

- {遗留项 1}
- {遗留项 2}
```

---

## 使用规则

1. **一个产品一个主 tracking issue**，不要拆散
2. **每次 push 必须回写 Wave 评论**，这是纪律不是建议
3. **编号连贯**：修复项用连续字母（R/S/T/U/V...）跨 Wave 不重置，方便追溯
4. **验证状态用固定词**：`FIXED High` / `PARTIAL` / `INVESTIGATION` / `REGRESSION`
5. **中台卡点不写在产品 repo 子 issue**：所有 skill 用不顺 / 能力缺失 / 工程生成 bug 一律提到 `turningsyn/ae-pm`，AE Team 在 ae-pm 内部路由到对应源仓

## 产品 issue vs 中台反馈 issue 的分流

| 类型 | 去向 | 示例 |
|------|------|------|
| 产品 bug / UX / 文案 | 产品 repo（子 issue） | "Paywall 按钮点击无响应" |
| 产品功能需求 | 产品 repo | "需要加聊天记录导出" |
| 所有 AE 工具链 / skill / 中台能力 / 工程生成反馈 | `turningsyn/ae-pm`（AE Team 内部路由，builder 不用自己分类） | "/ae-speckit-to-app 生成工程 build 失败" / "想一键接 Adjust 但没 skill" / "生成的 Xcode Bundle ID 字段丢失" |

中台反馈 issue 用简单模板：**场景 / 期望 / 实际 / 现有 workaround**。
