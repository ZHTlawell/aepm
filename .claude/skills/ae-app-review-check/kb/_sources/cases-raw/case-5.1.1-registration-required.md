# Case 5.1.1 — 强制注册才能购买非账户相关 IAP

**Source:** https://blog.csdn.net/weixin_39339407/article/details/149016777
**Fetched at:** 2026-04-21
**Apple Guideline:** 5.1.1 - Legal - Data Collection and Storage
**Rejection date:** 2025-07 (Submission ID 33c9704d-e215-4e35-8fc1-14ab755455ae)

## Apple Rejection Text (verbatim)

> "We noticed that your app requires users to register with personal information to purchase in-app purchase products that are not account based."
>
> "Apps cannot require user registration prior to allowing access to app content and features that are not associated specifically to the user."
>
> "To resolve this issue, please revise your app to not require users to register before purchasing in-app purchase products that are not account based."

## 场景还原

App（教育类）把 IAP 购买流程放在"需要先注册账号"之后。用户想买一个课程 IAP，必须先提供姓名/邮箱注册。但该 IAP 产品本身不绑定账户（即不是订阅、不是云同步），违反了 "非账户相关的功能不可强制注册"。

## 修复做法

1. 课程详情页入口去掉登录门槛
2. 把登录提示移到"解锁/购买"按钮上（而不是入口）
3. 提供"访客登录"选项 — 自动创建访客账户
4. 允许用户未注册即浏览内容

## 对扫描器的启示

无法纯静态判断，但可以检查：
- 是否存在"启动即弹登录页"（LoginView 在 App entry 之前）
- 是否存在"NavigationLink 前有登录守卫"覆盖所有入口
