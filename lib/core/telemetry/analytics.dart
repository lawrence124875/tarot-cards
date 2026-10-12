/// 使用統計介面（HANDOFF §18）。畫面與功能不直接碰 Firebase，只透過事件匯流排
/// 由 [AnalyticsListener] 轉成統計事件；換實作（或停用）只改 main.dart。
///
/// ⚠️ 隱私（§13）：絕不記錄「想問的事」、回顧文字或任何使用者輸入的文字。
abstract class Analytics {
  /// 事件名稱一律 `tr_` 開頭（與智慧聽覺巡航共用同一個 Firebase 專案，見 §18）。
  /// 參數值只用 String 或 num（Firebase 限制）。不拋例外。
  Future<void> log(String name, [Map<String, Object> params = const {}]);
}

class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> log(String name, [Map<String, Object> params = const {}]) async {}
}
