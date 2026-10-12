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
        PaywallShown p => ('tr_paywall_shown', {'source': p.source}),
        RewardedEarned r => ('tr_rewarded_earned', {'source': r.source}),
        Subscribed s => ('tr_subscribed', {'period': s.period}),
        _ => null,
      };

  void _handle(AppEvent e) {
    final d = describe(e);
    if (d != null) _analytics.log(d.$1, d.$2);
  }

  Future<void> dispose() => _sub.cancel();
}
