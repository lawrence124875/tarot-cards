/// 遠端開關介面（HANDOFF §9 第 4 項、§18）。目前只用來開關功能入口：
/// 參數名稱 `tr_feature_<功能 id>`（布林），App 內預設全部開啟。
///
/// Firebase 專案與其他 App 共用，所以參數一律 `tr_` 開頭；在主控台設定值時
/// 加上條件「App＝com.lclab.tarot」（iOS 上架後再加 iOS App）。
abstract class RemoteFlags {
  bool featureEnabled(String featureId);

  /// 整數參數（免費版限制等，HANDOFF §23）；讀不到回傳 [fallback]。
  int intValue(String key, int fallback);
}

/// 參數名稱（主控台建立參數時照這個寫）。
String featureFlagKey(String featureId) => 'tr_feature_$featureId';

/// 沒有 Firebase（初始化失敗、測試）時：全部照 App 內預設，也就是全部開啟。
class DefaultRemoteFlags implements RemoteFlags {
  const DefaultRemoteFlags();

  @override
  bool featureEnabled(String featureId) => true;

  @override
  int intValue(String key, int fallback) => fallback;
}
