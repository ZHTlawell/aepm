# Apple — Third-party SDKs Requiring Privacy Manifest + Signature

**Source:** https://developer.apple.com/support/third-party-SDK-requirements/
**Fetched at:** 2026-04-21
**Fetch method:** Playwright

---

## 规则

- 下列 SDK 只要被 App 使用（直接或通过二次打包），App 提交/更新时**必须**：
  - 该 SDK 的 `PrivacyInfo.xcprivacy` 必须随 SDK 附带
  - 以 binary dependency 形式使用时，SDK 必须有 signature
- 任意版本的列出 SDK 都适用
- 对列出 SDK 做二次封装（repackage）的也适用

## SDK 清单（按字母序，完整原文）

Abseil / AFNetworking / Alamofire / AppAuth / BoringSSL / openssl_grpc
Capacitor / Charts / connectivity_plus / Cordova
device_info_plus / DKImagePickerController / DKPhotoGallery
FBAEMKit / FBLPromises / FBSDKCoreKit / FBSDKCoreKit_Basics / FBSDKLoginKit / FBSDKShareKit
file_picker
FirebaseABTesting / FirebaseAuth / FirebaseCore / FirebaseCoreDiagnostics / FirebaseCoreExtension / FirebaseCoreInternal / FirebaseCrashlytics / FirebaseDynamicLinks / FirebaseFirestore / FirebaseInstallations / FirebaseMessaging / FirebaseRemoteConfig
Flutter / flutter_inappwebview / flutter_local_notifications / fluttertoast
FMDB
geolocator_apple
GoogleDataTransport / GoogleSignIn / GoogleToolboxForMac / GoogleUtilities
grpcpp / GTMAppAuth / GTMSessionFetcher
hermes
image_picker_ios
IQKeyboardManager / IQKeyboardManagerSwift
Kingfisher
leveldb / Lottie
MBProgressHUD
nanopb
OneSignal / OneSignalCore / OneSignalExtension / OneSignalOutcomes
OpenSSL / OrderedSet
package_info / package_info_plus / path_provider / path_provider_ios
Promises / Protobuf
Reachability / RealmSwift
RxCocoa / RxRelay / RxSwift
SDWebImage / share_plus / shared_preferences_ios / SnapKit / sqflite / Starscream / SVProgressHUD / SwiftyGif / SwiftyJSON
Toast
UnityFramework
url_launcher / url_launcher_ios
video_player_avfoundation / wakelock / webview_flutter_wkwebview

## Christian / Bible 类 App 常见命中项

基于 iOS app 常见栈推断：
- **FirebaseCrashlytics / FirebaseAnalytics / FirebaseAuth / FirebaseMessaging** — 几乎必用
- **OneSignal*** — 推送
- **Alamofire / AFNetworking** — HTTP
- **SDWebImage / Kingfisher / Lottie** — 图片/动画
- **RxSwift / RxCocoa** — 响应式框架
