# ae-i18n-integrate 用户场景验收清单

## 场景 1: 英文 only 产品扩展到 10 语言（典型路径）

- **前置**：项目主 `.lproj` 只有 en，部分 Locals Pod 有 9 语言（历史老 Pod），部分 Locals Pod 只有 en（业务新增 Pod）
- **用户说**："我们要出海，加全套语言"
- **预期行为**：
  1. Phase 1 现状扫描：列出项目主 / 每个 Locals Pod 的语言覆盖
  2. Phase 2 文案 key 分层：grep 硬编码字符串 + 业务 key 抽出来注册到项目 Language.swift
  3. Phase 3 批量扩展：9 种新语言目录 + 复制 en 占位到项目主 + 所有 Locals Pod
  4. Phase 4 InfoPlist.strings 每语言补齐
  5. Phase 5 扫描埋点误用 + 修正英文硬编码
  6. Phase 6 unused key 清理
  7. Phase 7 编译 + 语言切换验证
- **验收标准**：
  - [ ] 所有语言的 Localizable.strings key 数一致（diff 为空）
  - [ ] 所有语言的 InfoPlist.strings key 数一致
  - [ ] 所有 Locals Pod 覆盖同样的 10 种语言
  - [ ] 业务代码 grep 不到硬编码字符串（Text("xxx") / Label("xxx") 英文字面量）
  - [ ] `BCTrack.track(Language.xxx)` 误用数 = 0
- **状态**：⏳ 未测试

## 场景 2: 通用文案误定义在项目（反模式识别）

- **前置**：业务代码写 `Text(Language.my_product_cancel)`，项目 Language.swift 有 `static var my_product_cancel: String { self.text(for: "my_product_cancel") }`
- **用户说**：审计 / 新产品接手
- **预期行为**：Agent 识别 `cancel` 是通用 UI 文案，检查 CL10nKit：
  > ❌ `my_product_cancel` 是通用 UI 文案（Cancel 按钮），应该用 CL10nKit 已有的 `Language.ctext_cancel`。
  > ✅ 修复：
  > 1. 业务代码改 `Text(Language.ctext_cancel)`
  > 2. 项目 Language.swift 删除 `my_product_cancel` static var
  > 3. 项目 Localizable.strings 删除 `"my_product_cancel" = "Cancel";`（其他语言也删）
- **验收标准**：
  - [ ] Agent 能识别哪些 key 属于 CL10nKit 已有通用文案
  - [ ] 给出完整清理清单（static var + strings entries）
- **状态**：⏳ 未测试

## 场景 3: 埋点事件名本地化（反模式识别）

- **前置**：业务代码：
  ```swift
  BCTrack.track(Language.wepray_chat_sent, type: .click)
  ```
- **用户说**：审计 / BI 说事件聚合不上
- **预期行为**：Agent 识别反模式第 4 条：
  > ❌ 埋点事件名 `Language.wepray_chat_sent` 会跟随用户语言切换（中文用户是"聊天发送"）。BI 后台无法跨地区聚合。
  > ✅ 修复：`BCTrack.track("chat_sent", type: .click)` 硬编码英文。
  > 例外：如果必须上报本地化内容（如用户反馈 category），用 `Language.enText(for: key)` 强制英文。
- **验收标准**：
  - [ ] Agent 定位到具体位置
  - [ ] 区分"展示给用户的文案"vs"BI 聚合的 event name"
  - [ ] 给 `Language.enText(for:)` 例外用法示例
- **状态**：⏳ 未测试

## 场景 4: Pod 语言覆盖不一致（故障排查）

- **前置**：用户切中文后首页正常，进入 Welcome 引导是英文
- **用户说**："为什么 onboarding 是英文，其他页面都是中文？"
- **预期行为**：Agent 用 Phase 1.3 脚本扫描：
  ```bash
  for pod_dir in Locals/*/; do
      lproj_count=$(find "$pod_dir" -type d -name "*.lproj" | wc -l)
      echo "$(basename $pod_dir): $lproj_count langs"
  done
  ```
  识别 Welcome_01 只有 en.lproj，没有 zh-Hans.lproj。修复：
  - 执行 Phase 3.2 同步扩展（mkdir zh-Hans.lproj + 复制 en 为占位）
  - 通知 PM 组织 Welcome_01 的中文翻译
- **验收标准**：
  - [ ] Agent 能用脚本快速定位哪些 Pod 不全
  - [ ] 给出批量补齐方案（bash 循环）
  - [ ] 不试图改 Pod 源码，只处理 Pod bundle 的 Localizable
- **状态**：⏳ 未测试

## 场景 5: InfoPlist.strings 缺失（审核风险）

- **前置**：产品加了相机功能，Info.plist 有 NSCameraUsageDescription，只翻译了英文
- **用户说**："App Store 审核被拒，理由是多语言支持不完整"
- **预期行为**：Agent 扫描 InfoPlist.strings 一致性：
  ```bash
  for lang_lproj in Template/Resources/Localizations/*.lproj; do
      echo "=== $lang_lproj ==="
      grep "NSCameraUsageDescription" "$lang_lproj/InfoPlist.strings" || echo "MISSING"
  done
  ```
  定位缺失语言，批量补 InfoPlist.strings。
  
  额外建议：ATT 弹窗文案要打磨（直接影响拒授率），让 PM 专门翻译而非机器翻译。
