---
description: "引导 PM 完成 iOS TestFlight 发布全流程（App 注册、签名、Archive、分发）"
permissions:
  allow:
    - "mcp__playwright__*"
    - "Bash(npx playwright install:*)"
    - "Bash(fastlane *)"
    - "Bash(xcodebuild *)"
    - "Bash(xcrun *)"
    - "Bash(security find-identity:*)"
---

# Skill: TestFlight 发布引导 (testflight-publish)

## 触发条件

当 PM 需要将 iOS App 发布到 TestFlight 供团队或用户试用时触发。典型场景：
- V0 原型完成，需要上真机给团队试用
- 首次发布到 TestFlight，从未注册过 App ID
- Archive 或上传过程中遇到签名/证书问题

## 核心原则

**PM 手上只有一个能本地跑的 demo，skill 需要从零开始把他带到 TestFlight。** 
1. **PM 不懂术语** — 不抛"证书"、"Provisioning Profile"等概念，给具体的「点哪里→填什么」
2. **阻塞项前置** — 先扫描所有缺失项，一次性列出，避免走到一半才发现缺东西
3. **Automatic Signing 优先** — 开发 + TestFlight 阶段不走 Manual，让 Xcode 自动管理
4. **分 Phase 执行** — Phase 1 App 注册 → Phase 2 本地配置 → Phase 3 Archive 上传 → Phase 4 分发。每个 Phase 完成后确认再继续

## 前置条件

| 条件 | 说明 |
|------|------|
| Xcode 已安装 | 需要 Xcode 15+ |
| Apple Developer 账号 | 公司已有 Apple Developer Program 会员（$99/年），且许可协议已接受 |
| Playwright MCP 可用 | Phase 1 的 Apple Developer Portal 操作需要浏览器自动化。检查 `browser_navigate` 工具是否存在 |
| 项目可编译 | `xcodebuild build` 或 Xcode 中 ⌘B 能成功 |
| 真机或模拟器已验证 | App 基本功能已在本地跑通 |

### Playwright MCP 环境检查

Phase 1 需要通过浏览器操作 Apple Developer Portal。如果 `browser_navigate` 工具不可用：

```bash
# 注册 Playwright MCP Server（全局，一次性）
# ⚠️ 必须加 --browser chrome — Apple CDN 会 TLS 指纹检测拦截 Playwright 自带的 Chromium，
#    导致 developer.apple.com 和 appstoreconnect.apple.com 的 CSS/JS 返回空响应（页面白屏）。
#    使用系统 Chrome 的 TLS 指纹与正常用户一致，不会被拦截。
claude mcp add playwright -s user -- npx @playwright/mcp@latest --browser chrome
```

注册后需**重新开始对话**，新对话中 `browser_navigate` 等工具才会出现。

> **故障排查：** 如果 Apple 页面出现白屏 / CSS 不加载 / 点击无响应，先检查 Playwright MCP 是否使用了 `--browser chrome`。
> 执行 `claude mcp get playwright` 确认 Args 中包含 `--browser chrome`。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | Xcode 项目根目录 |
| 产品名称 | 是 | 如 "Faithful Guide" |
| Bundle ID | 否 | 如已在 project.yml / .xcodeproj 中配置则自动读取 |

## 执行流程

### Phase 0: 项目状态扫描

在动手之前，先扫描项目当前状态，生成检查报告。

**0a. 读取项目配置**

```bash
# XcodeGen 项目 — 从 project.yml 读
grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|bundleIdPrefix|CODE_SIGN" project.yml 2>/dev/null

# 标准 Xcode 项目 — 从 pbxproj 读
grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|PROVISIONING_PROFILE" *.xcodeproj/project.pbxproj 2>/dev/null

# App Icon 检查
find . -name "AppIcon*" -path "*/Assets.xcassets/*" 2>/dev/null

# Info.plist 检查
find . -name "Info.plist" -not -path "*/Pods/*" -not -path "*/.build/*" | head -5
```

**0b. 输出检查报告**

