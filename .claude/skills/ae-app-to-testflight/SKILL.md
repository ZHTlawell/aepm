---
description: "从源码工程到 TestFlight 可安装的全流程引导（Apple 注册 → 签名 → Archive → 上传 → 分发）"
permissions:
  allow:
    - "Bash(ae asc *)"
    - "Bash(python3 *ae-asc*)"
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(xcrun *)"
    - "Bash(security find-identity:*)"
    - "Bash(python3 *)"
    - "Bash(plutil *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: xcrun
      verify: "xcrun --version"
    - name: ae
      verify: "ae asc auth validate --pretty"
  api_keys:
    - ASC_KEY_ID
    - ASC_ISSUER_ID
    - ASC_KEY_PATH
  scripts:
    - ae-asc.py
smoke_test:
  command: "xcodebuild -version && ae asc auth validate --pretty 2>/dev/null | grep -q valid"
  expected_exit: 0
  description: "xcodebuild + ASC API credentials available"
---

# Skill: TestFlight 发布全流程 (ae-app-to-testflight)

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
4. **推荐先接埋点** — 没有埋点的 TestFlight 版本 = 盲测，建议先跑 `/ae-analytics-integrate` 接入 Firebase + Adjust，再上传 TestFlight（约束 ios-pub-027）
5. **每个 Phase 完成确认后再继续** — 不跳步，Apple 生态的依赖链环环相扣
5. **收集 constraint_candidates** — 过程中发现的新约束记录到 publish-state.yaml，供 ae-postflight 回写

## 前置条件

| 条件 | 验证方式 | 说明 |
|------|---------|------|
| Xcode 15+ 已安装 | `xcodebuild -version` | 需要支持 visionOS 之后的 archive 格式 |
| Apple Developer 账号 | PM 提供 Apple ID | 需已付费 $99/年，许可协议已接受 |
| ASC API 凭据已配置 | `ae asc auth validate --pretty` | Phase 1 + Phase 4 的 ASC API 操作必需 |
| ae-preflight 已通过 | 项目根目录有 `publish-state.yaml` 且 preflight.status=done | 或手动确认：编译通过 + 无硬编码 Key + 有 App Icon |
| ae-analytics-integrate 已完成（推荐） | Firebase + Adjust SDK 已接入 | 非必须，但强烈推荐：无埋点 = 盲测 |
| 项目可编译 | `xcodebuild build` → BUILD SUCCEEDED | 编译不通过 = 全流程阻塞 |

### ASC API 凭据检查

Phase 1 和 Phase 4 通过 `ae asc` CLI 直接调用 App Store Connect REST API，无需浏览器自动化。

```bash
# 确认 ASC API 凭据可用，并探测 effective permissions
ae asc auth validate --pretty
```

输出包含 `effective_permissions`（GET 探针推断）+ `likely_role` 启发式 + `warnings`。**注意**：ASC API **没有 self-introspection 端点**，role/permissions 是通过 GET 探针（`/apps`, `/bundleIds`, `/betaGroups`, `/users`）的 200/403 响应反推的，不是直接查询。如果输出 `warnings` 里提示 `apps.create 可能不可用`（Developer 角色没有 apps:CREATE 权限），Phase 1.5 走到 `ae asc app create` 撞 403 时改走 Web UI / Playwright fallback。

如果报错"缺少 ASC 凭据"，需要在 `~/.config/ae/credentials.env` 中配置：

```bash
# ASC API Key — 在 ASC → 用户和访问 → 集成 → 团队密钥 中创建
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_KEY_PATH=~/.config/ae/AuthKey_XXXXXXXXXX.p8
```

> **注意：** API Key 由 Account Holder 在 ASC 中创建，.p8 文件只能下载一次。依赖 PyJWT + cryptography（`pip3 install PyJWT cryptography`）。

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

**0d. 列出本机签名身份与 Team 归属**

项目 `project.yml` / `.xcodeproj` 里写死的 `DEVELOPMENT_TEAM` 不一定是当前 keychain 能签出来的 Team。本机有多个 Apple ID / 多个 Team 时容易混淆，提前列出来让 PM 选。

