---
description: "扫描 iOS 项目的生产就绪问题，自动修复能修的，报告不能修的"
permissions:
  allow:
    - "Bash(xcodebuild build:*)"
    - "Bash(xcodebuild -showBuildSettings:*)"
    - "Bash(find *)"
    - "Bash(file *)"
    - "Bash(sips *)"
    - "Bash(security find-identity:*)"
    - "Bash(grep *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: security
      verify: "which security"
    - name: sips
      verify: "sips --help"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version"
  expected_exit: 0
  description: "xcodebuild available"
---

# Skill: iOS 发布前预检 (ae-preflight)

## 触发条件

当 PM 准备将 iOS App 推向 TestFlight 或 App Store 时，先跑 preflight 扫描。典型场景：
- demo 完成，准备进入发布流程
- ae-dev 生成成品后，发布前检查
- 任何时候不确定项目是否 production-ready

## 核心原则

**扫描必须实际执行命令验证，不能只读代码猜测。**
- "编译通过" = `xcodebuild build` 返回 BUILD SUCCEEDED，不是"看起来能编译"
- "无硬编码秘钥" = grep 扫描零匹配，不是"Config.swift 看起来用了 plist"
- "App Icon 存在" = `file` + `sips` 确认 PNG 且 1024x1024，不是"目录里有个文件"

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | 包含 project.yml 或 .xcodeproj 的根目录 |
| 目标 | 否 | `testflight`（默认）或 `appstore`（检查项更多） |

## 执行流程

### Phase 0: 项目识别

确认项目类型和基本信息：

```bash
# 项目管理方式
ls project.yml 2>/dev/null && echo "XcodeGen" || echo "Standard Xcode"

# Scheme 列表
xcodebuild -list 2>/dev/null | grep -A 20 "Schemes:"

# 当前 git 状态
git status --short
git log --oneline -5
```

记录：项目名、scheme 名、git 状态（有多少未 commit 的改动）。

### Phase 1: 签名与身份扫描

逐项检查并记录状态：

**1a. DEVELOPMENT_TEAM**

```bash
# XcodeGen 项目
grep "DEVELOPMENT_TEAM" project.yml

# 标准 Xcode 项目
grep "DEVELOPMENT_TEAM" *.xcodeproj/project.pbxproj
```

- 空或缺失 → 阻塞（需要 PM 提供 Team ID）
- 有值 → 记录，继续

**1b. Bundle ID**

```bash
grep "PRODUCT_BUNDLE_IDENTIFIER\|bundleIdPrefix" project.yml *.xcodeproj/project.pbxproj 2>/dev/null
```

检查：
- 是否包含 `Demo`、`Test`、`Example` → 警告（正式发布应清理）
- 是否符合反向域名规范 → 警告

**1c. Signing Style**

```bash
grep "CODE_SIGN_STYLE\|CODE_SIGN_IDENTITY" project.yml *.xcodeproj/project.pbxproj 2>/dev/null
```

- 未配置 → 默认 Automatic（可以）
- Manual → 需要 Provisioning Profile 文件（阻塞项更多）

**1d. Xcode 账号验证**

```bash
# 尝试实际编译来验证签名链路
xcodebuild build -scheme "<SchemeName>" -destination "generic/platform=iOS" -allowProvisioningUpdates 2>&1 | tail -10
```

- `No Account for Team` → 阻塞：PM 需在 Xcode Settings → Accounts 登录对应 Apple ID
- `No profiles for` → 阻塞：需先注册 App ID（→ 转 ae-apple-identity）
- `BUILD SUCCEEDED` → 通过

### Phase 2: 敏感信息扫描

**2a. 硬编码 API Key / Secret**

```bash
grep -rn 'sk-proj-\|sk-live-\|sk-test-\|api[_-]key.*=.*"[a-zA-Z0-9]\{20,\}' --include="*.swift" .
```

- 有匹配 → 阻塞：必须外部化（Secrets.plist / Environment Variable / Keychain）

**2b. 秘钥文件泄露风险**

```bash
# 检查 .gitignore 是否存在且包含敏感文件
cat .gitignore 2>/dev/null | grep -i "secret\|credential\|\.env\|\.plist"

# 检查敏感文件是否被 git track
git ls-files | grep -i "secret\|credential\|\.env" | grep -v "example\|template"
```

- Secrets.plist 被 track → 严重阻塞：必须 `git rm --cached` + 加入 .gitignore
- .gitignore 不存在 → 阻塞：创建 .gitignore

