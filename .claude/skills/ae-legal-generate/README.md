# ae-legal-generate

App 法务三件套生成 — Privacy Policy + Terms of Use + Subscription Terms 一键生成，规避 Apple 拒审。

## 定位

**上架前合规资产生成器**。不属于主流程（app 跑起来不需要），属于**发布准备链**，和 `ae-app-review-check` / `ae-asc-submit` 同组。

## 什么时候用

- 准备上 App Store 前，要提交 Privacy Policy URL / Terms of Use / Subscription Terms
- `/ae-asc-submit` 的 Precheck"法务三件套就位"报 FAIL
- `/ae-app-review-check` 标记 3.1.2a / 5.1.1 / Schedule 2 相关风险

## 不解决什么

- App 本地/真机跑不起来的问题（那是 `ae-speckit-to-app` 的范畴）
- TestFlight internal testing 分发（internal 不需要 Privacy Policy）
- 律师级别的条款定制（本 skill 用固化模板，复杂主体/特殊业务需律师审阅）

## 产出

在项目 `legal/` 目录：

```
legal/
├── privacy-policy.html       # 可直接托管
├── terms-of-use.html         # 含 Schedule 2 subscription terms
├── paywall-copy.md           # 付费墙 7 要素文案（ae-paywall-integrate 消费）
├── hosting.md                # 托管方案 + 最终 URL
└── consistency-check.md      # 与 PrivacyInfo.xcprivacy + Nutrition Label 一致性报告
```

## 全局配置

公司主体跨产品复用，一次配置：

```bash
mkdir -p ~/.ae/legal
cat > ~/.ae/legal/company.json <<'EOF'
{
  "subject": "杭州某某科技有限公司",
  "subject_en": "Hangzhou XX Technology Co., Ltd.",
  "email": "support@example.com",
  "jurisdiction": "China",
  "website": "https://example.com"
}
EOF
```

## 触发词

"生成协议" / "Privacy Policy" / "法务文档" / "付费墙文案" / "要提审了协议还没准备"

## 下游联动

| 下游 skill | 消费点 |
|-----------|--------|
| `ae-paywall-integrate` | ConversionPage 文案引用 `legal/paywall-copy.md` |
| `ae-app-review-check` | 知识库 case 引用 `legal/consistency-check.md` |
| `ae-asc-submit` | Precheck 检查 `legal/` 产出完整 + Phase 1 元数据引用托管 URL |

## 已知限制

- 首版仅支持英文 + 中文模板，其他语言 fallback 英文
- Nutrition Label 一致性只能产出手工 review 清单（ASC UI 无法纯代码对照）
- 法律主体变更需手工重跑所有产品（无增量更新）
