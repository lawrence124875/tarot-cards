import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tarot/draw.dart';

/// 趨勢五級（不用「凶」字）：大吉 +2、吉 +1、平 0、小阻 -1、阻 -2。
enum TrendLevel {
  block(-2),
  minorBlock(-1),
  neutral(0),
  good(1),
  greatGood(2);

  const TrendLevel(this.score);

  final int score;

  static TrendLevel fromScore(int s) => values.firstWhere((l) => l.score == s.clamp(-2, 2));

  /// 三張牌平均分 → 五級（門檻 ±0.4、±1.2；平均落在 -0.4～0.4 為平）。
  static TrendLevel fromAverage(double avg) {
    if (avg >= 1.2) return greatGood;
    if (avg >= 0.4) return good;
    if (avg > -0.4) return neutral;
    if (avg > -1.2) return minorBlock;
    return block;
  }

  int get sign => score.sign;
}

/// 兩方的關係：共識（同向，或兩方都持平）／部分呼應（一方持平）／分歧（正負相反）。
enum CrossRelation {
  consensus,
  partial,
  divergent;

  static CrossRelation of(TrendLevel tarot, TrendLevel lenormand) {
    if (tarot.sign == lenormand.sign) return consensus;
    if (tarot.sign == 0 || lenormand.sign == 0) return partial;
    return divergent;
  }
}

/// 時間區間：近期／數週內／一季內。
enum CrossTiming { soon, weeks, season }

/// 牌的節奏代碼（scores.json 的 p）。
const _speedValue = {'fast': 0, 'medium': 1, 'slow': 2};

/// 一張牌（塔羅某正逆位、或雷諾曼）在交叉解讀中的分數、主題標籤與節奏。
class CardScore {
  const CardScore({required this.score, this.tags = const [], this.speed = 'medium'});

  factory CardScore.fromJson(Object? j) {
    if (j is! Map) return const CardScore(score: 0);
    final s = j['s'];
    return CardScore(
      score: s is num ? s.toInt().clamp(-2, 2) : 0,
      tags: [for (final t in (j['t'] is List ? j['t'] as List : const [])) t.toString()],
      speed: _speedValue.containsKey(j['p']) ? j['p'] as String : 'medium',
    );
  }

  final int score;
  final List<String> tags;
  final String speed;

  TrendLevel get level => TrendLevel.fromScore(score);
}

/// 全部牌的分數（tarot-content `cross/scores.json`：預設表＋overrides 合併後的結果）。
class CrossScores {
  CrossScores({Map<int, CardScore>? tarotUp, Map<int, CardScore>? tarotRev, Map<int, CardScore>? lenormand})
      : _up = tarotUp ?? const {},
        _rev = tarotRev ?? const {},
        _len = lenormand ?? const {};

  factory CrossScores.fromJson(Map<String, dynamic> j) {
    final up = <int, CardScore>{}, rev = <int, CardScore>{}, len = <int, CardScore>{};
    final t = j['tarot'];
    if (t is Map) {
      for (final e in t.entries) {
        final id = int.tryParse(e.key.toString());
        if (id == null || e.value is! Map) continue;
        up[id] = CardScore.fromJson((e.value as Map)['u']);
        rev[id] = CardScore.fromJson((e.value as Map)['r']);
      }
    }
    final l = j['lenormand'];
    if (l is Map) {
      for (final e in l.entries) {
        final id = int.tryParse(e.key.toString());
        if (id != null) len[id] = CardScore.fromJson(e.value);
      }
    }
    return CrossScores(tarotUp: up, tarotRev: rev, lenormand: len);
  }

  final Map<int, CardScore> _up, _rev, _len;

  bool get isEmpty => _up.isEmpty && _len.isEmpty;

  CardScore tarot(DrawnCard c) => (c.reversed ? _rev : _up)[c.cardId] ?? const CardScore(score: 0);

  CardScore lenormand(int id) => _len[id] ?? const CardScore(score: 0);
}

