---
description: "iOS 多语言全流程 — CL10nKit + BCLocalization + 项目/Pod 级 Language extension + InfoPlist.strings（Scale Global 生态）"
last_updated: "2026-04-23"
permissions:
  allow:
    - "Bash(xcodebuild *)"
    - "Bash(pod *)"
    - "Bash(python3 *)"
    - "Bash(grep *)"
    - "Bash(find *)"
    - "Bash(ls *)"
    - "Bash(mkdir *)"
    - "Bash(cp *)"
dependencies:
  mcp: []
  cli:
    - name: xcodebuild
      verify: "xcodebuild -version"
    - name: pod
      verify: "pod --version"
    - name: python3
      verify: "python3 --version"
  api_keys: []
  scripts: []
smoke_test:
  command: "xcodebuild -version"
  expected_exit: 0
  description: "xcodebuild available"
---

# Skill: 多语言全流程 (ae-i18n-integrate)

> **经 bible-ios-template + plant-app 实战验证。** 基于 Scale Global 内部 `CL10nKit` + `BCLocalization` + `Localize_Swift` 三层封装，产出文案 key 管理、多语言扩展、InfoPlist 本地化、埋点英文一致性、unused key 清理的全流程。

## 核心原则

> **你是 i18n 工程师。** 基于 PM 提供的支持语言清单 + 业务文案场景，产出：① 文案 key 分层放置（CL10nKit 通用 / 项目业务 / Pod 专属）；② 多语言 `.lproj` 目录扩展；③ `Language` extension static var 批量注册；④ InfoPlist.strings 系统权限文案本地化；⑤ 埋点英文一致性保证。
>
> **关键约束：**
> 1. 通用文案先查 **CL10nKit 已内置 310+ `ctext_xxx`**，不要重复定义
> 2. 展示给用户的文案走 `Language.xxx` / `Language.text(for: key)`；**埋点事件名 / parameter key 必须英文硬编码**（不走 Language）
> 3. 新加语言必须**同步覆盖项目主 + 所有 Locals Pod**，否则混合回落 en 会产生"半翻译"体验
> 4. 禁止业务代码直接用 `NSLocalizedString` / 硬编码字符串

## 触发条件

- PM 说"加中文 / 日文 / 西班牙语"、"支持多语言"、"出海多国发布"
- 新产品初始只有英文（参考 bible-ios-template 主 strings 只有 en），需扩展
- preflight / App Store 审核提示"本地化覆盖不足"
- UI 审计发现硬编码字符串

## 角色分工

| 事项 | 谁做 |
|------|------|
| Podfile 含 CL10nKit + BCLocalization | **杭州团队（触发本 skill 前完成）** |
| 支持语言清单（业务决策）| PM + 出海市场团队 |
| 翻译（专业翻译 / AI 翻译 / 社区）| PM 组织（本 skill 不包含翻译工作）|
| 通用 `ctext_xxx` 新增（需提 PR 到 CL10nKit Pod）| **杭州团队**（仅通用）|
| 项目 Language extension 新增业务 key | Agent |
| Pod 专属文案（Welcome_XX 等）| Agent 或业务 Pod 维护者 |
| `.lproj` 目录创建 + 文件占位 | Agent |
| 翻译文件填充 | PM（本 skill 只提供骨架）|
| InfoPlist.strings 系统权限文案 | Agent + PM（系统文案由 PM 确认后 Agent 写入）|
| unused key 清理脚本跑通 | Agent |

## 前置条件

| 条件 | 验证方法 |
|------|---------|
| ae-preflight 已通过 | 编译通过 |
| Podfile 含 CL10nKit + BCLocalization | `grep -E 'pod "(CL10nKit\|BCLocalization)"' Podfile` 有匹配 |
| `Template/Resources/Localizations/Language.swift` 存在 | `find Template/Resources/Localizations -name "Language.swift"` |
| `Template/Resources/Localizations/en.lproj/Localizable.strings` 存在 | 同 |
| `Template/Resources/Localizations/en.lproj/InfoPlist.strings` 存在 | 同 |

前置未就绪 → **停在这里**。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| 产品名称 | 是 | 如 "WePray" |
| 当前语言状态 | 是 | 当前已支持哪些 `.lproj`（通常起步 = en-only）|
| 目标语言清单 | 是 | 如 `["en","de","es","fr","it","ja","nl","pt-BR","zh-Hans","zh-Hant"]`（Scale Global 标准 10 语言）|
| 新增业务文案清单（如有）| 否 | key + 英文原文（可能是产品迭代新增的业务文案）|
| InfoPlist 权限文案 | 否 | 产品用到的系统权限（camera / photo / location / tracking 等）|

