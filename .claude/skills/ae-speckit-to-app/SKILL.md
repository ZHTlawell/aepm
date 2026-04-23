---
description: "Speckit → 本地可用 iOS 程序：Route B 选型约束 + 代码模板包 + precheck + 调试速查，供外部 harness 驱动实现"
last_updated: "2026-04-23"
permissions:
  allow:
    - "Bash(pod install:*)"
    - "Bash(pod repo:*)"
    - "Bash(xcodebuild *)"
    - "Bash(xcodegen *)"
    - "Bash(xcrun *)"
    - "Bash(git clone:*)"
    - "Bash(git ls-remote:*)"
    - "Bash(git remote:*)"
    - "Bash(idb *)"
    - "Bash(python3 *)"
    - "Bash(ruby *)"
    - "Bash(plutil *)"
    - "Read(*)"
    - "Write(*)"
    - "Edit(*)"
    - "Glob(*)"
    - "Grep(*)"
dependencies:
  mcp: []
  cli:
    - name: pod
      verify: "pod --version"
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: xcodegen
      verify: "xcodegen --version"
    - name: idb
      verify: "idb --help 2>&1 | head -1"
    - name: git
      verify: "git --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "pod --version && xcodebuild -version && git --version"
  expected_exit: 0
  description: "CocoaPods + Xcode + git 就位即可"
---

# Skill: Speckit → 本地可用程序 (ae-speckit-to-app)

> **本 skill 不是 step-by-step workflow，而是 Route B 约束 + 代码模板包。**
> 外部 harness（claude manager / superpower / 其他编排层）负责安排执行顺序，本 skill 只透传：
> **① 38 条选型约束 ② 代码模板库 ③ 必要基础要素 precheck ④ 调试方法速查 ⑤ done criteria**
>
> 经 bible-app (WePray / Faithful Guide) 端到端实跑产出（2026-04-15 ~ 2026-04-16），所有约束和模板来自真实踩坑，非理论推演。

## 触发条件

PM/Agent 已经有一个 **Speckit**（产品规格包，含 6 模块：overview / IA / Screen / Data / Service / Paywall 等），需要把它生成为 **本地可编译运行 + 能通过 stage 后端 CI 的 iOS App**。

典型场景：
- ae-speckit-brainstorm / ae-demo-to-speckit 产出完 Speckit，准备落地成代码
- 需要 app-service stage 后端联调的产品（带 LLM / 支付 / 归因 / 埋点全套）
- 接入 BytesCell 组件体系

> **所有产品必须走 Route B。** Route A（纯前端 demo 直链 TestFlight）不再作为例外保留——原因：Route A 产品无法同步用户信息和支付状态，产品成功后无法扩量；而后端 Route B 流程已成熟，接入成本可控。

## 定位声明 — 薄 harness + 推荐执行顺序

SKILL.md **故意不硬编排 Phase 1/2/3/...**，但给出"推荐执行顺序（默认路径）"供 harness 参考。80% 情况照走即可，剩余 20% 按实际阻塞点灵活跳步。

**推荐执行顺序：**

```
1. Precheck P1/P2/P3 权限类（🛑 阻塞点，任一不过全停）
       │
       ▼
2. Precheck P4 BCConfig 品牌参数
       │
       ▼
3. Podfile 模板装配（templates/cocoapods/）
       │
       ▼
4. Precheck P5 pod install 通过
       │
       ▼
5. Work Chain 12 步骨架装配（templates/work-chain/）
       │
       ▼
6. 业务代码按 TS-020/021/022/023 约束填充
       │
       ▼
7. iOS 15 兼容扫描（templates/ios15-compat/）
       │
       ▼
8. xcodebuild build（模拟器）
       │
       ▼
9. Precheck P6 后端 stage 可达性（🛑 有后端时阻塞）
       │
       ▼
10. 真机 archive 可过（🛑 codesigning 卡点）
       │
       ▼
11. 推 GitLab + CI 绿（🛑 后端 stage Pipeline）
       │
       ▼
12. Done Criteria D1~D5 逐项确认
```

🛑 = 可能的阻塞点，需要人工介入或外部依赖（杭州团队 / 运营 / Apple 账号）。其余步骤可并行或由 agent 自主推进。

