---
description: "引导 PM 完成 iOS TestFlight 发布全流程（签名、ASC 配置、Archive、分发）"
---

# Skill: TestFlight 发布引导 (testflight-publish)

## 触发条件

当 PM 需要将 iOS App 发布到 TestFlight 供团队或用户试用时触发。典型场景：
- V0 原型完成，需要上真机给团队试用
- 首次发布到 TestFlight，不熟悉签名和 App Store Connect 配置
- Archive 或上传过程中遇到签名/证书问题

## 核心原则

**TestFlight 是 V0 原型走向用户验证的第一道关卡。** 此 skill 的目标是：
1. **最小配置** — 只做 TestFlight 分发必需的步骤，跳过正式上架才需要的内容
2. **自动化优先** — 能用 Xcode Automatic Signing 就不走 Manual
3. **阻塞项前置** — 先识别所有阻塞项（Team ID、Bundle ID、ASC App Record），避免走到一半才发现缺东西
4. **PM 可执行** — 需要 PM 在 Xcode / ASC 网页上操作的步骤，给出精确的点击路径

## 前置条件

| 条件 | 说明 |
|------|------|
| Xcode 已安装 | 需要 Xcode 15+ |
| Apple Developer 账号 | 公司已有 Apple Developer Program 会员（$99/年） |
| 项目可编译 | `xcodebuild build` 或 Xcode 中 ⌘B 能成功 |
| 真机或模拟器已验证 | App 基本功能已在本地跑通 |

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | Xcode 项目根目录 |
| 产品名称 | 是 | 如 "Faithful Guide" |
| Bundle ID | 否 | 如已在 project.yml / .xcodeproj 中配置则自动读取 |
| DEVELOPMENT_TEAM | 否 | 如已配则自动读取，未配需 PM 提供 |

## 执行流程

### Phase 1: 前置检查（阻塞项扫描）

在动手之前，先扫描所有可能阻塞的配置项，一次性列出。

**1a. 读取项目配置**

```bash
# XcodeGen 项目 — 从 project.yml 读
grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|bundleIdPrefix|CODE_SIGN" project.yml 2>/dev/null

# 标准 Xcode 项目 — 从 pbxproj 读
grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|PROVISIONING_PROFILE" *.xcodeproj/project.pbxproj 2>/dev/null

# Info.plist 检查
find . -name "Info.plist" -not -path "*/Pods/*" -not -path "*/.build/*" | head -5
```

**1b. 生成检查报告**

向 PM 输出一份表格：

```
TestFlight 前置检查报告：

| 检查项           | 状态 | 当前值              | 需要操作          |
|-----------------|------|--------------------|--------------------|
| DEVELOPMENT_TEAM | ✅/❌ | 8D75JV7Y2Y / 空    | 需 PM 提供 Team ID |
| Bundle ID        | ✅/❌ | com.xxx.yyy / 空   | 需确认命名         |
| Signing Style    | ✅/❌ | Automatic / Manual | 建议改为 Automatic |
| App Icon         | ✅/⚠️ | 有 / 空            | 空会导致上传被拒   |
| Display Name     | ✅/❌ | "Faithful Guide"   | -                  |
| Version          | ✅    | 0.1.0 (1)          | -                  |
| 编译状态          | ✅/❌ | 可编译 / 有错误     | 需先修复编译       |
```

**有 ❌ 的项必须先解决再继续。** 逐项引导 PM 解决。

**1c. DEVELOPMENT_TEAM 缺失时的引导**

如果 Team ID 为空，引导 PM 获取：

