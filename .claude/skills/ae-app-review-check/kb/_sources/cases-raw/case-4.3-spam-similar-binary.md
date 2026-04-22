# Case 4.3(a) — Design Spam: 与已终止账户的 App 相似

**Source:** https://blog.csdn.net/weixin_43668101/article/details/138144735
**Fetched at:** 2026-04-21
**Apple Guideline:** 4.3(a) - Design - Spam

## Apple Rejection Text (verbatim)

> "We noticed your app shares a similar binary, metadata, and/or concept as apps previously submitted by a terminated Apple Developer Program account."
>
> 中文参考："我们注意到，您的应用程序与终止的苹果开发者计划帐户之前提交的应用程序共享类似的二进制、元数据和/或概念。"

## 触发因素

- 相似的 binary（疑似复用源码或使用了相同模板）
- 相似的 metadata（App 名称 / 描述 / 截图风格）
- 相似的功能概念

## 修复做法

作者采用的组合拳（整体替换而非小修小补）：
1. 改 App name + description
2. 截图全部换成真实运行截图（而非模板示意图）
3. 调整 metadata 内容
4. 重新打包提交

**关键经验：** 一旦 4.3 被拒，后续审核人员会加严，小改没用；需要"综合性改动跨多个版本"。

## 其他 4.3 常见触发（从搜索结果综合）

- 同一源码改 Logo / 名字 打马甲包
- 使用付费 App 模板导致 binary 相似
- 社交类 / 算命星座类赛道饱和（4.3(b)）
- 跨账号提交多个类似 App
