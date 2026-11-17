import '../core/daily/daily_card.dart';
import '../core/numerology/numerology.dart';
import '../core/reminders/reminder_service.dart';
import '../features/numerology/numerology_feature.dart';
import '../l10n/l10n.dart';
import 'feature_registry.dart';
import 'services.dart';

/// 依目前設定重排每日提醒；當天已抽過今日一張或起過卦，今天的提醒就不發。
/// 回傳 false 表示排程失敗（原因見 reminders.lastFailure）。
/// [askPermission]：啟動時傳 false（不請求權限，避免當機）；第一次抽牌時才請求。
/// [offOnDenied]：使用者拒絕通知權限時把開關改成關閉（Lawrence 2026-11-09：拒絕要顯示關閉）。
Future<bool> syncDailyReminder(Services s, {DateTime? now, bool offOnDenied = true, bool askPermission = true}) async {
  final n = now ?? DateTime.now();
  final l = L10n.current;
  final drewToday = await s.daily.today(n) != null || await s.quota.castToday();
  final bodyFor = await numdayReminderBody(s);
  final ok = await DailyReminders.apply(
    s.reminders,
    enabled: s.settings.dailyReminder,
    hour: s.settings.dailyHour,
    minute: s.settings.dailyMinute,
    title: l.dailyNotificationTitle,
    body: l.dailyNotificationBody,
    bodyFor: bodyFor,
    now: n,
    skipToday: drewToday,
    askPermission: askPermission,
  );
  if (!ok && offOnDenied && s.reminders.lastFailure?.kind == ReminderFailureKind.permissionDenied) {
    await s.settings.update(dailyReminder: false);
  }
  return ok;
}

/// 有生日時，每天的提醒內文帶當天流日與主題（0.5.1，Lawrence 2026-11-17）：「今天是流日 5：嘗試新鮮。…」。
/// 沒有生日、生命靈數關閉或讀不到內容時回傳 null（維持原提醒文字）。生日只在本機計算。
Future<String? Function(DateTime)?> numdayReminderBody(Services s) async {
  if (!activeFeatures(s.flags).any((f) => f.id == numerologyFeature.id)) return null;
  final birth = await s.birthdays.load();
  if (birth == null) return null;
  final texts = await s.numerology.texts();
  if (texts.isEmpty) return null;
  final l = L10n.current;
  return (at) {
    final day = Numerology.personalDay(birth, at);
    final theme = texts.numbers[day]?.dayTheme ?? '';
    return theme.isEmpty ? null : l.numReminderBody(day, theme);
  };
}