harness 只需要保证：每条 TS-XXX 约束被遵守、每个模板正确对接、precheck 全绿、done criteria 全过。**非阻塞步骤的顺序可调整**。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| Speckit 路径 | 是 | 含 overview/IA/Screen/Data/Service/Paywall 等模块的目录 |
| 目标 iOS template repo | 是 | BytesCell iOS template（GitLab: `products/{product}/ios/{product}` 或复用 bible-ios-template 结构）|
| App Service repo | 是 | 后端模板（GitLab: `products/{product}/server/{product}-app-service`）|
| 产品标识 | 是 | `{product}`（如 `bible`），用于域名/bucket/package 命名 |
| BCConfig 品牌参数 | 是 | appId / teamId / hosts / Adjust tokens / SKUs / supportEmail / awsBucket |

## 输出

1. **本地可编译运行的 iOS 工程** — `pod install` 零失败 + `xcodebuild build` BUILD SUCCEEDED + 真机启动后 12 步 Work Chain 全跑通展开 MainTab
2. **stage CI 过签证据** — `xcodebuild archive` 本地能过 + 已推送到 `products/{product}/ios/{product}` 触发 CI（iOS 端）+ 后端 Pipeline build/test/upload-stage/deploy-stage 全绿（如涉及后端）
3. **遗留约束记录** — 过程中新发现的约束记回 `publish-state.yaml` 的 `constraint_candidates`

---

## 核心第 1 块：Route B 选型约束 (TS-001 ~ TS-038)

> 以下 38 条约束全部从 bible-app trajectory 原文摘录（comment id 49695213, 2026-04-15 14:49:36），外部 harness 应把每条作为 machine-checkable 的 linter 规则使用。
> 格式：`TS-XXX: 必须/禁止 X，因为 Y（来自 bible-app Z 踩坑）`

### A. 工程约束（TS-001 ~ TS-006）

| TS-ID | 类别 | 约束 |
|-------|------|------|
| **TS-001** | 包管理 | 必须用 **CocoaPods**（非 SPM）。私有 Pod 托管在 gitlab.bytescell.net |
| **TS-002** | 私有源 | 必须同时配置 V2 + V1 双源：V2 `https://gitlab.bytescell.net/components/ios/2.0`，V1 `https://gitlab.bytescell.net/components/ios` |
| **TS-003** | 部署目标 | 必须 iOS **15.0+**。禁止使用 iOS 16+ API（NavigationStack、ShareLink、.italic()、.scrollContentBackground、.toolbarColorScheme、TextField axis、.lineLimit(range)、.onChange 双参数版本）。**完整禁止 API 清单 + 降级替代写法见 `templates/ios15-compat/api-downgrade-table.md`（不内嵌到此表，以保持薄 harness 原则，文龙 review 条目 3 决策）**。|
| **TS-004** | 模块化 | 业务代码必须放在 `Locals/` 下的本地 Pod，每个功能一个 Pod |
| **TS-005** | CI/CD | 必须走 GitLab CI 自动部署。本地开发调试，远程 repo 仅用于发布 |
| **TS-006** | 环境切换 | 必须在 BCConfig.swift 中用 `env` 属性（.prod / .stage / .test），本地调试 `.test` 指向 localhost |

### B. 依赖约束（TS-010 ~ TS-015）

| TS-ID | 禁止 | 替代方案 | 归属 skill |
|-------|------|---------|-----------|
| **TS-010** | `import AdjustSdk` | `BCAdjust.sendEvent(token)` | → 见 `/ae-analytics-integrate` |
| **TS-011** | `import FirebaseAnalytics` | `BCTrack.track(event, params)` | → 见 `/ae-analytics-integrate` |
| **TS-012** | `import SuperwallKit` | BCStoreKit + BCPurchaseUI | → 见 `/ae-paywall-integrate` |
| **TS-013** | 直连 OpenAI API | 通过 BCNetwork 调 app-service `/api/llm/v1/chat` | **本 skill**（核心 LLM 功能）|
| **TS-014** | 硬编码 API Key | 密钥只在服务端 CI 变量中，客户端不存储 | **本 skill**（安全基线）|
| **TS-015** | `import StoreKit` 直接使用 | 通过 BCStoreKit 封装 | → 见 `/ae-paywall-integrate` |

> **本 skill 只透传禁止项作为 linter 规则**（grep `import AdjustSdk` 等）。**接入验证不在本 skill 范围内**——完整 precheck、代码模板、接入正确性校验、故障排查由对应下游 integrate skill 负责（埋点验证 → `/ae-analytics-integrate`，支付验证 → `/ae-paywall-integrate`）。
>
> **Pod 版本号不在此表维护** — 替代方案涉及的 BCAdjust / BCSensor / BCStoreKit / BCNetwork 等 Pod 版本号**以 `templates/cocoapods/Podfile.tmpl` 为单一来源**，避免多处硬编码升级时漂移。

