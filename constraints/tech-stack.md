# 技术选型约束

PM 在使用 vibe coding 工具（Antigravity 等）生成 demo 原型时，必须遵守以下技术约束。这些约束确保 demo 能顺利通过后续的 speckit 提取、成品生成和 E2E 验证流程。

## iOS 前端

| 约束 | 要求 | 原因 |
|------|------|------|
| **UI 框架** | 必须使用 SwiftUI Native | WebView hybrid 无法被自动化测试工具（AXe）识别 UI 元素 |
| **禁止 WebView 包装** | 不得用 WKWebView 加载 HTML/JS 作为主要 UI | accessibility tree 为空，E2E 验证失败率高 |
| **可测试性** | 所有可交互元素必须设置 `accessibilityIdentifier` | 自动化测试依赖此属性精确定位元素 |
| **隐私声明** | Info.plist 必须声明所需权限（如 NSCameraUsageDescription）| 功能缺少权限声明会导致 crash |
| **项目结构** | 按功能模块拆分，单文件不超过 500 行 | 大文件超出 agent 处理能力 |

## 后端

| 约束 | 要求 | 原因 |
|------|------|------|
| **框架** | Spring Boot 3.x + Java 17 | 公司标准技术栈 |
| **ORM** | MyBatis + XML Mapper | 公司标准 |
| **数据库** | MySQL + Flyway 迁移 | 可追溯的 schema 变更 |
| **项目结构** | 多模块 Gradle 工程 | 业务域隔离 |

## 数据层

| 约束 | 要求 | 原因 |
|------|------|------|
| **数据分离** | 数据不得硬编码在 UI 代码中 | speckit 提取和成品生成都需要独立的数据层 |
| **API 契约** | Mock 必须遵循标准 REST 格式，与未来真实 API 结构一致 | 确保 mock→real 切换零改动 |

## 通用

| 约束 | 要求 | 原因 |
|------|------|------|
| **暗黑主题** | 优先深色模式 | 设计系统一致性 |
| **中英文** | 界面默认英文，支持中文切换 | 国际化基础 |
