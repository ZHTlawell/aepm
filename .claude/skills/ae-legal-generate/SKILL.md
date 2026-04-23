---
description: "App 法务三件套生成 — Privacy Policy + Terms of Use + Subscription Terms，从 speckit 一键产出 HTML + 付费墙文案 + 托管方案，规避 Apple 3.1.2a / 5.1.1 / Schedule 2 拒审"
permissions:
  allow:
    - "Bash(grep *)"
    - "Bash(find *)"
    - "Bash(cat *)"
    - "Bash(curl *)"
    - "Bash(python3 *)"
dependencies:
  mcp: []
  cli:
    - name: python3
      verify: "python3 --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "python3 --version"
  expected_exit: 0
  description: "python3 available for template rendering"
last_updated: "2026-04-23"
---

# Skill: 法务三件套生成 (ae-legal-generate)

> **定位：** 上架前合规资产生成器。**不影响主流程**（app 本地/真机跑通不需要真实协议，占位 URL 能编译能跑），但**上 App Store 前必须就位**，否则触发 Apple 拒审（Guideline 3.1.2a / 5.1.1 / Developer Program Schedule 2）。

## 触发条件

- PM 说"生成协议"、"Privacy Policy"、"法务文档"、"付费墙文案"、"要提审了协议还没准备"
- `/ae-asc-submit` 的 Precheck"法务三件套就位"报 FAIL
- `/ae-app-review-check` 标记 Guideline 3.1.2a / 5.1.1 存在风险

## 核心原则

1. **纯模板替换，不让 LLM 重写条款** — 协议措辞由律师模板固化，变量替换即可。LLM 重写 = 合规风险（可能遗漏必需条款或产生无效陈述）
2. **speckit 单一来源** — 品牌/法律主体/采集字段/SKU 全部从 speckit 读，不在生成流程中手填
3. **产出 = 可直接托管的 HTML + 可直接贴到付费墙的文案**，不是"待完善的草稿"
4. **一致性自检** — 生成后自动对照 `PrivacyInfo.xcprivacy` 和 Privacy Nutrition Label，不一致 → 报 FAIL（否则 5.1.1 拒审）

## 输入

从 speckit 抽取，**全部必填**（缺失即 FAIL）：

| 字段 | speckit 位置 | 举例 |
|------|-------------|------|
| `product.name` | `product-positioning.md` | Pray / WePray |
| `company.subject` | `company.json`（全局）或 speckit | 杭州某某科技有限公司 |
| `company.email` | 同上 | support@xxx.com |
| `jurisdiction` | `company.json` | China / US / Singapore |
| `data-sharing.fields` | `data-sharing.md` | 邮箱、设备 ID、IP、OS 版本... |
| `data-sharing.third-parties` | `data-sharing.md` | Firebase / Adjust / 神策 / Apple IAP |
| `paywall.sku`（付费 app 必填）| `paywall.md` | weekly $5.99 / yearly $39.99 / 7-day trial |

**全局配置**（公司主体可跨产品复用）：
- `~/.ae/legal/company.json` — 公司主体、email、jurisdiction（一次配置，所有产品共享）
- 产品 speckit 中只需覆盖 `product.name` 和 `data-sharing` / `paywall.sku`

## 输出

全部写到项目 `legal/` 目录：

| 文件 | 用途 | 下游消费者 |
|------|------|-----------|
| `legal/privacy-policy.html` | 可直接托管的 Privacy Policy | `ae-asc-submit` 填 Privacy Policy URL |
| `legal/terms-of-use.html` | 可直接托管的 Terms of Use（含 Schedule 2 subscription terms 段落）| App 内"服务条款"入口 + 付费墙"完整条款"链接 |
| `legal/paywall-copy.md` | 付费墙 7 要素文案片段（Markdown，便于复制到 SwiftUI）| `ae-paywall-integrate` 的 ConversionPage 文案 |
| `legal/hosting.md` | 托管方案 + 最终 URL 占位 | PM 填 URL 后 `ae-asc-submit` 引用 |
| `legal/consistency-check.md` | 与 `PrivacyInfo.xcprivacy` + Nutrition Label 的一致性报告 | `ae-app-review-check` 引用 |

## 执行流程

### Phase 1: 输入收集

```bash
# 1. 公司主体（全局配置）
cat ~/.ae/legal/company.json 2>/dev/null || echo "MISSING"

# 2. 产品信息
cat speckit/product-positioning.md
cat speckit/data-sharing.md 2>/dev/null || echo "MISSING"
cat speckit/paywall.md 2>/dev/null  # 付费 app 才有
```

Agent 手工校验：
- `company.json` 5 个字段齐全（subject / subject_en / email / jurisdiction / website）
- `data-sharing.md` 含"采集字段清单"+"第三方 SDK 清单"两段
- 付费 app：`paywall.md` 含至少一个 SKU（title / duration / price）

任一 FAIL → 阻塞，先修输入。

**全局配置缺失 → 引导 PM 创建 `~/.ae/legal/company.json`：**

```json
{
  "subject": "杭州某某科技有限公司",
  "subject_en": "Hangzhou XX Technology Co., Ltd.",
  "email": "support@example.com",
  "jurisdiction": "China",
  "website": "https://example.com"
}
```

**speckit data-sharing 缺失 → 阻塞**，提示 PM 先补 `speckit/data-sharing.md`（采集字段清单 + 第三方 SDK 清单）。

### Phase 2: 渲染 HTML

Agent 读 `templates/privacy-policy.html.tmpl` + `templates/terms-of-use.html.tmpl`，按 speckit + company.json 的字段做变量替换（Mustache 风格 `{{...}}`），写到项目 `legal/` 目录。