---

## Phase 1: 前置检查 + 现状扫描

### Step 1.1: Podfile

```bash
grep -E 'pod "(CL10nKit|BCLocalization|Localize_Swift)"' Podfile
```

**预期：** CL10nKit + BCLocalization 有匹配（tag 如 `1.10.2` / `1.6.1`）。Localize_Swift 通常通过 BCLocalization 依赖引入。

### Step 1.2: 现状扫描 — 项目主语言覆盖

```bash
ls Template/Resources/Localizations/
find Template/Resources/Localizations -name "*.strings" -exec wc -l {} \;
```

记录：当前已有哪些 `.lproj`，每个语言 `Localizable.strings` 和 `InfoPlist.strings` 的行数。差异 → 部分 key 未翻译。

### Step 1.3: 现状扫描 — Locals Pod 语言覆盖

```bash
for pod_dir in Locals/*/; do
    pod_name=$(basename "$pod_dir")
    lproj_count=$(find "$pod_dir" -type d -name "*.lproj" 2>/dev/null | wc -l)
    echo "$pod_name: $lproj_count langs"
done
```

记录：每个 Locals Pod 覆盖的语言数。**不一致（有的 Pod 9 语言，有的只 en）是常态**，本 skill Phase 3 会统一。

### Step 1.4: 现状扫描 — 硬编码字符串（反模式排查）

```bash
# 找 SwiftUI Text / Label 中的硬编码字符串（启发式，可能假阳）
grep -rnE 'Text\("[A-Za-z][^"]{3,}"\)|Label\("[A-Za-z][^"]{3,}"' --include="*.swift" . 2>/dev/null | grep -v Pods | head -30

# 找 NSLocalizedString 使用点（业务代码禁止直接用）
grep -rn "NSLocalizedString" --include="*.swift" . 2>/dev/null | grep -v Pods | grep -v "String+Ext.swift"
```

**结果用于 Phase 2 修复清单**：硬编码字符串需改走 `Language.xxx`。

### Step 1.5: 向 PM 确认

> 1. 目标支持语言清单？（建议 Scale Global 标准 10 语言：en/de/es/fr/it/ja/nl/pt-BR/zh-Hans/zh-Hant）
> 2. 是否有出海市场优先级排序？
> 3. 翻译资源就绪？（专业翻译文件 / AI 翻译工具 / 临时占位）

---

## Phase 2: 文案 key 分层放置

### Step 2.1: 判断文案归属

每条新文案决策树：

```
是通用 UI 文案（Cancel / OK / Save / Failed / Loading / Retry / …）?
  ├─ 是 → 先查 CL10nKit：grep "ctext_cancel\|ctext_ok" Pods/CL10nKit/CL10nKit/Classes/Language.swift
  │       ├─ 已有 → 用 Language.ctext_xxx，不重复定义
  │       └─ 没有 → 提需求给杭州团队扩 CL10nKit（本 skill 不直接改 Pod）
  └─ 否 → 是否是 Pod 专属（如 Welcome_01 的 onboarding 文案）?
          ├─ 是 → 定义在该 Pod 的 Language extension + 该 Pod 的 Localizable.strings
          └─ 否（业务主线文案）→ 定义在 Template/Resources/Localizations/Language.swift + 项目主 Localizable.strings
```

### Step 2.2: 项目业务 key 注册

在 `Template/Resources/Localizations/Language.swift` extension 中：

```swift
import Foundation
import BCLocalization
import CL10nKit
import Localize_Swift

extension Language {
    static func enText(for key: String) -> String {
        let bundle: Bundle = Bundle.main
        if let path = bundle.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        } else {
            return key.resolvedLocalization()
        }
    }

    // 业务 key（非通用），以 product 标识前缀
    static var wepray_chat_placeholder: String { self.text(for: "wepray_chat_placeholder") }
    static var wepray_bible_verse_title: String { self.text(for: "wepray_bible_verse_title") }
    // ...
}
```

**命名约定：**
- 通用 UI → `ctext_xxx`（CL10nKit 维护）
- 项目业务 → `{product}_xxx`（如 `wepray_chat_placeholder`）
- Pod 专属 → `{pod}_xxx`（如 `welcome_01_title`）

### Step 2.3: 项目主 Localizable.strings 补 key

