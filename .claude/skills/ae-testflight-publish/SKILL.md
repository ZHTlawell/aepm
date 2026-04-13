---
description: "从源码工程到 TestFlight 可安装的全流程引导（Apple 注册 → 签名 → Archive → 上传 → 分发）"
permissions:
  allow:
    - "mcp__playwright__*"
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(xcrun *)"
    - "Bash(security find-identity:*)"
    - "Bash(python3 *)"
    - "Bash(plutil *)"
dependencies:
  mcp:
    - playwright
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: xcrun
      verify: "xcrun --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version && claude mcp list 2>/dev/null | grep -q playwright"
  expected_exit: 0
  description: "xcodebuild + Playwright MCP available"
---

# Skill: TestFlight 发布全流程 (ae-testflight-publish)

> **经 bible-app (Faithful Guide) 端到端实跑验证。** 所有步骤、约束、故障排查均来自真实发布踩坑，非理论推演。

## 触发条件

PM 需要将一个能本地编译的 iOS 工程发布到 TestFlight，典型场景：
- Vibe Coding 产出的 demo 需要上真机给团队/用户试用
- 首次发布，从未注册过 App ID / ASC App
- 之前上传过，现在要推新版本

## 核心原则

1. **PM 不懂 iOS 发布术语** — 不抛 "Provisioning Profile"、"Distribution Certificate"，给具体的「做什么 → 预期看到什么」
2. **Automatic Signing 优先** — 开发 + TestFlight 阶段不走 Manual，让 Xcode 自动管理证书和 Profile
3. **先跑 ae-preflight** — 本 skill 假设 preflight 扫描已通过（API Key 已外部化、PrivacyInfo 已创建、App Icon 已就位、Bundle ID 已清理）。如未跑过，先执行 `/ae-preflight`
4. **推荐先接埋点** — 没有埋点的 TestFlight 版本 = 盲测，建议先跑 `/ae-analytics-setup` 接入 Firebase + Adjust，再上传 TestFlight（约束 ios-pub-027）
5. **每个 Phase 完成确认后再继续** — 不跳步，Apple 生态的依赖链环环相扣
5. **收集 constraint_candidates** — 过程中发现的新约束记录到 publish-state.yaml，供 ae-postflight 回写

## 前置条件

| 条件 | 验证方式 | 说明 |
|------|---------|------|
| Xcode 15+ 已安装 | `xcodebuild -version` | 需要支持 visionOS 之后的 archive 格式 |
| Apple Developer 账号 | PM 提供 Apple ID | 需已付费 $99/年，许可协议已接受 |
| Playwright MCP 可用 | `claude mcp list` 包含 playwright | Phase 1 浏览器自动化必需 |
| ae-preflight 已通过 | 项目根目录有 `publish-state.yaml` 且 preflight.status=done | 或手动确认：编译通过 + 无硬编码 Key + 有 App Icon |
| ae-analytics-setup 已完成（推荐） | Firebase + Adjust SDK 已接入 | 非必须，但强烈推荐：无埋点 = 盲测 |
| 项目可编译 | `xcodebuild build` → BUILD SUCCEEDED | 编译不通过 = 全流程阻塞 |

### Playwright MCP 环境检查

Phase 1 需要通过浏览器操作 Apple Developer Portal 和 App Store Connect。

```bash
# 确认 Playwright MCP 已注册
claude mcp list 2>/dev/null | grep playwright
```

如果未注册：

```bash
# ⚠️ 必须用 --browser chrome — Apple CDN 通过 TLS 指纹拦截 Playwright 自带 Chromium，
#    导致 developer.apple.com 和 appstoreconnect.apple.com 的 CSS/JS 返回空响应（页面白屏）
# ⚠️ 必须用 --user-data-dir — 持久化登录态，避免每次重新 2FA
# ⚠️ 必须用 --timeout-action 15000 — Apple 重型 SPA 的 click/fill 操作默认 5s 必超时
claude mcp add playwright -s user -- npx @playwright/mcp@latest --browser chrome --user-data-dir ~/.config/playwright-profile --timeout-action 15000
```

注册后需**重新开始对话**，新对话中 `browser_navigate` 等工具才会出现。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | 包含 project.yml 或 .xcodeproj 的根目录 |
| 产品名称 | 是 | 如 "Faithful Guide"，将用于 ASC App 名称 |
| Apple ID | 是 | 用于登录 Developer Portal 和 ASC |
| Bundle ID | 否 | 如已在项目中配置则自动读取；首次需确认 |

