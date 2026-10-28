/// 免費版限制（HANDOFF H，2026-10-28）。數值可由 Firebase Remote Config 調整（`tr_` 開頭），
/// 不設就用這裡的預設值。解讀內容（三組解讀、象徵、東西相映）永遠不鎖。
///
/// Firebase 專案與其他 App 共用：`tr_` 參數只有本 App 會讀，其他 App 讀不到也不受影響；
/// 若在主控台設定值，請加上條件「App＝com.lclab.tarot」（之前註解寫「謙卦 App 條件」是複製錯誤）。
class FreeLimits {
  const FreeLimits({
    this.castsPerDay = 2,
    this.rewardedPerDay = 2,
    this.journalMax = 10,
    this.freeBreathMinutes = const {1, 2},
  });

  /// 每天免費抽牌次數（所有牌陣合計）。
  final int castsPerDay;

  /// 每天最多可用獎勵廣告換幾次額外抽牌。
  final int rewardedPerDay;

  /// 免費版卦記上限（已存的不會被刪、仍可查看，只是不能再新增）。
  final int journalMax;

  /// 免費版可選的呼吸時長；其餘時長與雙耳節拍屬訂閱。
  final Set<int> freeBreathMinutes;

  /// Remote Config 參數名稱與預設值（firebase_telemetry 設定預設值用）。
  static const remoteDefaults = <String, int>{
    'tr_free_casts_per_day': 2,
    'tr_free_rewarded_per_day': 2,
    'tr_free_journal_max': 10,
  };

  /// 由遠端數值建立；讀不到或數值不合理就用預設。
  factory FreeLimits.from(int Function(String key, int fallback) read) {
    int v(String k, {int min = 0, int max = 1000}) {
      final d = remoteDefaults[k]!;
      final x = read(k, d);
      return (x < min || x > max) ? d : x;
    }

    return FreeLimits(
      castsPerDay: v('tr_free_casts_per_day', min: 1),
      rewardedPerDay: v('tr_free_rewarded_per_day'),
      journalMax: v('tr_free_journal_max', min: 1),
    );
  }
}
