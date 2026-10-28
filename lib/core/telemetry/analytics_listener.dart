import 'dart:async';

import '../events/event_bus.dart';
import 'analytics.dart';

/// 事件匯流排的「旁觀者」（§9 第 6 項）：把 App 事件轉成統計事件。
/// 只送功能使用情形的代碼與數字，不送任何使用者輸入的文字（§13）。
class AnalyticsListener {
  AnalyticsListener(EventBus events, this._analytics) {
    _sub = events.on<AppEvent>().listen(_handle);
  }

  final Analytics _analytics;
  late final StreamSubscription<AppEvent> _sub;

  /// 事件 → 統計事件名稱與參數；認不得的事件不送。可單獨測試。
  static (String, Map<String, Object>)? describe(AppEvent e) => switch (e) {
        ReadingShown r => (
            'tr_reading_shown',
            {'method': r.methodId, 'spread': r.spreadId, 'card': r.keyCard, 'reversed': r.reversed},
          ),
        JournalSaved j => ('tr_journal_saved', {'has_reminder': j.hasReminder ? 1 : 0}),
        BreathStarted b => (
            'tr_breath_started',
            {'card': b.cardId, 'minutes': b.minutes, 'silent': b.silent ? 1 : 0, 'binaural': b.binaural ? 1 : 0},
          ),
        BreathCompleted b => ('tr_breath_completed', {'card': b.cardId, 'minutes': b.minutes}),
        // 漏斗（HANDOFF H 第 7 點）：名稱加 tr_ 前綴，與共用 Firebase 專案的其他 App 區分
        FirstDraw f => ('tr_first_draw', {'spread': f.spreadId}),
        HitFreeLimit h => ('tr_hit_free_limit', {'type': h.type}),
        RewardedAdShown r => ('tr_rewarded_ad_shown', {'source': r.source, 'earned': r.earned ? 1 : 0}),
        RewardedAdFailed r => ('tr_rewarded_ad_failed', {'source': r.source}),
        InterstitialShown _ => ('tr_interstitial_shown', const {}),
        InterstitialFailed _ => ('tr_interstitial_failed', const {}),
        PaywallShown p => ('tr_paywall_view', {'source': p.source}),
        TrialStarted t => ('tr_trial_start', {'period': t.period}),
        Subscribed s when s.period == 'restore' => ('tr_restore', const {}),
        Subscribed s => ('tr_purchase', {'period': s.period}),
        _ => null,
      };

  void _handle(AppEvent e) {
    final d = describe(e);
    if (d != null) _analytics.log(d.$1, d.$2);
  }

  Future<void> dispose() => _sub.cancel();
}