---

## Phase 0: 项目状态扫描

在动手之前，快速确认项目当前状态。

**0a. 确认 preflight 已通过**

```bash
# 检查 publish-state.yaml
cat publish-state.yaml 2>/dev/null | grep -A2 "preflight:"

# 如果不存在，做快速检查
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS Simulator" 2>&1 | tail -5
grep -rn 'sk-proj-\|sk-live-\|sk-test-' --include="*.swift" .
find . -name "AppIcon*" -path "*/Assets.xcassets/*"
```

如果 preflight 未通过 → 先执行 `/ae-preflight`，不继续。

**0b. 读取项目配置**

```bash
# 项目类型
ls project.yml 2>/dev/null && echo "XcodeGen project" || echo "Standard Xcode project"

# 当前签名配置
grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_STYLE" project.yml *.xcodeproj/project.pbxproj 2>/dev/null

# Scheme 列表
xcodebuild -list 2>/dev/null | grep -A 20 "Schemes:"
```

**0c. 确认是首次发布还是更新**

向 PM 确认：
> 这个 App 之前上传过 TestFlight 吗？
> - **首次** → 需要完成 Phase 1（Apple 注册）+ Phase 2-4
> - **更新** → 跳到 Phase 2 Step 2.5（bump build number）→ Phase 3-4

---

## Phase 1: Apple 身份注册（Playwright 浏览器自动化）

**目标：在 Apple 的两个网站上完成注册 — Developer Portal 注册 Bundle ID + App Store Connect 创建 App。**

### ⚠️ 关键认知：两个网站、可能两个账号

| 网站 | 域名 | 管什么 | 谁有权限 |
|------|------|--------|---------|
| Developer Portal | developer.apple.com | Bundle ID、证书、设备、Provisioning Profile | **Account Holder**（个人账号=本人；组织账号=管理员） |
| App Store Connect | appstoreconnect.apple.com | App 记录、TestFlight、审核、IAP 商品 | Account Holder + Admin + App Manager |

**踩坑实录：** bible-app 发布时，Account Holder (sunshinee_7) 和 Admin (ligenjian007) 是不同的 Apple ID。Admin 在 ASC 有完整权限，但 Developer Portal 显示 "Access Unavailable"。必须用 Account Holder 的 Apple ID 才能在 Portal 注册 Bundle ID。

**先向 PM 确认：**

> 1. 你的 Apple Developer Program 是**个人账号**还是**组织账号**？
> 2. 你用哪个 Apple ID 登录 developer.apple.com？
> 3. 如果是组织账号，Account Holder 是谁？你的角色是什么？

### Step 1.1: 登录 Developer Portal

```
1. browser_navigate → https://developer.apple.com/account
2. 如果跳转到 idmsa.apple.com 登录页：
   - browser_type → 填入 Apple ID
   - browser_click → Sign In
   - browser_type → 填入密码
   - browser_click → Sign In
3. 等待 2FA — 提示 PM 在 iPhone/Mac 上批准或输入验证码
4. browser_snapshot → 确认看到 Account 页面
```

**检查项：**

| 看到什么 | 意味着 | 怎么办 |
|---------|--------|--------|
| Account 页面 + Membership 信息 | 登录成功，有 Portal 权限 | 记录 Team ID，继续 |
| "Access Unavailable" | 当前 Apple ID 无 Portal 权限 | 需要用 Account Holder 的 Apple ID 登录 |
| "Enroll" 按钮 | 还没加入 Developer Program | 需要先付 $99 注册 |
| 黄色横幅：许可协议 | DPLA 需要接受 | 执行 Step 1.1b |
| 多个组织选择页 | 同一 Apple ID 关联多个组织 | 选择正确的组织（约束 ios-pub-014） |

### Step 1.1b: 接受 DPLA 许可协议（如有）

Apple Developer Program License Agreement 更新后必须由 Account Holder 接受，否则无法注册 App ID 和上传构建。

```
1. browser_snapshot → 确认协议提示内容
2. browser_click → 勾选 "I have read and agree"
3. browser_click → Submit
4. browser_snapshot → 确认协议已接受
```

### Step 1.2: 确认 Bundle ID

Bundle ID 注册后**永远不可更改**，跟 PM 确认：