```
TestFlight 前置检查报告：

| 检查项           | 状态 | 当前值             | 需要操作               |
|-----------------|------|-------------------|-----------------------|
| DEVELOPMENT_TEAM | ✅/❌ | 8D75JV7Y2Y / 空   | → Phase 1 解决         |
| Bundle ID        | ✅/❌ | com.xxx.yyy / 空  | → Phase 1 解决         |
| Signing Style    | ✅/❌ | Automatic / 无    | → Phase 2 解决         |
| App Icon         | ✅/⚠️ | 有 / 空           | ⚠️ 空会导致上传被拒     |
| Display Name     | ✅/❌ | "Faithful Guide"  | -                     |
| Version          | ✅   | 0.1.0 (1)         | -                     |
| 编译状态          | ✅/❌ | 可编译 / 有错误    | ❌ 必须先修复编译       |
```

**编译不通过 = 全流程阻塞，必须先修复。** 其余缺失项在后续 Phase 中逐步解决。

---

### Phase 1: App 注册（通过 Playwright 浏览器自动化完成）

**PM 此前从未注册过 App，Agent 通过 Playwright 操作浏览器，在 Apple 的两个网站上完成注册。**

**工具依赖：** `browser_navigate`、`browser_snapshot`、`browser_click`、`browser_type`、`browser_take_screenshot`。如果这些工具不可用，先按前置条件中的步骤安装 Playwright MCP。

#### Step 1.1: 登录 Apple Developer 账号

向 PM 确认 Apple ID 和密码后，用 Playwright 自动登录：

```
1. browser_navigate → https://developer.apple.com/account
2. 如果跳转到登录页（URL 包含 idmsa.apple.com）：
   - browser_type → 填入 Apple ID（#account_name_text_field）
   - browser_click → 点击 Sign In（#sign-in）
   - browser_type → 填入密码（#password_text_field）
   - browser_click → 点击 Sign In
3. 等待 2FA — 提示 PM 在 iPhone 上批准或输入验证码
4. 登录成功后 browser_snapshot → 确认看到 Account 页面
```

**检查项：**
- 如果看到「Enroll」→ 说明还没付 $99 年费，需要先完成注册
- 如果看到黄色横幅「许可协议需要接受」→ 需要先接受协议（见下方 Step 1.1b）
- 如果看到「Membership」+ Team ID → 记录 Team ID，继续下一步

#### Step 1.1b: 接受许可协议（如有）

Apple Developer Program 许可协议更新后，**必须由账户持有人接受**，否则无法注册新 App。

```
1. browser_snapshot → 检查页面上是否有协议更新提示
2. 如果有 → browser_click → 点击协议链接（通常包含「Review」或「查看」文字）
3. browser_snapshot → 确认协议页面内容
4. browser_click → 勾选「I have read and agree」复选框
5. browser_click → 点击「Submit」/「同意」按钮
6. browser_snapshot → 确认协议已接受
```

#### Step 1.2: 确认 Bundle ID

Bundle ID 是 App 的唯一身份标识，注册后不可更改。跟 PM 确认：

> **你的 App 需要一个全球唯一的 ID，格式像这样：**
> - `com.scaleglobal.faithfulguide`（推荐：公司域名反转 + 产品名小写）
> - 避免用 `Demo`、`Test` 等词 —— 正式发布时改不了
>
> 建议：`com.{你的公司域名反转}.{产品名小写无空格}`
>
> 你想用什么 Bundle ID？

#### Step 1.3: 在 Apple Developer Portal 注册 App ID

用 Playwright 操作 Developer Portal 注册 App ID：

```
1. browser_navigate → https://developer.apple.com/account/resources/identifiers/list
2. browser_snapshot → 确认在 Identifiers 页面
3. browser_click → 点击「+」按钮（新建 Identifier）
4. browser_click → 选择「App IDs」→ 点「Continue」
5. browser_click → 选择类型「App」→ 点「Continue」
6. browser_type → Description 填产品名称（如 Faithful Guide）
7. browser_click → 选择「Explicit」Bundle ID
8. browser_type → 输入确认的 Bundle ID（如 com.scaleglobal.faithfulguide）
9. browser_click → 点「Continue」
10. browser_snapshot → 确认信息正确
11. browser_click → 点「Register」
12. browser_snapshot → 确认注册成功
```

**注意：** Capabilities 列表保持默认即可，后续需要推送通知、Apple Pay 等再回来勾选。

#### Step 1.4: 确认签名证书

```
1. browser_navigate → https://developer.apple.com/account/resources/certificates/list
2. browser_snapshot → 查看证书列表
3. 检查是否有「Apple Distribution」且 Active 的证书
   - 有 → 记录，跳到下一步
   - 没有 → 不需要在这里手动创建，Xcode Automatic Signing 会自动处理
```

