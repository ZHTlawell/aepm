---
name: ae-speckit-brainstorm
description: "从 N 个现成 speckit 脑暴出一个新 speckit（merge 合并模式 / reference 参考模式）"
permissions:
  allow:
    - "Read({workdir}/**)"
    - "Write({workdir}/speckit/**)"
    - "Write({workdir}/speckit-brainstorm/**)"
    - "Edit({workdir}/speckit/**)"
    - "Edit({workdir}/speckit-brainstorm/**)"
    - "Bash(mkdir -p:*)"
    - "Bash(ls:*)"
    - "Bash(cp:*)"
dependencies:
  mcp: []
  cli: []
  api_keys: []
  scripts: []
smoke_test:
  command: "echo ok"
  expected_exit: 0
  description: "pure LLM skill, no external dependencies"
---

# Skill: Speckit Brainstorm (speckit-brainstorm)

## 触发条件

PM 手里已经有 N 个（N≥1）现成 speckit —— 可能来自 D 库下载、`/ae-app-to-speckit` 从已上架 App 逆向、或 `/ae-demo-to-speckit` 从 demo 源码提取 —— 现在想：

- **Mode A (merge)**：把这 N 个 speckit 做 remix 合并，产出一份融合版 speckit（并集 / 精选 / 去冲突）
- **Mode B (reference)**：以 N 个 speckit 作为参考 context，基于 PM 给的**新 idea**生成全新 speckit（类 RAG）

输出**一份新 speckit**，作为 M0 → M1（Idea → Speckit）流水线的中间品，经 PM 确认后进入后续 dev agent / vibe coding 环节。

## 定位

M0 → M1 工具箱的一环。本 skill 不产源码、不跑 demo、不碰真机，**纯 spec 层脑暴**。

- 上游：D 库 speckit / `ae-app-to-speckit` / `ae-demo-to-speckit` 的输出
- 下游：PM 手动微调 → `/ae-demo-to-figma` / vibe coding / dev agent

## 核心原则

1. **少生成多确认** — 每个模式的输出前后都有 PM review 检查点，skill 不擅自定稿
2. **可追溯** — 新 speckit 每个模块、每个关键字段都标注「来源于哪个源 speckit」或「来自 PM 新 idea」，便于 PM 事后核对
3. **模块粒度合并** — 6 模块（01 定位 / 02 场景 / 03 架构 / 04 设计 / 05 数据 / 06 API）采用**不同合并策略**，不能一刀切
4. **冲突显式化** — 发现冲突不擅自裁决，列出所有候选 + 推荐项给 PM 选择
5. **harness 薄，不写死 prompt** — 本 skill 是方法论 + 模板，具体 LLM 调用由 harness 层决定模型和参数

> **mode=reference 的对话收敛阶段：先调用 `superpowers:brainstorming`。** PM 的 idea + 源 speckit 收敛成"新 speckit 该长什么样"的过程，本质是 brainstorming 通用方法论（一次问一个问题、确认设计后再执行）。本 skill 只负责 speckit 6 模块文件结构 + 来源标注 + merge/reference 双模式策略。Mode A (merge) 不依赖 brainstorming（结构化 6 模块合并，无开放对话）。

## 输入

| 参数 | 必填 | 说明 |
|------|------|------|
| `--sources` | 是 | N 个源 speckit 的路径列表（逗号分隔或多次传入），每个应是一个含 `01-*.md` ~ `06-*.md` 的目录 |
| `--mode` | 是 | `merge` 或 `reference` |
| `--idea` | mode=reference 必填 | PM 的新 idea 描述（一段自然语言文本，或指向文本文件的路径） |
| `--out` | 否 | 输出目录，默认 `./speckit-brainstorm/` |
| `--name` | 否 | 新产品名称（用于模块 01），缺省则在 review 阶段询问 PM |

### 源 speckit 结构期望

每个源 speckit 目录应包含以下 6 个文件（缺失的允许，但要在 context manifest 中标注）：

```
<source>/
  01-project-positioning.md
  02-user-scenarios.md
  03-tech-architecture.md
  04-design-spec.md
  05-data-model.md
  06-api-spec.md
```

