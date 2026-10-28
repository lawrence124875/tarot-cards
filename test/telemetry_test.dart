import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/feature_registry.dart';
import 'package:tarot_cards/core/events/event_bus.dart';
import 'package:tarot_cards/core/telemetry/analytics.dart';
import 'package:tarot_cards/core/telemetry/analytics_listener.dart';
import 'package:tarot_cards/core/telemetry/remote_flags.dart';
import 'package:tarot_cards/core/telemetry/usage_sharing.dart';

class _Recorder implements Analytics {
  final logged = <(String, Map<String, Object>)>[];

  @override
  Future<void> log(String name, [Map<String, Object> params = const {}]) async => logged.add((name, params));
}

class _Off implements RemoteFlags {
  _Off(this.off);
  final Set<String> off;

  @override
  bool featureEnabled(String featureId) => !off.contains(featureId);

  @override
  int intValue(String key, int fallback) => fallback;
}

class _Other extends AppEvent {
  const _Other();
}

void main() {
  final events = <AppEvent>[
    const ReadingShown(methodId: 'ritual', spreadId: 'three', keyCard: 40, reversed: 1),
    const JournalSaved(hasReminder: true),
    const BreathStarted(cardId: 19, minutes: 3, silent: false, binaural: true),
    const BreathCompleted(cardId: 19, minutes: 3),
    const PaywallShown(source: 'cast_limit'),
    const RewardedAdShown(source: 'cast', earned: true),
    const Subscribed(period: 'yearly'),
    const FirstDraw(spreadId: 'one'),
    const HitFreeLimit(type: 'lesson'),
    const RewardedAdFailed(source: 'cast'),
    const InterstitialShown(),
    const InterstitialFailed(),
    const TrialStarted(period: 'yearly'),
    const Subscribed(period: 'restore'),
  ];

  test('統計事件一律 tr_ 開頭、名稱合規、參數只有字串或數字', () {
    final valid = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
    for (final e in events) {
      final d = AnalyticsListener.describe(e)!;
      expect(d.$1, startsWith('tr_'));
      expect(valid.hasMatch(d.$1), isTrue, reason: d.$1);
      expect(d.$2.length, lessThanOrEqualTo(25));
      for (final entry in d.$2.entries) {
        expect(valid.hasMatch(entry.key), isTrue, reason: entry.key);
        expect(entry.value is String || entry.value is num, isTrue, reason: entry.key);
      }
    }
  });

  test('認不得的事件不送', () {
    expect(AnalyticsListener.describe(const _Other()), isNull);
  });

  test('事件匯流排的事件會轉送到統計', () async {
    final bus = EventBus();
    final rec = _Recorder();
    final listener = AnalyticsListener(bus, rec);
    events.forEach(bus.emit);
    await Future<void>.delayed(Duration.zero);
    expect(rec.logged.map((e) => e.$1), [
      'tr_reading_shown',
      'tr_journal_saved',
      'tr_breath_started',
      'tr_breath_completed',
      'tr_paywall_view',
      'tr_rewarded_ad_shown',
      'tr_purchase',
      'tr_first_draw',
      'tr_hit_free_limit',
      'tr_rewarded_ad_failed',
      'tr_interstitial_shown',
      'tr_interstitial_failed',
      'tr_trial_start',
      'tr_restore',
    ]);
    expect(rec.logged.first.$2, {'method': 'ritual', 'spread': 'three', 'card': 40, 'reversed': 1});
    expect(rec.logged[1].$2, {'has_reminder': 1});
    expect(rec.logged[2].$2, {'card': 19, 'minutes': 3, 'silent': 0, 'binaural': 1});
    expect(rec.logged[3].$2, {'card': 19, 'minutes': 3});
    expect(rec.logged[4].$2, {'source': 'cast_limit'});
    expect(rec.logged[5].$2, {'source': 'cast', 'earned': 1});
    expect(rec.logged[6].$2, {'period': 'yearly'});
    expect(rec.logged[8].$2, {'type': 'lesson'});
    await listener.dispose();
  });

  test('遠端開關：參數名稱 tr_feature_<id>，預設全開，關掉的功能不出現在入口', () {
    expect(featureFlagKey('journal'), 'tr_feature_journal');
    final ids = registeredFeatures.map((f) => f.id).toList();
    expect(activeFeatures(const DefaultRemoteFlags()).map((f) => f.id), ids);
    expect(ids, ['daily', 'draw', 'learn', 'journal', 'breath']);
    expect(activeFeatures(_Off({'journal'})).map((f) => f.id), isNot(contains('journal')));
    expect(activeFeatures(_Off({'journal'})).length, ids.length - 1);
    // Remote Config 參數名稱限制：字母或底線開頭，最多 256 字
    for (final id in ids) {
      expect(RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(featureFlagKey(id)), isTrue, reason: id);
    }
  });

  test('使用統計開關：存檔並通知 Firebase，同值不重複通知', () async {
    final store = MemoryUsageSharingStore();
    final applied = <bool>[];
    final u = UsageSharing(initial: await store.load(), store: store, apply: (v) async => applied.add(v));
    expect(u.enabled.value, isTrue);
    await u.set(false);
    await u.set(false);
    expect(store.value, isFalse);
    expect(applied, [false]);
    await u.set(true);
    expect(applied, [false, true]);
  });
}