#### Step 1.5: 在 App Store Connect 创建 App

用 Playwright 操作 App Store Connect：

```
1. browser_navigate → https://appstoreconnect.apple.com/apps
2. browser_snapshot → 如果需要登录，用同一个 Apple ID 登录（流程同 Step 1.1）
3. browser_click → 点击「+」→ 选择「New App」
4. 填写表单：
   - browser_click → Platforms 勾选 iOS
   - browser_type → Name 填产品名称（如 Faithful Guide）
   - browser_click → Primary Language 选 English (U.S.)
   - browser_click → Bundle ID 下拉选择 Step 1.3 注册的那个
   - browser_type → SKU 填唯一字符串（如 faithfulguide_v1）
   - browser_click → User Access 选 Full Access
5. browser_click → 点击「Create」
6. browser_snapshot → 确认 App 创建成功，进入管理页面
```

其他信息（截图、描述等）TestFlight 内部测试不需要填。

**Phase 1 完成确认：** 请 PM 确认以下信息：
- Team ID: `__________`
- Bundle ID: `__________`
- App Store Connect 中 App 已创建: ✅

---

### Phase 2: 本地项目配置

**目标：把 Phase 1 拿到的信息写入项目，让 Xcode 知道「这个代码属于哪个 App」。**

#### Step 2.1: 写入 Team ID 和 Bundle ID

**如果项目用 XcodeGen（有 `project.yml` 文件）：**

修改 `project.yml`，确保有以下配置：

```yaml
settings:
  DEVELOPMENT_TEAM: XXXXXXXXXX    # 替换为 Phase 1 拿到的 Team ID
  
targets:
  你的AppTarget名:
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.scaleglobal.faithfulguide  # 替换为确认的 Bundle ID
      CODE_SIGN_STYLE: Automatic
      CODE_SIGN_IDENTITY: "Apple Development"
```

修改后重新生成项目：
```bash
xcodegen generate
```

**如果项目直接用 Xcode（有 `.xcodeproj` 但没有 `project.yml`）：**

引导 PM 在 Xcode 中操作：

> 1. 打开项目 → 点击左侧项目导航器最顶层的项目文件（蓝色图标）
> 2. 在中间区域选择「**Targets**」→ 选你的 App target
> 3. 点击「**Signing & Capabilities**」tab
> 4. 勾选「**Automatically manage signing**」
> 5. **Team** 下拉选择你的公司（如果没有，需要先在 Xcode → Settings → Accounts 中添加 Apple ID）
> 6. **Bundle Identifier** 填入 Phase 1 确认的 Bundle ID
> 7. 如果下方出现绿色勾 ✅「Signing Certificate: Apple Development: xxx」就说明配好了
> 8. 如果出现红色错误 → 截图给我看

#### Step 2.2: 确保 Xcode 已登录 Apple Developer 账号

> 1. Xcode 菜单栏 → **Xcode** → **Settings**（或按 ⌘,）
> 2. 点击「**Accounts**」tab
> 3. 看列表里有没有你的公司 Apple ID
>    - **有** → 点击它，确认下方 Team 列表显示了正确的公司名和 Team ID
>    - **没有** → 点左下角「**+**」→ 选「**Apple ID**」→ 登录公司的开发者账号

#### Step 2.3: 确认 App Icon（上传 TestFlight 必须有）

```bash
# 检查是否有 App Icon
find . -name "AppIcon*" -path "*/Assets.xcassets/*" 2>/dev/null
```

如果没有 App Icon：

> TestFlight 上传要求必须有 App Icon。最快的方式：
> 1. 准备一张 1024x1024 的 PNG 图片（可以用 AI 生成一个临时 icon）
> 2. 在 Xcode 中打开 `Assets.xcassets` → 点击 `AppIcon` → 把图片拖进去
> 3. 如果没有 `AppIcon` 条目 → 右键 Assets.xcassets → New App Icon

#### Step 2.4: 验证编译

```bash
# 尝试编译，确认签名配置无报错
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS" -allowProvisioningUpdates 2>&1 | tail -5
```

编译成功（`BUILD SUCCEEDED`）才能继续。

**Phase 2 完成确认：**
- Xcode Signing & Capabilities 显示绿色勾 ✅
- App Icon 已配置
- 编译通过

---

### Phase 3: Archive & 上传

**目标：把 App 打包成安装包，上传到 Apple 的服务器。**

