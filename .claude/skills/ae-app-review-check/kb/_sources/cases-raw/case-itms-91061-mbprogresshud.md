# Case ITMS-91061 — 第三方 SDK 缺少 privacy manifest

**Source:** https://blog.csdn.net/crasowas/article/details/144596383
**Fetched at:** 2026-04-21
**Apple Guideline:** 5.1 (Privacy) + 2.3.1 (元数据完整性)
**Rejection date effective:** 新 App 2024-11-12 起强制

## Apple Rejection Text (verbatim)

> "Your app includes 'Frameworks/MBProgressHUD.framework/MBProgressHUD', which includes MBProgressHUD, an SDK that was identified in the documentation as a privacy-impacting third-party SDK."
>
> "Starting November 12, 2024, new apps including such SDKs must have valid privacy manifest files."

## 涉及的 SDK（文中点名）

- MBProgressHUD
- AFNetworking

（完整清单参见 `apple-official/third-party-sdk-requirements.md`）

## 涉及的 API Category（Apple 警告邮件中引用）

- `NSPrivacyAccessedAPICategoryDiskSpace`
- `NSPrivacyAccessedAPICategoryFileTimestamp`
- `NSPrivacyAccessedAPICategorySystemBootTime`
- `NSPrivacyAccessedAPICategoryUserDefaults`

## 社区修复工具

**App Privacy Manifest Fixer** (shell 脚本，开源)
- 项目：https://github.com/crasowas/app_privacy_manifest_fixer
- 功能：扫描 Pods / SDK，自动识别缺失 privacy manifest，生成 template 补齐
- 集成方式：project build 时自动运行

## 对扫描器的启示

- 扫 `Frameworks/*.framework/` 和 `Pods/` 下的 SDK，对照 Apple 官方清单
- 任一命中 SDK 无 PrivacyInfo.xcprivacy → fail，Apple 会拒 ITMS-91061
