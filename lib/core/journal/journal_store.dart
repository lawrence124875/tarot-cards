import 'package:flutter/foundation.dart';

import 'journal_entry.dart';

/// 塔羅日記的儲存介面（依賴反轉：畫面只認這個介面，換儲存方式不改畫面）。
/// 有變動時 notifyListeners，列表頁據此更新。
abstract class JournalStore extends ChangeNotifier {
  /// 由新到舊。
  Future<List<JournalEntry>> all();

  Future<JournalEntry?> byId(String id) async {
    for (final e in await all()) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 新增或更新（以 id 判斷）。
  Future<void> save(JournalEntry entry);

  Future<void> delete(String id);

  /// 匯入備份：只加入這支手機上還沒有的（以 id 判斷），已有的不覆蓋。回傳實際加入的那些。
  /// 不受免費版則數上限限制（已存的日記一律保留，§23.1）。
  Future<List<JournalEntry>> addMissing(List<JournalEntry> entries) async {
    final have = {for (final e in await all()) e.id};
    final added = <JournalEntry>[];
    for (final e in entries) {
      if (have.add(e.id)) added.add(e);
    }
    for (final e in added) {
      await save(e);
    }
    return added;
  }
}

/// 只存在記憶體中（測試用）。
class MemoryJournalStore extends JournalStore {
  final List<JournalEntry> _entries = [];

  @override
  Future<List<JournalEntry>> all() async =>
      [..._entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> save(JournalEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.add(entry);
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