### C. 架构约束（TS-020 ~ TS-027）

| TS-ID | 类别 | 约束 | 归属 skill |
|-------|------|------|-----------|
| **TS-020** | UI 架构 | MVVM + Combine。SwiftUI 视图必须用 `BCHostingController` 包装到 UIKit 容器中 | **本 skill** |
| **TS-021** | 导航 | CTMediator 跨模块通信。Tab 页必须在 `TabbarItemType` 枚举中注册 | **本 skill** |
| **TS-022** | 启动序列 | `WorkVoidCallbackTask` 串行链 **12 步（bible-app 参考实现）**：ComponentConfig → Adjust → Debug → Legal → ABTest → UserInit → Upgrade → AfterLogin → DataPreload → Welcome → ConversionPage → MainPage。**支持可选第 11 步 `SupportRateWork`（Capvault 模式 13 步变体）**，模板见 `templates/work-chain/11_SupportRateWork.swift.tmpl` | **本 skill**（骨架）+ 分步实现由对应 integrate 提供 |
| **TS-023** | 账号 | 必须用 BCAccount 设备自动登录，无需用户注册。Login 在 `LaunchTransitionViewController` 中触发 | **本 skill** |
| **TS-024** | 支付 | `BCStoreKit.setup(skus)` 初始化 → `BCPurchaseUIManager` 展示付费墙 → `BCAccount.isVip` 判断 VIP 状态 | → `/ae-paywall-integrate` |
| **TS-025** | AB 测试 | 必须用 `BCABTest.shared.syncFetch*()` 获取服务端配置 | → `/ae-abtest-integrate` |
| **TS-026** | 埋点 | BCSensor 统一路由（神策 + Firebase），`BCTrack.track()` 为唯一入口 | → `/ae-analytics-integrate` |
| **TS-027** | Onboarding | 必须放在 `Locals/Welcome_XX` 本地 Pod 中，通过 AB 测试动态加载 class name | → `/ae-onboarding-integrate` |

> Work Chain 12 步中，**ComponentConfig / UserInit / Upgrade / AfterLogin / DataPreload / MainPage** 由本 skill 负责骨架；**Adjust / ABTest / Welcome / ConversionPage** 四步的具体实现由对应 integrate skill 注入（未接入对应 integrate 时这些 step 应为 no-op）。

### D. 后端约束（TS-030 ~ TS-038）

| TS-ID | 类别 | 约束 |
|-------|------|------|
| **TS-030** | 框架 | 必须 Spring Boot 3.3.4 + Java 17 + MyBatis Plus |
| **TS-031** | LLM | `com.bytescell.component:llm` 组件自动注册 `/api/llm/v1/chat` 和 `chat_stream` 端点，system prompt 配置在项目 `resources/prompt/` 中 |
| **TS-032** | 支付 | `com.bytescell.component:purchase-sdk` 对接内部 purchase-service，Apple S2S Notification 由 purchase-service 接收 |
| **TS-033** | 用户 | `com.bytescell.component:user` 自动注册 `/api/user/v1/*` 端点 |
| **TS-034** | 加密 | `com.bytescell.component:crypto`，prod 开启请求/响应加密，stage 关闭 |
| **TS-035** | 存储 | `com.bytescell.component:storage`，AWS S3（bucket 名 `{product}-scope`） |
| **TS-036** | 新模块 | 必须遵循 controller → service → repository → mapper → entity → dto 分层结构，参考 identify 模块 |
| **TS-037** | 数据库迁移 | Flyway，迁移文件放 `resources/db/migration/` |
| **TS-038** | CI 密钥 | OPENAI_API_KEY、DB 密码、CRYPTO_KEY、AWS 密钥均通过 GitLab CI 变量注入，**禁止提交到仓库** |

### harness 的约束检查建议

本 skill 只负责"核心功能 + 工程基础"的 linter 规则。integrate 层的 TS 约束由对应 skill 自查：

