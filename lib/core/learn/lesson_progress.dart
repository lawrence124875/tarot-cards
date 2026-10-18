import '../settings/json_file.dart';

/// 課程進度：讀完的課以「單元id/課id」記錄。只存在手機裡（lesson_progress.json）。
class LessonProgress {
  LessonProgress({KeyValueFile? store}) : _store = store ?? FileKeyValue('lesson_progress.json');

  final KeyValueFile _store;
  Set<String>? _done;

  static String _key(String unitId, String lessonId) => '$unitId/$lessonId';

  Future<Set<String>> _load() async {
    if (_done != null) return _done!;
    final j = await _store.read();
    final list = j['done'];
    return _done = {if (list is List) for (final e in list) e.toString()};
  }

  Future<bool> isDone(String unitId, String lessonId) async => (await _load()).contains(_key(unitId, lessonId));

  /// 這個單元讀完幾課（只算 [lessonIds] 裡還存在的課）。
  Future<int> doneIn(String unitId, Iterable<String> lessonIds) async {
    final d = await _load();
    return lessonIds.where((id) => d.contains(_key(unitId, id))).length;
  }

  Future<void> markDone(String unitId, String lessonId) async {
    final d = await _load();
    if (!d.add(_key(unitId, lessonId))) return;
    await _store.write({'done': d.toList()..sort()});
  }
}