### Phase 3: 隐私合规扫描

**3a. PrivacyInfo.xcprivacy**

```bash
find . -name "PrivacyInfo.xcprivacy" -not -path "*/Pods/*" -not -path "*/.build/*"
```

- 不存在 → 阻塞（App Store 2024 年起要求）
- 存在 → 读取内容，确认声明的 API 类型与实际使用匹配

**3b. Info.plist 权限声明**

```bash
# 检查代码中使用的系统权限
grep -rn "AVCaptureSession\|CLLocationManager\|PHPhotoLibrary\|CNContactStore\|ATTrackingManager" --include="*.swift" .

# 检查 Info.plist 中的权限声明
grep -r "NSCameraUsageDescription\|NSLocationWhenInUseUsageDescription\|NSPhotoLibraryUsageDescription" . --include="*.plist"
```

- 代码用了某权限但 Info.plist 没声明 → 运行时 crash，阻塞

**3c. 隐私合规弹窗**

```bash
# 检查是否有首次启动的隐私/法律合规弹窗
grep -rn "privacy\|legal\|consent\|GDPR\|terms" --include="*.swift" . -i
```

- 无任何合规提示 → 警告（App Store 审核可能被拒）

### Phase 3.5: 埋点 SDK 检查（建议项）

**3.5a. Firebase Analytics**

```bash
# 检查 Firebase SDK 是否已接入
grep -rn "FirebaseAnalytics\|import Firebase\|Analytics.logEvent" --include="*.swift" .
# 检查 GoogleService-Info.plist
find . -name "GoogleService-Info.plist" -not -path "*/Pods/*"
```

- 均无匹配 → 警告：无埋点的 TestFlight 版本等于盲测，建议先跑 `/ae-analytics-setup`
- 有 SDK 但无 plist → 阻塞：Firebase 初始化会 crash

**3.5b. Adjust SDK**

```bash
grep -rn "import Adjust\|ADJConfig\|Adjust.initSdk" --include="*.swift" .
```

- 无匹配 → 警告：无归因数据，投放无法追踪

**3.5c. DPLA 协议提示**

```
⚠️ 如果近期更换了 Apple Developer 账号或长时间未登录，Account Holder 可能需要接受更新的 DPLA 协议，否则无法创建新 App 或上传构建。建议在 Phase 结束前提醒 PM 确认。
```

### Phase 4: 资产完整性

**4a. App Icon**

```bash
# 查找 App Icon 文件
find . -name "AppIcon*" -path "*/Assets.xcassets/*" -o -name "AppIcon*" -path "*/*.xcassets/*" 2>/dev/null

# 验证尺寸
sips -g pixelWidth -g pixelHeight <找到的 icon 路径>
```

- 不存在 → 阻塞（Archive 上传会被拒）
- 存在但非 1024x1024 → 阻塞
- 路径不在 ASSETCATALOG_COMPILER_APPICON_NAME 指定的 xcassets 中 → 警告

**4b. Launch Screen**

```bash
grep -r "UILaunchScreen\|LaunchScreen" . --include="*.plist" --include="project.yml" 2>/dev/null
```

- 无配置 → 警告（SwiftUI 项目可用 Info.plist 配置）

### Phase 5: 生成报告

输出结构化报告：

```
═══════════════════════════════════════════════════
  PREFLIGHT REPORT — {项目名}
  Date: {日期}  Target: {testflight|appstore}
═══════════════════════════════════════════════════

BLOCKERS (必须修复才能继续):
  ❌ [签名] Xcode 未登录 Team 8D75JV7Y2Y 的 Apple ID
  ❌ [签名] 无 Provisioning Profile for com.scaleglobal.FaithfulGuide

WARNINGS (建议修复):
  ⚠️ [合规] 无首次启动隐私合规弹窗
  ⚠️ [支付] Paywall 无 StoreKit 集成，Restore 为空实现
  ⚠️ [埋点] 无 Firebase Analytics 接入 → 建议 /ae-analytics-setup
  ⚠️ [埋点] 无 Adjust SDK → 投放归因缺失

PASSED:
  ✅ [秘钥] API Key 已外部化到 Secrets.plist
  ✅ [秘钥] Secrets.plist 在 .gitignore 中
  ✅ [隐私] PrivacyInfo.xcprivacy 存在
  ✅ [资产] App Icon 1024x1024 ✓
  ✅ [配置] Bundle ID: com.scaleglobal.FaithfulGuide
  ✅ [配置] DEVELOPMENT_TEAM: 8D75JV7Y2Y

CONSTRAINT CANDIDATES (供 ae-postflight 回写):
  - demo 生成时应避免硬编码 API Key（→ CLAUDE.md 约束）
  - demo 生成时 Bundle ID 不应包含 Demo（→ speckit 检测规则）
  - demo 应包含 PrivacyInfo.xcprivacy 骨架（→ CLAUDE.md 约束）

NEXT STEPS:
  1. [人工] Xcode Settings → Accounts → 登录公司 Apple ID
  2. [人工] 确认 Bundle ID 最终值
  3. [agent] 登录后重跑 preflight 验证编译通过
  4. [agent] 编译通过后进入 /ae-apple-identity
═══════════════════════════════════════════════════
```