/// 一次交叉解讀的判斷結果（全部規則，不呼叫 AI）。
class CrossResult {
  const CrossResult({
    required this.tarotLevel,
    required this.lenormandLevel,
    required this.relation,
    required this.overall,
    required this.tags,
    required this.timing,
    required this.tarotAverage,
    required this.lenormandAverage,
  });

  /// 塔羅＝心理面。
  final TrendLevel tarotLevel;

  /// 雷諾曼＝事件面。
  final TrendLevel lenormandLevel;
  final CrossRelation relation;

  /// 綜合趨勢：共識與部分呼應取兩方平均；分歧不強行合成，記為平。
  final TrendLevel overall;

  /// 主題標籤（最多 2 個，兩方共有的優先）。
  final List<String> tags;
  final CrossTiming timing;
  final double tarotAverage, lenormandAverage;
}

/// 交叉判斷：塔羅三張（含正逆位）× 雷諾曼三張。
CrossResult evaluateCross(CrossScores scores, List<DrawnCard> tarot, List<int> lenormand) {
  final t = [for (final c in tarot) scores.tarot(c)];
  final l = [for (final id in lenormand) scores.lenormand(id)];
  double avg(List<CardScore> xs) => xs.isEmpty ? 0 : xs.map((x) => x.score).reduce((a, b) => a + b) / xs.length;
  final ta = avg(t), la = avg(l);
  final tl = TrendLevel.fromAverage(ta), ll = TrendLevel.fromAverage(la);
  final relation = CrossRelation.of(tl, ll);
  final overall = relation == CrossRelation.divergent ? TrendLevel.neutral : TrendLevel.fromAverage((ta + la) / 2);
  return CrossResult(
    tarotLevel: tl,
    lenormandLevel: ll,
    relation: relation,
    overall: overall,
    tags: crossTags(t, l),
    timing: crossTiming(t, l),
    tarotAverage: ta,
    lenormandAverage: la,
  );
}

/// 主題標籤：兩方都出現的標籤優先，再依出現次數（同數依第一次出現的順序），取前 2 個。
List<String> crossTags(List<CardScore> tarot, List<CardScore> lenormand) {
  final count = <String, int>{};
  final order = <String>[];
  for (final c in [...lenormand, ...tarot]) {
    for (final tag in c.tags) {
      if (!count.containsKey(tag)) order.add(tag);
      count[tag] = (count[tag] ?? 0) + 1;
    }
  }
  final tSet = {for (final c in tarot) ...c.tags};
  final lSet = {for (final c in lenormand) ...c.tags};
  int rank(String tag) => (tSet.contains(tag) && lSet.contains(tag) ? 100 : 0) + count[tag]!;
  final sorted = [...order]..sort((a, b) {
      final r = rank(b).compareTo(rank(a));
      return r != 0 ? r : order.indexOf(a).compareTo(order.indexOf(b));
    });
  return sorted.take(2).toList();
}

/// 時間區間：雷諾曼節奏為主（權重 2）、塔羅為輔（權重 1）；快 0、中 1、慢 2。
/// 加權平均 < 0.67 近期、< 1.34 數週內，其餘一季內。
CrossTiming crossTiming(List<CardScore> tarot, List<CardScore> lenormand) {
  double avg(List<CardScore> xs) =>
      xs.isEmpty ? 1 : xs.map((x) => _speedValue[x.speed] ?? 1).reduce((a, b) => a + b) / xs.length;
  final v = (avg(lenormand) * 2 + avg(tarot)) / 3;
  if (v < 0.67) return CrossTiming.soon;
  if (v < 1.34) return CrossTiming.weeks;
  return CrossTiming.season;
}

/// 從 App 資產讀分數表：assets/cross/scores.json（由 CI 從 tarot-content 匯入）。
Future<CrossScores> loadCrossScores({AssetBundle? bundle}) async {
  try {
    final raw = await (bundle ?? rootBundle).loadString('assets/cross/scores.json');
    return CrossScores.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (e) {
    debugPrint('交叉分數表讀取失敗');
    return CrossScores();
  }
}