```
# Template/Resources/Localizations/en.lproj/Localizable.strings
"wepray_chat_placeholder" = "Ask anything about the Bible...";
"wepray_bible_verse_title" = "Today's Verse";
```

**每个 static var 对应一条英文 key-value**。

### Step 2.4: 硬编码字符串改造

对 Phase 1 Step 1.4 找到的硬编码位置：

```swift
// ❌ 改前
Text("Submit")

// ✅ 改后（使用 CL10nKit 已有 key）
Text(Language.ctext_submit)

// ✅ 改后（业务特有 key，需 Step 2.2 注册）
Text(Language.wepray_chat_send_button)
```

---

## Phase 3: 多语言扩展

### Step 3.1: 创建新语言 `.lproj` 目录（项目主）

```bash
TARGET_LANGS=("de" "es" "fr" "it" "ja" "nl" "pt-BR" "zh-Hans" "zh-Hant")
SOURCE_LPROJ="Template/Resources/Localizations/en.lproj"

for lang in "${TARGET_LANGS[@]}"; do
    target="Template/Resources/Localizations/${lang}.lproj"
    mkdir -p "$target"
    cp "$SOURCE_LPROJ/Localizable.strings" "$target/Localizable.strings"
    cp "$SOURCE_LPROJ/InfoPlist.strings" "$target/InfoPlist.strings"
done
```

**先复制 en 版作为占位**，PM 再组织翻译填充。

### Step 3.2: Locals Pod 同步扩展

```bash
for pod_dir in Locals/*/; do
    pod_name=$(basename "$pod_dir")
    en_lproj=$(find "$pod_dir" -type d -name "en.lproj" 2>/dev/null | head -1)
    [ -z "$en_lproj" ] && continue  # Pod 无 en.lproj 的跳过

    parent_dir=$(dirname "$en_lproj")
    for lang in "${TARGET_LANGS[@]}"; do
        target="$parent_dir/${lang}.lproj"
        if [ ! -d "$target" ]; then
            mkdir -p "$target"
            cp "$en_lproj/Localizable.strings" "$target/Localizable.strings"
            [ -f "$en_lproj/InfoPlist.strings" ] && cp "$en_lproj/InfoPlist.strings" "$target/InfoPlist.strings"
        fi
    done
done
```

**每个 Locals Pod 必须覆盖同样的语言集**，否则 Pod 文案回落英文会和项目主语言不一致。

### Step 3.3: Xcode project.pbxproj 注册语言

在 Xcode 中：Project → Info → Localizations → + 添加每种语言（或 xcodegen 的 `project.yml` 加 `settings: LOCALIZATIONS: [en, de, es, ...]`）。

**验证：** `grep "knownRegions" *.xcodeproj/project.pbxproj | head -5` 应看到所有语言 code。

### Step 3.4: PM 组织翻译

给 PM 的输出：

```
文件清单（N 个语言 × M 个文件 = N*M 份 strings）：
Template/Resources/Localizations/de.lproj/Localizable.strings
Template/Resources/Localizations/de.lproj/InfoPlist.strings
Locals/Welcome_01/Welcome_01/Localizable/de.lproj/Localizable.strings
...

翻译方式：
  [ ] 专业翻译（Lokalise / Phrase / Transifex）
  [ ] AI 翻译（DeepL / Google Translate API）
  [ ] 社区翻译
```

**本 skill 不做翻译**，只交付文件骨架 + 英文原文。

---

## Phase 4: InfoPlist.strings 系统权限文案

### Step 4.1: 识别用到的系统权限

```bash
grep -E "NS(Camera|PhotoLibrary|Location|UserTracking|Microphone|FaceID|Contacts|Calendar).*UsageDescription" Info.plist
```

### Step 4.2: 每种语言的 InfoPlist.strings 补齐

```
# en.lproj/InfoPlist.strings
"NSCameraUsageDescription" = "Take photos of Bible verses to save and share.";
"NSUserTrackingUsageDescription" = "This helps us personalize your Bible study experience.";

# zh-Hans.lproj/InfoPlist.strings
"NSCameraUsageDescription" = "拍摄经文照片并分享保存。";
"NSUserTrackingUsageDescription" = "帮助我们个性化您的圣经学习体验。";
```

**所有语言的 key 必须完全一致**（只差翻译内容），缺失 key → 系统弹窗显示英文或空字符串。

---

## Phase 5: 埋点英文一致性

### Step 5.1: 埋点硬规则

所有埋点事件名、event type、parameter key、parameter value（枚举类）**必须英文硬编码**，**不走** `Language.xxx`。