```bash
# 本 skill 负责：
grep -rn 'sk-proj-\|sk-live-' --include="*.swift"                # TS-014 API Key 安全
grep -rn 'NavigationStack\|ShareLink\|\.scrollContentBackground\|\.toolbarColorScheme' --include="*.swift" Locals/  # TS-003 iOS 15 兼容

# TS-010/011/012/015 的 grep 检查由对应 integrate skill 负责：
# /ae-analytics-integrate: AdjustSdk + FirebaseAnalytics 直接引入扫描
# /ae-paywall-integrate:   SuperwallKit + 原生 StoreKit 直接引入扫描
```

---

## 核心第 2 块：代码模板库索引

所有可复用片段放在 `skills/pm/ae-speckit-to-app/templates/` 下。harness 根据 Speckit 的需求选取对应模板，填入产品信息后写入目标工程。

| 模板目录 | 用途 | 文件 | 来源 |
|---------|------|------|------|
| `templates/work-chain/` | Work Chain 骨架（12 步 + 1 可选）| `README.md` + 13 个 `.swift.tmpl`（01~13，其中 `11_SupportRateWork` 为 Capvault 模式可选插入点，bible-app 未启用）| ✅ 从 bible-ios-template `Template/Core/StartupSequence/` + Capvault 对齐 |
| `templates/config/` | BCConfig 环境切换（prod/stage/test） | `BCConfig.swift.tmpl` | ✅ 从 `Locals/BCConfig/BCConfig/BCConfig.swift` 提取 |
| `templates/ios15-compat/` | iOS 15 API 降级速查表（9 类） | `api-downgrade-table.md` | ✅ 从 04-15 trajectory 原文提取 |
| `templates/cocoapods/` | V1+V2 私有源 Podfile 配置 | `Podfile.tmpl` | ✅ 从 bible-ios-template `Podfile` 提取 |

> **已迁出**（v0.58.0 主流程减肥）：
> - `templates/purchase/` → `skills/pm/ae-paywall-integrate/templates/purchase/`
> - `templates/analytics-bootstrap/` → `skills/pm/ae-analytics-integrate/templates/analytics-bootstrap/`

### 模板使用约定

1. 所有 `.swift.tmpl` 文件的占位符格式：`{{UPPERCASE_KEY}}`
2. harness 生成目标文件时，将 `.swift.tmpl` 去掉 `.tmpl` 后缀 + 按下表替换占位符
3. 每个模板目录下的 `README.md` 描述该模板的职责、对接点、已知 TODO

#### 占位符约定清单（文龙 review 条目 9）

| 占位符 | 含义 | 示例 | 来源 |
|--------|------|------|------|
| `{{PRODUCT_NAME}}` | 产品代号（小写单词，无空格）| `bible` / `wepray` / `capvault` | PM + BCConfig `appProductId` |
| `{{PRODUCT_DISPLAY_NAME}}` | 展示名称 | `"WePray"` / `"CapVault"` | PM |
| `{{BUNDLE_ID}}` | iOS Bundle Identifier | `com.kjv.bible.prayer.app` | ASC + pbxproj |
| `{{TEAM_ID}}` | Apple Developer Team ID | `ABCD1234EF` | ASC |
| `{{APP_ID}}` | ASC App ID | `6761982880` | ASC 后台 |
| `{{MAIN_HOST_PROD}}` | 生产环境 host | `app.bible.itemvaults.com` | BCConfig |
| `{{MAIN_HOST_STAGE}}` | stage 环境 host | `app-stage.bible.itemvaults.com` | BCConfig |
| `{{MEMO}}` | AB 变体标识（String，无长度/字符硬性限制）| `01` / `02` / `07` / `vip_a_big_cta` | `BCABTest.shared.syncFetch*()` |

**`{{MEMO}}` 在两个 skill 中的拼接模式不同**（注意不可混用）：

- **Paywall / 转化页**（`/ae-paywall-integrate`）：`PurchaseUI{{MEMO}}ViewController` — 直接拼接，**无下划线**
- **Welcome / 欢迎页**（`/ae-onboarding-integrate`）：`Welcome_{{MEMO}}ViewController` — **下划线连接**

两者 memo 语义相同（由 `BCABTest.shared.syncFetchVip()` 或 `syncFetchWecome()` 返回），但对应代码的类名拼接约定不同，硬编码写错会导致 `NSClassFromString` 动态加载失败 fallback 默认 variant。

**harness 替换命令**：

```bash
sed -i '' "s|{{PRODUCT_NAME}}|$PRODUCT_NAME|g" $output_file
sed -i '' "s|{{BUNDLE_ID}}|$BUNDLE_ID|g" $output_file
# ... 其他占位符同上
```

---

## 核心第 3 块：必要基础要素 Precheck

