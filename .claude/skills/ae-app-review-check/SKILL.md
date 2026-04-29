---
description: "App Store 审核自检 — 知识库驱动，按 Apple Guideline 分章节扫描项目 + 关联真实拒审案例"
permissions:
  allow:
    - "Bash(grep *)"
    - "Bash(find *)"
    - "Bash(plutil *)"
    - "Bash(python3 scripts/app-review-scan.py *)"
    - "Bash(python3 scripts/app-review-kb-lint.py *)"
    - "Bash(python3 scripts/app-review-kb-feedback.py *)"
dependencies:
  mcp: []
  cli:
    - name: python3
      verify: "python3 --version"
    - name: pyyaml
      verify: "python3 -c 'import yaml'"
    - name: plutil
      verify: "which plutil"
  api_keys: []
  scripts:
    - scripts/app-review-scan.py
    - scripts/app-review-kb-lint.py
smoke_test:
  command: "python3 scripts/app-review-kb-lint.py"
  expected_exit: 0
  description: "kb entries lint clean"
---

# Skill: App Store 审核自检 (ae-app-review-check)

## 触发条件

- PM 完成 TestFlight 验证、准备提交 App Store 审核
- 被 Apple 拒审后修复完成，需要复检
- 不确定 App 是否符合某个 Guideline

## 核心原则

**知识库驱动，不靠猜测。** 所有检查规则来自结构化 kb（按 Apple Guideline 章节组织），每条规则关联 Apple 官方条文 + 真实拒审案例 URL。kb 条目位于 `skills/pm/ae-app-review-check/kb/`，案例位于 `cases/cases.jsonl`。

## 输入

| 输入 | 必填 | 说明 |
|------|------|------|
| iOS 项目路径 | 是 | 包含 .xcodeproj 或 project.yml 的根目录 |
| ASC 元数据（Privacy Policy URL / Review Notes 等） | 否 | 如有，用于生成 Review Notes 草稿 |
| 上次拒审邮件内容 | 否 | 触发反馈入库流程 |

## 执行流程

### Phase 1: Lint & 环境检查

```bash
python3 scripts/app-review-kb-lint.py
```

确认 kb YAML 条目格式正确、case_refs 引用完整。lint 不通过不能继续。

### Phase 2: 扫描

```bash
python3 scripts/app-review-scan.py --project-dir <iOS 项目路径> --output both --report-file review-check-report
```

脚本会：
1. 从 `kb/` 递归加载所有 YAML 条目
2. 按 chapter 顺序执行每条 `auto_checks` 下的规则
3. 根据 `expected` + `match_pattern` 评估 pass/fail/warn/skip
4. 输出 markdown 报告 + JSON 机读结果

### Phase 2.5: Rubric 评分 + 档位判定（v0.66.0+）

scan.py 在输出 PASS/WARN/FAIL 报告之前，先计算 6 维 Rubric 评分和 T0/T1/T2 档位结论。这是给"打样 App 是否可上架/投广"的最直接判断。

**6 个维度**：

| 维度 | 含义 | 主要 kb 条目 |
|------|------|------------|
| D1 | 法务合规（Privacy Policy / Terms / Subscription Terms） | `5.1.1-data-collection` · `3.1.2-subscriptions` (D1 部分) |
| D2 | Privacy Manifest（PrivacyInfo.xcprivacy / Required Reason API / 第三方 SDK manifest） | `2.3.1-accurate-metadata` |
| D3 | 模板纯净度（无 fork 自其他 App 的字符串残留） | `2.3.1-template-residue` |
| D4 | 权限文案语义匹配（usage description 与业务对应） | `5.1.1-purpose-string-semantic` |
| D5 | Free 路径完整度（无 vaporware / Free 用户核心功能可走通或前置告知） | `4.2-minimum-functionality` · `4.2-vaporware` |
| D6 | Paywall 漏斗合规（Restore + Terms + Privacy + 自动续费披露 + 不强弹冷启动） | `3.1.2-subscriptions` · `3.2.1-paywall-frequency` |

