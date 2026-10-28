import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/content/card_content.dart';
import 'package:tarot_cards/core/monetization/cast_quota.dart';
import 'package:tarot_cards/core/monetization/free_limits.dart';
import 'package:tarot_cards/core/monetization/premium_service.dart';

void main() {
  group('每日抽牌次數（HANDOFF H 第 1 點）', () {
    late DateTime now;
    late MemoryQuotaStorage storage;
    CastQuota quota() => CastQuota(limits: const FreeLimits(), storage: storage, clock: () => now);

    setUp(() {
      now = DateTime(2026, 10, 28, 9);
      storage = MemoryQuotaStorage();
    });

    test('免費 2 次 → 需要獎勵 → 獎勵 2 次後用完（每日上限 4）', () async {
      final q = quota();
      for (var i = 0; i < 2; i++) {
        expect(await q.check(), CastAllowance.free);
        await q.recordCast();
      }
      expect(await q.check(), CastAllowance.needsReward);
      for (var i = 0; i < 2; i++) {
        await q.grantReward();
        expect(await q.check(), CastAllowance.free);
        await q.recordCast(rewarded: true);
      }
      expect(await q.check(), CastAllowance.exhausted);
    });

    test('跨日歸零（本機日期），且計數存檔（重開 App 仍在）', () async {
      final q = quota();
      for (var i = 0; i < 2; i++) {
        await q.recordCast();
      }
      expect(await quota().check(), CastAllowance.needsReward); // 新物件讀存檔
      now = DateTime(2026, 10, 29, 0, 1);
      expect(await quota().check(), CastAllowance.free);
      expect(await quota().freeLeft(), 2);
    });

    test('插頁只在每日第 1 次免費抽牌；獎勵換來的、訂閱戶不播', () async {
      final q = quota();
      final first = await q.recordCast();
      expect(first.dailyIndex, 1);
      expect(first.wantsInterstitial, isTrue);
      expect((await q.recordCast()).wantsInterstitial, isFalse);
      await q.grantReward();
      expect((await q.recordCast(rewarded: true)).wantsInterstitial, isFalse);
      now = DateTime(2026, 10, 29, 8);
      expect((await quota().recordCast()).wantsInterstitial, isTrue); // 隔天第 1 次又播
      expect((await quota().recordCast(premium: true)).wantsInterstitial, isFalse);
    });

    test('第一次抽牌（first_draw）只記一次，跨日、重開都不再出現', () async {
      expect((await quota().recordCast()).firstEver, isTrue);
      expect((await quota().recordCast()).firstEver, isFalse);
      now = DateTime(2026, 11, 1);
      expect((await quota().recordCast()).firstEver, isFalse);
    });

    test('訂閱戶不計次', () async {
      final q = quota();
      for (var i = 0; i < 5; i++) {
        await q.recordCast(premium: true);
      }
      expect(await q.freeLeft(), 2);
    });
  });

  test('遠端數值：tr_ 開頭、預設 2／2；不合理的值退回預設；插頁頻率參數已移除', () {
    for (final k in FreeLimits.remoteDefaults.keys) {
      expect(k, startsWith('tr_'));
    }
    expect(FreeLimits.remoteDefaults['tr_free_casts_per_day'], 2);
    expect(FreeLimits.remoteDefaults['tr_free_rewarded_per_day'], 2);
    expect(FreeLimits.remoteDefaults.keys.where((k) => k.contains('interstitial')), isEmpty);
    final l = FreeLimits.from((k, d) => k == 'tr_free_casts_per_day' ? 0 : (k == 'tr_free_journal_max' ? 20 : d));
    expect(l.castsPerDay, 2); // 0 不合理
    expect(l.rewardedPerDay, 2);
    expect(l.journalMax, 20);
    expect(const FreeLimits().freeBreathMinutes, {1, 2});
  });

  group('課程試讀（HANDOFF H 第 3 點）', () {
    LessonUnit unit(String id, {bool free = false, int lessons = 5}) => LessonUnit.fromJson({
          'id': id,
          'title': id,
          'free': free,
          'lessons': [
            for (var i = 0; i < lessons; i++) {'id': '$id$i', 'title': '$i', 'sections': const []},
          ],
        });

    test('入門單元全免費', () {
      final u = unit('intro', free: true, lessons: 6);
      expect(List.generate(6, u.lessonFree), everyElement(isTrue));
      expect(u.lockedCount, 0);
    });

    test('付費單元只有第 1 課免費試讀，其餘 N 課要訂閱', () {
      final u = unit('majors');
      expect(u.lessonFree(0), isTrue);
      expect(List.generate(4, (i) => u.lessonFree(i + 1)), everyElement(isFalse));
      expect(u.lockedCount, 4);
    });
  });

  group('付費牆價格（HANDOFF H 第 6 點）', () {
    test('年繳每月約多少：沿用商店字串的幣別符號，不寫死幣別', () {
      const twd = SubscriptionPlan(period: PlanPeriod.yearly, price: 'NT\$590.00', amount: 590, currencyCode: 'TWD');
      expect(twd.perMonth('zh_TW'), startsWith('NT\$'));
      expect(twd.perMonth('zh_TW'), contains('49'));
      const usd = SubscriptionPlan(period: PlanPeriod.yearly, price: '\$24.99', amount: 24.99, currencyCode: 'USD');
      expect(usd.perMonth('en'), '\$2.08');
      const eur = SubscriptionPlan(period: PlanPeriod.yearly, price: '24,99 €', amount: 24.99, currencyCode: 'EUR');
      expect(eur.perMonth('es'), endsWith('€'));
      expect(eur.perMonth('es'), contains('2,08'));
    });

    test('月繳、沒有數字價格時不顯示每月約價', () {
      const m = SubscriptionPlan(period: PlanPeriod.monthly, price: '\$3.99', amount: 3.99, currencyCode: 'USD');
      expect(m.perMonth('en'), isNull);
      const y = SubscriptionPlan(period: PlanPeriod.yearly, price: '\$24.99');
      expect(y.perMonth('en'), isNull);
    });

    test('試用', () {
      expect(const SubscriptionPlan(period: PlanPeriod.yearly, price: 'x', trialDays: 7).hasTrial, isTrue);
      expect(const SubscriptionPlan(period: PlanPeriod.yearly, price: 'x').hasTrial, isFalse);
    });
  });
}