> 这些是**入口阻塞项**：任何一项没过，后续全链路不可推进。harness 必须在开始执行前通过全部 precheck，否则在 issue / PR 上 comment 阻塞原因并停止。

### P1. CocoaPods V1 + V2 私有源权限

```bash
# 检查：能否 clone V2 任一 pod
git ls-remote https://gitlab.bytescell.net/components/ios/2.0/bc_utility.git HEAD 2>&1 | head -3
# 检查：能否 clone V1 任一 pod（如 BCImageProcess 只在 V1）
git ls-remote https://gitlab.bytescell.net/components/ios/bc_imageprocess.git HEAD 2>&1 | head -3
```

- 两个都返回 commit hash → 通过
- 任一返回 403 / not found → **阻塞**：找龙哥开 `components/ios` + `components/ios/2.0` 两个 group 的 Reporter 权限（bible-app 踩坑：只开 V2 会在最后一个 V1 Pod 失败）

### P2. GitLab 业务仓库 push 权限

```bash
# 检查能否 push 到目标 product repo
git ls-remote https://gitlab.bytescell.net/products/{product}/ios/{product}.git HEAD 2>&1 | head -3
# 真正 push 测试见 harness 本地 dry-run
```

- bible-app 踩坑：`li.genjian` 只有 read 权限，push 时 403 "You are not allowed to upload code"
- **阻塞**：需龙哥给业务仓库加 Developer 角色

### P3. Xcode 已登录 Team Apple ID (2FA 通过)

```bash
security find-identity -p codesigning -v | grep -E "Apple Development|Apple Distribution"
```

- 至少一个对应 Team ID 的证书 → 通过
- 空 → **阻塞**：Xcode → Settings → Accounts → + Apple ID，登录后 2FA 验证（唯一人工卡点）

> **执行环境限制（当前阶段）：** P3 要求在**开发者本地机器**执行（Xcode GUI 登录 + 2FA 交互），不支持 CI 自动化。**CI Mac 方案待 iOS CI 流程成熟后补充**（目前 Scale Global iOS 侧未建立 CI pipeline）。

### P4. BCConfig env 文件就位 + 品牌参数已填

harness 检查 `Locals/BCConfig/BCConfig/BCConfig.swift`：
- `appId` / `teamId` / `supportEmail` / `awsBucket` / `mainHost(prod/stage)` 非占位
- `appProductId` 非占位（AB 测试 key 前缀 + Adjust 归属依赖）

有任一占位 → **阻塞**：向 PM / 运营索要实际值。

> **`AdjustToken` 枚举 token 的非占位检查** 由 `/ae-analytics-integrate` Phase 1 前置负责（属于埋点/归因领域）。

### P5. `pod install` 通过

```bash
cd {project_root}
pod install --repo-update 2>&1 | tail -10
```

- 看到 `Pod installation complete!` → 通过
- 常见失败：P1 未过 / 网络超时（`ENV["COCOAPODS_TIMEOUT"] = "600"` 已在 Podfile，可重试）

### P6. 后端 stage 可达（有后端时）

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://app-stage.{product}.itemvaults.com/api/user/v1/initialize
```

**返回码解读：**

| 返回 | 含义 | 状态 |
|------|------|------|
| **401 / 403** | 服务在线，客户端请求缺必要参数（缺 SIGN header / userId）或参数不符合预期，属于预期响应 | ✅ 通过 |
| **200** | 服务在线（可能存在空 GET 端点） | ✅ 通过 |
| **5xx（500/502/503）** | 服务端异常（后端崩 / OOM / 未启动） | 🛑 阻塞：查 stage EC2 Java 进程 + 日志（bible-app 踩坑：deploy 后 OOM）|
| **504 / 连接超时 / curl error 28** | 服务不可达（网关 timeout / DNS 解析失败 / 端口未开放） | 🛑 阻塞：查网络 + Load Balancer + EC2 安全组 |

### P7. pbxproj 品牌参数 + NSUsageDescription 合规扫描（S1 + S3，dogfood 发现）

**S1 — pbxproj 品牌参数非模板残留：**

```bash
PBXPROJ=$(find . -name "*.xcodeproj" -maxdepth 2 | head -1)/project.pbxproj