> **你的 App 需要一个全球唯一的 ID：**
> - 推荐格式：`com.{组织域名反转}.{产品名小写}`
> - 例如：`com.scaleglobal.faithfulguide`
> - ❌ 不要包含 Demo、Test、Example（约束 ios-pub-005）
> - ❌ `com.scaleglobal.*` 可能已被其他团队占用（约束 ios-pub-010，Bundle ID 全球唯一）
>
> **如果 Bundle ID 被占用，改用组织实际域名或个人前缀。**
> bible-app 经验：`com.scaleglobal.FaithfulGuide` 被占用 → 改为 `com.qinxu.FaithfulGuide`。

### Step 1.3: 在 Developer Portal 注册 Bundle ID

```
1. browser_navigate → https://developer.apple.com/account/resources/identifiers/list
2. browser_snapshot → 确认在 Identifiers 页面
3. browser_click → 点击「+」按钮
4. browser_click → 选择「App IDs」→ Continue
5. browser_click → 选择「App」类型 → Continue
6. browser_type → Description 填产品名称
7. browser_click → 选择「Explicit」
8. browser_type → 输入确认的 Bundle ID
9. 按需勾选 Capabilities（InAppPurchase + AppGroups 推荐默认勾选）
10. browser_click → Continue → Register
11. browser_snapshot → 确认注册成功
```

**约束 ios-pub-013：** Bundle ID 必须在 Developer Portal 注册后，ASC 创建 App 时的 Bundle ID 下拉框才会出现。顺序不能反。

### Step 1.4: 在 App Store Connect 创建 App

```
1. browser_navigate → https://appstoreconnect.apple.com/apps
2. browser_snapshot → 确认在 Apps 页面（可能需要重新登录）
3. browser_click → 点击「+」→「New App」
```

**⚠️ Playwright 踩坑：** ASC 是重型 React SPA，`browser_click` 在点击后等待导航稳定，经常超时。**优先用 `browser_run_code` + `force: true`：**

```javascript
// 方案 1（推荐）：force click 跳过 actionability 等待
await page.locator('button:has-text("新建 App")').click({ force: true });
```

```javascript
// 方案 2（兜底）：如果 locator 也不好使，用 evaluate 直接发事件
const el = document.querySelector('button[data-test="create-app-button"]');
if (el) {
  el.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true}));
  el.dispatchEvent(new PointerEvent('pointerup', {bubbles: true}));
  el.dispatchEvent(new MouseEvent('click', {bubbles: true}));
}
```

> **通用规则：** Apple 页面上所有 `browser_click` 超时都可用 `browser_run_code` + `page.locator('...').click({ force: true })` 替代。

继续填写表单：

```
4. browser_click → Platforms: iOS
5. browser_type → Name: 产品名称
6. browser_click → Primary Language: English (U.S.)
7. browser_click → Bundle ID 下拉 → 选择 Step 1.3 注册的 ID
8. browser_type → SKU: 唯一标识（如 FaithfulGuide001）
9. browser_click → Full Access
10. browser_click → Create
11. browser_snapshot → 确认 App 创建成功
12. 记录 App ID（URL 中的数字，如 6761919115）
```

**Phase 1 完成确认：**
- [ ] Team ID: `__________`
- [ ] Bundle ID: `__________`（已在 Portal 注册）
- [ ] ASC App ID: `__________`（已在 ASC 创建）

---

## Phase 2: 工程配置

**目标：把 Phase 1 拿到的信息写入项目，确保编译签名通过。**

### Step 2.1: 写入签名配置

**XcodeGen 项目（有 `project.yml`）：**

在 `project.yml` 中确保以下配置：

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "<Team ID>"        # Phase 1 拿到的 Team ID
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "Apple Development"

targets:
  <TargetName>:
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: "<Bundle ID>"  # Phase 1 确认的 Bundle ID
```

修改后重新生成：

```bash
xcodegen generate
```

**标准 Xcode 项目（有 `.xcodeproj`）：**

引导 PM 在 Xcode 中操作：
> 1. 打开项目 → 选择 Target → Signing & Capabilities
> 2. 勾选 Automatically manage signing
> 3. Team 选择你的组织
> 4. Bundle Identifier 填入确认的 Bundle ID
> 5. 看到绿色勾 ✅ 就说明配好了

### Step 2.2: iPad 方向声明

**约束 ios-pub-017：** 即使 App 主要面向 iPhone，上传 ASC 时也必须声明 iPad 支持的屏幕方向，否则验证失败。

**XcodeGen 项目** — 在 `project.yml` 的 target settings 中添加：

```yaml
settings:
  INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
