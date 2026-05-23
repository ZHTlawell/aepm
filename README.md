# AE QA Agent

> 让测试人员快速熟悉陌生产品项目，并高效完成测试分析、用例设计、执行验证、缺陷回流和发布风险判断。

## 这是什么

AE QA Agent 是一套面向测试人员的 **AI 测试工作流能力包**。安装或链接后，Codex / Claude Code / Cursor 等 AI 编程助手可以按标准流程帮助 QA 进入项目、理解产品、识别风险、生成测试资产，并把验证结果沉淀为可复用的质量知识。

它解决的核心问题是：测试人员接手一个新项目时，资料分散在源码、产品图、PRD、测试用例、历史 bug、测试报告、接口文档、数据库说明和自动化脚本中。靠人工串起来成本高，靠 AI 随意阅读又容易漏重点。AE QA Agent 把这个过程标准化为可检查、可追溯、可复用的测试入驻流程。

本项目面向开源使用。默认流程不绑定某个公司、缺陷平台或测试管理系统；GitHub、GitLab、Jira、Gitee、ZenTao、TestRail 等平台应通过 `.qa-agent.yml`、overrides 或 provider 适配器接入。

QA Agent 是 **产品专属** 的：一个产品对应一个仓库或目录，一个 Agent 只维护一个产品的 QA Memory。如果用户提供第二个产品的需求或文档，Agent 会提示创建新的产品目录并初始化新的产品 Agent，避免跨产品记忆污染。

## 核心流水线

```text
Q0 项目输入
  源码 / PRD / Speckit / 产品图 / 测试用例 / Bug 单 / 测试报告 / API / DB / 自动化
  |
  | [Q0 -> Q0.5] /ae-qa-product-init
  v
Q0.5 产品专属初始化
  产品身份、熟悉度评分、QA Memory、是否达到 85 分门槛
  |
  | [Q0.5 -> Q1] /ae-qa-start 或 /ae-qa-intake-check + /ae-qa-onboard-project
  v
Q1 产品理解包
  产品定位、核心用户、主流程、模块地图、页面地图、业务规则、待确认问题
  |
  | [Q1 -> Q2] /ae-qa-consistency-check + /ae-qa-risk-scan
  v
Q2 测试地图
  覆盖缺口、资料冲突、风险分级、冒烟路径、回归热点、优先级
  |
  | [Q2 -> Q3] /ae-qa-generate-cases
  v
Q3 测试资产
  P0 冒烟用例、P1 核心回归、P2 模块回归、边界用例、自动化候选点
  |
  | [Q3 -> Q4] /ae-qa-change-impact + 执行验证 + /ae-qa-file-bugs + /ae-qa-release-check
  v
Q4 验证结论
  测试报告、缺陷列表、阻塞项、回归范围、发布风险、Go / No-Go 建议
```

## v0.1 能力

| 能力 | 命令 | 产物 |
|------|------|------|
| 产品专属初始化 | `/ae-qa-product-init` | 产品身份、熟悉度评分、QA Memory、是否进入产品专属模式 |
| 新项目入驻总入口 | `/ae-qa-start` | 入驻汇总、资料缺口、关键风险、第一周测试建议 |
| 入驻资料检查 | `/ae-qa-intake-check` | 资料完整度评分、缺失项、影响说明、下一步建议 |
| 项目入驻理解 | `/ae-qa-onboard-project` | 产品理解包、模块地图、用户路径、开放问题 |
| 资料一致性检查 | `/ae-qa-consistency-check` | PRD / 用例 / API / DB / bug / 自动化之间的冲突清单 |
| 风险扫描 | `/ae-qa-risk-scan` | 风险地图、优先级、历史回归热点 |
| 测试用例生成 | `/ae-qa-generate-cases` | 分级测试用例、冒烟清单、回归清单、自动化候选 |
| 变更影响分析 | `/ae-qa-change-impact` | 影响模块、建议回归范围、历史 bug 关联、风险提示 |
| 缺陷回流 | `/ae-qa-file-bugs` | 结构化缺陷内容、查重、确认后提交 |
| 发布准入检查 | `/ae-qa-release-check` | Go / Conditional Go / No-Go 结论 |
| 新模块测试规划 | `/ae-qa-new-module-test` | 可选择的测试任务清单，用户选择后继续执行 |

## 推荐执行顺序

