import '../core/daily/daily_card.dart';
import '../core/reminders/reminder_service.dart';
import '../l10n/l10n.dart';
import 'services.dart';

/// 依目前設定重排每日提醒；當天已抽過今日一張或起過卦，今天的提醒就不發。
/// 回傳 false 表示排程失敗（原因見 reminders.lastFailure）。
/// [askPermission]：啟動時傳 false（不請求權限，避免當機）；第一次抽牌時才請求。
/// [offOnDenied]：使用者拒絕通知權限時把開關改成關閉（Lawrence 2026-11-09：拒絕要顯示關閉）。
Future<bool> syncDailyReminder(Services s, {DateTime? now, bool offOnDenied = true, bool askPermission = true}) async {
  final n = now ?? DateTime.now();
  final l = L10n.current;
  final drewToday = await s.daily.today(n) != null || await s.quota.castToday();
  final ok = await DailyReminders.apply(
    s.reminders,
    enabled: s.settings.dailyReminder,
    hour: s.settings.dailyHour,
    minute: s.settings.dailyMinute,
    title: l.dailyNotificationTitle,
    body: l.dailyNotificationBody,
    now: n,
    skipToday: drewToday,
    askPermission: askPermission,
  );
  if (!ok && offOnDenied && s.reminders.lastFailure?.kind == ReminderFailureKind.permissionDenied) {
    await s.settings.update(dailyReminder: false);
  }
  return ok;
}