```

**标准 Xcode 项目** — 在 Info.plist 或 Target → General → Deployment Info 中勾选 iPad 四个方向。

### Step 2.3: 出口合规预配置（可选但推荐）

在 Info.plist 中添加以下 key，可跳过上传后的手动合规声明（约束 ios-pub-019）：

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

适用条件：App 只使用标准 HTTPS 通信，不含自定义加密算法。绝大多数 App 适用。

**XcodeGen 项目** — 在 `project.yml` 中：

```yaml
settings:
  INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: false
```

### Step 2.4: 确保 Xcode 已登录对应 Apple ID

```bash
# 检查本地签名身份
security find-identity -p codesigning -v
```

如果列表中没有对应 Team 的证书：

> 1. Xcode → Settings (⌘,) → Accounts
> 2. 点击「+」→ Apple ID → 登录**有 Developer Portal 权限的 Apple ID**
> 3. 登录后确认 Team 列表显示了正确的组织名和 Team ID

**约束 ios-pub-023：** 多 Apple ID 环境下，Xcode Automatic Signing 可能选错账号。确保只有一个 Apple ID 关联目标组织，或在 project 配置中明确指定 DEVELOPMENT_TEAM。

### Step 2.5: 验证编译 + Bump Build Number

```bash
# 如果是更新版本，先 bump build number
# XcodeGen 项目：修改 project.yml 中的 build number
# 标准项目：
agvtool next-version -all  # build number +1

# 验证编译（必须用 generic/platform=iOS，不能用模拟器）
xcodebuild build \
  -scheme "<SchemeName>" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="<TeamID>" \
  2>&1 | tail -20
```

**必须看到 `BUILD SUCCEEDED` 才能继续。** 编译失败的常见原因：

| 错误 | 原因 | 解决 |
|------|------|------|
| `No account for team` | Xcode 未登录对应 Apple ID | Step 2.4 |
| `No profiles for '<BundleID>'` | Bundle ID 未在 Portal 注册 | Step 1.3 |
| `Signing certificate not found` | 证书缺失 | Xcode Accounts → Manage Certificates → + Apple Development |
| SPM resolve 失败 | 网络问题 | 重试或配置代理 |

**Phase 2 完成确认：**
- [ ] DEVELOPMENT_TEAM 已填入
- [ ] Bundle ID 已配置且与 Portal 注册一致
- [ ] iPad 方向已声明
- [ ] `xcodebuild build` → BUILD SUCCEEDED

---

## Phase 3: Archive & Upload

**目标：把 App 打包并上传到 Apple 服务器。**

### Step 3.1: 生成项目文件（XcodeGen 项目）

```bash
# XcodeGen 项目需要先生成 .xcodeproj
xcodegen generate
```

### Step 3.2: Archive

```bash
xcodebuild archive \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -archivePath /tmp/<ProductName>.xcarchive \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=<TeamID>
```

**等待直到看到 `** ARCHIVE SUCCEEDED **`。** 首次 archive 可能需要 2-5 分钟。

如果失败，常见原因：
- iPad 方向未声明 → Step 2.2
- App Icon 缺失或尺寸不对 → 需要 1024x1024 PNG
- 代码签名错误 → 回到 Step 2.4 检查

### Step 3.3: 创建 ExportOptions.plist

**约束 ios-pub-018：** 上传 ASC 需要特定的 ExportOptions.plist 配置：

```bash
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string><TeamID></string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF
```

**注意：** `<TeamID>` 替换为实际 Team ID。`destination: upload` 表示直接上传到 ASC（不导出 IPA 文件）。

### Step 3.4: Export & Upload

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/<ProductName>.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -exportPath /tmp/<ProductName>Export \
  -allowProvisioningUpdates
```

输出中应看到：

```
Progress 100%: Upload succeeded.
Uploaded <ProductName>
** EXPORT SUCCEEDED **
```

**上传成功后，Apple 需要 10-30 分钟处理构建。** 处理完成后 PM 会收到邮件通知。

### Step 3.5: 等待 ASC 处理

可以通过 Playwright 检查处理状态：

```
1. browser_navigate → https://appstoreconnect.apple.com/apps/<AppID>/testflight
2. browser_snapshot → 检查 Build 状态
```