# 三个关键品牌字段必须 = 新产品命名，不是 WePray/CapVault/占位
grep -E "PRODUCT_BUNDLE_IDENTIFIER\s*=" "$PBXPROJ" | sort -u | head -5
grep -E "INFOPLIST_KEY_CFBundleDisplayName\s*=" "$PBXPROJ" | sort -u | head -3
grep -E "PRODUCT_NAME\s*=" "$PBXPROJ" | sort -u | head -3

# 反向扫描：是否残留历史品牌标识
grep -iE "capvault|wepray|biblechat|\{\{[A-Z_]+\}\}" "$PBXPROJ" | head -10
```

预期：前三个字段 = 新产品命名（如 `com.{product}.app`），反向扫描 0 匹配。**发现残留 → 阻塞**，替换为新品牌值。

**S3 — NSUsageDescription Apple Review Guideline 5.1.1 合规扫描：**

```bash
INFO_PLIST=$(find . -name "Info.plist" -not -path "./Pods/*" -not -path "./build/*" | head -1)

plutil -p "$INFO_PLIST" | grep -E "NS(Camera|PhotoLibrary|Microphone|Location|FaceID|Contacts|Calendar|Motion|Speech|Reminders|UserTracking|Bluetooth|Health)UsageDescription"
```

每条 NS*UsageDescription 必须：

- ✅ 非空
- ✅ 非 Apple 默认占位（"Replace me" / "TODO" / "{{placeholder}}" / 纯英文骨架如 "We use your camera"）
- ✅ 描述**清晰说明本产品使用场景**（不是复用 WePray/CapVault 的文案）
- ✅ 符合 Apple 5.1.1：用途具体、不恐吓、不误导

**发现不合规 → 阻塞**：向 PM 索要文案，或从 `/ae-asc-submit` 的 Review Notes 对齐。

---

## 核心第 4 块：调试方法速查

### 4.1 模拟器 UI 自动化 — fb-idb（替代 cliclick）

**背景（04-16 comment 踩坑）**：Quartz CGEvent / cliclick 会劫持物理鼠标，中间用户移动鼠标 tap 会错位。`fb-idb` 直接操作模拟器 view tree。

```bash
# 安装
brew tap facebook/fb && brew install idb-companion
pip3 install fb-idb

# 常用
idb list-targets                          # 查看模拟器 UDID
idb ui describe-all --udid {UDID}        # 导出完整 view tree (JSON)
idb ui tap 100 200 --udid {UDID}          # 精确点击坐标
idb ui text "hello" --udid {UDID}        # 输入文本
idb launch {bundle_id} --udid {UDID}
```

### 4.2 Work Chain 串行链调试 — DEBUG_SKIP

**背景（04-15 comment "坑7"）**：12 步任一卡住后续全断。最常卡的 3 步：UserInitWork（后端不可达）/ WelcomeWork（onboarding 要点完）/ ConversionPageWork（付费墙加载不到）。

临时跳过方法：在对应 Work 类的 `work(_:)` 入口加 `#if DEBUG` 早 callback：

```swift
func work(_ callback: @escaping VoidCallback) {
    #if DEBUG
    if ProcessInfo.processInfo.environment["DEBUG_SKIP_USERINIT"] == "1" {
        callback()
        return
    }
    #endif
    // 原逻辑
    LaunchTransitionViewController.show(...)
}
```

运行时：Xcode → Edit Scheme → Run → Arguments → Environment Variables 加 `DEBUG_SKIP_USERINIT=1`。

> ⚠️ **推 GitLab 前必须全部去除**（04-15 comment 已踩过）

**自动检查（文龙 review 条目 10：双处强制）：**

- **Precheck 提示层（agent 开发时看到）**：

  ```bash
  # 在 P7 之后加一条非阻塞提示（若扫到未守卫的 DEBUG_SKIP，提醒 agent 是否临时测试中）
  grep -rn "DEBUG_SKIP" --include="*.swift" Template/ Locals/ 2>/dev/null | grep -v "#if DEBUG"
  ```

- **Done Criteria 发布卡点层（强制零匹配才 publish）**：见下方 Done Criteria **D6**。

### 4.3 Stage 500 定位 — 查 OPENAI_API_KEY + system_prompt

**背景（04-15 comment）**：`/api/llm/v1/chat` 500 最常见两个原因：

1. **OPENAI_API_KEY CI 变量为空 / 无效** → 让后端同学查 `gitlab.bytescell.net/products/{product}/server/{product}-app-service/-/settings/ci_cd` 的 Variables
2. **system_prompt 文件名不匹配** → LLM 组件默认读 `system_prompt.txt`，如果自定义名字（如 `bible_chat_prompt.txt`）必须在 application.properties 里改 `llm.prompt.path`

