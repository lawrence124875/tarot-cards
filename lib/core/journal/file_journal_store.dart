import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'journal_entry.dart';
import 'journal_store.dart';

/// 塔羅日記存成 App 私有資料夾裡的一個 JSON 檔（只在手機上，不上傳）。
/// 先寫暫存檔再改名，避免寫到一半當掉而毀損。
class FileJournalStore extends JournalStore {
  static const _schemaVersion = 1;

  List<JournalEntry>? _cache;
  Future<void> _writing = Future.value();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/journal.json');
  }

  Future<List<JournalEntry>> _load() async {
    if (_cache != null) return _cache!;
    final list = <JournalEntry>[];
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        for (final e in (data['entries'] as List? ?? const [])) {
          if (e is Map<String, dynamic>) {
            final entry = JournalEntry.tryFromJson(e);
            if (entry != null) list.add(entry);
          }
        }
      }
    } catch (_) {
      // 檔案毀損時不讓 App 壞掉；保留原檔不覆蓋，改從空清單開始。
    }
    return _cache = list;
  }

  Future<void> _persist() {
    final snapshot = [..._cache!];
    _writing = _writing.then((_) async {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'schemaVersion': _schemaVersion,
        'entries': [for (final e in snapshot) e.toJson()],
      }));
      await tmp.rename(f.path);
    });
    return _writing;
  }

  @override
  Future<List<JournalEntry>> all() async =>
      [...await _load()]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> save(JournalEntry entry) async {
    final list = await _load();
    final i = list.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.add(entry);
    }
    notifyListeners();
    await _persist();
  }

  /// 一次寫檔（不逐筆 save）。
  @override
  Future<List<JournalEntry>> addMissing(List<JournalEntry> entries) async {
    final list = await _load();
    final have = {for (final e in list) e.id};
    final added = [for (final e in entries) if (have.add(e.id)) e];
    if (added.isEmpty) return added;
    list.addAll(added);
    notifyListeners();
    await _persist();
    return added;
  }

  @override
  Future<void> delete(String id) async {
    (await _load()).removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }
}