- **验收标准**：
  - [ ] Agent 能定位具体哪几个语言的 InfoPlist.strings 缺 key
  - [ ] 修复每种语言（先英文占位，通知 PM 翻译）
  - [ ] 提醒 ATT 文案特殊重要性
- **状态**：⏳ 未测试

## 场景 6: remove_unused_localized_keys.py 通用化

- **前置**：当前 `Scripts/remove_unused_localized_keys.py` 三个路径写死 plant-app
- **用户说**："运行清理脚本"
- **预期行为**：Agent 识别路径写死问题：
  > ❌ 当前脚本三个路径（Language.swift / Localizable.strings / search root）写死 `/Users/leelty/Documents/BC/Products/plant/`。不能直接在当前项目跑。
  > ✅ 先通用化：改为 argparse 接受 3 个路径参数，提交 PR 改进脚本。
  > 临时替代：改脚本里三行路径为当前项目的相对路径，跑完撤销。
- **验收标准**：
  - [ ] Agent 不直接跑写死 plant 路径的脚本
  - [ ] 提出通用化方案（argparse 或 env vars）
  - [ ] 临时方案给出 diff
  - [ ] dry-run 先输出删除清单，不直接改文件
- **状态**：⏳ 未测试

## 场景 7: 语言切换后 UI 不更新

- **前置**：iOS 设置里切中文，App 仍显示英文；只有完全杀掉 App 重启才生效
- **用户说**："运行时切语言不生效"
- **预期行为**：Agent 识别 `Localize_Swift` 的动态切换机制：
  > `Localize_Swift` 提供 `Localize.setCurrentLanguage(lang)` 动态切换，但需要：
  > 1. 调用后发 `LCLLanguageChangeNotification` 通知
  > 2. rootVC 响应通知重建视图 Tree（SwiftUI 需要父 View 触发 re-render）
  > 3. Scene / AppDelegate 重新 set window.rootViewController
  > 
  > 多数 Scale Global 产品**设计上不做运行时切换**，iOS 设置改语言需杀进程重启 —— 系统用 Preferred Languages 列表，App 启动时一次性读取。
  > 如果确实需要 App 内切语言，参考 Localize_Swift 文档 + 重建 rootVC。
- **验收标准**：
  - [ ] 区分"iOS 系统切语言"vs"App 内切语言"两种场景
  - [ ] 说明 Scale Global 生态默认不支持 App 内切
  - [ ] 给出真需要时的集成路径（不本 skill 范围直接实现）
- **状态**：⏳ 未测试

## 场景 8: 新加 key 忘给其他语言补（一致性破坏）

- **前置**：PM 加了新功能 feedback_chat_too_preachy，只在 en.lproj 补了，zh-Hans / de / es 等其他语言都没补
- **用户说**：出海用户反馈"feedback 列表里有个英文选项在中文环境里"
- **预期行为**：Agent 跑 Phase 7.3 key 一致性检查：
  ```bash
  python3 -c "..."  # SKILL.md Phase 7.3 的脚本
  ```
  输出每种语言 missing keys 清单 + 补齐：
  ```bash
  # 用 en 版本为占位自动补到所有缺失语言
  for lang in de es fr it ja nl pt-BR zh-Hans zh-Hant; do
      echo "\"feedback_chat_too_preachy\" = \"Too preachy tone\";" >> \
        Template/Resources/Localizations/$lang.lproj/Localizable.strings
  done
  ```
- **验收标准**：
  - [ ] Agent 主动扫 key 一致性（不是等用户报问题才查）
  - [ ] 每加新 key 都提醒扫一致性
  - [ ] 补占位 + 通知 PM 组织翻译
- **状态**：⏳ 未测试

---

## 验收通过标准

- 场景 1-8 全部 ✅ 通过
- 所有 ❌ / ⏳ 必须有明确阻塞原因和修复 PR
- 龙哥审计通过：
  - 4 层架构（Localize_Swift / BCLocalization / CL10nKit / 项目 Language）分层正确
  - 埋点英文一致性规则合理
  - Pod 专属文案归属（Welcome_XX 的 key 放 Pod 自己的 Language）
  - remove_unused_localized_keys.py 通用化是否采纳

## 已知阻塞项（等龙哥审计）

- [ ] `.xcstrings` 是否应引入（Xcode 15+ 新格式，但生态全是老 .strings，迁移风险）
- [ ] 运行时 App 内切语言是否应作为标准能力（当前生态不支持，Localize_Swift 可做但成本高）
- [ ] `remove_unused_localized_keys.py` 通用化（加 argparse）是否应提 PR 到 ae-platform scripts/
- [ ] 新通用文案加到 CL10nKit Pod 的 PR 流程（杭州团队 vs AE Team 谁 review）
- [ ] Welcome_XX Pod 的 AB 变体是否应同步语言覆盖（当前 Welcome_01 / Welcome_02 只有 en，ae-onboarding-integrate 可能需要规范）