格式参考 `ae-demo-to-speckit` / `ae-app-to-speckit` 的 6 模块约定。

## 输出

写入 `--out` 指定目录（默认 `speckit-brainstorm/`）：

| 文件 | 内容 |
|------|------|
| `01-project-positioning.md` | 新产品定位 |
| `02-user-scenarios.md` | 用户场景与流程 |
| `03-tech-architecture.md` | 技术架构 |
| `04-design-spec.md` | 设计规范 |
| `05-data-model.md` | 数据模型 |
| `06-api-spec.md` | API 规范 |
| `00-brainstorm-manifest.md` | 脑暴溯源：本次使用的模式、源 speckit 清单、每个模块引用来源、已知取舍 |
| `conflicts.md` | （仅 merge 模式）冲突清单 + 候选项 + 推荐项 + PM 选择记录 |
| `review-checklist.md` | PM 确认清单（签字前必须走完） |

**引用标注约定**：模块内每个重要字段后用小尾注 `[from: S1]` / `[from: S2+S3 merged]` / `[from: idea]` / `[inferred]` 标注来源，便于 PM 核对。

## 6 模块合并策略（Mode A 用，Mode B 借用）

不同模块性质不同，不能一套逻辑走到底：

| 模块 | 合并策略 | 理由 |
|------|---------|------|
| **01 产品定位** | **单选 + 融合叙事** — 从 N 个里选一个作主基调，再融合差异点形成新产品定位。禁止并集（定位并集=定位模糊） | 一个产品只能有一个定位 |
| **02 用户场景** | **并集 + 去重** — 场景/流程可以叠加，但同名流程需合并步骤、去掉重复步骤 | 功能是可以累加的 |
| **03 技术架构** | **单选主栈 + 可选组件并集** — 技术选型必须单选（Swift vs React 不能并存），但周边组件（缓存/埋点/存储）可并集 | 主栈冲突=工程崩盘 |
| **04 设计规范** | **单选风格 + token 并集** — 设计风格（极简 vs 拟物）单选，具体 token（颜色/圆角/间距）按风格主源为准，其余作为备选池 | 视觉风格需一致 |
| **05 数据模型** | **schema 并集 + 字段去冲突** — 不同源的 entity 可共存，同名 entity 字段需合并且去冲突（类型冲突须 PM 裁决） | 数据模型天然可扩展 |
| **06 API 规范** | **endpoint 并集 + 去冲突** — 不同 API 可共存，同路径同方法不同语义需 PM 裁决 | 同 05 |

## 执行流程 — Mode A (merge)

### Step A1: 读入源 speckit

1. 按 `--sources` 逐一扫描目录，读取 6 个模块文件
2. 对每个源生成摘要：`{source_id, path, modules_present, modules_missing, char_count}`
3. 写入 `00-brainstorm-manifest.md` 的「源清单」段落
4. 缺失模块 ≥3 个的源 → 告警 PM，询问是否继续

### Step A2: 逐模块合并（按上表策略）

对 6 个模块依次执行：

1. **收集** — 从每个源提取本模块内容，并列呈现
2. **比对** — 识别重合部分 / 互补部分 / 冲突部分
3. **按策略合并** — 按上表策略生成本模块草稿
4. **标注来源** — 每个关键字段带 `[from: S*]` 尾注
5. **冲突登记** — 所有冲突点写入 `conflicts.md`，格式：

```markdown
## Conflict #N: <字段/主题>
- **模块**: 03 技术架构 / 状态管理
- **S1 (shoelens)**: Redux Toolkit
- **S2 (capvault)**: Zustand
- **推荐**: Zustand（轻量，更贴合本次 MVP 规模）
- **PM 选择**: [ ] S1  [ ] S2  [ ] 其他: ____
```

### Step A3: 冲突 Review（PM 检查点 #1）

**必须暂停**，向 PM 呈现：
- `conflicts.md` 全量
- 每个冲突的推荐项与理由

PM 在 `conflicts.md` 中勾选选择后，skill 读回并应用到对应模块。