```bash
# 列出所有可用签名身份及 Team ID
security find-identity -p codesigning -v | grep -E "Apple Development|Apple Distribution"

# 查每张 cert 的 OU.Org（粗判个人 vs 公司）
for hash in $(security find-identity -p codesigning -v | awk '/Apple (Development|Distribution)/{print $2}'); do
  subject=$(security find-certificate -c "$hash" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
  echo "  $hash → $subject"
done
```

输出示例：
```
ABC123... "Apple Development: foo (B798N3T6TK)"  → O = "li genjian US"
DEF456... "Apple Development: bar (2P74ND2JUB)"  → O = "Scale Dynamics LLC"
```

> **个人 vs 公司粗判**: OU.Org 含 `LLC`/`Inc`/`Limited`/`Co.`/`Corp` 通常是公司账号；纯人名通常是个人账号。**这是粗筛启发式不是硬规则**——理论上个人账号也能起公司化的 OU。最终归属请向 PM 当面确认。
>
> **约束 ios-pub-024**（个人账号开发者名为中文影响海外转化，企业账号优先）。如果项目目标用户是海外而当前 team 是个人账号，建议切公司 team。Reflow Grain 案例：项目里写 "Scale Global B798N3T6TK"，但该 Team OU.Org 实际是 "li genjian US"（个人账号），不是 Scale Global。

**0e. 设备识别符版本边界（Xcode 15+ 注意事项）**

Xcode 15+ / iOS 17+ 引入新的设备 destination identifier 格式，与传统 UDID 不同。**接命令的工具决定用哪种 ID，不要跨工具复用 ID 字符串**：

| 命令 | 输出 ID 格式 | 用于 |
|------|------------|------|
| `xcodebuild -showdestinations` | 24 字符 `XXXXXXXX-XXXXXXXXXXXXXXXX`（前 8 位 SoC 标识 + 后 16 位 ECID 派生） | `xcodebuild -destination "id=..."` |
| `xcrun devicectl list devices` | 接受 UUID/ECID/serial/UDID/name 多种 | `devicectl --device <id>` |
| 传统 UDID（Xcode 14 及之前老设备） | 40 字符全 hex 小写 | Provisioning Profile 内嵌 / 老 simctl |

混用会直接卡（script 假定 40 字符 UDID 但拿到 24 字符 destination ID）。

---

## Phase 1: Apple 身份注册（ae asc CLI）

**目标：通过 `ae asc` CLI 注册 Bundle ID + 创建 App。无需浏览器、无需 2FA。**

### Step 1.1: 确认 Bundle ID

Bundle ID 注册后**永远不可更改**，跟 PM 确认：

> **你的 App 需要一个全球唯一的 ID：**
> - 推荐格式：`com.{组织域名反转}.{产品名小写}`
> - 例如：`com.scaleglobal.faithfulguide`
> - ❌ 不要包含 Demo、Test、Example（约束 ios-pub-005）
> - ❌ `com.scaleglobal.*` 可能已被其他团队占用（约束 ios-pub-010，Bundle ID 全球唯一）
>
> **如果 Bundle ID 被占用，改用组织实际域名或个人前缀。**
> bible-app 经验：`com.scaleglobal.FaithfulGuide` 被占用 → 改为 `com.kjv.bible.prayer.app`。

### Step 1.2: 检查 Bundle ID 是否已注册

```bash
ae asc bundle-id list --filter-identifier <BUNDLE_ID> --pretty
```

- 如果返回结果 → 已注册，跳到 Step 1.4
- 如果结果为空 → 需要注册，继续 Step 1.3

### Step 1.3: 注册 Bundle ID

```bash
ae asc bundle-id register \
  --identifier <BUNDLE_ID> \
  --name "<产品名称>" \
  --pretty
```

成功输出包含 `id`（ASC 内部资源 ID）和 `identifier`（Bundle ID 字符串）。

**约束 ios-pub-013：** Bundle ID 必须先注册，才能创建 App。ASC API 自动处理 Developer Portal + ASC 两侧的注册。

### Step 1.4: 检查 App 是否已创建

```bash
ae asc app list --filter-bundle-id <BUNDLE_ID> --pretty
```

