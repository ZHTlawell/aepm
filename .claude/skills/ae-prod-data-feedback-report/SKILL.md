---
name: ae-prod-data-feedback-report
description: "基于埋点数据 + speckit 生成产品数据反馈报告（含产品/运营/埋点改进建议）"
permissions:
  allow:
    - "Bash(ae sensors *)"
    - "Bash(python3 *sensors-query.py:*)"
    - "Bash(python3 *privacy-mask.py:*)"
    - "Bash(ae git issues *)"
    - "Write({workdir}/**)"
    - "Edit({workdir}/**)"
    - "Bash(cp *)"
    - "Bash(mkdir -p *)"
    - "Bash(ls *)"
dependencies:
  mcp: []
  cli:
    - name: ae
      verify: "ae version"
    - name: ae sensors
      verify: "ae sensors count"
      description: "神策数据查询 CLI，需要 ~/.config/ae/sensors.env 中有 SENSORS_API_SECRET"
  api_keys:
    - name: SENSORS_API_SECRET
      path: "~/.config/ae/sensors.env"
      description: "神策 API Secret，通过 HTTP header token 认证"
  scripts:
    - sensors-query.py
    - privacy-mask.py
smoke_test:
  command: "ae sensors count"
  expected_exit: 0
  description: "神策 API 连通性验证"
---

# Skill: 产品数据反馈报告 (ae-prod-data-feedback-report)

> **经 Spoly 实战验证 + 5 轮 subagent 迭代 + 产品团队反馈校正。**

## 触发条件

- 新 APP 上线 2-4 周后需首份数据反馈报告
- 需基于埋点数据给出产品迭代建议
- 需评估 Onboarding/付费/留存等核心漏斗表现

## 前置条件

1. `ae sensors count` 能返回数据
2. speckit 已就绪（通过 `ae-app-to-speckit`）
3. 知道目标 APP 的 `$app_name`

---

## 报告结构

```
报告头部
  数据来源（神策 project 名）、数据范围、产品版本、平台
  speckit 链接（Gitee URL）、截图目录（相对路径）

产品简介
  一句话定位 + 核心流程 + Tab 结构 + 商业模式 + 4 张关键截图

一、核心发现
  executive summary（粗体一段话，10 秒抓重点，基调平衡：问题+改善并列）
  5 个关键数字（每条 → [详见 X.X] 锚点链接）
  积极信号
  待确认事项

二、改进建议
  产品改进（P0/P1/P2，每条：问题+数据引用+≥3条具体措施+截图）
  运营改进（P0/P1/P2）
  埋点改进（必须/高/中）
  需对接的外部数据源

三、详细分析
  3.1 留存率 — D1/D7/D14 + 周 Cohort + 付费/免费分群 + 稳态 DAU
  3.2 DAU 与新增趋势 — ASCII 条形图（5-6 个关键节点）
  3.3 版本与核心指标 — 全量+活跃双口径，按版本拆关键指标
  3.4 核心漏斗 — 端到端主漏斗 + 付费漏斗 + Scan Limit + 评分
  3.5 功能模块 — Tab 渗透率 + Collection 深度 + 失败后行为 + 首屏问题
  3.6 用户路径：留存 vs 流失 — ★首日行为对比+倍数排序+Aha Moment+典型路径
  3.7 付费 vs 免费 — ★人均行为+留存+因果方向讨论
  3.8 Onboarding 漏斗
  3.9 技术质量（可选，压缩到 3-5 行）

附录
  A. 事件合并映射表
  B. 免费用户定义
  C. 数据口径说明（统一分母定义）
  D. 勘误记录
  E. Speckit 引用（Gitee 链接）
  F. 查询工具
```

### 行业基准参考值

以下基准值来自公开报告，用于报告中对标。**必须标注来源，不能编造。**

| 指标 | 基准值 | 来源 |
|------|--------|------|
| iOS D1 留存率 | ~24% | Phiture / Adjust 2025 Mobile App Trends |
| iOS D7 留存率 | ~10% | 同上 |
| Download → Trial Start（订阅 APP） | ~10.9% | Adapty State of In-App Subscriptions 2025（16k app 样本） |
| Trial → Paid 转正率 | 25%-38% | RevenueCat State of Subscription Apps 2025 |
| Utility 类首次续费留存 | 58.1% | RevenueCat 2025 |
| Hard paywall D35 download-to-paid | 10.7% | RevenueCat 2025 |
| App Store 评分弹窗转化率 | 10%-15% | 行业最佳实践 |

