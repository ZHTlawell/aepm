---
description: "将工业产品级代码快速转为本地可运行原型，分离公司独有 vs 通用依赖"
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

# Skill: 生产代码本地原型化 (prod-to-local)

## 触发条件

当 PM 拿到其他团队（如杭州团队）开发的已上线产品代码，需要：
1. 在本地开发机上跑通核心链路
2. 搞清楚哪些是公司独有依赖、哪些可以用公开方案替代
3. 为后续 ae-pm vibe coding 建立参照基线

## 核心原则

**不是要跑通 100% 功能，是要跑通核心链路的最小可验证版本。** 能跑的部分直接跑，跑不了的标记清楚原因和解决路径，产出一份"找原团队要什么"的精确清单。

**分类驱动**：每个依赖都必须归入三档之一，这个分类直接决定 ae-dev 生成新产品时的 constraints。

## 输入

- **产品代码目录**：一个或多个 git repo（前端 + 后端 + 配置）
- **产品简述**（可选）：一句话说明产品做什么，帮助判断"核心链路"

## 输出

| 产出 | 文件 | 用途 |
|------|------|------|
| 依赖分类表 | `local-prototype/dependency-map.md` | 公司独有 vs 可替代 vs 通用，每项含理由 |
| 本地运行指南 | `local-prototype/local-run-guide.md` | 从 0 到跑通的完整步骤 |
| 代码补丁 | `local-prototype/patches/` | 本地运行所需的配置文件、mock、环境切换 |
| 原团队请求清单 | `local-prototype/team-request.md` | 需要原团队提供的权限/配置/说明，按阻塞程度排序 |
| Speckit 约束草案 | `local-prototype/constraints-draft.md` | 从依赖分析中提炼的 ae-dev 约束条目 |

## 执行流程

### Phase 1: 代码扫描与依赖分析

#### Step 1.1: 识别项目结构

扫描输入目录，识别所有子项目：

| 特征 | 项目类型 |
|------|---------|
| `*.xcodeproj` + `Podfile` + `*.swift` | iOS Native (CocoaPods) |
| `*.xcodeproj` + `Package.swift` | iOS Native (SPM) |
| `build.gradle` + Spring Boot | Java 后端 |
| `package.json` + React/Next | Web 前端 |
| `Dockerfile` / `docker-compose.yml` | 容器化服务 |
| 只有配置文件（properties/yaml） | 配置仓库（无源码） |

对每个子项目记录：语言、框架、文件数、代码行数。

#### Step 1.2: 依赖全量提取

**iOS (CocoaPods)**:
1. 读 `Podfile` — 列出所有 pod 及其 source（trunk / 私有 git / 本地 path）
2. 读 `Podfile.lock` — 获取精确版本和实际拉取地址
3. 用 `import` 语句统计每个库的引用次数

**iOS (SPM)**:
1. 读 `Package.swift` 或 `Package.resolved`
2. 区分 registry package vs git URL package

**Java (Gradle)**:
1. 读所有 `build.gradle` — 列出 dependencies
2. 识别公司 Maven 仓库地址（非 mavenCentral / google）
3. 识别 `com.{company}.*` groupId 的内部组件

**通用**:
1. 读 CI 配置（`.gitlab-ci.yml` / `.github/workflows`）— 识别部署依赖
2. 读环境配置（`application*.properties` / `.env*`）— 识别外部服务依赖

#### Step 1.3: 依赖三档分类

对每个依赖，判断归属：

| 分类 | 定义 | 判断规则 | ae-dev 处理方式 |
|------|------|---------|----------------|
| **A: 公司独有，不可替代** | 深度绑定公司业务/基础设施，无公开等价物 | 涉及用户体系、支付系统、部署目标、数据加密 | 必须作为 constraint 写入 speckit |
| **B: 公司独有，可替代** | 内部封装但底层是公开库，或功能简单可重写 | 查看源码/API，确认底层依赖；功能单一且接口薄 | ae-dev 用底层公开库直接集成 |
| **C: 纯通用** | 公开的第三方库 | 来自 CocoaPods trunk / mavenCentral / npm registry | ae-dev 直接使用 |

**分类判断流程**（对每个非公开依赖）：

