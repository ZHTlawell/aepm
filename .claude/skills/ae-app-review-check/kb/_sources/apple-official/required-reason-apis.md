# Apple — Required Reason APIs (完整枚举)

**Sources:**
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype

**Fetched at:** 2026-04-21
**Fetch method:** Playwright

---

## 关键合规要点

- 用户是否同意 ATT tracking 不影响此要求 — **fingerprinting is not allowed regardless**
- **2024-05-01 起**，使用 Required Reason API 但未在 manifest 中声明的 App 将被 App Store Connect 拒收
- App 和每个使用 Required Reason API 的 executable / dynamic library 都要独立声明
- 第三方 SDK 不能让引用它的 App 代为声明

## 5 个 API 类别及允许的 reason 代码

### 1. NSPrivacyAccessedAPICategoryFileTimestamp

**API 列表：**
creationDate / modificationDate / fileModificationDate / contentModificationDateKey / creationDateKey / getattrlist / getattrlistbulk / fgetattrlist / stat / fstat / fstatat / lstat / getattrlistat

| Reason | 用途 | 约束 |
|--------|------|------|
| DDA9.1 | 向用户显示文件时间戳 | 不可离线 |
| C617.1 | 访问 app container / app group container / CloudKit container 内的文件元数据 | — |
| 3B52.1 | 访问用户通过 document picker 显式授权的文件元数据 | — |
| 0A2A.1 | SDK 为 App 提供 wrapper function 时使用 | 仅第三方 SDK 可声明 |

### 2. NSPrivacyAccessedAPICategorySystemBootTime

**API 列表：** systemUptime / mach_absolute_time()

| Reason | 用途 | 约束 |
|--------|------|------|
| 35F9.1 | 测量 App 内事件间隔或 timer 计算 | 不可离线（事件间隔时间可离线） |
| 8FFB.1 | 计算 App 内事件的 absolute timestamp（如 UIKit / AVFAudio 事件） | 时间戳可离线，但 boot time 本身不可 |
| 3D61.1 | 用户主动提交的 bug report 中包含 boot time | 仅在用户确认提交后离线 |

### 3. NSPrivacyAccessedAPICategoryDiskSpace

**API 列表：** volumeAvailableCapacityKey / volumeAvailableCapacityForImportantUsageKey / volumeAvailableCapacityForOpportunisticUsageKey / volumeTotalCapacityKey / systemFreeSize / systemSize / statfs / statvfs / fstatfs / fstatvfs / getattrlist / fgetattrlist / getattrlistat

| Reason | 用途 | 约束 |
|--------|------|------|
| 85F4.1 | 向用户展示磁盘空间 | 不可离线（同用户设备间的 LAN 传输为例外） |
| E174.1 | 检查写入前磁盘空间充足 | 不可离线 |
| 7D9E.1 | 用户主动提交的 bug report | 仅用户确认后离线 |
| B728.1 | 健康研究 App 告知研究参与者磁盘不足 | 必须符合 Guideline 5.1.3 |

### 4. NSPrivacyAccessedAPICategoryActiveKeyboards

**API：** activeInputModes

| Reason | 用途 | 约束 |
|--------|------|------|
| 3EC4.1 | 自定义键盘 App 获取当前活跃键盘 | 不可离线；App 主要功能必须是系统级键盘 |
| 54BD.1 | 根据 active keyboard 调整 UI | 不可离线；App 必须有文本输入字段且行为可被用户观察 |

### 5. NSPrivacyAccessedAPICategoryUserDefaults

**API：** UserDefaults

| Reason | 用途 | 约束 |
|--------|------|------|
| CA92.1 | 仅 App 自身可访问的 UserDefaults 读写 | 不允许读其他 App 或系统写入的信息 |
| 1C8F.1 | App Group 内共享的 UserDefaults | — |
| C56D.1 | SDK 为 App 提供 wrapper | 仅第三方 SDK 可声明 |
| AC6B.1 | 读 `com.apple.configuration.managed` 或写 `com.apple.feedback.managed`（MDM） | — |

## 扫描器可识别的"触发 API 出现"信号

下列符号只要在源码中出现，就**必须**在 PrivacyInfo.xcprivacy 声明对应类别：

| 符号片段 | 类别 |
|---------|------|
| `systemUptime`, `mach_absolute_time` | SystemBootTime |
| `volumeAvailableCapacityKey`, `statfs(`, `statvfs(`, `systemFreeSize` | DiskSpace |
| `activeInputModes` | ActiveKeyboards |
| `UserDefaults`, `NSUserDefaults`, `.standard.set(`, `.standard.object(` | UserDefaults |
| `.creationDate`, `.modificationDate`, `fileModificationDate`, `.contentModificationDateKey`, `getattrlist(`, `stat(` | FileTimestamp |

> **注意：** UserDefaults 几乎所有 Swift App 都会用到 — 命中本身不是 fail，只在 PrivacyInfo.xcprivacy 缺失或未声明 UserDefaults 类别时 fail。