**评分规则**（每维 0-3 分）：
- 维度内每个 kb 条目根据其 status 贡献分数（PASS = 3 / WARN = 2 / FAIL = 0，可在 yaml 内 override）
- 多个条目按 weight 加权求和，归一化到 0-3
- 该维度所有条目都未触发 → 记 N/A，不计入档位判定

**档位判定**：
- **T0 — 理论可过审**：D1 ≥ 2 AND D2 ≥ 2 AND 总分 ≥ 12 AND 无任一维度=0
- **T1 — 可投广基线**：T0 AND 总分 ≥ 16 AND 至少 4 维有分 AND 无任一维度=0
- **T2 — 数据闭环可读**：T1 AND 数据闭环（v1 留空，依赖 ae-analytics-integrate 漏斗事件就绪）

报告头部会输出：
```
📊 RUBRIC 评分（RQ 打样模式 v0）
档位：T1 ✅ 可投广基线
总分：16/18    有分维度：5/6

| 维度 | 名称 | 得分 | 命中条目 |
| D1 | 法务合规 | 3/3 | ✅ 5.1.1 |
| D2 | Privacy Manifest | 3/3 | ✅ 2.3.1 |
| D3 | 模板纯净度 | 3/3 | ✅ 2.3.1 |
| D4 | 权限文案语义 | 2/3 | ⚠️ 5.1.1 |
| D5 | Free 路径完整度 | N/A | N/A — 该维度无 kb 条目触发 |
| D6 | Paywall 漏斗合规 | 3/3 | ✅ 3.1.2 · ✅ 3.2.1 |
```