第一次阅读本项目后，下一步应该先创建或进入某个产品目录，然后初始化产品专属 QA Agent：

```bash
ae qa product-init <product_dir>
```

熟悉度达到 85/100 后，Agent 才能进入该产品的专属测试模式。

`product-init` 会自动创建配置和资料包目录：

```text
<product_dir>/
  .qa-agent.yml
  qa-onboarding-input/
    00-project-structure.md
    01-product-overview.md
    02-product-screens/
    03-product-docs/
    04-api-docs/
    05-database-docs/
    06-test-cases/
    07-bug-history/
    08-test-reports/
    09-automation/
  qa/
  .qa-memory/
```

之后用户可以通过三种方式补资料：

1. 上传文件到对话。
2. 粘贴文档内容。
3. 把文件放入 `qa-onboarding-input/` 对应目录。

Agent 应负责归档和判断资料类型。资料不足时，它应该要求补资料，而不是直接追问细碎产品细节。

新测试人员接手项目时：

```bash
ae qa start <project_or_package_dir>
```

或分步执行：

```bash
ae qa intake-check <project_or_package_dir>
ae qa onboard <project_or_package_dir>
ae qa consistency-check <project_or_package_dir>
ae qa risk-scan <project_or_package_dir>
ae qa generate-cases <project_or_package_dir>
```

版本迭代或需求变更时：

```bash
ae qa change-impact <diff_or_requirement>
ae qa risk-scan <project_or_package_dir>
ae qa generate-cases <project_or_package_dir>
ae qa release-check <project_or_package_dir>
```

也可以在 AI 工具中直接触发：

```text
/ae-qa-product-init
/ae-qa-start
/ae-qa-intake-check
/ae-qa-onboard-project
/ae-qa-consistency-check
/ae-qa-risk-scan
/ae-qa-generate-cases
/ae-qa-change-impact
/ae-qa-file-bugs
/ae-qa-release-check
/ae-qa-new-module-test
```

## 测试入驻包

推荐把项目资料整理成一个入驻包，资料越完整，Agent 的判断越可靠。

```text
qa-onboarding-input/
  00-project-structure.md
  01-product-overview.md
  02-product-screens/
  03-product-docs/
  04-api-docs/
  05-database-docs/
  06-test-cases/
  07-bug-history/
  08-test-reports/
  09-automation/
```

Agent 输出建议统一放到：

```text
qa/
  01-product-brief.md
  02-module-map.md
  03-user-journeys.md
  04-business-rules.md
  05-api-data-map.md
  06-risk-map.md
  07-existing-test-coverage.md
  08-regression-hotspots.md
  09-test-cases.md
  10-open-questions.md
```

## 设计原则

1. **先校验资料，再做判断**：资料不全时必须标注缺口和影响，禁止自信补全。
2. **结论必须可追溯**：关键判断要写明来源，例如 PRD、接口文档、历史 bug、源码路径或测试报告。
3. **先理解，再覆盖，再执行**：不要跳过产品理解直接生成用例。
4. **风险驱动优先级**：历史 bug、高复杂度链路、权限、支付、数据删除、状态流转、外部依赖优先。
5. **沉淀项目 QA Memory**：入驻结果应能被后续回归、变更影响分析和缺陷提交复用。

## 仓库结构

```text
AGENTS.md                 QA Agent 行为准则
README.md                 项目说明
manifest.yml              QA 能力清单
cli/ae                    AE CLI 入口
cli/lib/qa/commands.sh    QA 子命令
constraints/              QA 方法、用例、缺陷、质量门禁约束
.agents/skills/ae-qa-*    QA skills
scripts/                  可选平台适配、截图、OCR、报告等辅助脚本
```

## 配置

复制 [.qa-agent.example.yml](C:/Users/30203/Desktop/aepm/.qa-agent.example.yml:1) 为 `.qa-agent.yml` 后按项目调整：

```yaml
issue_provider:
  type: manual
  repository: ""
  project_key: ""
```

`manual` 表示只生成结构化缺陷正文，不自动提交。团队可以扩展为 `github`、`gitlab`、`jira`、`gitee`、`zentao` 或 `testrail`。

## 开源贡献

贡献指南见 [CONTRIBUTING.md](C:/Users/30203/Desktop/aepm/CONTRIBUTING.md:1)。新增能力时请保持通用、可配置、可追溯，不要把私有平台规则硬编码进 skill。
