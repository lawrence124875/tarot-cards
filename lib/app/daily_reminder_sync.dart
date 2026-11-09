import '../core/daily/daily_card.dart';
import '../l10n/l10n.dart';
import 'services.dart';

/// 依目前設定重排每日提醒；當天已抽過今日一張或起過卦，今天的提醒就不發。
/// 回傳 false 表示排程失敗（原因見 reminders.lastFailure）。
Future<bool> syncDailyReminder(Services s, {DateTime? now}) async {
  final n = now ?? DateTime.now();
  final l = L10n.current;
  final drewToday = await s.daily.today(n) != null || await s.quota.castToday();
  return DailyReminders.apply(
    s.reminders,
    enabled: s.settings.dailyReminder,
    hour: s.settings.dailyHour,
    minute: s.settings.dailyMinute,
    title: l.dailyNotificationTitle,
    body: l.dailyNotificationBody,
    now: n,
    skipToday: drewToday,
  );
}
