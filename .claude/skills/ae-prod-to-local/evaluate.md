# ae-prod-to-local 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-prod-to-local

## Test Stories

### Story 1: 单仓库 iOS 项目本地原型化
- **Prompt**: "杭州团队给了 ShoeLens 的 iOS 代码，在 ~/Projects/shoelens-ios，帮我搞清楚怎么在本地跑起来"
- **Expect**: Skill 按 Phase 1-4 执行：(1) 扫描项目结构识别为 iOS Native（CocoaPods/SPM），提取 Podfile/Package.swift 中的全部依赖并进行三档分类（A 不可替代 / B 可替代 / C 通用）；(2) 制定本地运行方案（pod install、环境指向 localhost、支付/登录 mock 方案）；(3) 生成 `local-prototype/` 目录包含 dependency-map.md、local-run-guide.md、team-request.md、constraints-draft.md；(4) 尝试实际执行并更新产出。
- **Max Time**: 300s

### Story 2: 前后端多仓库项目分析
- **Prompt**: "这个产品有 3 个 repo：~/Projects/cap-ios（iOS 客户端）、~/Projects/cap-service（Java 后端）、~/Projects/cap-config（配置仓库），帮我做 prod-to-local 分析"
- **Expect**: Skill 分别识别三个子项目类型（iOS Native、Spring Boot、配置仓库），对每个仓库独立提取依赖并分类。后端部分生成 `application-local.properties` 补丁指向本地 MySQL，iOS 部分生成 base URL 指向 localhost 的配置补丁。配置仓库标记为"本地不需要运行"并说明哪些功能因此不可用。dependency-map.md 按仓库分节展示。
- **Max Time**: 300s

### Story 3: 私有 Pod 仓库不可达
- **Prompt**: "pod install 失败了，说找不到 gitlab.bytescell.net 的 repo，我没有权限"
- **Expect**: Skill 将私有 pod 仓库权限列为 P0 阻塞项写入 team-request.md，同时评估每个不可达的私有 pod：B 类的给出替代方案（如 BCNetwork → 直接用 Alamofire），A 类的标记为必须获取权限或提供二进制 framework。给出两条路径：(1) 找 admin 开 SSH 权限（预计沟通时间）；(2) 用 B 类替代方案手动替换后重试 pod install。
- **Max Time**: 120s

### Story 4: 依赖分类准确性验证
- **Prompt**: "帮我分析 ~/Projects/demo-app 的依赖，我需要确认分类是否准确——BCAccount 是用户认证库，BCNetwork 是 Alamofire 的薄封装，Kingfisher 是公开的图片缓存库"
- **Expect**: Skill 对每个依赖执行分类判断流程：(1) BCAccount — 来自私有仓库、绑定公司用户体系 → A 类，无替代方案；(2) BCNetwork — 来自私有仓库、底层是 Alamofire、薄封装 → B 类，替代方案为直接用 Alamofire + 自定义 interceptor；(3) Kingfisher — 来自 CocoaPods trunk → C 类。每个分类都附带判断理由，B 类附带迁移成本评估。
- **Max Time**: 120s

### Story 5: 产出与 ae-demo-to-speckit 的衔接
- **Prompt**: "本地环境跑通了，下一步我想基于这个产品生成 speckit"
- **Expect**: Skill 在完成后引导中提示三个选项：(1) `/ae-demo-to-speckit` 并说明 dependency-map.md 和 constraints-draft.md 是 speckit 的输入；(2) 手动过代码深入理解；(3) 发送 team-request.md 解决剩余阻塞项。constraints-draft.md 中 A 类约束应以 speckit 可消费的格式编写（分 iOS/后端，标注约束 key 如 `ios-auth`、`be-deploy`）。
- **Max Time**: 60s

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 0/5 (0%)
- **平均耗时**: 47.0s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| 单仓库 iOS 项目本地原型化 | 1/5 | 59.9s | 目录不存在时无降级策略 | 识别了问题并给出计划概要，但未生成任何 local-prototype/ 产出文件 |
| 前后端多仓库项目分析 | 1/5 | 85.8s | 沙箱路径限制，无自动回退 | 提供了 3 种替代方案和所需文件清单，但零实际产出 |
| 私有 Pod 仓库不可达 | 0/5 | 65.7s | 死循环，触发 max turns (10) | 完全失败——应能基于用户描述直接生成 team-request.md 和替代路径，无需真实文件系统 |
| 依赖分类准确性验证 | 0/5 | 19.1s | API 速率限制 | 用户已在 prompt 中给出三个依赖的明确描述，skill 应能纯推理完成分类，但因 rate limit 无输出 |
| 产出与 speckit 衔接 | 0/5 | 4.4s | API 速率限制 | 纯引导型任务，不依赖文件系统，因 rate limit 无输出 |

## 瓶颈分析
- **P0: 缺乏"无源码降级"模式**。Story 1/2 中目录不存在时 skill 完全停摆。应设计降级路径：当源码不可达时，基于用户描述和已知信息（如 prompt 中提到的库名、框架类型）先生成模板化的 dependency-map.md 和 team-request.md 骨架，标注待验证项，而非阻塞等待。
- **P0: Story 3 死循环**。pod install 失败场景是纯咨询型任务（用户已告知错误信息和仓库地址），skill 应能直接基于文本推理产出 team-request.md 和 B 类替代方案，但却进入了 10 轮无效循环。需排查循环逻辑——可能是反复尝试执行 pod install 或访问不存在的路径。
- **P1: 未充分利用 prompt 内信息**。Story 4 中用户已在 prompt 里给出了 BCAccount（认证）、BCNetwork（Alamofire 封装）、Kingfisher（公开库）的完整描述，这是一个纯 LLM 推理任务，不应依赖文件系统。虽然此次因 rate limit 失败，但 skill 设计应确保此类场景走快速推理路径。

## 结论
Skill 当前处于不可用状态（0% 通过率）。最高优先级：增加无源码降级模式使 Story 1/2/3 在目录不可达时仍能产出骨架文档；其次修复 Story 3 的死循环问题；rate limit 导致的 Story 4/5 失败属外部因素，但应确保这类纯推理任务走轻量路径以降低 token 消耗。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 0/5 (0%) | 47.0s |