| 状态 | 含义 | 下一步 |
|------|------|--------|
| Processing | Apple 正在处理 | 等待 10-30 分钟 |
| Missing Compliance | 需要回答出口合规 | Phase 4 Step 4.1 |
| Ready to Test | 可以分发 | Phase 4 Step 4.2+ |
| Invalid Binary | 构建有问题 | 检查邮件中的具体错误 |

**Phase 3 完成确认：**
- [ ] Archive 成功
- [ ] Upload 成功（`Progress 100%: Upload succeeded`）
- [ ] ASC TestFlight 页面可见构建

---

## Phase 4: TestFlight 分发

**目标：让 PM 和团队能在 iPhone 上通过 TestFlight 安装 App。**

### Step 4.1: 出口合规声明

如果 Step 2.3 中已预配置 `ITSAppUsesNonExemptEncryption = NO`，此步自动跳过。

否则，构建旁会显示黄色 "Missing Compliance" 标记：

```
1. browser_navigate → https://appstoreconnect.apple.com/apps/<AppID>/testflight
2. browser_click → 构建版本旁的 "Manage" 或 "Missing Compliance"
3. 回答问题：「你的 App 是否使用了加密？」
   - 如果只用 HTTPS → 选「Yes」→「Only using standard encryption exemptions」
   - 或选「No」（不含任何加密）
4. browser_click → Save
5. browser_snapshot → 确认状态变为 Ready to Test
```

### Step 4.2: 选择分发路径

向 PM 确认测试策略：

> **你想怎么分发测试？**
>
> | 方式 | 适合 | 限制 | 需要审核？ |
> |------|------|------|----------|
> | **内部测试** | 团队成员试用 | 最多 100 人，必须是 ASC 团队成员 | 不需要，秒生效 |
> | **外部测试** | 更广泛的用户群 | 最多 10000 人 | 需要 Beta 审核（24-48h） |
> | **公开链接** | 任何人 | 需要先建外部测试组 | 需要 Beta 审核 |
>
> **推荐首次先走内部测试 — 秒生效，不需要审核。**

### Step 4.3: 内部测试（推荐首选）

**约束 ios-pub-020：** 内部测试只能添加 ASC 中已有的团队成员，不能添加外部邮箱。

```
1. browser_navigate → https://appstoreconnect.apple.com/apps/<AppID>/testflight
2. browser_snapshot → 确认构建状态为 Ready to Test
3. browser_click → Internal Testing → 「+」Create Group
4. browser_type → 组名如 "Internal Team"
5. browser_click → 勾选 "Enable automatic distribution"（新构建自动推送）
6. browser_click → Create
7. browser_click → 「+」Add Testers → 选择团队成员
8. browser_click → Add
```

被邀请人会收到邮件 → 安装 TestFlight App → 点击邀请链接 → Install。

### Step 4.4: 外部测试（可选）

如果需要更大范围测试或公开链接分发：

```
1. browser_click → External Testing → Create Group
2. browser_type → 组名如 "Public Beta"
3. browser_click → Add Build → 选择构建版本
4. 填写 Test Information:
   - What to Test: 一句话说明测试重点
   - App Description: App 简介
   - Feedback Email: 接收反馈的邮箱
5. browser_click → Submit for Review
```

**注意：** 外部测试需要 Beta 审核（通常 24-48h），但标准远低于正式审核。被拒不影响账号信用。

**⚠️ 外部测试可能需要 Privacy Policy URL。** 如果没有：
- 方案 A：暂时只走内部测试（不需要 Privacy Policy）
- 方案 B：用 GitHub Pages 快速部署一个简版隐私政策

### Step 4.5: 公开链接（可选）

外部测试组审核通过后：

```
1. 进入外部测试组
2. browser_click → Enable Public Link
3. browser_snapshot → 复制生成的链接（如 testflight.apple.com/join/xxxxxx）
```

任何人用 iPhone 打开该链接即可安装，不需要逐个添加邮箱。

**Phase 4 完成确认：**
- [ ] 出口合规已声明
- [ ] 内部测试组已创建 + 测试员已添加
- [ ] PM 的 iPhone 已通过 TestFlight 安装成功

---

## Phase 5: 验证 & 输出

### Step 5.1: 真机验证

PM 在自己的 iPhone 上通过 TestFlight 安装后验证：
- App 能正常打开
- Onboarding 流程完整
- 核心功能可用（如 AI Chat 能正常对话）
- 无 crash

### Step 5.2: 输出分发信息