> 方法论起源：[ae-platform IJCBRW](https://e.gitee.com/turningsyn/issues/list?issue=IJCBRW) — RQ 打样 App 5 样本逆向调研。

### Phase 3: 报告解读

报告分三档：
- **FAIL**（severity=high 且 check 未通过）：大概率被拒，必须修
- **WARN**（severity=medium/low 且 check 未通过）：降低拒审风险，建议修
- **PASS**：当前检查通过

每个 FAIL/WARN 项会：
- 打印 Apple 精确错误码（如 ITMS-91053/91056/91061）
- 附 `case_refs` 指向 `cases/cases.jsonl` 中的真实拒审案例 URL
- 给出 `fix_suggestions` 修复路径

### Phase 4: 已知扫描盲区 — 人工复核

以下项目静态扫描覆盖不到，**PM 必须手动复核**：

| 项目 | 如何验证 |
|------|---------|
| Superwall / RevenueCat / Adapty Paywall 远程配置 | 登录对应 dashboard，确认 Paywall 模板含 Terms of Service + Privacy Policy + 自动续费披露 |
| ASC 后台截图 + 描述 | 登录 ASC，确认截图是真实运行截图（2.3.3），描述无占位符（2.3.1） |
| App Icon 版权与原创性 | 人工确认图标非盗用、无蹭品牌 |
| 内容合规（宗教/政治敏感性） | PM 自行判断 |
| Review Notes demo account | 确认 demo 账号已注册 + 预置数据且可登录 |

### Phase 5: Review Notes 草稿生成

从命中的 kb 条目 `review_notes_template` 字段拼装 Review Notes。例如：
- 若 3.1.1 全部 pass → 自动拼一段 "All digital content purchases use StoreKit 2..."
- 若 ai-attribution-sdk-detected 命中 → 拼一段 "The app uses Adjust SDK for internal attribution only..."

### Phase 6: 状态持久化

将结果追加到项目的 `publish-state.yaml`：

```yaml
app_review_check:
  status: pass | blocked
  checked_at: <ISO 日期>
  kb_version: <kb commit hash>
  fails: [{guideline, check_id, evidence, case_refs}]
  warns: [...]
  review_notes_draft: |
    ...
  manual_review_required:
    - "Verify Superwall paywall template includes Terms/Privacy links"
```

### Phase 7: 拒审反馈入库（可选）

若 PM 提供了 Apple 拒审邮件：

```bash
python3 scripts/app-review-kb-feedback.py --rejection-email <path>
```

（P3 实现）脚本会解析邮件文本 → 识别 Guideline → 生成新 case 条目 append 到 `cases.jsonl`，并可选更新 kb auto_checks。

## kb 扩展指南

### 新增 Guideline 条目

1. 在 `kb/_sources/apple-official/` 下补充官方条文 fixture（标注 fetch 日期 + URL）
2. 在 `kb/<chapter>/<guideline>-<slug>.yaml` 写条目，引用 fixture 中的原文
3. 跑 `python3 scripts/app-review-kb-lint.py` 确认格式正确

### 新增拒审案例

1. 案例原文存 `kb/_sources/cases-raw/`
2. 脱敏后追加到 `cases/cases.jsonl`（一行一个 JSON）
3. kb 相关条目的 `case_refs` 字段加上新 case id

## 已验证的约束（从 P1 扫描 bible-app 得出）

| ID | 约束 | 发现场景 |
|----|------|---------|
| review-001 | PrivacyInfo.xcprivacy 必须覆盖所有实际使用的 Required Reason API（至少 UserDefaults） | 2.3.1 ITMS-91053 |
| review-002 | NSPrivacyTracking 声明必须与 tracking SDK 使用情况一致 | 2.3.1 声明矛盾 |
| review-003 | 第三方 SDK 必须使用带 privacy manifest 的版本（Apple 清单 87 项） | 2.3.1 ITMS-91061 |
| review-004 | API Key 必须外部化，不能硬编码到源码/plist | 2.3.1 安全风险 |
| review-005 | 有订阅必须展示 Terms/Privacy/自动续费（Paywall 内而不是 Settings） | 3.1.2 |
| review-006 | 有归因 SDK 必须在 Review Notes 主动说明用途 | AI 审核误判 |
| review-007 | 有登录必须在 ASC Review Notes 提供 demo account | AI 审核要求 |
| review-008 | 有账户注册必须提供账户删除入口 | 5.1.1(v) |
| review-009 | 敏感 API（Camera/Location/Photos/Microphone）必须配置 Info.plist usage description | ITMS-90683 |
| review-010 | 模板/竞品 App 字符串残留检测（FaceFlow/CoKnit/knitting/makeup/facial features 等关键词） | RQ 打样 IJCBRW · D3 |
| review-011 | 权限文案语义与业务匹配（拼豆 App 不能写 'analyze facial features'） | RQ 打样 IJCBRW · D4 |
| review-012 | Free 用户核心功能必须可走通或前置告知（不能让用户走完流程才看到 Failed） | RQ 打样 IJCBRW · D5 |
| review-013 | Vaporware 检测：onboarding 承诺的功能必须在 App 内有入口 | RQ 打样 IJCBRW · D5 |
| review-014 | Cold-launch paywall 不强弹（除首次），避免 3.2.1 frequent prompts | RQ 打样 IJCBRW · D6 |

## 与其他 skill 的关系

```
/ae-preflight → 代码就绪
    ↓
/ae-app-to-testflight → TestFlight 验证
    ↓
/ae-app-review-check → 审核自检 ← 本 skill
    ↓
/ae-asc-submit → 提审
```

## 已知限制

- **无法覆盖所有 Apple Guideline 条款** — 当前 kb 覆盖 2.1/2.3.1/3.1.1/3.1.2/4.1/4.2/4.3/5.1.1 + 3 条 AI 审核规则。其他条款（1.x Safety / 5.1.3 Health 等）按需扩展
- **AI 审核规则持续变化** — 本 kb 基于 2026-04 调研，需定期更新 fixture
- **远程配置盲区** — Superwall/RevenueCat Paywall、ASC 截图与描述无法静态扫，依赖 PM 人工复核（Phase 4）
- **内容合规判断** — 宗教/政治/地域敏感性仍需 PM 结合当地法律自行判断
- **Apple Dev Forum 案例采集** — 目前只抓公开源（Reddit 被我的搜索工具屏蔽，CSDN/V2EX 可抓）。Apple Dev Forum 部分帖子需登录，由 PM 按需手动粘贴