快速验证：

```bash
# 客户端触发一次 chat（需已通过 /user/v1/initialize 拿到 userId + accessToken）
curl -X POST https://app-stage.{product}.itemvaults.com/api/llm/v1/chat \
  -H "Content-Type: application/json" \
  -H "ACCESS_TOKEN: {accessToken}" \
  -H "SIGN: {md5(userId|timestamp)}" \
  -d '{"message":"hello"}'
# 200 → 通；500 → 去后端日志 grep "OpenAI\|OPENAI\|ApiKey"
```

### 4.4 CocoaPods V1+V2 权限诊断

```bash
# 逐个 clone 测试，定位哪个 group 缺权限
GITLAB_USER="{your-gitlab-user}"
TOKEN="{your-pat}"
for url in "components/ios/2.0/bc_utility" "components/ios/bc_imageprocess"; do
  curl -s -o /dev/null -w "$url %{http_code}\n" \
    "https://$GITLAB_USER:$TOKEN@gitlab.bytescell.net/$url.git/info/refs?service=git-upload-pack"
done
# 200 = 有权限 | 401 = token 错 | 404 = 无 group 权限
```

### 4.5 Xcode 项目引用 — 新建 .swift 文件不在 target

**背景（04-15 comment "坑5"）**：直接 `Write` 新 .swift 到 `Template/Feature/` 下，Xcode 项目 `.pbxproj` 不会自动识别。

**推荐：团队统一用 Bundler（避免 gem 路径写死 CocoaPods 版本）：**

```ruby
# Gemfile 加入 xcodeproj gem（随项目锁定版本）
# gem 'xcodeproj'

bundle exec ruby -rxcodeproj -e "
project = Xcodeproj::Project.open('Template.xcodeproj')
target = project.targets.find { |t| t.name == 'Template' }
group = project.main_group.find_subpath('Template/Feature/TabContent/Chat', true)
file_ref = group.new_reference('ChatTabViewController.swift')
target.add_file_references([file_ref])
project.save
"
```

**无 Bundler 的临时方案 — 动态定位 CocoaPods 内置的 xcodeproj：**

```bash
# 不要写死 1.16.2_2 等版本号（文龙 review 条目 11）
# 方式 1：通过 pod binary 反查 libexec
POD_LIBEXEC="$(dirname "$(dirname "$(which pod)")")/libexec"

# 方式 2：如果 xcodeproj gem 已系统安装（或 rbenv/gem install），直接：
ruby -rxcodeproj -e '...'

# 方式 3：询问 CocoaPods 自己的 ruby 环境
POD_RUBY_PATH=$(pod env 2>/dev/null | grep "Ruby Path" | awk -F': ' '{print $2}')
```

或更简单：用 Xcode GUI → Add Files to Template → 勾选对应 target（一次性操作用这个即可，不需写脚本）。

---

## Done Criteria（可机械验证）

harness 必须验证以下 6 项全过才能标记 skill 完成：

| # | 检查 | 命令 / 方法 | 通过标准 |
|---|------|------------|----------|
| D1 | `pod install` 零失败 | `pod install --repo-update` | `Pod installation complete!` + 无 error |
| D2 | 模拟器编译通过 | `xcodebuild build -workspace Template.xcworkspace -scheme Template -destination "generic/platform=iOS Simulator"` | `BUILD SUCCEEDED` |
| D3 | 真机 archive 可过 | `xcodebuild archive -workspace Template.xcworkspace -scheme Template -archivePath /tmp/{product}.xcarchive -destination 'generic/platform=iOS' -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM={TeamID}` | `** ARCHIVE SUCCEEDED **` |
| D4 | 启动链跑通到 MainTab | 模拟器/真机启动 + `idb ui describe-all` 或手动观察 | 看到 4 个 Tab（按 Speckit 定义），非启动页白屏 |
| D5 | stage CI 绿灯 | 推送后查 GitLab CI 页面 | **当前阶段**：iOS 侧无 CI（Scale Global iOS CI pipeline 未建立），**仅检查后端 Pipeline 全绿**；iOS CI 搭建后需回来更新本条 |
| **D6** | **无未守卫的 `DEBUG_SKIP` 代码**（文龙 review 条目 10）| `grep -rn "DEBUG_SKIP" --include="*.swift" Template/ Locals/ \| grep -v "#if DEBUG"` | 0 匹配（所有 `DEBUG_SKIP_*` 分支必须包在 `#if DEBUG` / `#endif` 中，release 编译不生效）|