### Step A4: 定稿输出

1. 按 PM 选择更新各模块草稿
2. 写入 `01-*.md` ~ `06-*.md`
3. 生成 `00-brainstorm-manifest.md` 完整版 + `review-checklist.md`

### Step A5: 最终 Review（PM 检查点 #2）

PM 走完 `review-checklist.md`（见 done criteria 清单），签字后整个流程完成。

## 执行流程 — Mode B (reference)

### Step B1: 读入 idea + 源 speckit

1. 读取 `--idea` 文本（或其文件），提取 PM 的新产品核心诉求
2. 读取 N 个源 speckit（同 A1），作为参考池
3. 向 PM 回显对 idea 的理解（一段话摘要）+ 源 speckit 定位对比，等 PM 确认后再继续

### Step B2: 逐模块生成（以 idea 为锚，源 speckit 为参考）

按 6 模块顺序，每个模块执行：

1. **锚定 idea** — 从 idea 文本提取本模块相关诉求
2. **筛选参考** — 从 N 个源 speckit 中挑出与本模块 idea 最相关的段落（不必全用）
3. **生成草稿** — 以 idea 为主，引用参考作为模式/结构借鉴
4. **标注来源** — 每段带 `[from: idea]` / `[from: S*]` / `[inferred]`
5. 模块间互引一致性（如 02 场景引用的实体必须在 05 数据模型中定义）由 Step B3 兜底

### Step B3: 内部一致性自检

生成 6 模块后，执行交叉引用检查：

- [ ] 02 场景中出现的每个实体（商品、订单、用户...）在 05 数据模型中有定义
- [ ] 02 场景中出现的每个远程调用在 06 API 规范中有 endpoint
- [ ] 03 架构中声明的技术选型与 04 设计、05 数据的实现方式一致
- [ ] 01 定位中承诺的核心功能在 02 场景中有对应流程

不一致项写入 `00-brainstorm-manifest.md` 的「一致性待修正」段落，由 Step B4 处理。

### Step B4: Review + 修正（PM 检查点）

**必须暂停**，向 PM 呈现：
- 6 模块草稿
- 一致性自检结果（通过/待修正）
- 每个模块的来源分布（idea 占比 / 参考占比 / inferred 占比）

PM 可直接编辑文件或在 `review-checklist.md` 勾选反馈。skill 根据反馈迭代，直到 PM 签字。

## PM 确认检查点（两模式共用）

| 检查点 | 模式 | 内容 |
|--------|------|------|
| CP-Conflicts | merge | `conflicts.md` 所有冲突已由 PM 选择 |
| CP-Final | merge & reference | `review-checklist.md` 全部项打勾 |

## Done Criteria

一份 brainstorm 输出只有以下条件全部满足才算完成：

- [ ] 6 模块文件全部生成（`01-*.md` ~ `06-*.md`），且每个模块非空
- [ ] `00-brainstorm-manifest.md` 完整记录：使用的模式、源 speckit 清单、每个模块的来源分布
- [ ] merge 模式：`conflicts.md` 所有冲突项都有 PM 选择
- [ ] reference 模式：内部一致性自检通过（或不通过项已在 manifest 中标注并获 PM 豁免）
- [ ] 内部引用一致：02 场景引用的实体在 05 有定义；场景中的远程调用在 06 有 endpoint
- [ ] `[inferred]` 标注字段不超过总字段的 30%（超过则告警 PM 补充信息）
- [ ] PM 在 `review-checklist.md` 最后一行完成签字（手动 `[x] Reviewed by <PM name> @ <date>`）

## 参考

- `skills/pm/ae-demo-to-speckit/SKILL.md` — 6 模块结构定义、置信度标注约定
- `skills/pm/ae-app-to-speckit/SKILL.md` — 截图引用规范、HTML img 宽度限制约定
- `gitee.com/turningsyn/ae-speckit-examples` — 已验证 speckit 样本（ShoeLens 等）

## 适用范围

所有准备从"已有参考"进入"新产品 spec"阶段的 PM 都会用到本 skill。M0 → M1 流水线的关键衔接件之一。