```
═══════════════════════════════════════════
  TestFlight 发布完成 ✅
═══════════════════════════════════════════

App 信息:
  名称:      {产品名称}
  Bundle ID: {bundle_id}
  版本:      {version} (Build {build_number})
  Team:      {team_name} ({team_id})
  ASC App:   https://appstoreconnect.apple.com/apps/{app_id}

分发状态:
  内部测试: 已添加 {N} 人，邀请邮件已发送
  外部测试: {已提交 Beta 审核 / 未配置}
  公开链接: {链接 / 未开启}

测试员安装步骤:
  1. App Store 搜索 TestFlight → 安装（免费）
  2. 查收邮件邀请 → 点击 View in TestFlight
  3. 在 TestFlight App 中点击 Install

后续更新:
  改代码 → bump build number → Phase 3 Archive → Upload → 内部测试秒生效
═══════════════════════════════════════════
```

### Step 5.3: Constraint Candidates 收集

记录过程中发现的新约束，追加到 `publish-state.yaml`：

```yaml
constraint_candidates:
  - id: "ios-pub-0XX"
    source_skill: ae-testflight-publish
    description: "..."
    suggested_target: ["CLAUDE.md", "preflight"]
```

### Step 5.4: 状态持久化

更新项目根目录的 `publish-state.yaml`：

```yaml
project: <项目名>
testflight_publish:
  status: done
  published_at: <ISO 日期>
  version: <版本号>
  build_number: <构建号>
  team_id: <Team ID>
  bundle_id: <Bundle ID>
  asc_app_id: <ASC App ID>
  distribution:
    internal: true
    external: false
    public_link: null
  constraint_candidates: [...]
```

---

## 已验证的约束清单

以下约束全部来自 bible-app (Faithful Guide) 实际发布过程中的踩坑。

### 代码就绪类

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-001 | API Key 禁止硬编码在源码中 | Config.swift 中明文 OpenAI key |
| ios-pub-002 | AppIcon 必须有实际 PNG 图片 | appiconset 只有 Contents.json |
| ios-pub-003 | 有网络请求必须有 PrivacyInfo.xcprivacy | URLSession 存在但无隐私清单 |
| ios-pub-005 | Bundle ID 不含 Demo/Test | com.scaleglobal.BibleAppDemo |
| ios-pub-017 | 即使主要面向 iPhone，也必须声明 iPad 方向 | ASC 验证失败 |
| ios-pub-018 | ExportOptions.plist 需配置 method/teamID/destination/signingStyle | 上传失败 |
| ios-pub-019 | 上传后必须回答出口合规，否则构建卡在 export.compliance.missing | 构建无法测试 |

### Apple 身份类

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-008 | ASC 权限 ≠ Developer Portal 权限 | Admin 在 ASC 有权限但 Portal 显示 "Access Unavailable" |
| ios-pub-009 | 个人开发者账号无法在 Portal 加团队成员 | INDIVIDUAL 账号没有 People 管理入口 |
| ios-pub-010 | Bundle ID 全球唯一（跨所有开发者账号） | com.scaleglobal.FaithfulGuide 已被占用 |
| ios-pub-011 | Team ID 不能假设复用 | 不同 Apple ID 对应不同 Team ID |
| ios-pub-012 | Xcode Automatic Signing 是最简路径 | 配好 Accounts 后 -allowProvisioningUpdates 自动注册 |
| ios-pub-013 | Bundle ID 必须先在 Portal 注册，ASC 才能选到 | ASC 创建 App 时下拉为空 |
| ios-pub-014 | 同一 Apple ID 可能关联多个组织 | sunshinee_7 关联了 Hangzhou Yuancheng + qin xu |
| ios-pub-015 | Xcode Automatic Signing 注册的 ID 仅对 Xcode 构建有效 | ASC 需要在 Portal 单独注册 |
| ios-pub-016 | 2FA 是自动化唯一人工卡点 | ASC API Key 可绕过（一次性配置） |

### TestFlight 分发类

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-020 | 内部测试只能添加 ASC 已有团队成员 | 不能添加外部邮箱 |
| ios-pub-021 | 一个组织不应有多个 Apple ID 角色分裂 | Developer Portal vs ASC 权限混乱 |
| ios-pub-022 | 设备注册后需重新生成 Provisioning Profile | 新设备不自动包含 |
| ios-pub-023 | 多 Apple ID 环境下 Automatic Signing 可能选错账号 | 需明确指定 DEVELOPMENT_TEAM |