#### Step 3.1: Archive 构建

**推荐 PM 用 Xcode 界面操作（更直观）：**

> 1. 在 Xcode 中，确认顶部设备选择器选的是「**Any iOS Device (arm64)**」（不能选模拟器）
> 2. 菜单栏 → **Product** → **Archive**
> 3. 等待构建完成（进度条在顶部，⌘8 打开 Report Navigator 看详情）
> 4. 构建成功后会自动弹出 **Organizer** 窗口，列出你刚打好的包

**或者用命令行（适合 agent 自动执行）：**

```bash
xcodebuild archive \
  -scheme "<SchemeName>" \
  -archivePath "./build/<ProductName>.xcarchive" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=<TeamID>
```

**常见失败及解决：**

| 看到什么 | 意思 | 怎么办 |
|---------|------|--------|
| `No signing certificate "Apple Distribution" found` | 你的电脑上没有发布证书 | Xcode → Settings → Accounts → 选 Team → 点「Manage Certificates」→ 点左下角「+」→ 选「Apple Distribution」 |
| `No profiles for 'com.xxx.xxx' were found` | App ID 没注册或 Bundle ID 不匹配 | 检查代码中的 Bundle ID 是否和 Phase 1 注册的一致 |
| `The app icon set "AppIcon" has X unassigned children` | App Icon 尺寸不对 | 确保放了 1024x1024 的图 |
| 红色编译错误 | 代码有问题 | 先 ⌘B 修复所有编译错误 |

#### Step 3.2: 上传到 App Store Connect

Archive 成功后，在 Organizer 窗口操作：

> 1. 选中刚才的 archive（最新的在最上面）
> 2. 点击右侧的「**Distribute App**」按钮
> 3. 选择「**TestFlight & App Store**」→ 点「**Next**」
> 4. 保持默认选项（Distribute → Upload）→ 点「**Next**」
> 5. 再次确认 → 点「**Upload**」
> 6. 等待上传完成 —— 取决于网络和包大小，通常 5-15 分钟
> 7. 看到「Upload Successful」就完成了

**上传成功后，Apple 还需要 10-30 分钟处理你的包。** 处理完成后会收到一封邮件。

如果 Organizer 没自动弹出：Xcode 菜单 → **Window** → **Organizer**

#### Step 3.3: 等待处理 & 处理合规弹窗

> 1. 打开 **appstoreconnect.apple.com** → 进入你的 App → 点击「**TestFlight**」tab
> 2. 等待 Build 状态从「Processing」变为可用
> 3. 如果 Build 旁边出现黄色警告「**Missing Compliance**」：
>    - 点击「**Manage**」
>    - 问题是「你的 App 是否使用了自定义加密？」
>    - 如果你只用了 HTTPS（绝大多数 App 都是）→ 选「**Yes**」→ 再选「**Only using standard encryption**」（或 App 的 Info.plist 已有 `ITSAppUsesNonExemptEncryption = NO` 则选「No」）
>    - 点「**Save**」

**Phase 3 完成确认：**
- Organizer 中上传成功 ✅
- ASC TestFlight 页面中 Build 状态为可用（非 Processing）

---

### Phase 4: TestFlight 分发

**目标：让团队成员能在自己 iPhone 上安装试用。**

#### Step 4.1: 内部测试（推荐先做，秒生效，不需要审核）

内部测试员 = Apple Developer Team 中有 App Store Connect 角色的成员（最多 100 人）。

> 1. 在 **appstoreconnect.apple.com** 进入你的 App → 「**TestFlight**」tab
> 2. 左侧「Internal Testing」→ 点「**+**」旁边的「**Create Group**」
> 3. 给组取个名字（如 `Internal Team`）
> 4. 点「**+**」添加测试员 → 选择 Team 成员（这些人需要先在 ASC 的「Users and Access」中被添加过）
> 5. 添加后，被邀请人会收到邮件
>
> **被邀请人安装步骤：**
> 1. 在 iPhone 上打开 App Store → 搜索「**TestFlight**」→ 安装（Apple 官方免费 App）
> 2. 打开邮件中的邀请链接 → 自动跳转到 TestFlight App
> 3. 点击「**Install**」→ 完成

#### Step 4.2: 外部测试（需要 Beta 审核，通常 24-48h）

如果要邀请 Team 以外的人（如用户、合作伙伴）：

