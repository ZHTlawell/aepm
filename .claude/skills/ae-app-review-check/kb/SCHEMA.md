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

## 命名约定

- Apple Guideline 条目：`{chapter}/{guideline}-{slug}.yaml`，如 `3-business/3.1.1-iap-storekit.yaml`
- AI 审核规则：`ai-review/ai-{slug}.yaml`，如 `ai-review/ai-webview-wrapper.yaml`
