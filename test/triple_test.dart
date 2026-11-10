import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/cross/cross_composer.dart';
import 'package:tarot_cards/core/cross/cross_engine.dart';
import 'package:tarot_cards/core/cross/triple_composer.dart';
import 'package:tarot_cards/core/cross/triple_engine.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/runes/runes.dart';
import 'package:tarot_cards/core/tarot/draw.dart';

CardScore _c(int s, [List<String> tags = const []]) => CardScore(score: s, tags: tags);

const _tarot = [DrawnCard(13), DrawnCard(14), DrawnCard(15)];

CrossScores _scores({required int t, required int l, required int r, int rRev = 0}) => CrossScores(
      tarotUp: {13: _c(t), 14: _c(t), 15: _c(t)},
      lenormand: {8: _c(l, ['self']), 9: _c(l, ['love']), 10: _c(l, ['work'])},
      runeUp: {9: _c(r), 1: _c(r)},
      runeRev: {1: _c(rRev)},
    );

void main() {
  group('三方關係', () {
    test('三同向＝強共識；二對一＝多數；各異＝分歧', () {
      const g = TrendLevel.good, n = TrendLevel.neutral, b = TrendLevel.minorBlock;
      expect(TripleRelation.of(g, TrendLevel.greatGood, g), TripleRelation.strong);
      expect(TripleRelation.of(n, n, n), TripleRelation.strong);
      expect(TripleRelation.of(g, g, b), TripleRelation.majority);
      expect(TripleRelation.of(n, b, b), TripleRelation.majority);
      expect(TripleRelation.of(g, n, b), TripleRelation.divergent);
    });

    test('強共識取三方平均', () {
      final r = evaluateTriple(_scores(t: 2, l: 2, r: 1), _tarot, [8, 9, 10], const DrawnRune(9));
      expect(r.relation, TripleRelation.strong);
      expect(r.overall, TrendLevel.greatGood);
      expect(r.minority, isNull);
    });

    test('二對一：找出少數方，綜合取多數兩方平均', () {
      final r = evaluateTriple(_scores(t: 1, l: 1, r: -2), _tarot, [8, 9, 10], const DrawnRune(9));
      expect(r.relation, TripleRelation.majority);
      expect(r.minority, TripleSystem.rune);
      expect(r.overall, TrendLevel.good);
      final r2 = evaluateTriple(_scores(t: -1, l: 1, r: 1), _tarot, [8, 9, 10], const DrawnRune(9));
      expect(r2.minority, TripleSystem.tarot);
      expect(r2.overall, TrendLevel.good);
    });

    test('三方各異：綜合記為平，不強行合成', () {
      final r = evaluateTriple(_scores(t: 2, l: 0, r: -2), _tarot, [8, 9, 10], const DrawnRune(9));
      expect(r.relation, TripleRelation.divergent);
      expect(r.overall, TrendLevel.neutral);
    });

    test('盧恩逆位用逆位分數；scores.json 讀盧恩', () {
      final s = _scores(t: 1, l: 1, r: 1, rRev: -1);
      expect(s.rune(const DrawnRune(1)).score, 1);
      expect(s.rune(const DrawnRune(1, reversed: true)).score, -1);
      expect(s.rune(const DrawnRune(9, reversed: true)).score, 1); // 沒有逆位資料退回正位
      final j = CrossScores.fromJson({
        'runes': {
          '1': {'u': {'s': 1, 't': ['money'], 'p': 'medium'}, 'r': {'s': -1, 't': ['money'], 'p': 'medium'}},
          '9': {'u': {'s': -2, 't': ['self'], 'p': 'fast'}},
        },
      });
      expect(j.rune(const DrawnRune(1, reversed: true)).level, TrendLevel.minorBlock);
      expect(j.rune(const DrawnRune(9)).level, TrendLevel.block);
      expect(j.rune(const DrawnRune(5)).score, 0);
    });
  });

  group('組合拳矩陣', () {
    final tpl = TripleTemplates.fromJson({
      'relationNames': {'majority': '多數共識'},
      'format': {'minorityLead': '少數方提醒：', 'reversedNote': '逆位', 'core': '核心行動', 'poem': '符文詩', 'reminder': '核心提醒'},
      'level1': {'majority_1': ['L1{tarot}{len}{rune}']},
      'minority': {'rune_neg': 'M{rune}'},
      'level2': {'major_love': 'L2{tarot}{len}'},
      'level3': {'hagal_majority': 'L3{rune}'},
      'level4': {'t16+r9': 'X{t}{r}', 't13+l8+r9': 'C{t}{l}{r}', 't13+r9': 'Y'},
      'reflection': {'majority': ['R']},
    });
    final base = CrossTemplates.fromJson({
      'format': {'name': '〈{name}〉', 'coreTiming': 'T{timing}'},
      'timing': {'weeks': '數週內'},
      'levels': {'1': '吉'},
    });

    test('組別與強組合（元素多者優先）', () {
      expect(TripleTemplates.tarotGroup(0), 'major');
      expect(TripleTemplates.tarotGroup(22), 'wands');
      expect(TripleTemplates.tarotGroup(77), 'pentacles');
      expect(tpl.combo([13, 1, 2], [8, 3, 4], 9)?.$1, 't13+l8+r9');
      expect(tpl.combo([13, 1, 2], [3, 4, 5], 9)?.$1, 't13+r9');
      expect(tpl.combo([1, 2, 3], [3, 4, 5], 9), isNull);
    });

    test('拼出核心指引：層1＋少數提醒＋層2＋層4＋時間；盧恩段落與核心行動', () {
      final r = evaluateTriple(_scores(t: 1, l: 1, r: -2), _tarot, [8, 9, 10], const DrawnRune(9));
      const cards = TripleCards(
        cross: CrossCards(
          tarot: [
            CrossTarotCard(name: '死神', reversed: false, score: 1),
            CrossTarotCard(name: '節制', reversed: false, score: 1),
            CrossTarotCard(name: '惡魔', reversed: false, score: 1),
          ],
          lenormand: [
            CrossLenormandCard(name: '棺木', score: 1),
            CrossLenormandCard(name: '花束', score: 1),
            CrossLenormandCard(name: '鐮刀', score: 1),
          ],
        ),
        tarotIds: [13, 14, 15],
        lenormandIds: [8, 9, 10],
        lenormandTags: [['love'], ['love'], ['work']],
        rune: TripleRuneCard(id: 9, name: '冰雹', reversed: false, aett: 'hagal', advice: 'A', poem: 'P', reminder: 'RM'),
      );
      final rep = tpl.compose(r, 0, base: base, cards: cards);
      expect(rep.relationName, '多數共識');
      expect(rep.overall, '吉');
      expect(rep.reflection, 'R');
      final d = rep.detail!;
      expect(d.core, startsWith('L1〈節制〉〈棺木〉〈冰雹〉M〈冰雹〉L2〈節制〉〈棺木〉C〈死神〉〈棺木〉〈冰雹〉'));
      expect(d.aettText, 'L3〈冰雹〉');
      expect(d.coreAction, 'A');
      expect(d.reminder, 'RM');
      expect(d.runeReversedNote, '');
      expect(tpl.compose(r, 0, base: base).detail, isNull);
    });
  });

  test('紀錄：三系統存盧恩一顆，類型為 triple，雙系統不受影響', () {
    final e = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'three', methodId: 'quick', cards: const [DrawnCard(1), DrawnCard(2), DrawnCard(3)]),
      now: DateTime(2026, 11, 10),
      question: 'q',
      lenormand: [1, 21, 36],
      runes: [-5],
    );
    expect(e.kind, JournalKind.triple);
    final back = JournalEntry.tryFromJson(e.toJson())!;
    expect(back.isTriple, isTrue);
    expect(back.isCross, isFalse);
    expect(back.runes, [-5]);
    final twoRunes = Map<String, dynamic>.from(e.toJson())..['runes'] = [1, 2];
    expect(JournalEntry.tryFromJson(twoRunes)!.kind, JournalKind.cross);
  });
}
