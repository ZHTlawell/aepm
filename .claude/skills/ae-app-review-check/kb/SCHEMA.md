# KB Entry Schema

每个 YAML 文件 = 一条 Guideline（或 AI 审核规则）。文件名：`<guideline-id>-<slug>.yaml`。

## 必填字段

```yaml
guideline: "3.1.1"              # Apple Guideline 条款编号，AI 规则用 "ai-XXX"
chapter: "3-Business"           # 所属章节
title: "In-App Purchase"
severity: high                  # high | medium | low
official_text: |                # 官方条文摘要（3-6 行）
official_url: "https://developer.apple.com/app-store/review/guidelines/#3.1.1"

triggers:                       # 什么情况下此条适用（人读，用于判断是否扫）
  - "app has paywall"
  - "app sells digital content"

auto_checks:                    # 可执行检查规则（scan.py 逐条运行）
  - id: "3.1.1-storekit-import"
    type: grep                  # grep | file_exists | file_content_match | shell
    pattern: "import StoreKit"  # grep: pattern；file_exists: path
    include: "*.swift"          # 可选，grep 过滤
    expected: non_empty         # non_empty | empty | match | no_match
    severity: high              # 覆盖顶层 severity
    on_fail: "有 paywall 但未引入 StoreKit"
    case_refs: ["case-2026-014"]

review_notes_template: |        # 命中此条时追加到 Review Notes
  This app uses StoreKit 2 for all digital content purchases.

case_refs: []                   # 关联的历史拒审案例 id（来自 cases.jsonl）
```

## 可选字段

```yaml
conditions:                     # 只在特定条件下运行 auto_checks
  requires_any:
    - check: "grep"
      pattern: "PaywallView\\|Superwall"
      include: "*.swift"
fix_suggestions:                # 修复建议
  - "在 Paywall 引入 StoreKit 2，删除第三方支付 SDK"
updated_at: "2026-04-21"
```

## Rubric 字段（v0.66.0+，参与 6 维评分）

```yaml
rubric:
  dimension: D3                 # D1..D6 | null（null = 不参与 Rubric 评分）
  score_on_pass: 3              # 该条全部 auto_checks PASS 时贡献的分数（0..3）
  score_on_warn: 2              # WARN 时贡献的分数（0..3）
  score_on_fail: 0              # FAIL 时贡献的分数（0..3）
  weight: 1                     # 同维度多 entry 时的权重；默认 1
```

### 6 维定义

| 维度 | 含义 |
|------|------|
| **D1** | 法务合规（Privacy Policy / Terms / Subscription Terms / Schedule 2） |
| **D2** | Privacy Manifest（PrivacyInfo.xcprivacy / Required Reason API / 第三方 SDK manifest） |
| **D3** | 模板纯净度（无 fork 自其他 App 的字符串残留） |
| **D4** | 权限文案语义匹配（Info.plist usage description 与业务对应） |
| **D5** | Free 路径完整度（无 vaporware / Free 用户核心功能可走通或前置告知） |
| **D6** | Paywall 漏斗合规（Restore + Terms + Privacy + 自动续费披露 + 不强弹冷启动） |

不归属任一维度（普适或 review-notes 类）的 kb 条目可省略 rubric 字段或写 `rubric: { dimension: null }`，仍走 PASS/WARN/FAIL 老路径。

### 评分聚合

每个维度的最终分 = 该维度所有 kb 条目的 (status 对应分数 × weight) 之和 / 该维度的 cap × 3，四舍五入到 0-3。
若某维度的所有 kb 条目都未触发 auto_checks（app 无该 surface area），该维度记 N/A，不计入档位判定。

### 档位判定（详见 SKILL.md Phase 2.5）

- **T0** = D1≥2 AND D2≥2 AND 总分≥12 AND 无任一维度=0
- **T1** = T0 AND 总分≥16 AND 至少 4 维有分 AND 无任一维度=0
- **T2** = T1 AND 数据闭环条件（v1，留空）

## 命名约定

- Apple Guideline 条目：`{chapter}/{guideline}-{slug}.yaml`，如 `3-business/3.1.1-iap-storekit.yaml`
- AI 审核规则：`ai-review/ai-{slug}.yaml`，如 `ai-review/ai-webview-wrapper.yaml`
