/// 意見回饋類別。寫進資料庫的永遠是代碼（bug／suggestion／other），與英文 App 相同，方便在後台篩選。
enum FeedbackCategory { bug, suggestion, other }

/// 一則使用者意見回饋。
class FeedbackEntry {
  const FeedbackEntry({required this.message, required this.category, this.contactEmail, this.locale});

  /// 內容（畫面限制 [maxMessageLength] 字）。
  final String message;
  final FeedbackCategory category;

  /// 選填；使用者想收到回覆才留。
  final String? contactEmail;

  /// 送出當時的 App 介面語言（例如 zh-Hant），判斷該用哪種語言回覆。
  final String? locale;

  static const maxMessageLength = 2000;
  static const maxEmailLength = 200;
}

/// 送出意見回饋。Firebase 實作只在 lib/core/firebase/firebase_feedback.dart（HANDOFF §18）。
abstract class FeedbackSender {
  /// 失敗時拋出例外；畫面顯示「送出失敗」。
  Future<void> send(FeedbackEntry entry);
}

/// 測試用：記在記憶體。
class MemoryFeedbackSender implements FeedbackSender {
  final sent = <FeedbackEntry>[];

  @override
  Future<void> send(FeedbackEntry entry) async => sent.add(entry);
}