- 如果返回结果 → App 已存在，记录 App ID，跳到 Phase 2
- 如果结果为空 → 继续 Step 1.5

### Step 1.5: 创建 App

> **App 名称命名建议**: ASC App 名称是**全球唯一**的（与 Bundle ID 的全球唯一不同维度）。短词形如 "Reflow" / "Reader" / "Bible" 几乎都被占。推荐 `<品牌>: <品类描述>` 双段命名，重复率显著降低。
>
> 团队既有案例：`NoteFusion: AI Note Taker`、`WePray: Daily Bible Prayer`、`BugID: Insect Identifier`。Reflow 案例：`Reflow` / `Reflow Reader` 全被占用，最终用 `Reflow Grain` 通过。

```bash
ae asc app create \
  --bundle-id <BUNDLE_ID> \
  --name "<App 名称>" \
  --sku "<SKU>" \
  --pretty
```

> **SKU** = 唯一标识符，如 `FaithfulGuide001`。建议用 Bundle ID 最后一段或产品英文名。
>
> **如果 `auth validate` 的 warnings 里提示 `apps.create 可能不可用`**（API Key 是 Developer 角色），此处会撞 HTTP 403。改走 ASC Web UI 或 Playwright fallback：登录 https://appstoreconnect.apple.com/apps → My Apps → + → New App。

成功输出包含 `id`（App ID，如 `6761982880`）。

**Phase 1 完成确认：**
- [ ] Bundle ID: `__________`（已注册）
- [ ] ASC App ID: `__________`（已创建）
- [ ] SKU: `__________`

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

### Step 2.4b: Automatic Signing 失败时的 Manual Signing fallback

如果 `xcodebuild build -allowProvisioningUpdates` 报错 `you do not have permission to register them`（设备无法被自动注册），**先排查根因**：

| 根因 | 检查方式 | 解决 |
|------|---------|------|
| **(a) Admin 开启了 "Prevent registration of new test devices" 限制** | Developer Portal → Membership → People → 你的 Apple ID 看 Automatic Signing Controls 列 | 让 Admin 关掉限制开关，或临时升级你为 App Manager 角色 |
| **(b) Team 设备配额已满（100 台/年）** | Developer Portal → Devices 看计数 | 让 Admin 移除不再用的设备（每年 1 月可重置一次） |
| **(c) 团队账号未付费 / 续费过期** | Developer Portal 顶部 banner 是否提示 "Your account has not yet been activated" | 让 Account Holder 续费 |
| **(d) ios-pub-028: 24-72h Processing 期** | Devices 列表中目标设备 status 为 "Processing" | 等 Apple 处理完，或走 TestFlight（不依赖 device 注册） |

> **注意**: Developer 角色**默认有权限**通过 Xcode 自动注册设备，要 Admin 主动开启 (a) 的限制开关才会撞这个错。直接升级到 Admin 不一定能解决 — 先确认根因。

如果以上根因不适用且时间紧迫，走 **Manual Signing fallback**：

**Step 2.4b.1: Developer Portal 创建 Development Profile**

> ASC API **不支持 Profile 操作**（API 只到 Bundle ID 层面），必须走 Web UI 或 Playwright MCP。

1. 打开 https://developer.apple.com/account/resources/profiles/add
2. 选 iOS App Development → 选 Bundle ID → 选 Certificate → 选 Devices → 命名（如 `<App> Dev`）→ Generate → Download
3. 双击下载的 `.mobileprovision` 安装到本地

**Step 2.4b.2: 项目切到 Manual Signing**

XcodeGen 项目 (`project.yml`):

```yaml
settings:
  base:
    CODE_SIGN_STYLE: Manual
    PROVISIONING_PROFILE_SPECIFIER: "<Profile 名称>"
    DEVELOPMENT_TEAM: "<Team ID>"
```

标准 Xcode 项目: Target → Signing & Capabilities → 取消 Automatically manage signing → 手动选 Profile。

**Step 2.4b.3: 重新编译（不要带 -allowProvisioningUpdates）**

```bash
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS"
# 不要加 -allowProvisioningUpdates，避免 Xcode 重新走自动签名流程把 manual config 覆盖
```