### Phase 6: 自动修复（可选，PM 确认后执行）

对于 agent 能自动修复的项目，列出修复方案让 PM 确认后批量执行：

| 问题 | 自动修复方案 | 需确认？ |
|------|------------|---------|
| 无 .gitignore | 生成标准 iOS .gitignore + Secrets.plist | 否 |
| 无 PrivacyInfo.xcprivacy | 生成骨架（声明 UserDefaults） | 否 |
| API Key 硬编码 | 提取到 Secrets.plist + Config.swift 封装 | 是（需确认 key 存放方式） |
| Bundle ID 含 Demo | 替换为正式 ID | 是（需确认最终值） |
| DEVELOPMENT_TEAM 空 | 填入 Team ID | 是（需确认 Team ID） |

**原则：有业务决策的项必须 PM 确认，纯技术项直接修。**

### Phase 7: 状态持久化

将扫描结果写入项目根目录的 `publish-state.yaml`：

```yaml
project: <项目名>
preflight:
  status: done | blocked
  scanned_at: <ISO 日期>
  blockers:
    - category: signing
      description: "Xcode 未登录 Team Apple ID"
      resolution: "人工操作"
  warnings:
    - category: compliance
      description: "无首次启动隐私合规弹窗"
  constraint_candidates:
    - target: claude_md
      rule: "demo 生成时应避免硬编码 API Key"
```

## 验证标准

| 标准 | 验证方法 |
|------|---------|
| 编译通过 | `xcodebuild build` 返回 BUILD SUCCEEDED |
| 零硬编码敏感信息 | `grep -rn 'sk-proj-\|sk-live-' --include="*.swift"` 零匹配 |
| PrivacyInfo 存在 | `find . -name "PrivacyInfo.xcprivacy"` 有结果 |
| App Icon 合规 | `sips -g pixelWidth` 返回 1024 |
| .gitignore 有效 | `git ls-files` 不含 Secrets 文件 |

**所有标准必须通过 `xcodebuild build` 实际验证。Phase 1-4 的检查只是提前发现问题，最终判定以编译结果为准。**

## 与其他 skill 的关系

```
/ae-preflight  →  扫描 + 修复 → 编译通过
      │
      ├── 签名阻塞 → /ae-testflight-publish Phase 1（Apple 注册）
      ├── 资产缺失 → /ae-store-assets（生成 Icon、截图、描述）
      ├── 埋点缺失 → /ae-analytics-setup（Firebase + Adjust）
      └── 编译通过 → /ae-testflight-publish Phase 3-4（Archive → TestFlight）
                          │
                          └── /ae-postflight（约束闭环）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| ios-pub-001 | API Key 禁止硬编码在源码中 | Config.swift 中明文 OpenAI key |
| ios-pub-002 | AppIcon 必须有实际 PNG 图片 | appiconset 只有 Contents.json |
| ios-pub-003 | 有网络请求必须有 PrivacyInfo.xcprivacy | URLSession 存在但无隐私清单 |
| ios-pub-029 | 依赖境外 API（OpenAI、Gemini 等）的功能，base URL 必须可配置，不能硬编码域名 | WePray AI Chat 在中国网络不可直连，ChatService 需支持 Secrets.plist 配置 OPENAI_BASE_URL |

## 已知限制

- **无法替代 PM 登录 Apple ID** — Xcode Accounts 登录需要人工操作 + 2FA
- **无法判断 Provisioning Profile 是否匹配** — 需要实际编译才能确认
- **SPM 依赖问题需联网** — 首次编译可能因网络问题 resolve 失败，不是项目本身的问题
