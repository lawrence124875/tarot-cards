import 'package:flutter/widgets.dart';

/// 廣告（HANDOFF §23）。畫面只認這個介面；AdMob 只出現在 `lib/core/admob/admob_ads.dart`。
///
/// 三種廣告：底部橫幅、插頁（解讀頁關閉回到起卦頁時，依 [InterstitialPacer] 限頻）、
/// 獎勵（使用者自己選擇觀看，換一次額外起卦）。訂閱戶全部不顯示（[enabled] = false）。
abstract class AdService {
  /// 訂閱狀態改變時由 main.dart 設定；false＝不載入、不顯示任何廣告。
  bool get enabled;
  set enabled(bool value);

  /// 底部橫幅；不顯示時回傳 null（畫面就不留空位）。
  Widget? banner();

  /// 一次解讀看完、使用者離開解讀頁時呼叫；由限頻規則決定是否跳插頁。
  void readingClosed();

  /// 預先載入獎勵廣告（顯示「看廣告再抽一次」之前呼叫）。
  Future<bool> prepareRewarded();

  /// 播放獎勵廣告；使用者看完（拿到獎勵）才回傳 true。
  Future<bool> showRewarded();

  /// 是否需要在選單提供「廣告隱私設定」（歐洲等需要同意的地區才為 true，Google UMP）。
  bool get privacyOptionsRequired;

  Future<void> showPrivacyOptions();
}

/// 沒有廣告（測試、訂閱戶、AdMob 初始化失敗）。
class NoAds implements AdService {
  @override
  bool enabled = false;

  @override
  Widget? banner() => null;

  @override
  void readingClosed() {}

  @override
  Future<bool> prepareRewarded() async => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

/// 插頁廣告限頻（純邏輯，可單獨測試）：
/// 每 [every] 次解讀最多一次，且距上一次全螢幕廣告至少 [minGap]。
/// 第一次解讀永遠不跳（新使用者第一次體驗不被打斷）。
class InterstitialPacer {
  InterstitialPacer({this.every = 3, this.minGap = const Duration(minutes: 3), DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final int every;
  final Duration minGap;
  final DateTime Function() _clock;
  int _readings = 0;
  DateTime? _lastFullScreen;

  /// 記一次解讀，回傳這次是否該跳插頁。真的顯示後要呼叫 [shown]。
  bool readingClosed() {
    _readings++;
    if (every <= 0 || _readings % every != 0) return false;
    final last = _lastFullScreen;
    return last == null || _clock().difference(last) >= minGap;
  }

  /// 任何全螢幕廣告（插頁、獎勵）播完時呼叫，重新計算間隔。
  void shown() => _lastFullScreen = _clock();
}
