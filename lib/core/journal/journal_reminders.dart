import '../reminders/reminder_service.dart';
import 'journal_entry.dart';

/// 通知標題與內文：由介面層提供（l10n 的 reviewMessage），core 不放介面文字。
typedef ReviewMessage = ({String title, String body}) Function(int cardId, int days);

/// 日記與提醒的接合：回顧時間、payload、排程。
class JournalReminders {
  JournalReminders._();

  /// 回顧提醒固定在晚上八點（一天結束、適合回想的時間）。
  static const reviewHour = 20;
  static const payloadPrefix = 'journal:';

  /// [from] 之後第 [days] 天的晚上八點（本地時間）。
  static DateTime reviewTime(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days, reviewHour);

  static String payloadFor(JournalEntry e) => '$payloadPrefix${e.id}';

  static String? entryIdFrom(String payload) =>
      payload.startsWith(payloadPrefix) ? payload.substring(payloadPrefix.length) : null;

  /// 依 entry.reminderAt 重新排程（先取消舊的）。沒有提醒或時間已過則只取消。
  /// 通知內文不放「想問的事」：鎖定畫面上任何人都看得到。
  static Future<bool> apply(ReminderService reminders, JournalEntry e, ReviewMessage message) async {
    await reminders.cancel(e.notificationId);
    final at = e.reminderAt;
    if (at == null || !at.isAfter(DateTime.now())) return true;
    final days = DateTime(at.year, at.month, at.day)
        .difference(DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .inDays;
    final m = message(e.keyCard.cardId, days);
    return reminders.schedule(
      id: e.notificationId,
      at: at,
      title: m.title,
      body: m.body,
      payload: payloadFor(e),
    );
  }
}
