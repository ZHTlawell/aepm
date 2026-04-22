# iOS 15 兼容 API 降级速查表

> 来源：bible-app trajectory 2026-04-15 comment "iOS Template 改造完整链路" 表 2.3 原文 + 4.3 节扩展
> 模板依据：部署目标 iOS **15.0**（TS-003）
> bible-app 影响面：7-9 个文件，合计 3-4 小时改造

## 完整降级表（9 类）

| # | iOS 16+ API | iOS 15 替代 | 适用场景 / 注意 |
|---|-------------|------------|----------------|
| 1 | `NavigationStack` | `NavigationView` | 影响最广（bible-app 7 文件）。注意 iOS 15 下 `NavigationView` 默认会 push 到第一个 detail |
| 2 | `ShareLink(item:)` | `UIActivityViewController` 包成 `UIViewControllerRepresentable` | bible-app 2 文件 |
| 3 | `.onChange(of:) { _, new in ... }`（双参数） | `.onChange(of:) { new in ... }`（单参数） | bible-app 3 处；注意闭包签名 |
| 4 | `TextField(text:, axis: .vertical)` | `TextField(text:)` 单行 或 `TextEditor` | iOS 15 TextField 不支持多行 axis |
| 5 | `.lineLimit(1...4)`（范围） | `.lineLimit(4)` 最大值 或移除 | 1 处 |
| 6 | `.italic()` | `.font(.system(size:, design: .serif))` 或移除 | bible-app 4 文件 |
| 7 | `.scrollContentBackground(.hidden)` | 直接移除 | List/ScrollView 背景透明需其他方案 |
| 8 | `.toolbarColorScheme(.dark, for:)` | 直接移除 | bible-app 7 文件 |
| 9 | `transaction.currency` | `transaction.currencyCode`（String?，无需 `.identifier`） | StoreKit 2 API 差异 |

## 扫描脚本（harness 使用）

```bash
# 在目标工程根目录运行
cd {{PROJECT_ROOT}}

# 1. NavigationStack
grep -rn 'NavigationStack' --include="*.swift" Locals/

# 2. ShareLink
grep -rn 'ShareLink(' --include="*.swift" Locals/

# 3. onChange 双参数（需多行 grep 或正则识别闭包第二个参数）
grep -rn '\.onChange(of:' --include="*.swift" Locals/ | head -20
#    手动检查闭包签名：{ _, new in ... } 是双参数版本

# 4. TextField axis: .vertical
grep -rn 'TextField.*axis:' --include="*.swift" Locals/

# 5. lineLimit 范围
grep -rn '\.lineLimit([0-9]*\.\.\.[0-9]*' --include="*.swift" Locals/

# 6. .italic()
grep -rn '\.italic()' --include="*.swift" Locals/

# 7. scrollContentBackground
grep -rn '\.scrollContentBackground' --include="*.swift" Locals/

# 8. toolbarColorScheme
grep -rn '\.toolbarColorScheme' --include="*.swift" Locals/

# 9. transaction.currency
grep -rn 'transaction\.currency[^C]' --include="*.swift" Locals/
```

## 修复优先级

1. **必修**：1 / 3 / 4 / 5 / 9（不修会编译报错）
2. **软降级**：2 / 6 / 7 / 8（视觉/交互差异，不修编译过但功能受损）

## 已知 TODO

- 若项目用到 `NavigationPath`（NavigationStack 的伴生），iOS 15 无对应 API，需重设计导航路径为 enum + State
- iOS 15 `SubscriptionStoreView`（StoreKit 2 UI）完全不可用，必须走 BCPurchaseUI 自定义 UI
