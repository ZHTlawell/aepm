# ae-legal-generate Test Scenarios

## S1. 首次生成（付费 app，全流程）

**前置：**
- 已有 speckit（含 product-positioning / data-sharing / paywall）
- `~/.ae/legal/company.json` 已配置

**执行：**
```bash
cd /path/to/app-project
# 触发 /ae-legal-generate
```

**预期：**
- [ ] `legal/privacy-policy.html` 生成 + 无 `{{...}}` 残留
- [ ] `legal/terms-of-use.html` 含 `auto-renewable` + `cancel` 关键词
- [ ] `legal/paywall-copy.md` 含 7 要素（title / duration / per-period price / iTunes 扣款 / 自动续期 / 取消路径 / PP+ToU 链接）
- [ ] `legal/hosting.md` 列出 3 种方案 + 最终 URL 占位
- [ ] `legal/consistency-check.md` 对照 `PrivacyInfo.xcprivacy` + Podfile

---

## S2. 非付费 app（免费工具类）

**前置：** speckit 无 `paywall.md` 或 `paywall.sku` 为空

**预期：**
- [ ] `legal/privacy-policy.html` 照常生成
- [ ] `legal/terms-of-use.html` 照常生成，**不含** subscription terms 段落
- [ ] `legal/paywall-copy.md` **不生成**（或生成空文件带注释说明"本 app 无付费"）

---

## S3. 全局配置缺失

**前置：** `~/.ae/legal/company.json` 不存在

**预期：**
- [ ] skill 不静默继续，引导 PM 创建 `company.json` + 提供模板
- [ ] PM 创建后重跑，正常产出

---

## S4. speckit data-sharing 缺失

**前置：** speckit 无 `data-sharing.md`

**预期：**
- [ ] skill 阻塞，提示 PM 先补 data-sharing（采集字段 + 第三方 SDK）
- [ ] 不生成空 Privacy Policy（否则审核拒）

---

## S5. 品牌残留扫描

**前置：** 模板中有历史遗留 `CapVault` 字符串（模拟 bug）

**预期：**
- [ ] Phase 5 consistency-check 报 FAIL
- [ ] 明确指出残留文件 + 行号

---

## S6. 托管 URL 404 自检

**前置：** PM 填了占位 URL 但未真的部署

**预期：**
- [ ] Phase 5 curl 检测 404 → 报 FAIL
- [ ] 提示 PM 先部署再 `ae-asc-submit`

---

## S7. 跨产品复用 company.json

**前置：** 在 project-A 配置过 `~/.ae/legal/company.json`，切换到 project-B

**预期：**
- [ ] project-B 不需要重新配置公司主体
- [ ] 只需 project-B 自己的 speckit（product.name + data-sharing + paywall）即可跑通

---

## S8. 与 ae-paywall-integrate 集成

**前置：**
- `ae-legal-generate` 已产出 `legal/paywall-copy.md`
- 然后触发 `/ae-paywall-integrate`

**预期：**
- [ ] `ae-paywall-integrate` 的 ConversionPage 文案步骤**优先引用** `legal/paywall-copy.md`
- [ ] 如果 `legal/paywall-copy.md` 不存在，`ae-paywall-integrate` 提示先跑 `ae-legal-generate`

---

## S9. 与 ae-asc-submit Precheck 集成

**前置：**
- `legal/` 目录不存在（未跑 ae-legal-generate）
- 触发 `/ae-asc-submit`

**预期：**
- [ ] `ae-asc-submit` 前置检查报"法务三件套缺失" FAIL
- [ ] 指引 PM 先跑 `/ae-legal-generate`
