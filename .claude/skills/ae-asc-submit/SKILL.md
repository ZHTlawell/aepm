---
description: "App Store 提审全流程 — ASC 元数据配置 + 截图上传 + Review Notes + 提交审核"
permissions:
  allow:
    - "Bash(ae asc *)"
    - "Bash(xcrun altool *)"
    - "Bash(fastlane *)"
    - "Bash(xcrun simctl *)"
    - "Bash(xcodebuild *)"
    - "Bash(sips *)"
    - "Bash(grep *)"
    - "Bash(find *)"
    - "Bash(cat *)"
dependencies:
  mcp: []
  cli:
    - name: ae
      verify: "ae --version"
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: fastlane
      verify: "fastlane --version"
      optional: true
      note: "非必须。ae asc CLI 覆盖核心功能，fastlane deliver 作为截图批量上传的备选方案"
  api_keys:
    - name: ASC_API_KEY
      verify: "ae asc auth check"
      note: "App Store Connect API Key (.p8)，通过 ae asc auth setup 配置"
  scripts: []
smoke_test:
  command: "ae asc auth check"
  expected_exit: 0
  description: "ASC API Key configured and valid"
---

# Skill: App Store 提审 (ae-asc-submit)

## 触发条件

当 PM 完成以下前置步骤后执行：
- `/ae-app-review-check` 全部 PASS（无 FAIL 项）
- TestFlight Build 已验证通过
- 准备正式提交 App Store 审核

## 核心原则

1. **自动化优先** — 元数据填入、截图上传通过 ASC API 完成，不需要 PM 手动操作浏览器
2. **PM 确认后提交** — 最终提审动作需 PM 明确确认
3. **幂等安全** — 重复执行不会创建重复数据，已有配置跳过

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | 包含 .xcodeproj 或 project.yml 的根目录 |
| App Store App ID | 是 | ASC 中的 App ID（可通过 `ae asc app list` 获取） |
| 语言 | 否 | 默认 `en-US`，支持多语言 |

## 前置检查

执行前确认：

```bash
# 1. ASC API Key 可用
ae asc auth check

# 2. App 已在 ASC 中创建
ae asc app list --pretty

# 3. 有已处理完成的 Build
ae asc testflight builds --app-id <APP_ID> --pretty

# 4. /ae-app-review-check 已通过
cat publish-state.yaml | grep "app_review_check" -A 2

# 5. 法务三件套就位（必检，缺失 = 拒审风险）
ls legal/privacy-policy.html legal/terms-of-use.html legal/hosting.md 2>&1
# 付费 app 额外检查
ls legal/paywall-copy.md 2>&1
```

任一项不满足则阻止执行，提示 PM 先完成对应步骤。

**法务三件套检查明细**（对应 `legal/` 目录产出，由 `/ae-legal-generate` 生成）：

| 检查项 | 通过标准 | 不通过时 |
|--------|---------|---------|
| `legal/privacy-policy.html` 存在 | 文件存在 + 无 `{{...}}` 残留 + 无历史品牌残留（CapVault / 错误产品名）| 🛑 阻塞 — Apple 5.1.1 拒审风险 |
| `legal/terms-of-use.html` 存在 | 文件存在 + 含 Schedule 2 subscription terms 段落（付费 app）| 🛑 阻塞 — Developer Program Schedule 2 违约 |
| `legal/hosting.md` 最终 URL 可达 | `curl -o /dev/null -w "%{http_code}" <URL>` 返回 200 | 🛑 阻塞 — Privacy Policy URL 404 = 3.1.2a 拒审 |
| 付费 app：`legal/paywall-copy.md` 7 要素齐全 | 7 个必填文案关键词全部命中 | 🛑 阻塞 — 付费墙文案不全 = 3.1.2a 拒审 |

**FAIL 时**：指引 PM 先跑 `/ae-legal-generate`，不允许直接 `ae-asc-submit`。

## 执行流程

### Phase 1: 收集 App Store 元数据

从项目和 speckit 中自动提取元数据，PM 确认后使用。

**1a. 基础信息提取**