### 核心发现的 5 个关键数字选取规则

从以下维度中选 5 个最有 headline 价值的。**executive summary 段必须是一句话把最关键结论串起来，不要长段落堆砌。**

| 候选维度 | 选取条件 | 呈现要求 |
|---------|---------|---------|
| 留存率 | 必选。用上方基准表对标 | 如有改善趋势，同时写出改善幅度（"W4 比 W2 提升 X%"） |
| 留存最强信号 | 必选（来自 3.6 留存 vs 流失） | 突出差异对比："收藏 Nx > 拍照 Mx"（N>M 证明收藏更强）|
| 付费转化 | 必选。用 Download→Trial 口径，用上方基准表对标 | 标注 Trial Start ≠ Paid |
| Limit/墙触发流失 | 如有 scan limit/hard limit 则必选 | 给出流失人数和流失率（如"84.5% 直接流失"），建议含"展示沉没成本" |
| 核心指标当前值 | 必选。用最近 7 天活跃口径 | 如成功率等核心体验指标 |
| 体验满意度 | 如无满意度埋点则**必选为核心发现之一** | 标注"缺乏度量"，在埋点建议中标为"必须" |

---

## 执行流程

### Phase 1: 准备

**1.1 确认 APP 基本信息 + 记录报告头部参数**

```bash
ae sensors sql "select \$app_name, \$os, count(distinct \$device_id) as users, count(*) as events, min(date) as first_date, max(date) as last_date from events where \$app_name = '{APP}' group by \$app_name, \$os"
```

记录：总用户数（作为后续所有"渗透率"的统一分母）、project 名称、数据范围。

**1.2 读取 speckit**

理解 01-project-positioning.md（定位/商业模式）、02-user-scenarios.md（页面/流程）、feature-checklist.md（功能清单）。

**1.3 建立事件合并映射表**

```bash
ae sensors sql "select event, count(*) as cnt from events where \$app_name = '{APP}' and event not like '\$%' group by event order by cnt desc limit 100"
```

检查相似命名事件（xxx 和 xxxv2、xxx_new 和 xxx_old），建立合并映射表。**后续所有查询都用合并口径**，用 `event in ('eventA', 'eventA_v2')` 的方式。

**1.4 确认免费用户定义**

找到付费标记事件（如 `adjustajvip`），确认：
- 付费用户 = 触发过该事件的 $device_id
- 免费用户 = NOT IN 付费用户集合
- **后续所有"免费 vs 付费"对比使用统一定义**

**1.5 确认统一分母**

报告中的"渗透率"统一用 Phase 1.1 获取的总用户数作为分母，不要在不同章节用不同分母。

**1.6 验证 speckit 中的产品限制假设（★必做）**

speckit 中标注的产品限制（如"收藏是 Premium 功能"、"免费用户不能 XXX"）**必须用数据验证**，不能直接采信。

```bash
# 对 speckit 中每个标注为 Premium/付费限制 的功能：
# 查看免费用户有没有该行为
ae sensors sql "select count(distinct \$device_id) as free_users_with_action from events where \$app_name='{APP}' and event='{ACTION_EVENT}' and \$device_id not in (select distinct \$device_id from events where \$app_name='{APP}' and event='{PAID_MARK_EVENT}')"
```

如果免费用户有该行为 → speckit 的限制标注不准确，报告中不能使用"免费用户无法 XXX"的表述。

**1.7 记录 speckit Gitee 链接**

记录 speckit 的 Gitee 仓库链接（如 `https://gitee.com/{owner}/{repo}/tree/master/{app}/speckit`），用于报告附录引用。不能用本地路径或个人仓库链接。

### Phase 2: 数据采集

**所有指标区分"全量累计"和"最近 7 天活跃"双口径。**

#### 2.1 留存率

**D1/D7/D14 整体留存**（排除最后 N 天新增）：

```bash
# D1 留存（分母排除最后 1 天新增）
ae sensors sql "select count(distinct a.\$device_id) as d0, count(distinct b.\$device_id) as d1 from (select distinct \$device_id, date as first_date from events where \$app_name='{APP}' and \$is_first_day=1 and date<='{TODAY-1}') a left join (select distinct \$device_id, date from events where \$app_name='{APP}') b on a.\$device_id=b.\$device_id and b.date=date_add(a.first_date,1)"

# D7（分母排除最后 7 天）、D14（排除最后 14 天）同理，改 date<= 和 date_add 参数
```