**任一不过 → 不 publish，不 close issue，comment 说明阻塞原因。**

---

## 常见失败模式 + 修复速查

从 trajectory 提炼的高频问题：

| # | 失败现象 | 根因 | 修复 |
|---|---------|------|------|
| F1 | `pod install` 最后一个 Pod 404 | V1 group 权限缺失 | precheck P1 |
| F2 | Archive 报 `No account for team` | Xcode 未登录对应 Apple ID | precheck P3 |
| F3 | 真机启动卡在启动页（白屏） | UserInitWork login 卡住，stage 后端不可达 | precheck P6 / 临时 DEBUG_SKIP |
| F6 | 编译报 `NavigationStack` 等不可用 | iOS 15 不支持 iOS 16+ API | 按 templates/ios15-compat/api-downgrade-table.md 降级 |
| F7 | 跨模块引用 View 报 `cannot find 'XxxView' in scope` | Pod 模块内 struct 默认 internal | 所有跨模块 View 必须 `public struct` + `public var body` + `public init()` |
| F8 | `/api/llm/v1/chat` 500 | OPENAI_API_KEY 空 / system_prompt 文件名不匹配 | 4.3 调试速查 |
| F9 | iOS 26 模拟器多一个橙色相机按钮 | `TabBarController.setupControllers()` 的 `IOS26 {}` 分支加了 identify tab | 注释掉 IOS26 分支的 EmptySearchViewController 添加 |
| F10 | `pod install` 成功但主工程报 `No such module 'XXX'` | Podfile 改动后没重新打开 workspace | `killall Xcode && open Template.xcworkspace` |

> **已迁出**（v0.58.0 主流程减肥）：
> - F4 付费墙主题错误 / F5 关闭按钮 touch 传递失效 → `/ae-paywall-integrate` 故障排查

---

## 与其他 skill 的关系

```
Speckit 输入
    │
    ▼
/ae-speckit-to-app ──→ 本地可编译 + 启动链通 + stage CI 绿（本 skill 瘦身版）
    │
    │  ── 核心功能 + 工程基础（保留在本 skill）：
    │     Work Chain 骨架 / BCConfig / CocoaPods V1+V2 / iOS15 降级 /
    │     LLM (TS-013) / API Key 安全 (TS-014) / UI 架构 (TS-020~021) /
    │     账号 (TS-023) / 后端约束 (TS-030~038)
    │
    ├── 后置 integrate 能力（按需接入，不影响主流程）：
    │   ├── /ae-analytics-integrate ──→ TS-010/011/026 埋点 + 归因 (templates/analytics-bootstrap)
    │   ├── /ae-paywall-integrate ───→ TS-012/015/024 Paywall + BCStoreKit (templates/purchase)
    │   ├── /ae-notification-integrate → 本地通知
    │   ├── /ae-feedback-integrate ───→ 用户反馈
    │   ├── /ae-i18n-integrate ───────→ 多语言
    │   ├── /ae-abtest-integrate ─────→ TS-025 AB 测试
    │   └── /ae-onboarding-integrate ─→ TS-027 Welcome_XX + 评分引导
    │
    └── 发布路径：
        └── /ae-app-to-testflight ──→ 签名 → Archive → TestFlight
```

**Route B 走本 skill**（Route A `/ae-superwall-setup` 已废弃，独立 StoreKit 2 + Superwall 不依赖 BytesCell 体系）。

**v0.58.0 主流程减肥** — 原 38 条 TS 约束中 TS-010/011/012/015/024/025/026/027 共 8 条迁出到对应 integrate skill，本 skill 保留 30 条核心约束 + 4 个工程基础模板（原 6 个模板中 purchase / analytics-bootstrap 迁出）。

## 复用说明

所有模板均以产品无关方式编写（占位符 `{{PRODUCT_NAME}}` / `{{MEMO}}` / `{{BUNDLE_ID}}` 等）。新产品接入：
1. 复制整套 `templates/` 到目标工程对应路径
2. 全局替换占位符为本产品值
3. 按 precheck P1~P6 逐项放行
4. harness 按 TS-001~038 校验并补齐
5. 跑 done criteria D1~D5

**关键变量只有约 15 个**（product / appId / teamId / bundleId / hosts / skus / adjust tokens / supportEmail / awsBucket / scheme / memo），其余完全复用。
