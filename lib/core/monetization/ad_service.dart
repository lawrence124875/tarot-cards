import 'package:flutter/widgets.dart';

/// 廣告（HANDOFF H，2026-10-28）。畫面只認這個介面；AdMob 只出現在 `lib/core/admob/admob_ads.dart`。
///
/// 三種廣告：
/// - 橫幅：只放首頁、卦記列表、牌陣選擇頁、課程列表（解讀、課程內文、呼吸練習不放）。
/// - 插頁：只在「每日第 1 次抽牌」動畫結束、顯示解讀前播一次（見 [showInterstitial]）。
/// - 獎勵：使用者自己選擇觀看，換一次額外抽牌。
/// 訂閱戶全部不顯示（[enabled] = false）。
abstract class AdService {
  /// 訂閱狀態改變時由 main.dart 設定；false＝不載入、不顯示任何廣告。
  bool get enabled;
  set enabled(bool value);

  /// 底部橫幅；不顯示時回傳 null（畫面就不留空位）。
  Widget? banner();

  /// 播一則插頁，等使用者關掉才回傳。最多等 [loadTimeout] 載入；
  /// 載入失敗、無填充、逾時或顯示失敗都回傳 [AdResult.failed]，呼叫端直接往下走。
  Future<AdResult> showInterstitial({Duration loadTimeout = const Duration(seconds: 3)});

  /// 預先載入獎勵廣告（顯示「看廣告再抽一次」之前呼叫）。
  Future<bool> prepareRewarded();

  /// 播放獎勵廣告：看完拿到獎勵＝[AdResult.earned]；中途關掉＝[AdResult.dismissed]；
  /// 沒載入、顯示失敗＝[AdResult.failed]。
  Future<AdResult> showRewarded();

  /// 是否需要在選單提供「廣告隱私設定」（歐洲等需要同意的地區才為 true，Google UMP）。
  bool get privacyOptionsRequired;

  Future<void> showPrivacyOptions();
}

enum AdResult {
  /// 插頁播完並關閉。
  shown,

  /// 獎勵廣告看完並拿到獎勵。
  earned,

  /// 獎勵廣告中途關掉（沒有獎勵）。
  dismissed,

  /// 載入失敗、無填充、逾時或顯示失敗。
  failed,

  /// 廣告關閉中（訂閱戶、沒有廣告），什麼都沒做。
  skipped,
}

/// 沒有廣告（測試、訂閱戶、AdMob 初始化失敗）。
class NoAds implements AdService {
  @override
  bool enabled = false;

  @override
  Widget? banner() => null;

  @override
  Future<AdResult> showInterstitial({Duration loadTimeout = const Duration(seconds: 3)}) async => AdResult.skipped;

  @override
  Future<bool> prepareRewarded() async => false;

  @override
  Future<AdResult> showRewarded() async => AdResult.failed;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