```swift
// ❌ 禁止
BCTrack.track(Language.wepray_chat_event, type: .click)

// ✅ 正确（英文硬编码）
BCTrack.track("chat_send", type: .click, parameters: ["source": "paywall_close"])
```

### Step 5.2: 例外：需要上报本地化内容时

极少数场景（如用户反馈内容需要带用户语言）可用 `Language.enText(for: key)` 强制英文：

```swift
BCTrack.track("feedback", parameters: [
    "category_en": Language.enText(for: "feedback_chat_irrelevant")  // 永远英文
])
```

### Step 5.3: 扫描误用

```bash
grep -rnE "BCTrack\.track\(Language\." --include="*.swift" . 2>/dev/null | grep -v Pods
```

**预期：0 匹配**。有匹配 → 改为英文硬编码。

---

## Phase 6: 清理 unused key

### Step 6.1: 复用 `Scripts/remove_unused_localized_keys.py` 脚本

**⚠️ 原脚本（bible-ios-template/Scripts/）路径写死 Plant 项目，需改通用化：**

```bash
# 通用化调用
python3 Scripts/remove_unused_localized_keys.py \
    --language-file "Template/Resources/Localizations/Language.swift" \
    --strings-file "Template/Resources/Localizations/en.lproj/Localizable.strings" \
    --search-root "."
```

如原脚本不支持参数，需先 PR 通用化（把三个 path 变量改为 argparse）。

### Step 6.2: 执行清理

```bash
python3 Scripts/remove_unused_localized_keys.py
# 输出：未使用 key 清单 + 修改后的 Language.swift / Localizable.strings
```

**谨慎：** 脚本只扫 `Language.swift` 的 `static var` vs 其他 .swift 文件的字符串匹配。可能假阳性（key 在 strings file 但 Language.swift 没注册）。先 dry-run 列出再删。

---

## Phase 7: 集成验证

### Step 7.1: 编译通过

```bash
xcodebuild build -workspace <Name>.xcworkspace -scheme <Scheme> \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15
```

### Step 7.2: 运行时语言切换验证

1. iOS Settings → General → Language & Region → Preferred Language 顺序 → 把目标语言拖到顶
2. 重启 App
3. 检查：
   - UI 文案 = 目标语言
   - 系统权限弹窗（NSUserTrackingUsageDescription 等）= 目标语言
   - App Store 元数据（如有多语言）显示目标语言

### Step 7.3: 缺失翻译 fallback 行为

某些 key 仅在 en.lproj 有、其他语言没补：
- 预期：显示英文（iOS 自动回落 dev language）
- 不预期：显示裸 key（说明 en.lproj 也没有）

```bash
# 检查所有语言的 key 一致性
python3 -c "
import os, re
base = 'Template/Resources/Localizations'
en_keys = set(re.findall(r'\"([^\"]+)\"\s*=', open(f'{base}/en.lproj/Localizable.strings').read()))
for d in os.listdir(base):
    if d.endswith('.lproj') and d != 'en.lproj':
        path = f'{base}/{d}/Localizable.strings'
        if os.path.exists(path):
            keys = set(re.findall(r'\"([^\"]+)\"\s*=', open(path).read()))
            print(f'{d}: missing {len(en_keys - keys)} keys, extra {len(keys - en_keys)} keys')
"
```

---

## Phase 8: 输出

```
═══════════════════════════════════════════
  多语言集成完成 ✅
═══════════════════════════════════════════

产品：{产品名称}
支持语言：{N} 种 ({en, de, es, fr, it, ja, nl, pt-BR, zh-Hans, zh-Hant})

覆盖状态：
  项目主 Localizations：
    - Localizable.strings：N × {key 数}
    - InfoPlist.strings：N × {权限数}
  Locals Pod：
    - Welcome_01：{语言数} / N
    - Welcome_02：{语言数} / N
    - BCAppSearch：{语言数} / N
    - ...

新注册业务 key：{数量}（定义在 Template/Resources/Localizations/Language.swift）
硬编码字符串修复：{数量} 处
埋点 Language 误用修复：{数量} 处

待 PM 处理：
  - [ ] {N-1} 种语言的翻译填充（当前占位为英文）
  - [ ] ASC App Store 元数据多语言（标题/描述/关键词）
  - [ ] 推送文案多语言（远程推送 payload，如有）
═══════════════════════════════════════════
```

---

## 硬性规则

