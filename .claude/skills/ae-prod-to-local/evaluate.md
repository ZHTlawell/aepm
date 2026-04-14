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

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