**按周 Cohort 拆 D1**（4 周，每周 7 天）。注意：Cohort 必须从数据范围的第一个完整周开始编号，**不能跳过早期数据**。如果前几天样本小，也要标为 W1（可标注"样本小"），确保编号连续且覆盖全部数据：

```bash
ae sensors sql "select case 
  when a.first_date between '{W1_START}' and '{W1_END}' then 'W1'
  when a.first_date between '{W2_START}' and '{W2_END}' then 'W2'
  when a.first_date between '{W3_START}' and '{W3_END}' then 'W3'
  when a.first_date between '{W4_START}' and '{W4_END}' then 'W4'
  end as cohort, count(distinct a.\$device_id) as d0, count(distinct b.\$device_id) as d1
from (...) a left join (...) b on ...
group by cohort order by cohort"
```

**付费/免费分群留存**（D1 和 D7 都要）。

**稳态 DAU 推算**：

```
稳态 DAU ≈ 日新增 / (1 - D1 留存率)
例：日新增 1,000、D1 = 10.8% → 稳态 DAU ≈ 1,000 / 0.892 ≈ 1,121
如果当前实际 DAU ≈ 稳态值，说明全靠拉新驱动。
```

#### 2.2 核心漏斗（端到端）

对照 speckit 用户流程，从首页到最终价值行为逐步查询。

```bash
# 每步用合并口径，如：
ae sensors sql "select
  count(distinct case when event='home_exposure' then \$device_id end) as step1_home,
  count(distinct case when event='xxx_click' then \$device_id end) as step2_action,
  count(distinct case when event in ('result_exposure','result_v2_exposure') then \$device_id end) as step3_result,
  count(distinct case when event in ('collect_click','collect_v2_click') then \$device_id end) as step4_value
from events where \$app_name='{APP}'"
```

**规则**：
- 漏斗必须延伸到价值行为（收藏/购买）
- 转化率不能超过 100%。如果出现，修正分母（可能是多入口导致后续步骤用户>前置步骤）
- 每步给步骤转化率 + 累计转化率

**Scan Limit 分析**（如有）：

```bash
# 触达硬限制的用户，有多少后续付费？
ae sensors sql "select count(distinct \$device_id) as limit_users from events where \$app_name='{APP}' and event='identify_hardlimitbuy_exposure'"

ae sensors sql "select count(distinct \$device_id) as limit_then_paid from events where \$app_name='{APP}' and event='{PAID_EVENT}' and \$device_id in (select distinct \$device_id from events where \$app_name='{APP}' and event='identify_hardlimitbuy_exposure')"

# 限制前人均使用次数
ae sensors sql "select count(distinct \$device_id) as users, sum(case when event='{ACTION_EVENT}' then 1 else 0 end) as total_actions from events where \$app_name='{APP}' and \$device_id in (select distinct \$device_id from events where \$app_name='{APP}' and event='identify_hardlimitbuy_exposure')"
```

**付费漏斗**（Download→Trial 口径，分母 = Phase 1.1 的总用户数）。

**关键规则**：付费漏斗中的 "Trial Start" 用户数必须**等于 Phase 1.4 确认的付费标记事件用户数**（如 `adjustajvip`），不能用 `buy_click` 或 `subscriptionbuy_click`（这些是点击购买按钮的人，包含后来取消的，大于实际 Trial Start）。

**App 评分分析**（不要与调查问卷混淆）：

评分弹窗事件通常含 `review`/`rate` 关键字（如 `seekgoodreview_exposure`→`seekgoodreview_leavereview_click`），调查问卷事件含 `survey`/`feedback` 关键字。两者是完全不同的漏斗，不能混用。评分转化率 = 去评分人数 / 弹窗曝光人数。

#### 2.3 版本与核心指标

```bash
# 全量累计（了解历史）
ae sensors sql "select \$app_version, <关键指标> from events where \$app_name='{APP}' group by \$app_version"

# 最近 7 天活跃（了解当前真实体验）
ae sensors sql "select <关键指标> from events where \$app_name='{APP}' and date>='{7_DAYS_AGO}'"
```

**核心指标必须给出"最近 7 天活跃"加权值**，在核心发现中使用活跃值而非累计值。