> 1. 左侧「External Testing」→「**Create Group**」→ 取名（如 `Beta Testers`）
> 2. 点「**Add Build**」→ 选择你上传的版本
> 3. 首次需要填写：
>    - **Test Information**: 
>      - What to Test: 一句话告诉测试员要测什么
>      - App Description: App 简介
>      - Feedback Email: 接收反馈的邮箱
>    - **⚠️ 如果被要求填 Privacy Policy URL**：
>      - 方案 A: 暂时只做内部测试（不需要 Privacy Policy）
>      - 方案 B: 快速用 GitHub Pages 托管一个简版隐私政策
> 4. 点「**Submit for Review**」
> 5. Apple 审核通过后 → 点「**+**」添加测试员邮箱 → 他们会收到邀请邮件

#### Step 4.3: 生成公开测试链接（可选，最方便的分发方式）

> 1. 进入外部测试组 → 找到「**Public Link**」开关
> 2. 开启后会生成一个链接（如 `testflight.apple.com/join/xxxxxx`）
> 3. 把这个链接发给任何人 → 他们用 iPhone 打开就能安装（不需要逐个添加邮箱）

### Phase 5: 验证 & 输出

**5a. 自验**

在自己的 iPhone 上通过 TestFlight 安装并验证：
- App 能正常打开
- 核心功能可用
- 没有 crash

**5b. 输出分发信息**

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
1. 在 App Store 下载 TestFlight App（免费）
2. 查收邮件中的邀请 → 点击「View in TestFlight」
3. 在 TestFlight App 中点击「Install」

后续更新：
- 代码改了之后 → 重新 Product → Archive → Distribute → TestFlight 自动推新版
- 内部测试秒生效；外部测试需要重新提交 Beta 审核
```

## 故障排查

| 问题 | 怎么办 |
|------|--------|
| Apple 页面白屏 / CSS 不加载 / 点击无响应 | Playwright MCP 必须用 `--browser chrome`（系统 Chrome），不能用自带 Chromium。Apple CDN 通过 TLS 指纹拦截 Chromium。执行 `claude mcp get playwright` 确认 |
| developer.apple.com 登录后看到「Enroll」 | Apple Developer Program 还没付费（$99/年），需要先完成注册 |
| ASC 创建 App 时 Bundle ID 下拉为空 | Phase 1 的 App ID 还没注册，或注册后需等几分钟刷新 |
| ASC 创建 App 报名称已被占用 | App 名称全球唯一，换一个名字（Bundle ID 不影响） |
| Xcode Signing 红色错误 `No matching provisioning profiles` | Automatic Signing 下通常是 Team ID 或 Bundle ID 不匹配 —— 检查是否和 ASC/Developer Portal 中一致 |
| Archive 成功但 Distribute 报错 | 截图错误信息 → 常见原因：证书过期、Bundle ID 不匹配、缺 App Icon |
| ASC 处理后 Build 旁显示 `Missing Compliance` | 见 Phase 3 Step 3.3 的处理步骤 |
| TestFlight 安装后闪退 | 检查 Xcode Console crash log → 常见：缺 Info.plist 权限声明、API key 为 debug 值 |
| 外部测试审核迟迟不通过 | 正常 24-48h，超过后在 ASC 检查是否有 `Issues` 标记 |
| `This build is not available for testing` | ASC 还在处理中，等 10-30 分钟 |

## 与其他 skill 的关系

```
/ae-onboarding-design  → 生成 Onboarding 页面 ─┐
/ae-paywall-design     → 生成 Paywall 页面    ─┤
/ae-superwall-setup    → 集成 Superwall SDK   ─┤  产品功能就绪
/ae-image-decopyrighter → App Icon 等素材处理  ─┘
                                                 │
                                                 ▼
/ae-testflight-publish → App 注册 → 签名配置 → Archive → TestFlight 分发
                                                 │
                                                 ▼
                                          团队/用户试用
```

## 复用说明

所有 iOS 产品都需要经过 TestFlight 分发。首次注册 + 配置约 30-45 分钟（主要时间花在 ASC 创建 App 和等待处理），后续每次更新只需 Archive → Upload，5 分钟完成。

## 参考资料

- `content/research/bible-app-publish-checklist.md` — 基于 Capvault 的完整上架 checklist（涵盖 IAP、埋点、归因等正式上架内容）
- `content/research/ios-publish-glossary.md` — iOS 发布相关名词科普（PM 不懂某个术语时查阅）
