import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/cross/cross_composer.dart';
import 'package:tarot_cards/core/cross/cross_engine.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/tarot/draw.dart';

CardScore _c(int s, [List<String> tags = const [], String p = 'medium']) => CardScore(score: s, tags: tags, speed: p);

void main() {
  group('五級映射', () {
    test('單張分數 → 五級，超出範圍夾到 ±2', () {
      expect(TrendLevel.fromScore(2), TrendLevel.greatGood);
      expect(TrendLevel.fromScore(1), TrendLevel.good);
      expect(TrendLevel.fromScore(0), TrendLevel.neutral);
      expect(TrendLevel.fromScore(-1), TrendLevel.minorBlock);
      expect(TrendLevel.fromScore(-2), TrendLevel.block);
      expect(TrendLevel.fromScore(5), TrendLevel.greatGood);
      expect(TrendLevel.fromScore(-9), TrendLevel.block);
    });

    test('平均分門檻：±0.4、±1.2 的邊界', () {
      expect(TrendLevel.fromAverage(1.2), TrendLevel.greatGood);
      expect(TrendLevel.fromAverage(1.19), TrendLevel.good);
      expect(TrendLevel.fromAverage(0.4), TrendLevel.good);
      expect(TrendLevel.fromAverage(0.39), TrendLevel.neutral);
      expect(TrendLevel.fromAverage(-0.39), TrendLevel.neutral);
      expect(TrendLevel.fromAverage(-0.4), TrendLevel.minorBlock);
      expect(TrendLevel.fromAverage(-1.19), TrendLevel.minorBlock);
      expect(TrendLevel.fromAverage(-1.2), TrendLevel.block);
    });

    test('scores.json：塔羅正逆位分開、雷諾曼一張一筆；缺的牌當作平', () {
      final s = CrossScores.fromJson({
        'tarot': {
          '19': {
            'u': {'s': 2, 't': ['self'], 'p': 'medium'},
            'r': {'s': 0, 't': ['self'], 'p': 'medium'},
          },
        },
        'lenormand': {
          '21': {'s': -2, 't': ['work'], 'p': 'slow'},
        },
      });
      expect(s.tarot(const DrawnCard(19)).level, TrendLevel.greatGood);
      expect(s.tarot(const DrawnCard(19, reversed: true)).level, TrendLevel.neutral);
      expect(s.lenormand(21).level, TrendLevel.block);
      expect(s.lenormand(21).speed, 'slow');
      expect(s.tarot(const DrawnCard(5)).score, 0);
      expect(s.lenormand(1).score, 0);
      expect(CrossScores.fromJson({}).isEmpty, isTrue);
    });
  });

  group('共識／部分呼應／分歧', () {
    test('同向＝共識；兩方都平也是共識', () {
      expect(CrossRelation.of(TrendLevel.good, TrendLevel.greatGood), CrossRelation.consensus);
      expect(CrossRelation.of(TrendLevel.block, TrendLevel.minorBlock), CrossRelation.consensus);
      expect(CrossRelation.of(TrendLevel.neutral, TrendLevel.neutral), CrossRelation.consensus);
    });

    test('一方持平＝部分呼應', () {
      expect(CrossRelation.of(TrendLevel.neutral, TrendLevel.good), CrossRelation.partial);
      expect(CrossRelation.of(TrendLevel.minorBlock, TrendLevel.neutral), CrossRelation.partial);
    });

    test('正負相反＝分歧', () {
      expect(CrossRelation.of(TrendLevel.good, TrendLevel.minorBlock), CrossRelation.divergent);
      expect(CrossRelation.of(TrendLevel.block, TrendLevel.greatGood), CrossRelation.divergent);
    });

    test('整體判斷：分歧時綜合記為平，不強行合成', () {
      final s = CrossScores(
        tarotUp: {0: _c(2), 1: _c(2), 2: _c(1)},
        tarotRev: {0: _c(0)},
        lenormand: {1: _c(-2), 2: _c(-1), 3: _c(-1), 4: _c(2), 5: _c(1), 6: _c(0)},
      );
      final div = evaluateCross(s, const [DrawnCard(0), DrawnCard(1), DrawnCard(2)], [1, 2, 3]);
      expect(div.tarotLevel, TrendLevel.greatGood);
      expect(div.lenormandLevel, TrendLevel.block);
      expect(div.relation, CrossRelation.divergent);
      expect(div.overall, TrendLevel.neutral);

      final con = evaluateCross(s, const [DrawnCard(0), DrawnCard(1), DrawnCard(2)], [4, 5, 6]);
      expect(con.relation, CrossRelation.consensus);
      expect(con.overall, TrendLevel.greatGood); // (1.67 + 1) / 2 = 1.33 ≥ 1.2
    });
  });

  test('主題標籤：兩方共有優先，最多 2 個', () {
    final tags = crossTags(
      [_c(0, ['self']), _c(0, ['love', 'social']), _c(0, ['self'])],
      [_c(0, ['work']), _c(0, ['love']), _c(0, ['work', 'money'])],
    );
    expect(tags.first, 'love');
    expect(tags.length, 2);
    expect(tags, contains('work')); // work 2 次、self 2 次，雷諾曼的先出現
  });

  test('時間區間：雷諾曼為主、塔羅為輔', () {
    final fast = [_c(0, [], 'fast'), _c(0, [], 'fast'), _c(0, [], 'fast')];
    final slow = [_c(0, [], 'slow'), _c(0, [], 'slow'), _c(0, [], 'slow')];
    final mid = [_c(0), _c(0), _c(0)];
    expect(crossTiming(slow, fast), CrossTiming.soon); // (0×2 + 2) / 3 ≈ 0.667 < 0.67
    expect(crossTiming(fast, fast), CrossTiming.soon);
    expect(crossTiming(mid, mid), CrossTiming.weeks);
    expect(crossTiming(fast, slow), CrossTiming.weeks); // (2×2 + 0) / 3 ≈ 1.33 < 1.34
    expect(crossTiming(slow, slow), CrossTiming.season);
  });

  test('模板拼接：關係、方向、主題前綴、同一組牌文字固定', () {
    final tpl = CrossTemplates.fromJson({
      'levels': {'2': '大吉', '0': '平', '-1': '小阻'},
      'tags': {'love': '感情'},
      'timing': {'weeks': '數週內'},
      'relationNames': {'divergent': '分歧', 'partial': '部分呼應'},
      'tarot': {'2': ['T2']},
      'lenormand': {'-1': ['L-1'], '0': ['L0']},
      'relation': {
        'divergent_tarotpos': ['D+'],
        'partial_lenflat_pos': ['P'],
      },
      'actionPrefix': '在「{tag}」這件事上，',
      'action': {'div': ['A1'], 'pos': ['B1', 'B2']},
      'reflection': {'divergent': ['R1', 'R2']},
    });
    const div = CrossResult(
      tarotLevel: TrendLevel.greatGood,
      lenormandLevel: TrendLevel.minorBlock,
      relation: CrossRelation.divergent,
      overall: TrendLevel.neutral,
      tags: ['love'],
      timing: CrossTiming.weeks,
      tarotAverage: 1.5,
      lenormandAverage: -1,
    );
    final r = tpl.compose(div, 5);
    expect(r.relationName, '分歧');
    expect(r.tarotText, 'T2');
    expect(r.lenormandText, 'L-1');
    expect(r.relationText, 'D+');
    expect(r.action, '在「感情」這件事上，A1');
    expect(r.tags, ['感情']);
    expect(r.timing, '數週內');
    expect(tpl.compose(div, 5).reflection, r.reflection);
    const partial = CrossResult(
      tarotLevel: TrendLevel.greatGood,
      lenormandLevel: TrendLevel.neutral,
      relation: CrossRelation.partial,
      overall: TrendLevel.good,
      tags: [],
      timing: CrossTiming.soon,
      tarotAverage: 1.5,
      lenormandAverage: 0,
    );
    final p = tpl.compose(partial, 1);
    expect(p.relationText, 'P');
    expect(p.action, 'B2'); // 沒有主題時不加前綴；seed 1 → 第 2 個版本
    expect(crossSeed([1, 2, 3], [4, 5, 6]), crossSeed([1, 2, 3], [4, 5, 6]));
    expect(crossSeed([1, 2, 3], [4, 5, 6]), isNot(crossSeed([1, 2, 3], [4, 5, 7])));
  });

  test('紀錄：交叉解讀存雷諾曼牌與應驗選項，舊紀錄不受影響', () {
    final e = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'three', methodId: 'quick', cards: const [DrawnCard(1), DrawnCard(2, reversed: true), DrawnCard(3)]),
      now: DateTime(2026, 11, 4),
      question: 'q',
      lenormand: [1, 21, 36],
    ).copyWith(verdict: 'partial');
    final back = JournalEntry.tryFromJson(e.toJson())!;
    expect(back.isCross, isTrue);
    expect(back.lenormand, [1, 21, 36]);
    expect(back.verdict, 'partial');
    final old = Map<String, dynamic>.from(e.toJson())..remove('lenormand')..remove('verdict');
    final plain = JournalEntry.tryFromJson(old)!;
    expect(plain.isCross, isFalse);
    expect(plain.verdict, '');
    final bad = Map<String, dynamic>.from(e.toJson())..['verdict'] = 'maybe'..['lenormand'] = [0, 40, 5];
    final cleaned = JournalEntry.tryFromJson(bad)!;
    expect(cleaned.verdict, '');
    expect(cleaned.lenormand, [5]);
  });

  test('紀錄：雷諾曼單獨存檔，類型標示正確', () {
    final e = JournalEntry.fromLenormand(spreadId: 'len_three', cards: [4, 31, 35], now: DateTime(2026, 11, 5), question: 'q');
    expect(e.kind, JournalKind.lenormand);
    expect(e.keyLenormand, 31);
    final back = JournalEntry.tryFromJson(e.toJson())!;
    expect(back.isLenormand, isTrue);
    expect(back.isCross, isFalse);
    expect(back.lenormand, [4, 31, 35]);
    expect(back.spreadId, 'len_three');
    final wrong = Map<String, dynamic>.from(e.toJson())..['spread'] = 'len_one';
    expect(JournalEntry.tryFromJson(wrong), isNull);
    final none = Map<String, dynamic>.from(e.toJson())..remove('lenormand');
    expect(JournalEntry.tryFromJson(none), isNull);
    final tarot = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'one', methodId: 'quick', cards: const [DrawnCard(1)]),
      now: DateTime(2026, 11, 5),
    );
    expect(tarot.kind, JournalKind.tarot);
  });
}
