import 'dart:convert';

import 'journal_entry.dart';

/// 塔羅日記備份檔：使用者自行匯出、自己選擇存放位置（雲端硬碟、傳給自己…），換手機時再匯入。
/// App 不上傳任何資料；檔案內容與 journal.json 相同格式，另加 format 標記。
class JournalBackup {
  JournalBackup._();

  static const format = 'tarot-journal';
  static const schemaVersion = 1;

  static String encode(List<JournalEntry> entries, DateTime exportedAt) =>
      const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'entries': [for (final e in entries) e.toJson()],
      });

  /// 解析備份檔。也接受 App 私有的 journal.json（沒有 format 標記）。
  /// 不是塔羅日記備份時丟 [FormatException]；個別不合法的紀錄略過。
  static List<JournalEntry> decode(String text) {
    final Object? data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('not json');
    }
    if (data is! Map<String, dynamic>) throw const FormatException('not an object');
    final fmt = data['format'];
    if (fmt != null && fmt != format) throw const FormatException('other format');
    final list = data['entries'];
    if (list is! List) throw const FormatException('no entries');
    return [
      for (final e in list.whereType<Map<String, dynamic>>()) JournalEntry.tryFromJson(e),
    ].whereType<JournalEntry>().toList();
  }

  /// 備份檔檔名：tarot-journal-2026-10-09.json
  static String fileName(DateTime at) =>
      '$format-${at.year}-${_two(at.month)}-${_two(at.day)}.json';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