如果 Cohort 留存有改善，**量化归因**到版本迭代。

#### 2.4 付费 vs 免费（★独立章节）

至少对比：人均核心行为次数、D1/D7 留存、功能渗透率。

**必须讨论因果方向**：用 scan limit 等限制性数据辅助判断"限制是否压低了免费用户行为"。

#### 2.5 留存 vs 流失（★独立章节）

对比次日回来 vs 没回来的用户，首日每个核心行为的人均次数。

```bash
# 定义留存用户子查询（复用 2.1 的逻辑）
# 对比 4-5 个核心行为，算倍数排序
```

**必须输出**：倍数排序表、Aha Moment 推断、留存/流失典型路径。

#### 2.6 功能模块

Tab 渗透率（分母 = Phase 1.1 总用户数）+ Collection 深度 + 失败后行为 + 首屏问题。

**必须包含的分析项**：
- **操作失败后行为**：计算重试率 vs 放弃率的百分比（如"重拍 60%、放弃 40%"），并结合 speckit 分析引导是否缺失（如"Snap Tips 只首次展示，后续失败不再出现"）
- **App 评分转化率**：评分弹窗曝光 → 实际去评分 的转化率，与行业基准（10-15%）对比
- **Onboarding 中权限弹窗的触发时机**：分析相机权限/通知权限是在 Onboarding 内还是首次使用时触发，这影响漏斗解读
- **Collection 作为回访驱动**：分析从 Collection 发起核心操作（如 Scan）的用户比例，如有则说明收藏可反向驱动核心行为，建议强化此闭环

#### 2.7 技术质量（可选）

扫描 error/failed/timeout 事件。**如果结论是"需开发确认"，压缩到 3-5 行。**

#### 2.8 数据自检（★必做，写报告之前）

所有数据采集完成后、写报告之前，执行以下交叉验证。**任何一项不通过都必须先排查修正再继续。**

**验证 1：付费用户定义一致性**

```bash
# 付费标记用户数 应 ≤ Paywall 点击购买人数 ≤ Paywall 曝光人数
ae sensors sql "select
  count(distinct case when event='{PAID_MARK_EVENT}' then \$device_id end) as paid_users,
  count(distinct case when event like '%buy_click%' or event like '%subscriptionbuy%' then \$device_id end) as buy_click_users,
  count(distinct case when event like '%purchaseui_exposure%' then \$device_id end) as paywall_users
from events where \$app_name='{APP}'"
```

**检查**：如果 paid_users > buy_click_users，说明付费标记事件选错了（可能是启动时自动触发的状态检查事件，不是真正的付费动作）。必须换一个事件。

**验证 2：漏斗单调递减**

```
检查核心漏斗每步用户数是否 ≤ 上一步。
如果 step_N > step_N-1，说明：
  a) 该步骤有多个入口（如详情页可从扫描/Category/Shop 进入），需要限定来源
  b) 或事件合并有误
修正方案：用 $device_id IN (上一步用户) 限定分母
```

**验证 3：识别成功率分母确认**

```bash
# succeed + failed + unmatched 应 ≈ begin
ae sensors sql "select
  sum(case when event like '%begin%' then 1 else 0 end) as begins,
  sum(case when event like '%succeed%' then 1 else 0 end) as succeeds,
  sum(case when event like '%failed%' then 1 else 0 end) as fails,
  sum(case when event like '%unmatched%' then 1 else 0 end) as unmatched
from events where \$app_name='{APP}' and event like '%identifyloading%'"
```

**检查**：
- 如果 succeed + failed ≈ begin，unmatched 是独立分支 → 成功率 = succeed / (succeed + failed)
- 如果 succeed + failed + unmatched ≈ begin → 成功率 = succeed / begin，**且报告中必须标注"含 unmatched"**
- 必须搞清楚 unmatched 是"识别过程的一种结果"还是"独立的状态"，选对分母
- **按版本拆成功率时必须使用与整体相同的分母口径**，不能在整体用 succeed/begin 而在版本维度用 succeed/(succeed+failed)

**验证 4：留存分母一致**

```bash
# 总用户数 ≈ D1 分母 + 最后一天新增
# 如果差距 >5%，说明 $is_first_day 的定义或日期过滤有问题
ae sensors sql "select count(distinct \$device_id) as total from events where \$app_name='{APP}'"
# 对比 D1 查询中的 d0 值
```

**验证 5：付费/免费对比数据交叉验证**

