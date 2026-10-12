import 'dart:math';

import '../settings/json_file.dart';
import '../tarot/tarot_card.dart';

/// 認牌練習（間隔重複，Leitner 盒子法）：答對升一盒、答錯回第一盒；
/// 第 n 盒隔 [intervals][n] 天再出現。只存在手機裡（learn.json）。
class CardQuiz {
  CardQuiz({KeyValueFile? store}) : _store = store ?? FileKeyValue('learn.json');

  /// 第 0–4 盒的間隔天數（第 4 盒＝已熟記，每 30 天複習一次）。
  static const intervals = [0, 1, 3, 7, 30];

  final KeyValueFile _store;
  Map<int, ({int box, DateTime due})>? _state;

  Future<Map<int, ({int box, DateTime due})>> _load() async {
    if (_state != null) return _state!;
    final j = await _store.read();
    final m = <int, ({int box, DateTime due})>{};
    final cards = j['cards'];
    if (cards is Map) {
      for (final e in cards.entries) {
        final id = int.tryParse(e.key.toString());
        final v = e.value;
        if (id == null || v is! Map) continue;
        final due = DateTime.tryParse(v['due']?.toString() ?? '');
        final box = v['box'];
        if (due == null || box is! int) continue;
        m[id] = (box: box.clamp(0, intervals.length - 1), due: due);
      }
    }
    return _state = m;
  }

  Future<void> _save() => _store.write({
        'cards': {
          for (final e in _state!.entries) '${e.key}': {'box': e.value.box, 'due': e.value.due.toIso8601String()},
        },
      });

  /// 這一輪要練的牌：到期的優先，不足 [size] 張時補上還沒練過的（依牌序）。[pool] 限定範圍（例如只練大阿爾克那）。
  Future<List<int>> round(DateTime now, {int size = 10, Iterable<int>? pool, Random? random}) async {
    final s = await _load();
    final ids = (pool ?? [for (var i = 0; i < TarotCard.count; i++) i]).toList();
    final due = [for (final id in ids) if (s[id] != null && !s[id]!.due.isAfter(now)) id]
      ..sort((a, b) => s[a]!.box.compareTo(s[b]!.box));
    final fresh = [for (final id in ids) if (s[id] == null) id];
    final out = [...due.take(size), ...fresh.take(max(0, size - due.length))];
    if (random != null) out.shuffle(random);
    return out;
  }

  Future<void> answer(int cardId, bool correct, DateTime now) async {
    final s = await _load();
    final box = correct ? min((s[cardId]?.box ?? 0) + 1, intervals.length - 1) : 0;
    final day = DateTime(now.year, now.month, now.day);
    s[cardId] = (box: box, due: day.add(Duration(days: intervals[box])));
    await _save();
  }

  /// 已熟記（最後一盒）的張數。
  Future<int> mastered() async => (await _load()).values.where((v) => v.box == intervals.length - 1).length;

  /// 練過的張數。
  Future<int> seen() async => (await _load()).length;
}
