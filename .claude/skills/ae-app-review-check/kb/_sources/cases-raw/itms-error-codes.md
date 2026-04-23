# ITMS Error Codes — iOS App Store 提审常见错误码速查

**Source:** https://blog.csdn.net/midmirrorsoul/article/details/148144187
**Fetched at:** 2026-04-21
**Fetch method:** WebFetch

## 与隐私/元数据相关（本 kb 重点关注）

| Error Code | Apple 原文 | 触发条件 | 关联 Guideline |
|-----------|-----------|---------|----------------|
| ITMS-91053 | "Missing API declaration - Your app's code references APIs requiring reasons" | 使用了 Required Reason API 但 privacy manifest 中未声明 | 2.3.1 / 5.1 |
| ITMS-91056 | "Invalid privacy manifest - The PrivacyInfo.xcprivacy file is invalid" | PrivacyInfo.xcprivacy 包含无效的 key 或 value | 2.3.1 / 5.1 |
| ITMS-91061 | "Missing privacy manifest - Your app includes commonly used third-party SDK lacking manifest" | 引用的第三方 SDK 缺少 privacy manifest | 2.3.1 / 5.1 |
| ITMS-90683 | "Missing Info.plist key. Your app's code references [...] but Info.plist does not contain [...]" | 使用敏感数据 API 但 Info.plist 缺 purpose string | 5.1.1 / 5.1.5 |
| ITMS-90078 | "Missing push notification entitlement - entitlements do not include 'aps-environment'" | 使用 APNs API 但未声明 push notification 权限 | — |
| ITMS-90983 | "Missing purpose string in Info.plist for media classification." | iOS 16+ 需 media classification purpose string | 5.1.1 |

## 与 binary / 版本 / 签名相关（不在本 kb 主要范围，作为参考）

ITMS-90668 / ITMS-90087 / ITMS-90209 / ITMS-90125 / ITMS-90048 / ITMS-90426 / ITMS-90060 / ITMS-90062 / ITMS-90725 / ITMS-90098 / ITMS-90186 / ITMS-9000 / ITMS-90165 / ITMS-90046 / ITMS-90535 / ITMS-90809 / ITMS-90022 / ITMS-90025 / ITMS-90705 / ITMS-90096 / ITMS-90474 / ITMS-90475 / ITMS-90529