```bash
# 从 speckit 提取（如有）
cat speckit/product-positioning.md 2>/dev/null
cat speckit/scenarios.md 2>/dev/null

# 从 Info.plist 提取
grep -A 1 "CFBundleDisplayName\|CFBundleShortVersionString" */Info.plist
```

**1b. 生成元数据草稿**

基于 speckit 和项目信息，生成以下内容供 PM 确认：

| 字段 | 来源 | 说明 |
|------|------|------|
| App 名称 | speckit/product-positioning.md | 30 字符以内 |
| 副标题 | speckit/product-positioning.md | 30 字符以内，补充说明 |
| 描述 | speckit 综合 | 4000 字符以内，前 3 行最重要 |
| 关键词 | speckit/scenarios.md | 100 字符以内，逗号分隔 |
| 分类 | speckit/product-positioning.md | 主分类 + 次分类 |
| Privacy Policy URL | `legal/hosting.md`（由 `/ae-legal-generate` 产出）| 必须是可访问的 HTTPS URL |
| Support URL | 项目配置 | 必须是可访问的 HTTPS URL |

**展示完整草稿给 PM，等待确认或修改后继续。**

### Phase 2: App Store 截图

**2a. 确定需要的截图尺寸**

| 设备 | 尺寸 | 必需 |
|------|------|------|
| iPhone 6.9" (16 Pro Max) | 1320 x 2868 | 是 |
| iPhone 6.7" (15 Plus/Pro Max) | 1290 x 2796 | 是 |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | 是（兼容旧设备） |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | 否（可选） |
| iPad 12.9" | 2048 x 2732 | 仅 Universal App |

**2b. 截图获取策略**

优先级：
1. **已有截图** — 检查项目中 `screenshots/` 或 `fastlane/screenshots/` 目录
2. **模拟器截图** — 用 `xcrun simctl` 在对应尺寸模拟器上截图
3. **真机截图** — 使用 ae-go `/ae-mobile-agent` 在 TestFlight Build 上截图

```bash
# 检查已有截图
find . -name "*.png" -path "*/screenshot*" -o -name "*.png" -path "*/Screenshot*" 2>/dev/null

# 模拟器截图（如需要）
xcrun simctl list devices available | grep "iPhone"
xcrun simctl boot "iPhone 16 Pro Max"
xcrun simctl io booted screenshot ~/Desktop/screenshot_1.png
```

**2c. 截图尺寸验证**

```bash
# 验证所有截图尺寸
for f in screenshots/*.png; do
  sips -g pixelWidth -g pixelHeight "$f"
done
```

每个尺寸需要 2-10 张截图，展示 App 核心功能页面。

**展示截图预览给 PM，确认后继续。**

### Phase 3: Review Notes 准备

基于 `/ae-app-review-check` 的输出，生成 Review Notes：

```
Review Notes 草稿：

1. [如有归因 SDK] This app uses Adjust SDK for attribution analytics to understand user acquisition channels. It does not serve advertisements.

2. [如有登录] Demo Account:
   Email: review@example.com
   Password: ReviewPass123!

3. [如有订阅] In-app purchases can be tested using the Sandbox environment. No real charges will be made during review.

4. [其他说明] This is a [App 类别] app that [核心功能一句话描述].
```

**展示 Review Notes 草稿给 PM 确认。**

### Phase 4: 元数据上传

**4a. 通过 ASC API 上传元数据**

当前 `ae asc` CLI 尚未支持元数据上传 API。使用以下方案之一：

**方案 A: fastlane deliver（推荐，如已安装）**

```bash
# 初始化 fastlane（如未初始化）
fastlane init

# 创建 metadata 目录结构
mkdir -p fastlane/metadata/en-US
echo "<App 名称>" > fastlane/metadata/en-US/name.txt
echo "<副标题>" > fastlane/metadata/en-US/subtitle.txt
echo "<描述>" > fastlane/metadata/en-US/description.txt
echo "<关键词>" > fastlane/metadata/en-US/keywords.txt
echo "<Privacy Policy URL>" > fastlane/metadata/en-US/privacy_url.txt
echo "<Support URL>" > fastlane/metadata/en-US/support_url.txt
echo "<Review Notes>" > fastlane/metadata/review_information/notes.txt

# 上传截图
mkdir -p fastlane/screenshots/en-US
cp screenshots/*.png fastlane/screenshots/en-US/

# 上传元数据（不提审）
fastlane deliver --skip_binary_upload --skip_screenshots false --submit_for_review false
```