> **获取 Team ID 的方法（任选其一）：**
> 1. 打开 Xcode → Settings → Accounts → 选择 Apple ID → 查看 Team 列的字符串
> 2. 登录 [developer.apple.com/account](https://developer.apple.com/account) → Membership Details → Team ID
> 3. 问团队中已经发过 App 的同事要（同一公司共用一个 Team ID）

拿到 Team ID 后，帮 PM 写入项目配置：

```yaml
# project.yml (XcodeGen)
settings:
  DEVELOPMENT_TEAM: XXXXXXXXXX
```

或直接修改 `.xcodeproj/project.pbxproj` 中的 `DEVELOPMENT_TEAM` 值。

**1d. Bundle ID 确认**

Bundle ID 一旦注册不可更改。需要 PM 确认：
- 推荐格式：`com.{公司域名反转}.{产品名}` 如 `com.scaleglobal.faithfulguide`
- 避免使用 `Demo`、`Test` 等词（正式发布时改不了）
- 同一 Team 下不可重复

### Phase 2: App Store Connect 配置

TestFlight 分发需要先在 App Store Connect 中创建 App Record。

**2a. 检查 ASC 中是否已有此 App**

引导 PM 操作：

> 1. 打开 [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
> 2. 点击「My Apps」→ 搜索你的产品名称
> 3. 如果已存在 → 跳到 Phase 3
> 4. 如果不存在 → 继续下一步创建

**2b. 创建 App Record**

引导 PM 在 ASC 中操作：

> 1. 点击「My Apps」左上角的「+」→「New App」
> 2. 填写：
>    - **Platform**: iOS
>    - **Name**: {产品名称}（App Store 上显示的名字）
>    - **Primary Language**: English (U.S.)
>    - **Bundle ID**: 选择或输入 Phase 1 确认的 Bundle ID
>    - **SKU**: 任意唯一字符串，如 `faithfulguide_ios_v1`
> 3. 点击「Create」

**2c. TestFlight 测试信息（外部测试必填，内部测试可跳过）**

内部测试（同 Team 下的 Apple ID）不需要额外信息。如果要邀请外部测试员：

> 1. 在 ASC 中进入 App → TestFlight → Test Information
> 2. 填写：
>    - **Beta App Description**: 一句话描述 App 功能
>    - **Feedback Email**: 接收反馈的邮箱
>    - **Privacy Policy URL**: 隐私政策网页（⚠️ 外部测试必须有）

**⚠️ Privacy Policy URL 是外部测试的硬阻塞项。** 如果还没准备好：
- 方案 A: 先只做内部测试（Team 成员），不需要 Privacy Policy
- 方案 B: 快速生成一个 → 可用 GitHub Pages 或任意静态托管

### Phase 3: Signing 配置

**推荐：Automatic Signing（开发 + TestFlight 阶段最省心）**

**3a. 确保 Xcode 登录了 Apple Developer 账号**

> 1. Xcode → Settings (⌘,) → Accounts
> 2. 如果没有账号 → 点「+」→ Apple ID → 登录公司的开发者账号
> 3. 确认 Team 列显示正确的公司名 + Team ID

**3b. 开启 Automatic Signing**

如果项目用 XcodeGen (`project.yml`)，确保配置：

```yaml
targets:
  MyApp:
    settings:
      CODE_SIGN_STYLE: Automatic
      DEVELOPMENT_TEAM: XXXXXXXXXX
      CODE_SIGN_IDENTITY: "Apple Development"
```

如果直接用 Xcode：

> 1. 选择项目 → Targets → 你的 App Target → Signing & Capabilities
> 2. 勾选「Automatically manage signing」
> 3. Team 选择正确的公司 Team
> 4. 如果出现红色错误 → 通常是 Bundle ID 冲突或账号权限不足，按错误信息处理

**3c. 验证签名状态**

```bash
# 检查签名配置是否正确
xcodebuild -showBuildSettings -scheme <scheme_name> 2>/dev/null | grep -E "CODE_SIGN|DEVELOPMENT_TEAM|PROVISIONING"
```

输出中应有：
- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM = <你的 Team ID>`
- 无 `error:` 或 `warning:` 相关签名的信息

### Phase 4: Archive & 上传

**4a. 确认 Scheme**

```bash
# 列出可用 scheme
xcodebuild -list 2>/dev/null | grep -A 20 "Schemes:"
```

确认要 archive 的 scheme 名称（通常是 App 主 target 名）。

**4b. Archive 构建**

```bash
# 方式 A: 命令行 Archive（推荐，可追踪错误）
xcodebuild archive \
  -scheme "<SchemeName>" \
  -archivePath "./build/<ProductName>.xcarchive" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=<TeamID>
```

或引导 PM 用 Xcode GUI：

> 1. Xcode 菜单 → Product → Archive
> 2. 等待构建完成（⌘8 查看进度）
> 3. 构建成功后自动打开 Organizer 窗口

**常见 Archive 失败原因及解决：**

| 错误 | 原因 | 解决 |
|------|------|------|
| `No signing certificate` | 没有有效证书 | Xcode → Settings → Accounts → 选 Team → Download Manual Profiles → 或删掉重新添加账号 |
| `No profiles for 'com.xxx'` | Bundle ID 未注册 | Automatic Signing 会自动注册，检查网络和 Apple ID 权限 |
| `App Icon not found` | 缺少 App Icon | 添加 1024x1024 的 AppIcon 到 Assets.xcassets |
| 编译错误 | 代码问题 | 先用 ⌘B 修复所有编译错误 |

**4c. 上传到 App Store Connect**

**方式 A: Xcode Organizer（最简单，推荐 PM 使用）**

> 1. Archive 成功后 Organizer 自动打开（或 Xcode → Window → Organizer）
> 2. 选中刚才的 archive → 点击「Distribute App」
> 3. 选择「TestFlight & App Store」→ Next
> 4. 选择「Upload」→ Next
> 5. 保持默认选项 → Next → Upload
> 6. 等待上传完成（取决于包大小和网络，通常 5-15 分钟）

**方式 B: 命令行（自动化场景）**

```bash
# 从 archive 导出 ipa
xcodebuild -exportArchive \
  -archivePath "./build/<ProductName>.xcarchive" \
  -exportPath "./build/export" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates

# 上传 ipa 到 ASC
xcrun altool --upload-app \
  -f "./build/export/<ProductName>.ipa" \
  -t ios \
  -u "apple_id@example.com" \
  -p "@keychain:AC_PASSWORD"
```

命令行上传需要 App-Specific Password（Apple ID → 安全性 → App 专用密码）。PM 首次操作建议用 Xcode Organizer。

**4d. 等待 ASC 处理**

上传成功后，App Store Connect 需要处理（通常 10-30 分钟）：
- 自动检查 → 编译验证 → 生成不同设备版本
- 完成后会收到邮件通知
- 可在 ASC → My Apps → TestFlight 中查看处理状态

### Phase 5: TestFlight 分发

**5a. 内部测试（推荐先做，无需审核）**

内部测试员 = 你的 Apple Developer Team 中有 App Store Connect 角色的成员（最多 100 人）。

> 1. ASC → 你的 App → TestFlight → Internal Testing
> 2. 点击「+」添加测试员（必须是 Team 成员的 Apple ID）
> 3. 被邀请人会收到邮件 → 在 iPhone 上打开 TestFlight App → 安装

**5b. 外部测试（需要 Beta 审核）**

外部测试员 = 任何 Apple ID（最多 10,000 人）。需要经过 Apple Beta 审核（通常 24-48h，比正式审核快很多）。

> 1. ASC → TestFlight → External Testing → Create Group
> 2. 命名（如 "Beta Testers"）
> 3. 添加 Build → 选择刚上传的版本
> 4. 填写测试说明（用户打开 TestFlight 时看到的内容）
> 5. 提交 Beta 审核
> 6. 审核通过后 → 添加测试员邮箱 → 发送邀请

**5c. 生成公开测试链接（可选）**

> 1. ASC → TestFlight → External Testing → 你的测试组
> 2. 开启「Public Link」
> 3. 复制链接 → 发给任何人即可安装（不需要逐个添加邮箱）

### Phase 6: 验证 & 完成

**6a. 自验**

在自己的 iPhone 上通过 TestFlight 安装并验证：
- App 能正常打开
- 核心功能可用
- 没有 crash

**6b. 输出分发信息**

完成后向 PM 输出：

```
TestFlight 发布完成 ✅

App 信息：
- App 名称: {产品名称}
- Bundle ID: {bundle_id}
- 版本: {version} ({build_number})
- Team: {team_name} ({team_id})

分发方式：
- 内部测试: 已添加 {N} 人，邀请邮件已发送
- 外部测试: {已提交 Beta 审核 / 未配置}
- 公开链接: {链接 / 未开启}

测试员安装步骤：
1. 确保 iPhone 已安装 TestFlight App（App Store 免费下载）
2. 查收邮件中的 TestFlight 邀请 → 点击「View in TestFlight」
3. 在 TestFlight App 中点击「Install」

后续更新：
- 修改代码后重新 Archive → Upload → TestFlight 自动推送新版本给已有测试员
- 内部测试无需重新审核；外部测试需要重新提交 Beta 审核
```

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| Archive 时 `No signing certificate` | Xcode → Settings → Accounts → 选 Team → Manage Certificates → 点 `+` 创建 iOS Distribution |
| Upload 报 `Invalid Bundle` | 检查 Bundle ID 是否与 ASC 中注册的一致 |
| Upload 报 `Missing App Icon` | Assets.xcassets 中必须有 1024x1024 的 AppIcon |
| ASC 处理后显示 `Missing Compliance` | 进入 TestFlight → 对应 Build → Manage Compliance → 勾选「None of the algorithms」（如果没有用自定义加密） |
| TestFlight 安装后闪退 | 检查 Xcode Console 中的 crash log → 常见原因：缺少 Info.plist 权限声明、API key 硬编码为 debug 值 |
| 外部测试提交后迟迟不审核 | 正常是 24-48h，超过后在 ASC 中检查是否有 `Issues` 标记 |
| `This build is not available for testing` | ASC 还在处理中，等 10-30 分钟 |

## 与其他 skill 的关系

```
/ae-onboarding-design  → 生成 Onboarding 页面 ─┐
/ae-paywall-design     → 生成 Paywall 页面    ─┤
/ae-superwall-setup    → 集成 Superwall SDK   ─┤  产品功能就绪
/ae-image-decopyrighter → App Icon 等素材处理  ─┘
                                                 │
                                                 ▼
/ae-testflight-publish → 签名 → Archive → 上传 → TestFlight 分发
                                                 │
                                                 ▼
                                          团队/用户试用
```

## 复用说明

所有 iOS 产品都需要经过 TestFlight 分发。流程标准且固定，首次配置约 30 分钟（主要时间花在 ASC 创建 App 和等待处理），后续每次更新只需 Archive → Upload，5 分钟完成。

## 参考资料

- `content/research/bible-app-publish-checklist.md` — 基于 Capvault 的完整上架 checklist
- `content/research/ios-publish-glossary.md` — iOS 发布相关名词科普