```
付费用户数 + 免费用户数 应 = 总用户数（误差 <1%）
付费用户人均行为 × 付费用户数 + 免费用户人均行为 × 免费用户数 ≈ 总事件数
```

**验证 6：报告数字与 Phase 1 定义一致**

```
报告中的 "Trial Start 用户数" 必须 = Phase 1.4 确认的付费标记事件用户数。
如果不等 → 报告用错了事件。buy_click ≠ Trial Start，subscriptionbuy_click ≠ Trial Start。

报告中的 "App 评分转化率" 必须来自评分弹窗事件（含 review/rate），
不能来自调查问卷事件（含 survey/feedback）。
```

**验证 7：留存 vs 流失倍数合理性**

```
留存用户人均收藏 × 留存用户数 + 流失用户人均收藏 × 流失用户数 ≈ 总收藏事件数
如果不等式不成立，说明子查询的分群定义有误。
倍数通常在 2-6x 范围内，超过 10x 需要检查是否有口径问题。
```

**验证 7：Cohort 边界无重叠无遗漏**

```
W1 + W2 + W3 + W4 的新增用户数之和 应 ≈ D1 查询中的总分母
如果差距大，说明 Cohort 日期边界有重叠或遗漏
```

### Phase 3: 撰写初稿

| # | 规则 |
|---|------|
| 1 | 截图用相对路径，speckit 引用用 Phase 1.7 记录的 Gitee 链接 |
| 2 | **截图尺寸**：正文单张 width="120"-"160"，漏斗流程串联 width="90"，建议配图 width="200"。不要用 280 |
| 3 | DAU 用 ASCII 条形图，5-6 个关键节点，标注"周末 ~X，工作日 ~Y"的倍数关系 |
| 4 | 每条建议配截图 + `→ [详见 X.X]` 锚点 + ≥3 条具体措施 |
| 5 | 行业基准**必须使用上方基准参考值表中的数字和来源**，不能自行编造 |
| 6 | 报告基调平衡：问题 + 改善并列 |
| 7 | 核心发现的留存信号突出差异对比（"收藏 Nx > 拍照 Mx"）|
| 8 | 付费转化用 Download→Trial 口径 |
| 9 | 漏斗转化率不超过 100% |
| 10 | 技术质量可选，压缩呈现 |
| 11 | 自查 checklist 不写进报告 |
| 12 | **建议不能与数据矛盾**：如果某指标已高于行业基准，不能建议弱化该环节 |
| 13 | **Onboarding 漏斗必须配连续截图**（如 launch→onboarding→paywall→home） |
| 14 | **executive summary 一句话**：把最关键结论串成一句粗体（如"获客优秀+留存是短板+趋势在改善"），不要长段落堆砌 |

### Phase 4: 独立评审

#### 4.1 数据质量检查

**结构与内容检查**：

| # | 检查项 |
|---|--------|
| 1 | 核心漏斗端到端？ |
| 2 | 新旧事件全部合并？ |
| 3 | 版本/成功率用活跃口径？ |
| 4 | Trial Start 和 Paid 区分？ |
| 5 | 留存 vs 流失独立章节？ |
| 6 | 付费 vs 免费独立章节？ |
| 7 | 每条建议有数据+优先级+≥3 措施？ |
| 8 | 埋点建议含外部数据源？ |
| 9 | speckit 推断的限制用数据验证了？ |
| 10 | 稳态 DAU 推算了？ |
| 11 | 报告基调平衡？ |
| 12 | Cohort 留存如有改善，量化归因到版本？ |
| 13 | 改进建议有没有"过度推断"？ |

**数据精度检查（★关键——逐项用 SQL 验证，不能只看报告文字）**：

| # | 检查项 | 验证方法 |
|---|--------|---------|
| 14 | 付费标记事件正确？ | 付费用户数 ≤ Paywall 点击购买数 ≤ Paywall 曝光数 |
| 15 | 漏斗每步单调递减？ | step_N ≤ step_N-1，否则分母有问题 |
| 16 | 识别成功率分母正确？ | succeed + failed (+ unmatched?) ≈ begin |
| 17 | 留存分母正确？ | D1 分母 + 最后一天新增 ≈ 总用户数 |
| 18 | 付费+免费 = 总用户？ | 误差 <1% |
| 19 | Cohort 无重叠无遗漏？ | W1+W2+W3+W4 ≈ D1 分母 |
| 20 | 渗透率分母全报告统一？ | 都是 Phase 1.1 的总用户数 |
| 21 | 同一指标不同章节数值一致？ | 交叉比对核心发现 vs 详细分析中的数字 |
| 22 | 核心发现用的是活跃口径？ | 不是累计口径 |