**方案 B: 手动 ASC 操作引导**

如果 fastlane 不可用，引导 PM 在 ASC Web UI 中操作：
1. 打开 https://appstoreconnect.apple.com
2. 选择 App → App Store → 版本信息
3. 逐项填入已确认的元数据
4. 上传截图

**标注：后续 ae asc CLI 将新增 metadata 子命令覆盖此步骤。**

### Phase 5: 提交审核

**5a. 最终确认清单**

展示给 PM 的最终确认清单：

```
═══════════════════════════════════════
  提审确认清单 — {App 名称} v{版本号}
═══════════════════════════════════════

  ✅ App Store 元数据已填入
  ✅ 截图已上传（{N} 张 x {M} 种尺寸）
  ✅ Privacy Policy URL 可访问
  ✅ Review Notes 已填入
  ✅ /ae-app-review-check 全部 PASS
  ✅ Build {版本号} ({Build 号}) 已选择

  ⚠️ 提交后预计 24-48 小时内收到审核结果
  ⚠️ 首次提审通常需要较长时间

  确认提交审核？[Y/n]
═══════════════════════════════════════
```

**5b. 提交**

PM 确认后执行提交：

```bash
# 方案 A: fastlane
fastlane deliver --submit_for_review --automatic_release false

# 方案 B: ASC API（ae asc CLI 扩展后）
# ae asc app submit --app-id <APP_ID> --version <VERSION>
```

### Phase 6: 提审后跟踪

**6a. 记录提审状态**

```yaml
# 追加到 publish-state.yaml
app_store_submit:
  status: submitted
  submitted_at: <ISO 日期>
  version: <版本号>
  build: <Build 号>
  review_notes: |
    <Review Notes 内容>
```

**6b. 审核状态查询**

```bash
# 查询审核状态（ae asc CLI 扩展后）
# ae asc app review-status --app-id <APP_ID>

# 当前通过 fastlane 查询
fastlane deliver download_metadata
```

## 被拒后的处理流程

如果审核被拒：

1. 记录拒审原因和 Guideline 编号
2. 重跑 `/ae-app-review-check` 并传入拒审原因，针对性加强检查
3. 修复问题
4. 重新提审（不需要重新上传截图和元数据，除非被要求修改）

## 与其他 skill 的关系

```
/ae-app-review-check → 审核自检 PASS
    ↓
/ae-asc-submit → 本 skill
    ├── Phase 1: 元数据（从 speckit 提取）
    ├── Phase 2: 截图（模拟器/真机）
    ├── Phase 3: Review Notes（从 review-check 提取）
    ├── Phase 4: 上传
    └── Phase 5: 提审
```

## 已知限制

- **ae asc CLI 尚未支持元数据上传和提审** — 当前依赖 fastlane deliver 或手动 ASC 操作
- **截图需要对应尺寸的模拟器或真机** — 建议安装 iPhone 16 Pro Max 模拟器
- **App Store 审核时间不可控** — 通常 24-48 小时，首次可能更长
- **expedited review** — 紧急情况可申请加急审核，但需要 Apple 批准
- **多语言支持** — 当前只处理 en-US，多语言需要额外的翻译步骤

## CLI 扩展计划

以下 `ae asc` 子命令需要后续实现以完全消除 fastlane 依赖：

| 命令 | 功能 |
|------|------|
| `ae asc metadata set` | 设置 App Store 元数据 |
| `ae asc metadata get` | 获取当前元数据 |
| `ae asc screenshot upload` | 上传截图 |
| `ae asc app submit` | 提交审核 |
| `ae asc app review-status` | 查询审核状态 |
