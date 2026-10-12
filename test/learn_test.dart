import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/learn/card_quiz.dart';
import 'package:tarot_cards/core/settings/json_file.dart';

/// 認牌練習（Leitner 盒子法）。
void main() {
  final now = DateTime(2026, 10, 12, 21, 30);
  DateTime day(int offset) => DateTime(2026, 10, 12 + offset);

  test('沒練過：依牌序取前 10 張；可指定張數與範圍', () async {
    final q = CardQuiz(store: MemoryKeyValue());
    expect(await q.round(now), List.generate(10, (i) => i));
    expect(await q.round(now, size: 3), [0, 1, 2]);
    expect(await q.round(now, size: 5, pool: [50, 51, 52]), [50, 51, 52]);
    expect(await q.seen(), 0);
    expect(await q.mastered(), 0);
  });

  test('答對升一盒、隔對應天數再出現；答錯回第一盒、今天再練', () async {
    final store = MemoryKeyValue();
    final q = CardQuiz(store: store);
    await q.answer(0, true, now);
    expect(store.data['cards']['0'], {'box': 1, 'due': day(1).toIso8601String()});
    // 今天不再出現，由下一張還沒練過的補上
    expect(await q.round(now), List.generate(10, (i) => i + 1));
    // 明天到期，排在最前面
    expect((await q.round(day(1))).first, 0);

    await q.answer(0, true, day(1));
    expect(store.data['cards']['0'], {'box': 2, 'due': day(1 + 3).toIso8601String()});
    await q.answer(0, false, day(4));
    expect(store.data['cards']['0'], {'box': 0, 'due': day(4).toIso8601String()});
    expect((await q.round(day(4))).first, 0);
  });

  test('盒子間隔 0／1／3／7／30 天，最後一盒為已熟記', () async {
    final store = MemoryKeyValue();
    final q = CardQuiz(store: store);
    expect(CardQuiz.intervals, [0, 1, 3, 7, 30]);
    var t = now;
    for (var box = 1; box <= 4; box++) {
      await q.answer(5, true, t);
      final due = DateTime.parse(store.data['cards']['5']['due'] as String);
      expect(store.data['cards']['5']['box'], box);
      expect(due, DateTime(t.year, t.month, t.day + CardQuiz.intervals[box]));
      t = due;
    }
    // 已在最後一盒，答對仍留在最後一盒
    await q.answer(5, true, t);
    expect(store.data['cards']['5']['box'], 4);
    expect(await q.mastered(), 1);
    expect(await q.seen(), 1);
  });

  test('到期的牌依盒子由低到高排在前面，數量不超過一輪', () async {
    final q = CardQuiz(store: MemoryKeyValue());
    await q.answer(10, true, now); // 盒 1
    await q.answer(10, true, day(1)); // 盒 2（3 天後到期）
    await q.answer(20, false, now); // 盒 0
    await q.answer(30, true, now); // 盒 1
    final r = await q.round(day(10), size: 4);
    expect(r.take(3), [20, 30, 10]);
    expect(r, hasLength(4));
    expect(r.last, 0); // 補上第一張還沒練過的
    expect(await q.round(day(10), size: 2), [20, 30]);
  });

  test('進度存檔：新物件讀得到；壞掉的資料略過', () async {
    final store = MemoryKeyValue();
    await CardQuiz(store: store).answer(3, true, now);
    final again = CardQuiz(store: store);
    expect(await again.seen(), 1);
    expect((await again.round(now)).contains(3), isFalse);

    final broken = CardQuiz(
      store: MemoryKeyValue({
        'cards': {
          '1': {'box': 9, 'due': day(0).toIso8601String()}, // 盒號超出範圍：夾到最後一盒
          'x': {'box': 1, 'due': day(0).toIso8601String()},
          '2': {'box': '1', 'due': day(0).toIso8601String()},
          '3': {'box': 1, 'due': 'nope'},
          '4': 'bad',
        },
      }),
    );
    expect(await broken.seen(), 1);
    expect(await broken.mastered(), 1);
  });

  test('打亂順序不改變這一輪的牌', () async {
    final q = CardQuiz(store: MemoryKeyValue());
    final r = await q.round(now, random: Random(1));
    expect(r.toSet(), Set.of(List.generate(10, (i) => i)));
  });
}