```
1. 来源是公司私有仓库？
   否 → C 类（通用）
   是 ↓
2. 它封装了哪个公开库？（grep import/dependency 找底层依赖）
   能找到对应公开库 ↓
3. 封装层有多厚？（只是配置初始化 + 薄接口？还是有大量业务逻辑？）
   薄封装 → B 类（可替代），标注底层公开库名
   厚封装/无公开对应 ↓
4. 它绑定了公司账户体系/支付/部署/加密？
   是 → A 类（不可替代）
   否 → B 类（可替代），标注替代方案
```

对每个 B 类依赖，必须给出替代方案：
```
| 内部库 | 底层依赖 | 替代方案 | 迁移成本 |
| BCNetwork | Alamofire | 直接用 Alamofire + 自定义 interceptor | 低 |
| BCSensor | 神策+Firebase+Adjust | 分别直接集成三个 SDK | 中 |
```

### Phase 2: 本地运行方案制定

#### Step 2.1: 后端本地化

**目标**：`./gradlew bootRun` 或 `docker-compose up` 能启动。

1. **数据库**：
   - 读 application.properties 找 datasource 配置
   - 检查是否有 Flyway/Liquibase 迁移（有 → 本地 MySQL 即可自动建表）
   - 生成 `application-local.properties`：本地 MySQL 连接

2. **外部 API Key**：
   - 扫描配置中的 API key / secret 引用
   - base config 中已内嵌的 → 直接可用（标记安全提醒）
   - 引用环境变量的 → 记入"原团队请求清单"或用 mock

3. **公司内部组件**：
   - A 类依赖：检查是否有 mock/stub 模式；没有 → 记入请求清单
   - B 类依赖：评估是否可以本地绕过（如加密中间件关闭即可）

4. **验证**：列出启动后可测试的 API 端点（curl 命令）

#### Step 2.2: iOS 本地化

**目标**：Xcode 模拟器能打开 App，连接本地后端。

1. **依赖安装**：
   - 私有 pod repo → 检查是否需要 SSH key / access token（记入请求清单）
   - 尝试 `pod install`，记录成功/失败
   - 如果私有 pod 全部失败 → 评估能否用 B 类替代方案手动替换

2. **环境指向**：
   - 找到 base URL 配置文件
   - 生成指向 localhost 的配置补丁

3. **功能 Mock**：
   - 支付（A 类）→ mock IsVIP() 返回 true，跳过 StoreKit
   - 登录（A 类）→ 检查是否有匿名/游客模式
   - 埋点（B 类）→ 关闭或指向 dev null

4. **验证**：列出模拟器可测试的用户流程

#### Step 2.3: 其他服务

对配置仓库（如 purchase-service）：
- 标记为"本地不需要运行"
- 说明哪些功能因此不可用
- 给出 mock 方案（如直接在 App 端 mock VIP 状态）

### Phase 3: 产出生成

#### Step 3.1: dependency-map.md

```markdown
# 依赖分类表

## 总览
- A 类（不可替代）: X 个
- B 类（可替代）: Y 个
- C 类（通用）: Z 个

## iOS 依赖

| 库名 | 版本 | 分类 | 来源 | 用途 | 引用次数 | 替代方案 | 备注 |
|------|------|------|------|------|---------|---------|------|
| BCAccount | 1.7.2 | A | gitlab.bytescell.net | 用户认证 | 12 | — | 绑定公司用户体系 |
| BCNetwork | 1.5.2 | B | gitlab.bytescell.net | HTTP 客户端 | 全部 | Alamofire 直接使用 | 薄封装 |
| Kingfisher | 7.12.0 | C | CocoaPods trunk | 图片缓存 | 8 | — | — |

## 后端依赖

| 组件 | 版本 | 分类 | 用途 | 替代方案 |
|------|------|------|------|---------|
| component:user | 1.5.2 | A | JWT 认证 | — |
| component:crypto | 1.1.6 | B | 请求加密 | 本地关闭即可 |
```

#### Step 3.2: local-run-guide.md

按角色分节（后端开发 / iOS 开发 / 全栈），每一步都是可执行命令：

```markdown
# 本地运行指南

## 前置条件
- [ ] Java 17 (brew install openjdk@17)
- [ ] MySQL 8.0 (brew install mysql)
- [ ] Xcode 15+ (App Store)
- [ ] CocoaPods (gem install cocoapods)

## 后端启动（cap-app-service）
1. 创建数据库: `mysql -u root -e "CREATE DATABASE xxx_local"`
2. 复制配置: `cp local-prototype/patches/application-local.properties modules/common/src/main/resources/`
3. 启动: `./gradlew bootRun --args='--spring.profiles.active=local'`
4. 验证: `curl http://localhost:8281/api/...`

