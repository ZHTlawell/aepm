# Apple App Store Review Guidelines — 3.1 Payments

**Source:** https://developer.apple.com/app-store/review/guidelines/#3.1
**Fetched at:** 2026-04-21
**Fetch method:** WebFetch (static HTML)
**Page "last updated":** Not shown on page.

---

## 3.1 Payments

### 3.1.1 In-App Purchase

- If you want to unlock features or functionality within your app, (by way of example: subscriptions, in-game currencies, game levels, access to premium content, or unlocking a full version), you must use in-app purchase. Apps may not use their own mechanisms to unlock content or functionality, such as license keys, augmented reality markers, QR codes, cryptocurrencies and cryptocurrency wallets, etc.
- Apps may use in-app purchase currencies to enable customers to "tip" the developer or digital content providers in the app.
- Any credits or in-game currencies purchased via in-app purchase may not expire, and you should make sure you have a restore mechanism for any restorable in-app purchases.
- Apps may enable gifting of items that are eligible for in-app purchase to others. Such gifts may only be refunded to the original purchaser and may not be exchanged.
- Apps distributed via the Mac App Store may host plug-ins or extensions that are enabled with mechanisms other than the App Store.
- Apps offering "loot boxes" or other mechanisms that provide randomized virtual items for purchase must disclose the odds of receiving each type of item to customers prior to purchase.
- Digital gift cards, certificates, vouchers, and coupons which can be redeemed for digital goods or services can only be sold in your app using in-app purchase. Physical gift cards that are sold within an app and then mailed to customers may use payment methods other than in-app purchase.
- Non-subscription apps may offer a free time-based trial period before presenting a full unlock option by setting up a Non-Consumable IAP item at Price Tier 0 that follows the naming convention: "XX-day Trial." Prior to the start of the trial, your app must clearly identify its duration, the content or services that will no longer be accessible when the trial ends, and any downstream charges the user would need to pay for full functionality. Learn more about managing content access and the duration of the trial period using Receipts and DeviceCheck.
- Apps may use in-app purchase to sell and sell services related to non-fungible tokens (NFTs), such as minting, listing, and transferring. Apps may allow users to view their own NFTs, provided that NFT ownership does not unlock features or functionality within the app. Apps may allow users to browse NFT collections owned by others, provided that, except for apps on the United States storefront, the apps may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase.

### 3.1.1(a) Link to Other Purchase Methods

Developers may apply for entitlements to provide a link in their app to a website the developer owns or maintains responsibility for in order to purchase digital content or services. These entitlements are not required for developers to include buttons, external links, or other calls to action in their United States storefront apps. Please see additional details below.

- **StoreKit External Purchase Link Entitlements:** apps on the App Store in specific regions may offer in-app purchases and also use a StoreKit External Purchase Link Entitlement to include a link to the developer's website that informs users of other ways to purchase digital goods or services. In all other storefronts, except for the United States storefront, where this prohibition does not apply, apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase.
- **Music Streaming Services Entitlements:** music streaming apps in specific regions can use Music Streaming Services Entitlements to include a link (which may take the form of a buy button) to the developer's website that informs users of other ways to purchase digital music content or services.
- If your app engages in misleading marketing practices, scams, or fraud in relation to the entitlement, your app will be removed from the App Store and you may be removed from the Apple Developer Program.

### 3.1.2 Subscriptions

Apps may offer auto-renewable in-app purchase subscriptions, regardless of category on the App Store. When incorporating auto-renewable subscriptions into your app, be sure to follow the guidelines below.

**3.1.2(a) Permissible uses:** If you offer an auto-renewable subscription, you must provide ongoing value to the customer, and the subscription period must last at least seven days and be available across all of the user's devices.

- Subscriptions may be offered alongside à la carte offerings.
- Games offered in a streaming game service subscription may offer a single subscription that is shared across third-party apps and services; however, they must be downloaded directly from the App Store.
- Subscriptions must work on all of the user's devices where the app is available.
- As with all apps, those offering subscriptions should allow a user to get what they've paid for without performing additional tasks, such as posting on social media, uploading contacts, checking in to the app a certain number of times, etc.
- Subscriptions may include consumable credits, gems, in-game currencies, etc.
- If you are changing your existing app to a subscription-based business model, you should not take away the primary functionality existing users have already paid for.
- Auto-renewable subscription apps may offer a free trial period to customers by providing the relevant information set forth in App Store Connect.
- Apps that attempt to scam users will be removed from the App Store. This includes apps that attempt to trick users into purchasing a subscription under false pretenses or engage in bait-and-switch and scam practices.

**3.1.2(b) Upgrades and Downgrades:** Users should have a seamless upgrade/downgrade experience and should not be able to inadvertently subscribe to multiple variations of the same thing.

**3.1.2(c) Subscription Information:** Before asking a customer to subscribe, you should clearly describe what the user will get for the price. How many issues per month? How much cloud storage? What kind of access to your service?

### 3.1.3 Other Purchase Methods

The following apps may use purchase methods other than in-app purchase.

- **3.1.3(a) "Reader" Apps:** Apps may allow a user to access previously purchased content or content subscriptions (magazines, newspapers, books, audio, music, and video).
- **3.1.3(b) Multiplatform Services:** Apps that operate across multiple platforms may allow users to access content, subscriptions, or features they have acquired in your app on other platforms or your web site.
- **3.1.3(c) Enterprise Services:** If your app is only sold directly by you to organizations or groups for their employees or students.
- **3.1.3(d) Person-to-Person Services:** If your app enables the purchase of real-time person-to-person services between two individuals. One-to-few and one-to-many real-time services must use in-app purchase.
- **3.1.3(e) Goods and Services Outside of the App:** If your app enables people to purchase physical goods or services that will be consumed outside of the app.
- **3.1.3(f) Free Stand-alone Apps:** Free apps acting as a stand-alone companion to a paid web based tool (i.e. VoIP, Cloud Storage, Email Services, Web Hosting).
- **3.1.3(g) Advertising Management Apps:** Apps for the sole purpose of allowing advertisers to purchase and manage advertising campaigns across media types.

### 3.1.4 Hardware-Specific Content
In limited circumstances, such as when features are dependent upon specific hardware to function, the app may unlock that functionality without using in-app purchase.

### 3.1.5 Cryptocurrencies
- **(i)** Wallets: Apps may facilitate virtual currency storage, provided they are offered by developers enrolled as an organization.
- **(ii)** Mining: Apps may not mine for cryptocurrencies unless the processing is performed off device.
- **(iii)** Exchanges: Apps may facilitate transactions or transmissions of cryptocurrency on an approved exchange.
- **(iv)** Initial Coin Offerings: Apps facilitating ICOs must come from established banks, securities firms, futures commission merchants, or other approved financial institutions.
- **(v)** Cryptocurrency apps may not offer currency for completing tasks.