> ⚠️ **Manual Profile 是设备列表的快照**: profile 中嵌入的 device 列表是**生成时定格**的。如果当前是 ios-pub-028 的 24-72h Processing 期，profile 里没有该设备 UDID，重新签名后装真机仍会失败 — 此时只能等 Apple 处理完，或走 TestFlight 安装（distribution profile 不绑 UDID）。

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
- App Icon 缺失或尺寸不对 → 需要 1024x1024 PNG（项目完全没图时见**附录: 占位 AppIcon 生成器**，30 行 Swift+CG 兜底）
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

通过 `ae asc` 检查处理状态：

```bash
ae asc testflight list-builds --app-id <AppID> --pretty
```

| processingState | 含义 | 下一步 |
|-----------------|------|--------|
| PROCESSING | Apple 正在处理 | 等待 10-30 分钟，再次查询 |
| VALID | 处理完成 | 检查 `usesNonExemptEncryption` 字段，进入 Phase 4 |
| INVALID | 构建有问题 | 检查邮件中的具体错误 |

> `usesNonExemptEncryption: null` = Missing Compliance（需要 Step 4.1）；`false` = 已声明，可直接分发。

**Phase 3 完成确认：**
- [ ] Archive 成功
- [ ] Upload 成功（`Progress 100%: Upload succeeded`）
- [ ] ASC TestFlight 页面可见构建

---

## Phase 4: TestFlight 分发

**目标：让 PM 和团队能在 iPhone 上通过 TestFlight 安装 App。**

### Step 4.1: 出口合规声明

如果 Step 2.3 中已预配置 `ITSAppUsesNonExemptEncryption = NO`，此步自动跳过。

否则，`ae asc testflight list-builds` 中 `usesNonExemptEncryption: null` 的 Build 需要声明：

```bash
# 大多数 App 不含自定义加密（只用 HTTPS）→ uses-encryption false
ae asc testflight set-compliance \
  --build-id <BuildID> \
  --uses-encryption false \
  --pretty
```

> **BuildID** 从 `ae asc testflight list-builds` 的 `id` 字段获取（UUID 格式）。

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

**Step 4.3a: 创建内部测试组**

```bash
ae asc testflight create-group \
  --app-id <AppID> \
  --name "Internal Team" \
  --pretty
```

记录返回的 `id`（Group ID）。

**Step 4.3b: 添加测试员**

```bash
ae asc testflight add-tester \
  --group-id <GroupID> \
  --email <tester@example.com> \
  --first-name <名> \
  --last-name <姓> \
  --pretty
```

> 对每个测试员重复执行。被邀请人会收到邮件 → 安装 TestFlight App → 点击邀请链接 → Install。

### Step 4.4: 外部测试（可选）

外部测试需要 Beta 审核（通常 24-48h），需通过 ASC Web UI 操作（`ae asc` 暂不支持外部测试组的创建 + Beta 审核提交）。

如果需要外部测试：
1. 打开 `https://appstoreconnect.apple.com/apps/<AppID>/testflight`
2. External Testing → Create Group → 添加 Build → 填写 Test Information → Submit for Review

**⚠️ 外部测试可能需要 Privacy Policy URL。** 如果没有：
- 方案 A：暂时只走内部测试（不需要 Privacy Policy）
- 方案 B：用 GitHub Pages 快速部署一个简版隐私政策

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
    source_skill: ae-app-to-testflight
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
| ios-pub-028 | 新设备进入 24-72h "Processing" 等待期（仅在第 11-100 台 / 新开账号 / 续费过期场景触发，不是所有新设备） | 期间设备不会被加入任何 provisioning profile，USB 直装失败；TestFlight 走 distribution profile（不绑 UDID），所以**不依赖 device 注册**——但这是另一条签名链路，不是"绕过 Processing"。前 1-10 台设备立即可用，无等待期。Apple 文档原文术语是 "Processing"，不是 "iPhoneProcessing"。 |
| ios-pub-029 | ASC `bundle-id register` 成功 ≠ Developer Portal / Xcode 立即可用 | ASC API 与 Portal 是分离系统，ASC 注册的 bundle ID 在 Portal/Xcode 端可能延迟同步或要求二次操作。验证标准是 `xcodebuild -allowProvisioningUpdates` 通过，不是 ASC 返回 200。Reflow Grain 案例：`ai.scaleglobal.reflow` ASC 报 409 但 Portal team 早有了。 |

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
| ios-pub-031 | 切换 Bundle ID / Apple Developer 账号后，TestFlight 内测组、测试员、出口合规声明需要重新配置，不会从旧 App 继承 | WePray 从 com.qinxu.FaithfulGuide 切到 com.kjv.bible.prayer.app 后，旧内测组关联的是旧 ASC App，新 App 需重建 |

