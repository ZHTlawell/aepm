# Case 3.1.1 — 第三方支付被误判为 IAP 规避

**Source:** https://blog.csdn.net/heipingguowenkong/article/details/81069578
**Fetched at:** 2026-04-21
**Apple Guideline:** 3.1.1 - In-App Purchase

## 场景

教育/办公类 App 集成了**支付宝支付**（Alipay SDK），用于硬件设备费用结算（非软件功能解锁）。Apple AI 审核将其误判为"用第三方支付规避 IAP"。

## Apple Rejection（文中未完整引用原文）

作者描述 Apple 的拒审意见大意为："App 使用了非 IAP 支付机制解锁功能"。

## 修复做法

1. 在"我的订单"页面补充文案，明确说明支付用途（硬件费用 vs App 功能）
2. 提交详细的说明邮件给审核团队，区分硬件费和软件功能费
3. 附上硬件合同照片作为证据
4. 次日通过审核

## 关键认知

Guideline 3.1.3(e) 允许物理商品/服务用非 IAP 支付，但必须：
- 在 Review Notes 中主动说明
- 用户界面上清晰区分"实物购买" vs "App 功能"
- 必要时提供线下合同证据

## 对扫描器的启示

检测到 `import AlipaySDK` / `WXPay` / `import Stripe` 等第三方支付 SDK 时：
- 不是直接 fail（合法用途存在）
- 而是 warn + 强制提示：必须在 Review Notes 说明用途，证明是物理商品/服务