### 账号 & 流程类

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-024 | 个人账号开发者名为中文会影响海外转化，企业账号优先 | WePray 从个人 (qin xu) 迁移到企业 (Scale Dynamics) |
| ios-pub-025 | DPLA 协议更新后 Account Holder 必须登录接受，否则无法创建新 App | ASC 创建 App 时弹协议阻塞 |
| ios-pub-026 | 新 Apple 账号接入 Adjust 需要杭州团队前置操作（Connection） | 文龙/周文博老师需在 Adjust 后台操作 |
| ios-pub-027 | 无埋点的 TestFlight 版本等于盲测，应先接 Firebase + Adjust | WePray Build 1 无数据，Build 2-3 才有 |

---

## 故障排查

### Playwright / 浏览器

| 问题 | 原因 | 解决 |
|------|------|------|
| Apple 页面白屏 / CSS 不加载 | Playwright 用了内置 Chromium，被 TLS 指纹拦截 | 必须 `--browser chrome` 用系统 Chrome |
| 登录后 session 丢失（每次对话都要重新登录） | 未配置持久化 profile | 加 `--user-data-dir ~/.config/playwright-profile` |
| `browser_click` / `browser_fill_form` 5s 超时 | Playwright MCP 默认 `--timeout-action 5000`，Apple 重型 SPA 操作耗时超 5s | 重新注册 MCP 加 `--timeout-action 15000`；仍超时则用 `browser_run_code` + `{ force: true }` |
| ASC 对话框点击超时（元素已 visible/stable） | React 组件事件绑定 + 点击触发 SPA 导航，Playwright actionability check 等到超时 | 用 `browser_run_code` 执行 `page.locator('...').click({ force: true })` 跳过 actionability 等待 |
| `page.reload` / `browser_navigate` 超时 | 页面资源重，`load` 事件等待所有资源完成 | 用 `browser_run_code` 执行 `page.reload({ waitUntil: 'domcontentloaded' })` |
| Apple 站点反爬检测 | 频繁操作触发 | 操作间加 2-3 秒间隔 |

### 签名 / 编译

| 问题 | 原因 | 解决 |
|------|------|------|
| `No account for team "XXXXX"` | Xcode 未登录对应 Apple ID | Settings → Accounts → 添加 |
| `No profiles for 'com.xxx.xxx'` | Bundle ID 未注册 | Phase 1 Step 1.3 |
| `Signing certificate "Apple Distribution" not found` | 缺发布证书 | Xcode Accounts → Manage Certificates → + |
| Archive 后 Distribute 报错 | 证书过期 / Bundle ID 不匹配 / 缺 App Icon | 逐项排查 |

### TestFlight

| 问题 | 原因 | 解决 |
|------|------|------|
| Build 一直 Processing | Apple 处理中 | 正常 10-30 分钟，超过查邮件 |
| Missing Compliance 不消失 | 未回答出口合规问题 | Phase 4 Step 4.1 |
| "Not available for testing" | ASC 还在处理 | 等待 |
| TestFlight 安装后闪退 | 缺 Info.plist 权限声明 / API key 为空 | 检查 crash log |
| 外部审核被拒 | 通常是功能不完整或 crash | 查 Resolution Center |

---

## 与其他 skill 的关系

```
/ae-preflight ──────────→ 扫描 + 修复 → 编译通过
                                │
                                ▼
/ae-analytics-setup ────→ Firebase + Adjust 埋点接入（推荐）
                                │
                                ▼
/ae-testflight-publish ──→ Apple 注册 → 签名 → Archive → TestFlight ✅
                                │
                                ├── 后续迭代：改代码 → bump build → Phase 3-4 循环
                                │
                                ├── 支付接入：/ae-superwall-setup → Superwall + StoreKit 2
                                │
                                └── 正式上架：/ae-store-assets → /ae-archive-upload (App Store 模式)
                                              │
                                              └── /ae-publish-postflight → 约束闭环
```

**首次发布** 走 Phase 0-5 全流程（约 30-60 分钟，主要时间在 Apple 处理）。
**后续更新** 只需 Phase 3-4（bump build → archive → upload → 内部测试秒生效，5 分钟）。

## 复用说明

本 skill 适用于所有 iOS 项目的 TestFlight 首次发布和迭代更新。关键变量只有 3 个：Team ID、Bundle ID、Scheme Name。其余步骤完全通用。