#### 4.2 使用者视角反馈（★必做，最多 3 轮迭代）

初稿通过 4.1 后，**站在产品负责人角度**评审：

```
你是这款 APP 的产品负责人，刚收到数据分析报告。你需要从以下角度评审：

1. **可行动性**：看完报告后，你知道明天做什么吗？哪些建议太抽象无法落地？
2. **优先级**：P0 建议是否真的最紧急？有没有更重要的事被放在 P2？
3. **数据可信度**：哪个数字和你了解的情况矛盾？
4. **遗漏**：你最关心但报告没分析的维度？
   （识别准不准？价格满不满意？竞品对比？地域差异？）
5. **过度推断**：哪些建议在没有数据支撑的情况下假设了因果关系？
   特别检查：如果某指标已经高于行业基准，报告是否还在建议"优化"它？
6. **信噪比**：哪些分析对你做决策没用，建议删除或压缩？
7. **产品机制假设验证**：报告中关于免费/付费功能边界的描述是否正确？
   用数据验证：报告说"免费用户不能 XXX"，但数据显示免费用户有 XXX 行为 → 结论错误

逐条给反馈，指出具体段落或数字。
```

根据反馈修正报告，最多迭代 3 轮。

### Phase 5: 修正与发布

1. 根据 Phase 4 反馈修正
2. 产品团队反馈优先于 Agent 判断
3. 附录添加勘误记录
4. 截图脱敏（`privacy-mask.py`）
5. 发布到 speckit 仓库 + 更新 issue

---

## 踩坑记录

| # | 错误 | 规则 |
|---|------|------|
| 1 | 只统计新版事件，漏了旧版 | Phase 1.3 建立合并映射表，后续所有查询用合并口径 |
| 2 | 核心漏斗在"操作成功"处断裂 | 漏斗必须延伸到价值行为（收藏/购买） |
| 3 | 用累计口径分析版本分布 | 活跃口径优先，累计只用于历史参考 |
| 4 | 从 speckit 推断产品限制 | 必须用数据验证（"免费用户有没有 xxx 行为？"）|
| 5 | 免费用户定义不一致 | Phase 1.4 确认唯一定义，全报告统一 |
| 6 | Trial Start 当 Paid 用 | 必须标注口径，给乐观/悲观预估 |
| 7 | 核心体验满意度遗漏 | 如无满意度埋点，必须在核心发现+埋点建议中提出 |
| 8 | 渗透率分母不统一 | Phase 1.5 确认统一分母 |
| 9 | 技术事件占大量篇幅 | "需开发确认"的技术事件压缩到 3-5 行 |
| 10 | 建议只给方向不给措施 | 每条建议至少 3 条具体可操作措施 |
| 11 | Cohort 留存改善未归因 | 如有改善趋势，量化归因到版本/功能变更 |
| 12 | 行业基准数值来源不明 | 必须使用 SKILL.md 中的基准参考值表，不能编造 |
| 13 | 付费漏斗中 Trial Start 用了 buy_click 而非实际付费标记 | 报告中 Trial Start 数 必须 = Phase 1.4 的付费标记用户数 |
| 14 | App 评分转化率与调查问卷混淆 | 评分事件含 review/rate，问卷含 survey/feedback，两者是不同漏斗 |
| 15 | 按版本拆成功率时口径与整体不一致 | 按版本拆必须使用与整体相同的分母定义 |
| 16 | speckit Gitee 链接指向错误仓库 | Phase 1.7 记录正确的 Gitee 企业仓库链接 |

## 输出产物

| 产物 | 位置 |
|------|------|
| 报告（Markdown） | `{speckit-repo}/{app}/analytics-report.md` |
| 脱敏截图 | `{speckit-repo}/{app}/analytics-screenshots/` |
| Standalone HTML | `content/research/{app}-report-standalone.html` |
| Issue 进度 | Gitee issue comment |

## 关联 Skill

- `ae-app-to-speckit` — 前置：生成 speckit
- `ae-analytics-integrate` — 如 APP 未接入埋点
- `ae sensors` CLI — 数据查询工具
