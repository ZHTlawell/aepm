# Apple — Privacy Manifest Files

**Source:** https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
**Fetched at:** 2026-04-21
**Fetch method:** Playwright (SPA requires JS)

---

## 核心事实

- **文件名固定**：`PrivacyInfo.xcprivacy`
- **平台版本**：iOS 17.0+ / iPadOS 17.0+ / Mac Catalyst 14.0+ / macOS 14.0+ / tvOS 17.0+ / visionOS 1.0+ / watchOS 10.0+
- **强制截止日**：**2024-05-01 起**，使用 Required Reason API 但未在 privacy manifest 中描述原因的 App 将被 App Store Connect 拒收（详见 "Describing use of required reason API"）
- **格式**：property list (plist)，顶层为 dictionary

## 顶层必填 key

| Key | 类型 | 说明 |
|-----|------|------|
| `NSPrivacyTracking` | Boolean | App 是否按 ATT 定义做 tracking。为 true 时必须填 `NSPrivacyTrackingDomains` |
| `NSPrivacyTrackingDomains` | Array<String> | tracking 的 internet 域名。用户未授权 ATT 时这些域名的网络请求会失败 |
| `NSPrivacyCollectedDataTypes` | Array<Dict> | 收集的数据类型（参考 "Describing data use in privacy manifests"） |
| `NSPrivacyAccessedAPITypes` | Array<Dict> | 使用的 Required Reason API 类别（参考 "Describing use of required reason API"） |

## 适用对象

- **App**：对所有平台都要填 data collection 信息；在 iOS/iPadOS/tvOS/visionOS/watchOS 上还要填 required reason API
- **第三方 SDK**：在 "SDKs that require a privacy manifest and signature" 清单中的 SDK 必须提供；使用 Required Reason API / 收集数据 / 联系 tracking 域名的 SDK 也必须提供
- **静态库 SDK**：Xcode 15+ 支持 static framework bundle resources，把 privacy manifest 打进去

## 创建方法（Xcode）

1. File → New File
2. Resource 区 → App Privacy File
3. 选目标 target
4. 文件默认命名 `PrivacyInfo.xcprivacy`（不可改）