1. **文件格式锁定 `.strings`**（杭州审计 P0-12）— 不切换到 `.stringsdict` / `.xcstrings`。生态全是老 `.strings`，迁移成本高不值得。
2. **通用 UI 文案先查 CL10nKit 的 310+ `ctext_xxx`，不重复定义** — 重复等于 Pod 和项目各写一份，未来更新不同步会出问题。
3. **公共词条由开发手动判断入库**（杭州审计 P0-15）— **无自动提取机制**，开发判断某条文案通用后手动收录到公共词条库，避免各项目重复翻译相同文案。判断标准由开发把控。
4. **埋点事件名 / parameter key / 枚举 value 必须英文硬编码** — 不走 `Language.xxx`。埋点后台跨地区用户数据要可比，本地化 event name 会让 BI 无法聚合。
5. **所有 static var 对应 key 必须在 en.lproj/Localizable.strings 有条目** — 缺失会显示裸 key。
6. **新加语言必须覆盖项目主 + 所有 Locals Pod** — 部分覆盖会"半翻译"（主界面翻了，onboarding 英文）。
7. **InfoPlist.strings 每种语言都必须完整** — iOS 系统权限弹窗在缺失翻译时行为不可控（可能空字符串或英文）。
8. **Welcome_XX 欢迎页第一版 en-only**（杭州审计 P0-16）— 各欢迎页独立，第一版只适配英文；某 variant 数据表现好（高转化）再单独投入多语言，**不做统一多语化**。
9. **禁止业务代码直接用 `NSLocalizedString` 或硬编码字符串** — 统一走 `Language.xxx`（业务 key）或 `Language.ctext_xxx`（通用）。
10. **运行时切语言为未来扩展**（杭州审计 P0-13）— 第一版**跟随系统语言**即可。运行时切语言仅用于"App 不支持用户系统语言，需 fallback 其他语言"的场景（如系统泰语但用户懂法语），暂不作为标准能力。
11. **`remove_unused_localized_keys.py` 各产品自维护**（杭州审计 P0-14）— 按产品定位分类（内容型一套、工具型一套），**不集中到 ae-platform/scripts**。PR 通用化建议取消。

---

## 反模式

❌ **项目 Language extension 加 `static var ok: String`（通用文案重复定义）**
→ CL10nKit 已有 `Language.ctext_ok`。用 CL10nKit 版本，未来 Pod 更新通用文案项目跟进。

❌ **`Text("Submit")` 硬编码英文字符串**
→ 直接出海不可见。用 `Text(Language.ctext_submit)`。

❌ **业务代码 `NSLocalizedString("key", comment: "")`**
→ 绕开 Language 统一 API，未来迁移成本高。改为 `Language.text(for: "key")` 或定义 static var。

❌ **埋点 `BCTrack.track(Language.wepray_chat_event)`**
→ 用户地区切换后 event name 变了，后台无法聚合跨地区数据。event 必须英文硬编码。

❌ **加 zh-Hans 只加项目主 `.lproj`，不同步 Welcome_01 / BCAppSearch 等 Pod**
→ 用户切中文后首页中文、onboarding 英文、设置页中英混杂。必须全覆盖。

❌ **给 en.lproj 新增 key 但忘给其他语言补**
→ 其他语言显示英文，主界面多语言但新增功能单语言。每次加 key 跑 Step 7.3 一致性检查。

❌ **InfoPlist.strings 只有 en，其他语言没补 NSUserTrackingUsageDescription**
→ 非英文地区用户看到 ATT 弹窗是空的或英文，拒授率 +++。Apple Guideline 5.1.1 审核风险。

❌ **新 Pod（如 loopcraft 的 LoopModule）直接在项目主 Language.swift 加 key**
→ 违反分层原则。Pod 专属文案应定义在该 Pod 自己的 Language extension + 该 Pod 的 Localizable.strings（可跟 Pod bundle 一起分发）。

