# Apple App Store Review Guidelines — 5.1 Privacy

**Source:** https://developer.apple.com/app-store/review/guidelines/#5.1
**Fetched at:** 2026-04-21
**Fetch method:** WebFetch (static HTML)

---

## 5.1 Privacy [ASR & NR]

Protecting user privacy is paramount in the Apple ecosystem, and you should use care when handling personal data to ensure you've complied with privacy best practices, applicable laws, and the terms of the Apple Developer Program License Agreement, not to mention customer expectations.

### 5.1.1 Data Collection and Storage [ASR & NR]

**(i) Privacy Policies:** All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner. The privacy policy must clearly and explicitly:
- Identify what data, if any, the app/service collects, how it collects that data, and all uses of that data.
- Confirm that any third party with whom an app shares user data will provide the same or equal protection of user data as stated in the app's privacy policy.
- Explain its data retention/deletion policies and describe how a user can revoke consent and/or request deletion of the user's data.

**(ii) Permission:** Apps that collect user or usage data must secure user consent for the collection, even if such data is considered to be anonymous at the time of or immediately following collection. Paid functionality must not be dependent on or require a user to grant access to this data. Ensure your purpose strings clearly and completely describe your use of the data.

**(iii) Data Minimization:** Apps should only request access to data relevant to the core functionality of the app and should only collect and use data that is required to accomplish the relevant task.

**(iv) Access:** Apps must respect the user's permission settings and not attempt to manipulate, trick, or force people to consent to unnecessary data access.

**(v) Account Sign-In:** If your app doesn't include significant account-based features, let people use it without a login. If your app supports account creation, you must also offer account deletion within the app. If your core app functionality is not related to a specific social network (e.g. Facebook, WeChat, Weibo, X, etc.), you must provide access without a login or via another mechanism.

**(vi)** Developers that use their apps to surreptitiously discover passwords or other private data will be removed from the Apple Developer Program.

**(vii)** SafariViewController must be used to visibly present information to users; the controller may not be hidden or obscured by other views or layers.

**(viii)** Apps that compile personal information from any source that is not directly from the user or without the user's explicit consent, even public databases, are not permitted on the App Store.

**(ix)** Apps that provide services in highly regulated fields (such as banking and financial services, healthcare, gambling, legal cannabis use, air travel and crypto exchanges) or that require sensitive user information should be submitted by a legal entity that provides the services, and not by an individual developer.

**(x)** Apps may request basic contact information (such as name and email address) so long as the request is optional for the user.

### 5.1.2 Data Use and Sharing [ASR & NR]

**(i)** Unless otherwise permitted by law, you may not use, transmit, or share someone's personal data without first obtaining their permission. You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so. Data collected from apps may only be shared with third parties to improve the app or serve advertising. You must receive explicit permission from users via the App Tracking Transparency APIs to track their activity.

**(ii)** Data collected for one purpose may not be repurposed without further consent unless otherwise explicitly permitted by law.

**(iii)** Apps should not attempt to surreptitiously build a user profile based on collected data.

**(iv)** Do not use information from Contacts, Photos, or other APIs that access user data to build a contact database for your own use or for sale/distribution to third parties.

**(vi)** Data gathered from the HomeKit API, HealthKit, Clinical Health Records API, MovementDisorder APIs, ClassKit or from depth and/or facial mapping tools may not be used for marketing, advertising or use-based data mining.

### 5.1.3 Health and Health Research [ASR & NR]
Health, fitness, and medical data are especially sensitive. Apps may not use or disclose such data for advertising or marketing; must not store personal health information in iCloud; human subject research requires consent and independent ethics review board approval.

### 5.1.4 Kids
Apps intended primarily for kids should not include third-party analytics or third-party advertising. Kids Category apps must comply with COPPA and GDPR.

### 5.1.5 Location Services [ASR & NR]
Use Location Services only when directly relevant to features and services. Ensure you notify and obtain consent before collecting location data.
