import 'dart:math';

import '../reminders/reminder_service.dart';
import '../settings/json_file.dart';
import '../tarot/draw.dart';
import '../tarot/tarot_card.dart';

/// 今日一張：每天（手機當地日期）抽一次，當天再打開看到的是同一張。不計入每日抽牌次數。
class DailyCardStore {
  DailyCardStore({KeyValueFile? store}) : _store = store ?? FileKeyValue('daily.json');

  final KeyValueFile _store;

  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// 今天已抽的那張；還沒抽時為 null。
  Future<DrawnCard?> today(DateTime now) async {
    final j = await _store.read();
    if (j['day'] != dayKey(now)) return null;
    return DrawnCard.tryFromJson(j['card']);
  }

  /// 今天的那張（還沒抽就抽一張並記下）。
  Future<DrawnCard> drawToday(DateTime now, Random random, {bool reversals = true}) async {
    final have = await today(now);
    if (have != null) return have;
    final j = await _store.read();
    final streak = j['day'] == dayKey(_yesterday(now)) ? _streakOf(j) + 1 : 1;
    final card = DrawnCard(random.nextInt(TarotCard.count), reversed: reversals && random.nextBool());
    await _store.write({'day': dayKey(now), 'card': card.toJson(), 'streak': streak});
    return card;
  }

  /// 連續幾天翻了今日一張（今天或昨天有翻才算數，否則 0）。舊版存檔沒有 streak 時當 1 天。
  Future<int> streak(DateTime now) async {
    final j = await _store.read();
    final day = j['day'];
    if (day != dayKey(now) && day != dayKey(_yesterday(now))) return 0;
    return _streakOf(j);
  }

  static int _streakOf(Map<String, dynamic> j) => (j['streak'] as num?)?.toInt() ?? 1;

  static DateTime _yesterday(DateTime now) => DateTime(now.year, now.month, now.day - 1);
}

/// 每日提醒（預設開啟，每天 08:00）：一次排好接下來 [days] 天（一次性通知，App 每次開啟時補排；不依賴重複排程）。
class DailyReminders {
  DailyReminders._();

  static const payload = 'daily';
  static const baseId = 7700000;
  static const days = 14;

  static Future<bool> apply(
    ReminderService reminders, {
    required bool enabled,
    required int hour,
    required int minute,
    required String title,
    required String body,
    DateTime? now,
    bool skipToday = false,
    bool askPermission = true,
  }) async {
    for (var i = 0; i < days; i++) {
      await reminders.cancel(baseId + i);
    }
    if (!enabled) return true;
    final n = now ?? DateTime.now();
    var ok = true;
    // 當天已經抽過牌：今天的提醒不發，從明天開始排
    for (var i = skipToday ? 1 : 0; i < days; i++) {
      final at = DateTime(n.year, n.month, n.day + i, hour, minute);
      if (!at.isAfter(n)) continue;
      ok = await reminders.schedule(id: baseId + i, at: at, title: title, body: body, payload: payload, askPermission: askPermission) && ok;
      if (!ok) break;
    }
    return ok;
  }
}