---

## 故障排查

### ae asc CLI / ASC API

| 问题 | 原因 | 解决 |
|------|------|------|
| `缺少 ASC 凭据` | credentials.env 未配置 ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH | 在 ASC → 用户和访问 → 集成 → 团队密钥 创建 API Key，配置到 `~/.config/ae/credentials.env` |
| `认证失败 (HTTP 401)` | JWT 签名失败或 .p8 文件错误 | 检查 Key ID / Issuer ID 是否匹配，.p8 文件是否完整 |
| `资源冲突 (HTTP 409)` | Bundle ID 已注册或 App 已存在 | 用 `ae asc bundle-id list` / `ae asc app list` 检查是否已有 |
| `PyJWT / cryptography 缺失` | 依赖未安装 | `pip3 install PyJWT cryptography` |
| API 调用超时 | 网络问题 | ae-asc.py 内置 3 次重试 + 指数退避 |

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
/ae-analytics-integrate ────→ Firebase + Adjust 埋点接入（推荐）
                                │
                                ▼
/ae-app-to-testflight ──→ Apple 注册 → 签名 → Archive → TestFlight ✅
                                │
                                ├── 后续迭代：改代码 → bump build → Phase 3-4 循环
                                │
                                └── 正式上架：/ae-store-assets → /ae-archive-upload (App Store 模式)
                                              │
                                              └── /ae-publish-postflight → 约束闭环
```

**首次发布** 走 Phase 0-5 全流程（约 30-60 分钟，主要时间在 Apple 处理）。
**后续更新** 只需 Phase 3-4（bump build → archive → upload → 内部测试秒生效，5 分钟）。

## 复用说明

本 skill 适用于所有 iOS 项目的 TestFlight 首次发布和迭代更新。关键变量只有 3 个：Team ID、Bundle ID、Scheme Name。其余步骤完全通用。

---

## 附录: 占位 AppIcon 生成器

如果项目完全没有 AppIcon 资产，archive 会失败。下面这段 Swift+CoreText 脚本生成一张 1024×1024 PNG 兜底（实色背景 + 居中字母），喂给 `Assets.xcassets/AppIcon.appiconset/Icon-1024.png` 即可。

> ⚠️ **占位图不能用于正式 App Store 提审**——审核会拒。仅用于 TestFlight 内测期间快速跑通 archive。

保存为 `gen-placeholder-icon.swift` 后运行 `swift gen-placeholder-icon.swift <output.png> [letter]`：

```swift
#!/usr/bin/env swift
// gen-placeholder-icon.swift — Generate a 1024x1024 placeholder AppIcon PNG.
// Usage: swift gen-placeholder-icon.swift <output.png> [letter]

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift gen-placeholder-icon.swift <output.png> [letter]")
    exit(1)
}
let outputPath = args[1]
let letter = String((args.count > 2 ? args[2] : "A").prefix(1)).uppercased()

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Failed to create CGContext") }

ctx.setFillColor(CGColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 600, nil)
let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
]
let attrString = CFAttributedStringCreate(nil, letter as CFString, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrString)
let bounds = CTLineGetImageBounds(line, ctx)
ctx.textPosition = CGPoint(
    x: (CGFloat(size) - bounds.width) / 2 - bounds.minX,
    y: (CGFloat(size) - bounds.height) / 2 - bounds.minY
)
CTLineDraw(line, ctx)

guard let cgImage = ctx.makeImage() else { fatalError("Failed to create CGImage") }
let url = URL(fileURLWithPath: outputPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Failed to create image destination")
}
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
print("Generated: \(outputPath) (\(size)x\(size))")
```