## iOS 启动（ios-xxx）
1. 安装依赖: `cd ios-xxx && pod install`（需要 gitlab 权限，见 team-request.md）
2. 应用补丁: `cp local-prototype/patches/BCConfig+Local.swift ...`
3. 打开: `open xxx.xcworkspace`
4. 运行: Xcode → 选模拟器 → Run
```

#### Step 3.3: team-request.md

按阻塞程度排序，每项标注：是否阻塞本地运行、预计沟通时间、替代方案。

```markdown
# 需要原团队提供的内容

## P0 — 阻塞本地运行
- [ ] gitlab.bytescell.net SSH 访问权限（阻塞 pod install，无替代方案）
  预计沟通: 5 分钟（找 admin 开权限）

## P1 — 阻塞部分功能
- [ ] purchase-service stage 环境地址（阻塞支付测试）
  替代: mock VIP 状态，不影响核心链路

## P2 — 优化体验
- [ ] 是否有推荐的本地开发 mock 方案
- [ ] 内部组件文档入口
```

#### Step 3.4: constraints-draft.md

从依赖分析直接推导 ae-dev 约束：

```markdown
# Speckit 约束草案（从依赖分析推导）

## 不可替代依赖 → 必须约束

### iOS
- ios-auth: 必须使用 BCAccount 进行用户认证（com.bytescell 用户体系）
- ios-iap: 必须使用 BCStoreKit 进行 IAP（封装了公司统一的 receipt 验证流程）

### 后端
- be-auth: 必须使用 component:user 进行 JWT 认证
- be-deploy: 必须输出 Spring Boot JAR，部署到 AWS ECS

## 可替代依赖 → 建议约束（非强制）

### iOS
- ios-network: 建议直接使用 Alamofire（不依赖 BCNetwork 封装）
- ios-analytics: 建议直接集成神策/Firebase/Adjust SDK（不依赖 BCSensor 聚合层）
  理由: 新产品减少对内部库耦合，降低 pod install 失败风险

## 通用依赖 → 技术选型参考
- iOS: Alamofire, Kingfisher, SnapKit, Lottie, Firebase, SensorsAnalyticsSDK, Adjust
- 后端: Spring Boot 3.x, MyBatis Plus, Flyway, MySQL 8.0, Spring AI
```

### Phase 4: 验证与迭代

#### Step 4.1: 尝试本地启动

按 local-run-guide.md 的步骤实际执行：

1. 后端：`./gradlew bootRun` — 记录成功/失败，更新指南
2. iOS：`pod install` — 记录成功/失败，更新请求清单
3. API 测试：curl 核心端点 — 记录响应

#### Step 4.2: 更新产出

每次尝试后更新：
- 成功的步骤标记 ✅
- 失败的步骤标记 ❌ + 错误信息 + 下一步动作
- 新发现的阻塞项加入 team-request.md

## 已知限制

- **无法替代 A 类依赖**：用户体系、支付验证等必须由原团队提供或 mock
- **私有仓库不可达时**：iOS pod install 会整体失败，需要原团队开权限或提供二进制 framework
- **加密通信**：如果 prod 启用了请求加密，本地必须关闭加密或获取密钥
- **真实数据**：本地 Flyway 只建空表，需要原团队提供种子数据或自行录入

## 与其他 Skill 的关系

| Skill | 关系 |
|-------|------|
| `ae-demo-to-speckit` | prod-to-local 产出的 dependency-map 和 constraints-draft 是 speckit 的输入 |
| `ae-speckit-receive` | constraints-draft 中的 A 类约束必须写入 speckit，ae-dev 生成代码时遵循 |
| `ae-verify-app` | 本地环境跑通后，可用 verify-app 对比原始产品 vs ae-dev 生成产品 |

## 完成后引导

本地原型跑通后，提示用户下一步选择：

> 本地环境已跑通 {N}/{M} 个核心端点。
>
> 下一步可以：
> 1. `/ae-demo-to-speckit` — 基于本产品生成 speckit，用于 ae-dev 生成新产品
> 2. 手动过代码 — 深入理解各模块实现细节
> 3. 发送 `team-request.md` 给原团队 — 解决剩余阻塞项