❌ **不跑 `remove_unused_localized_keys.py` 定期清理**
→ Language.swift 膨胀（bible-ios-template 已到 311 行 / 310+ static var），review 成本高 + bundle size 虚胖。

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `Text(Language.xxx_yyy)` 显示裸 `xxx_yyy` 字符串 | Localizable.strings 未定义该 key | 检查 en.lproj/Localizable.strings 是否有对应 entry |
| 部分界面翻了、部分英文 | Locals Pod 没补对应语言 `.lproj` | Phase 3.2 同步扩展所有 Locals Pod |
| iOS 系统权限弹窗空字符串 | 对应语言的 InfoPlist.strings 缺 NS*UsageDescription | Phase 4.2 每种语言 InfoPlist.strings 补齐 |
| 语言切换后 App 没更新 UI | `Localize_Swift` 的 setLanguage 后 rootVC 未重建 | 切换语言后执行 `SceneDelegate.window.rootViewController = ...` 重建 |
| 埋点后台看到中文 event name | 业务代码用了 `Language.xxx` 做 event name | Phase 5.3 扫描修正为英文硬编码 |
| `Language.enText(for:)` 返回非英文 | 项目主 bundle 没 en.lproj 或 en.lproj 没该 key | 检查 Template/Resources/Localizations/en.lproj 存在且有该 key |
| Xcode 不识别新加的 .lproj | project.pbxproj 的 knownRegions 未包含新语言 | Xcode → Project → Info → Localizations → + Add，或改 project.yml |
| 清理脚本误删业务正在用的 key | 脚本只 grep `Language.static_var_name`，如果代码用 `Language.text(for: "xxx")` 动态传入会漏检 | 检查业务是否有动态 key 用法，脚本跑前先 dry-run 输出删除列表 |

---

## 与其他 skill 的关系

```
/ae-preflight ───────────────────→ 编译通过
       │
       ▼
/ae-i18n-integrate ──────────────→ CL10nKit + BCLocalization（本 skill）
       │
       ├──> /ae-notification-integrate → 通知文案本地化
       │
       ├──> /ae-feedback-integrate ──> feedback_xxx key 本地化
       │
       ├──> /ae-paywall-integrate ───> Paywall 文案本地化
       │
       ├──> /ae-onboarding-integrate → Onboarding 文案本地化（Welcome_XX Pod 的语言变体）
       │
       └──> /ae-asc-submit ──────────> ASC 元数据多语言（App Store 标题/描述/关键词）
```

## 已验证的约束

| ID | 约束 | 发现场景 |
|----|------|---------|
| i18n-001 | CL10nKit 1.10.2 已内置 310+ `ctext_xxx` 通用文案，新通用文案须 PR 到 Pod | Pods/CL10nKit/CL10nKit/Classes/Language.swift |
| i18n-002 | CL10nKit 的 `text(for:)` 走 `String.resolvedLocalization(for: CL10nKit.self, tableName: "Localizable")`，即从 Pod bundle 查 | 同上 |
| i18n-003 | 项目 Language.swift 的 `enText(for:)` 覆盖 Pod 版本，从主 bundle en.lproj 取（让项目 key 也能强制英文）| Template/Resources/Localizations/Language.swift |
| i18n-004 | BCLocalization 1.6.1 提供 `LocaleInfo` / `BCAppLanguage` / `Locale.fullMonthNames` / `Double.Ext` 数字格式化 | Pods/BCLocalization/BCLocalization/Classes |
| i18n-005 | `Localize_Swift` 是 CL10nKit / BCLocalization 的开源底层依赖 | Template/Resources/Localizations/Language.swift import |
| i18n-006 | Scale Global 标准支持 10 语言：en/de/es/fr/it/ja/nl/pt-BR/zh-Hans/zh-Hant（基于 BCAppSearch / DeleteAccountPage 等老 Pod）| Locals/BCAppSearch/BCAppSearch/Localizable/ 目录 |
| i18n-007 | 埋点 Language 误用当前在 bible-ios-template 为 0（grep 结果），但设计上允许通过 `enText(for:)` 强制英文 | 代码扫描 + CL10nKit.enText 定义 |
| i18n-008 | `Scripts/remove_unused_localized_keys.py` 路径写死 Plant 项目路径，需改 argparse 通用化才能复用 | Scripts/remove_unused_localized_keys.py:5-11 |
| i18n-009 | Welcome_01 / Welcome_02 Pod 目前只有 en.lproj（业务新增 Pod 语言覆盖不全）| Locals/Welcome_0*/Welcome_0*/Localizable |
| i18n-010 | InfoPlist.strings 的 NS*UsageDescription 必须每种语言独立翻译，系统弹窗不 fallback 英文 | Apple 文档 + Template/Resources/Localizations/en.lproj/InfoPlist.strings |

## 复用说明

所有 Scale Global 旗下 iOS 产品都应使用 CL10nKit + BCLocalization 生态做多语言。非 Scale Global 项目（无内部库）可用纯 Apple Localize_Swift 方案但无通用文案共享红利。出海产品必须跑 Phase 3-4 把所有 Locals Pod 语言覆盖补齐。
