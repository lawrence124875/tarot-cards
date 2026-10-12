import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/daily/daily_card.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/core/settings/json_file.dart';
import 'package:tarot_cards/core/tarot/draw.dart';

class _RecordingReminders extends NoopReminderService {
  final scheduled = <(int, DateTime)>[];
  final cancelled = <int>[];

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled.add((id, at));
    return true;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  group('今日一張', () {
    test('還沒抽時為 null；抽了之後當天都是同一張', () async {
      final store = MemoryKeyValue();
      final daily = DailyCardStore(store: store);
      final morning = DateTime(2026, 10, 12, 7);
      expect(await daily.today(morning), isNull);

      final card = await daily.drawToday(morning, Random(1));
      expect(card.cardId, inInclusiveRange(0, 77));
      expect(await daily.today(DateTime(2026, 10, 12, 23, 59)), card);
      // 換不同的亂數也一樣，且存檔後新物件讀得到
      expect(await DailyCardStore(store: store).drawToday(DateTime(2026, 10, 12, 22), Random(999)), card);
      expect(store.data['day'], DailyCardStore.dayKey(morning));
    });

    test('隔天換一張新的', () async {
      final store = MemoryKeyValue();
      final daily = DailyCardStore(store: store);
      await daily.drawToday(DateTime(2026, 10, 12, 9), Random(1));
      final tomorrow = DateTime(2026, 10, 13, 0, 1);
      expect(await daily.today(tomorrow), isNull);
      final next = await daily.drawToday(tomorrow, Random(2));
      expect(await daily.today(tomorrow), next);
      expect(store.data['day'], '2026-10-13');
      // 新的那張與 Random(2) 抽出的一致
      final r = Random(2);
      expect(next, DrawnCard(r.nextInt(78), reversed: r.nextBool()));
    });

    test('關閉逆位時一律正位', () async {
      for (var seed = 0; seed < 20; seed++) {
        final c = await DailyCardStore(store: MemoryKeyValue()).drawToday(DateTime(2026, 10, 12), Random(seed), reversals: false);
        expect(c.reversed, isFalse);
      }
    });

    test('存檔內容壞掉：當作還沒抽', () async {
      final daily = DailyCardStore(store: MemoryKeyValue({'day': '2026-10-12', 'card': {'id': 99}}));
      expect(await daily.today(DateTime(2026, 10, 12)), isNull);
      expect((await daily.drawToday(DateTime(2026, 10, 12), Random(1))).cardId, lessThan(78));
    });
  });

  group('每日提醒', () {
    test('一次排好 14 天，已過的時間略過；關閉時只取消', () async {
      final r = _RecordingReminders();
      final ok = await DailyReminders.apply(r,
          enabled: true, hour: 8, minute: 30, title: 't', body: 'b', now: DateTime(2026, 10, 12, 9));
      expect(ok, isTrue);
      expect(r.cancelled, List.generate(14, (i) => DailyReminders.baseId + i));
      expect(r.scheduled, hasLength(13)); // 今天 8:30 已過
      expect(r.scheduled.first, (DailyReminders.baseId + 1, DateTime(2026, 10, 13, 8, 30)));
      expect(r.scheduled.last.$2, DateTime(2026, 10, 25, 8, 30));

      final off = _RecordingReminders();
      await DailyReminders.apply(off, enabled: false, hour: 8, minute: 0, title: 't', body: 'b');
      expect(off.scheduled, isEmpty);
      expect(off.cancelled, hasLength(14));
    });

    test('沒有權限時回傳 false', () async {
      final ok = await DailyReminders.apply(NoopReminderService(),
          enabled: true, hour: 23, minute: 0, title: 't', body: 'b', now: DateTime(2026, 10, 12, 9));
      expect(ok, isFalse);
    });
  });
}
