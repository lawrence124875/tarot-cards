import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/monetization/ad_service.dart';
import 'package:tarot_cards/core/monetization/cast_quota.dart';
import 'package:tarot_cards/core/monetization/free_limits.dart';

void main() {
  group('每日抽牌次數（§23.1）', () {
    late DateTime now;
    late MemoryQuotaStorage storage;
    CastQuota quota() => CastQuota(limits: const FreeLimits(), storage: storage, clock: () => now);

    setUp(() {
      now = DateTime(2026, 10, 4, 9);
      storage = MemoryQuotaStorage();
    });

    test('免費 3 次 → 需要獎勵 → 獎勵 3 次後用完', () async {
      final q = quota();
      for (var i = 0; i < 3; i++) {
        expect(await q.check(), CastAllowance.free);
        await q.recordCast();
      }
      expect(await q.check(), CastAllowance.needsReward);
      for (var i = 0; i < 3; i++) {
        await q.grantReward();
        expect(await q.check(), CastAllowance.free);
        await q.recordCast();
      }
      expect(await q.check(), CastAllowance.exhausted);
    });

    test('跨日歸零，且計數存檔（重開 App 仍在）', () async {
      final q = quota();
      for (var i = 0; i < 3; i++) {
        await q.recordCast();
      }
      expect(await quota().check(), CastAllowance.needsReward); // 新物件讀存檔
      now = DateTime(2026, 10, 5, 0, 1);
      expect(await quota().check(), CastAllowance.free);
      expect(await quota().freeLeft(), 3);
    });
  });

  group('插頁限頻', () {
    test('每 3 次解讀一次、且間隔至少 3 分鐘；第一次不跳', () {
      var now = DateTime(2026, 10, 4, 9);
      final p = InterstitialPacer(clock: () => now);
      expect(p.readingClosed(), isFalse);
      expect(p.readingClosed(), isFalse);
      expect(p.readingClosed(), isTrue);
      p.shown();
      now = now.add(const Duration(minutes: 1));
      p.readingClosed();
      p.readingClosed();
      expect(p.readingClosed(), isFalse); // 第 6 次但距上次只 1 分鐘
      now = now.add(const Duration(minutes: 5));
      p.readingClosed();
      p.readingClosed();
      expect(p.readingClosed(), isTrue);
    });

    test('every = 0 表示關閉插頁', () {
      final p = InterstitialPacer(every: 0);
      for (var i = 0; i < 10; i++) {
        expect(p.readingClosed(), isFalse);
      }
    });
  });

  test('遠端數值：tr_ 開頭；不合理的值退回預設', () {
    for (final k in FreeLimits.remoteDefaults.keys) {
      expect(k, startsWith('tr_'));
    }
    final l = FreeLimits.from((k, d) => k == 'tr_free_casts_per_day' ? 0 : (k == 'tr_free_journal_max' ? 20 : d));
    expect(l.castsPerDay, 3); // 0 不合理
    expect(l.journalMax, 20);
  });
}
