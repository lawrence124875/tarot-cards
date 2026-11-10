import '../runes/runes.dart';
import '../tarot/draw.dart';
import 'cross_engine.dart';

/// 三系統（塔羅 × 雷諾曼 × 盧恩）的關係：
/// 強共識＝三方同向；多數共識＝二對一（多數方向＋少數提醒）；三方分歧＝三方各異（各自說明，不合成）。
enum TripleRelation {
  strong,
  majority,
  divergent;

  static TripleRelation of(TrendLevel tarot, TrendLevel lenormand, TrendLevel rune) {
    final signs = {tarot.sign, lenormand.sign, rune.sign};
    return switch (signs.length) { 1 => strong, 2 => majority, _ => divergent };
  }
}

/// 三系統中的一方。
enum TripleSystem { tarot, lenormand, rune }

/// 一次三系統交叉的判斷結果（全部規則，不呼叫 AI）。
class TripleResult {
  const TripleResult({
    required this.cross,
    required this.runeLevel,
    required this.relation,
    required this.overall,
    this.minority,
  });

  /// 塔羅 × 雷諾曼部分（沿用雙系統：五級、主題、時間區間）。
  final CrossResult cross;

  /// 盧恩＝核心能量（一顆，逆位分數已下修）。
  final TrendLevel runeLevel;
  final TripleRelation relation;

  /// 綜合趨勢：強共識取三方平均；多數共識取多數兩方平均；三方分歧記為平。
  final TrendLevel overall;

  /// 多數共識時方向不同的那一方；其他情況為 null。
  final TripleSystem? minority;

  TrendLevel get tarotLevel => cross.tarotLevel;
  TrendLevel get lenormandLevel => cross.lenormandLevel;

  TrendLevel levelOf(TripleSystem s) => switch (s) {
        TripleSystem.tarot => tarotLevel,
        TripleSystem.lenormand => lenormandLevel,
        TripleSystem.rune => runeLevel,
      };
}

/// 三系統判斷：塔羅三張（含正逆位）× 雷諾曼三張 × 盧恩一顆（核心之石）。
TripleResult evaluateTriple(CrossScores scores, List<DrawnCard> tarot, List<int> lenormand, DrawnRune rune) {
  final cross = evaluateCross(scores, tarot, lenormand);
  final ra = scores.rune(rune).score.toDouble();
  final rl = TrendLevel.fromScore(scores.rune(rune).score);
  final relation = TripleRelation.of(cross.tarotLevel, cross.lenormandLevel, rl);
  final avgs = {
    TripleSystem.tarot: cross.tarotAverage,
    TripleSystem.lenormand: cross.lenormandAverage,
    TripleSystem.rune: ra,
  };
  final levels = {TripleSystem.tarot: cross.tarotLevel, TripleSystem.lenormand: cross.lenormandLevel, TripleSystem.rune: rl};
  TripleSystem? minority;
  TrendLevel overall;
  switch (relation) {
    case TripleRelation.strong:
      overall = TrendLevel.fromAverage(avgs.values.reduce((a, b) => a + b) / 3);
    case TripleRelation.majority:
      // 少數方：符號只出現一次的那一方。
      minority = TripleSystem.values.firstWhere(
          (s) => TripleSystem.values.where((o) => levels[o]!.sign == levels[s]!.sign).length == 1);
      final rest = [for (final s in TripleSystem.values) if (s != minority) avgs[s]!];
      overall = TrendLevel.fromAverage((rest[0] + rest[1]) / 2);
    case TripleRelation.divergent:
      overall = TrendLevel.neutral;
  }
  return TripleResult(cross: cross, runeLevel: rl, relation: relation, overall: overall, minority: minority);
}