**替换规则：**
- `{{var}}` / `{{var.nested}}` — 简单变量，直接替换
- `{{#array}}...{{/array}}` — 数组循环段，对每个元素展开一次（`data_sharing.fields`、`paywall.sku`）
- `{{#optional}}...{{/optional}}` — 条件段，字段存在且非空才保留（如 `paywall.sku` 整段；非付费 app 删除 subscription terms 段）
- `{{^optional}}...{{/optional}}` — 反向条件，字段不存在才保留（用于 section 编号切换）

**强约束：** 产出 HTML 中**不得有任何 `{{...}}` 残留**。agent 产出后用 `grep -o '{{[^}]*}}' legal/*.html` 自检，有命中即 FAIL。

**首版实现建议：** agent 直接基于模板 + 输入数据生成完整 HTML（不依赖模板引擎脚本）。后续版本可在 `scripts/` 下抽取 `legal-render.py` 做机械化。

### Phase 3: 生成付费墙 7 要素文案

付费 app 才执行（无 `paywall.sku` 则跳过）。

渲染 `legal/paywall-copy.md`，7 要素齐全：

1. **Title** — 从 `paywall.sku.title`
2. **Duration** — weekly / monthly / yearly
3. **Per-period price** — 从 SKU 换算（$39.99/year → 约 $3.33/month）
4. **"Payment charged to iTunes account"** — 固定文案
5. **"Auto-renewable, cancel 24h before period end"** — 固定文案
6. **取消路径** — "iTunes Account Settings"
7. **Privacy Policy + Terms of Use 链接** — 用 `hosting.md` 中占位的托管 URL

### Phase 4: 托管方案

**默认 Vercel**（个人账户，5 分钟上线）：

```bash
# 引导 PM 在 ~/.ae/legal/ 建立独立 Vercel 项目（一次配置，多产品复用）
cd ~/.ae/legal
vercel deploy legal/  # 产出 URL 如 https://legal-xxx.vercel.app/{product-slug}/privacy-policy.html
```

可选方案（`legal/hosting.md` 文档化 3 选 1）：

| 方案 | 优点 | 缺点 |
|------|------|------|
| Vercel（默认）| 5 分钟上线，自动 HTTPS，免费 | 个人账户，非公司主体 |
| 公司官网子目录 | 正规，和品牌一致 | 需 IT/运维协作 |
| CDN + OSS | 中间路线 | 需账号 + 配置 |

PM 选定 → URL 写入 `legal/hosting.md` 的"最终 URL"段。

### Phase 5: 一致性校验

生成 `legal/consistency-check.md`，自动对照：

| 检查项 | 对照源 | 通过标准 |
|--------|--------|---------|
| 采集字段一致 | `PrivacyInfo.xcprivacy` vs Privacy Policy | Privacy Policy 列出的字段 ⊇ xcprivacy 声明的字段 |
| 第三方 SDK 一致 | `PrivacyInfo.xcprivacy` 的 `NSPrivacyTracking` + Podfile | Privacy Policy 披露的 SDK ⊇ xcprivacy + Podfile 中的追踪类 SDK |
| Nutrition Label 一致 | ASC App Privacy 配置 vs Privacy Policy | （手工 review，生成待办清单） |
| Subscription Terms 就位 | `terms-of-use.html` | grep `auto-renewable` + `cancel` + 7 要素关键词命中 |
| 品牌残留扫描 | 所有 HTML | 不含 `CapVault` / `WePray`（非本产品名）/ 历史品牌 |

任一 FAIL → 阻塞 done criteria，PM 修复后重跑。

## 与其他 skill 的关系

```
                     speckit（冻结）
                         ↓
                 ae-legal-generate
                         ↓
      ┌──────────────────┼──────────────────┐
      ↓                  ↓                  ↓
ae-paywall-integrate  ae-app-review-check  ae-asc-submit
（引用 paywall-copy）  （引用 consistency） （Precheck 检查就位 +
                                             填 Privacy Policy URL）
```

- **上游**：speckit（product-positioning / data-sharing / paywall）+ 全局 `~/.ae/legal/company.json`
- **下游**：
  - `ae-paywall-integrate` — ConversionPage 文案引用 `legal/paywall-copy.md`（替代硬编码 7 要素）
  - `ae-app-review-check` — 知识库补 case"3 份协议缺一 = 拒审"，引用 `legal/consistency-check.md`
  - `ae-asc-submit` — Precheck"法务三件套就位"检查 `legal/` 产出完整；Phase 1 元数据引用托管 URL

## Done Criteria

| D | 检查项 |
|---|--------|
| D1 | `legal/privacy-policy.html` 存在 + 无 `{{...}}` 残留 + 无历史品牌残留 |
| D2 | `legal/terms-of-use.html` 存在 + 含 Schedule 2 subscription terms 段落（grep `auto-renewable` 命中）|
| D3 | 付费 app：`legal/paywall-copy.md` 存在 + 7 要素齐全（关键词 7 项全部命中）|
| D4 | `legal/hosting.md` 存在，最终 URL 填写 + curl 200（不是 404）|
| D5 | `legal/consistency-check.md` 所有检查项 PASS（或已手工 review 标注）|

## 已知限制

- **模板语言覆盖**：首版仅产出英文 + 中文双语，其他语言暂时 fallback 到英文。扩展其他语言需先增加律师审阅的模板
- **Nutrition Label 一致性**：ASC App Privacy 配置是 UI 产物，无法纯代码对照；Phase 5 只能产出"待 PM 手工 review 清单"
- **法律主体变更**：`~/.ae/legal/company.json` 修改后需重跑所有已生成产品的 `ae-legal-generate`，没有增量更新机制

## 版本记录

- v0.62.0 (2026-04-23) — 首版发布（响应 #IJD7GE 伍新奎补充建议）
