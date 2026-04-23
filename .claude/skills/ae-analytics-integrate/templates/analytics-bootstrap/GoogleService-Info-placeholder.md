# GoogleService-Info.plist 替换点标注

> 本模板是**对接点**，不提供实际 plist 内容。真正的埋点接入由 `/ae-analytics-integrate` skill 负责。
> 来源：bible-app trajectory 2026-04-15 comment "资源替换 / 8.4 GoogleService-Info.plist"

## 文件位置

```
{{PROJECT_ROOT}}/Template/Resources/ThirdParty/GoogleService-Info.plist
```

## 默认状态

BytesCell iOS template 默认携带某个参考项目的 plist（如 bible-app 克隆时是植物项目 `plant-914e9`）。**必须替换**，否则：
- Firebase Analytics 事件打到错误项目
- 推送 APNs 证书不匹配
- 审核可能因 Bundle ID 与 Firebase 项目 mismatch 被警告

## 替换流程（由 /ae-analytics-integrate 执行）

1. 在 Firebase Console 新建 iOS App（Bundle ID = 本产品 Bundle ID，如 `{{BUNDLE_ID}}`）
2. 下载对应的 `GoogleService-Info.plist`
3. 替换到 `Template/Resources/ThirdParty/GoogleService-Info.plist`
4. 确认以下字段与本产品一致：
   - `BUNDLE_ID` = `{{BUNDLE_ID}}`
   - `GOOGLE_APP_ID` = Firebase 项目该 App 的 ID
   - `PROJECT_ID` = Firebase 项目（如 `{{PRODUCT_ID}}-xxxxx`）
   - `GCM_SENDER_ID` = 推送 Sender ID

## 本 skill 的对接点（交给 /ae-analytics-integrate）

本 `ae-speckit-to-app` skill **不负责**：
- Firebase 项目的创建（需要谷歌账号权限）
- Adjust Dashboard 的账号申请和 token 申请（需要运营侧操作）
- 神策项目的创建（如需对齐公司体系）
- ATT 弹窗的文案（需产品 / 法务 review）

本 skill **负责**：
- ✅ 在 `BCConfig.swift` 模板中预留 Adjust token 占位（templates/config/）
- ✅ 在 `ComponentConfigWork.swift` 模板中调用 `BCTrack.setup()` 和 `BCAdjust.appDidLaunch()`
- ✅ 在 Podfile 模板中引入 BCSensor + BCAdjust（TS-010 / TS-011）
- ✅ 标注 `GoogleService-Info.plist` 为占位符等待埋点 skill 替换

## 验证（埋点 skill 完成后）

harness 可用如下命令确认埋点已就位：

```bash
# Firebase 项目一致性
plutil -extract BUNDLE_ID raw Template/Resources/ThirdParty/GoogleService-Info.plist
# 应输出 {{BUNDLE_ID}}

plutil -extract PROJECT_ID raw Template/Resources/ThirdParty/GoogleService-Info.plist
# 应输出 {{PRODUCT_ID}}-xxxxx，非默认 plant-xxxx
```

## 权限描述（InfoPlist.strings）

埋点 skill 同时负责把 `InfoPlist.strings` 中的权限描述替换为本产品文案（见 trajectory 坑记 "8.5 权限描述"）。bible-app 踩坑：默认模板有"拍照识别植物"文案，审核会拒。
