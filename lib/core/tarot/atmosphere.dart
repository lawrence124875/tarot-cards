import 'draw.dart';
import 'spread.dart';
import 'tarot_card.dart';

/// 人物面向（依牌面畫法，由 deck.json 提供；逆位時左右互換）。
enum Facing { left, right, front, none }

/// 元素互動（黃金黎明 Book T 的元素尊貴）：同元素加強；火風、水土相助；火水、風土相剋；其餘中性。
enum Dignity { same, friendly, contrary, neutral }

Dignity dignityOf(TarotElement a, TarotElement b) {
  if (a == b) return Dignity.same;
  bool pair(TarotElement x, TarotElement y) => (a == x && b == y) || (a == y && b == x);
  if (pair(TarotElement.fire, TarotElement.air) || pair(TarotElement.water, TarotElement.earth)) {
    return Dignity.friendly;
  }
  if (pair(TarotElement.fire, TarotElement.water) || pair(TarotElement.air, TarotElement.earth)) {
    return Dignity.contrary;
  }
  return Dignity.neutral;
}

/// 數字所在的階段：1–3 開始、4–6 經歷、7–10 收成（常見解讀慣例）。
enum NumberStage { beginning, middle, completion }

enum Trend { rising, falling }

/// 整體氛圍的一則觀察。[code] 對應內容檔 atmosphere.json 的文字；其餘欄位填入文字裡的位置。
/// core 只產生代碼，不放介面文字。
class Observation {
  const Observation(this.code, {this.element, this.number, this.count = 0, this.positions = const [], this.dignity, this.stage, this.trend});

  /// majorsAll、majorsMany、majorsNone、elementDominant、elementMissing、elementSingle、dignity、
  /// numberRepeat、numberStage、numberFlow、courtsMany、reversedMany、allUpright、facing。
  final String code;
  final TarotElement? element;
  final int? number;
  final int count;

  /// 相關的位置（牌陣中的序號）。
  final List<int> positions;
  final Dignity? dignity;
  final NumberStage? stage;
  final Trend? trend;
}

/// 整體氛圍規則（策略：日後換規則＝換一個實作）。只看牌本身與牌陣，不看解讀文字。
abstract class AtmosphereRule {
  List<Observation> observe(SpreadDraw draw, {Facing Function(int cardId)? facing});
}

/// 預設規則組合：大阿爾克那比例、主導／缺少的元素、相鄰牌的元素互動、數字重複與階段、
/// 宮廷牌、逆位比例、關鍵牌的人物面向。
class StandardAtmosphere implements AtmosphereRule {
  const StandardAtmosphere();

  /// 元素互動要看的相鄰位置（依牌陣）。
  static const pairs = <String, List<(int, int)>>{
    'three': [(0, 1), (1, 2)],
    'choice': [(1, 2), (3, 4)],
    'relationship': [(0, 1)],
    'celtic': [(0, 1)],
  };

  /// 有時間順序、可以看數字流動的牌陣。
  static const ordered = {'three'};

  @override
  List<Observation> observe(SpreadDraw draw, {Facing Function(int cardId)? facing}) {
    final cards = draw.cards;
    final n = cards.length;
    final out = <Observation>[];
    if (n == 0) return out;
    if (n == 1) {
      final c = cards.first.card;
      out.add(Observation('elementSingle', element: c.element, positions: const [0]));
      if (c.isMajor) out.add(const Observation('majorsSingle', positions: [0]));
      return out;
    }

    // 大阿爾克那比例
    final majors = [for (var i = 0; i < n; i++) if (cards[i].card.isMajor) i];
    if (n >= 3) {
      if (majors.length == n) {
        out.add(Observation('majorsAll', count: n, positions: majors));
      } else if (majors.length * 2 >= n) {
        out.add(Observation('majorsMany', count: majors.length, positions: majors));
      } else if (majors.isEmpty) {
        out.add(const Observation('majorsNone'));
      }
    }

    // 元素：主導與缺少
    final byElement = {for (final e in TarotElement.values) e: <int>[]};
    for (var i = 0; i < n; i++) {
      byElement[cards[i].card.element]!.add(i);
    }
    final sorted = TarotElement.values.toList()..sort((a, b) => byElement[b]!.length.compareTo(byElement[a]!.length));
    final top = sorted.first, second = sorted[1];
    final topCount = byElement[top]!.length;
    if (topCount >= 2 && topCount > byElement[second]!.length && topCount * 2 >= n) {
      out.add(Observation('elementDominant', element: top, count: topCount, positions: byElement[top]!));
    }
    if (n >= 5) {
      for (final e in TarotElement.values) {
        if (byElement[e]!.isEmpty) out.add(Observation('elementMissing', element: e));
      }
    }

    // 相鄰牌的元素互動（同元素、相助、相剋；中性不提）
    for (final (a, b) in pairs[draw.spreadId] ?? const <(int, int)>[]) {
      if (a >= n || b >= n) continue;
      final d = dignityOf(cards[a].card.element, cards[b].card.element);
      if (d == Dignity.neutral) continue;
      out.add(Observation('dignity', dignity: d, positions: [a, b]));
    }

    // 數字：重複、階段、流動（只看小阿爾克那數字牌 1–10）
    final pips = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      final c = cards[i].card;
      if (c.isMajor || c.isCourt) continue;
      pips.putIfAbsent(c.number!, () => []).add(i);
    }
    for (final e in pips.entries) {
      if (e.value.length >= 2) out.add(Observation('numberRepeat', number: e.key, count: e.value.length, positions: e.value));
    }
    final pipCount = pips.values.fold(0, (a, b) => a + b.length);
    if (pipCount >= 2) {
      final sum = pips.entries.fold(0, (a, e) => a + e.key * e.value.length);
      final avg = sum / pipCount;
      final stage = avg <= 3.5 ? NumberStage.beginning : (avg <= 6.5 ? NumberStage.middle : NumberStage.completion);
      out.add(Observation('numberStage', stage: stage, count: pipCount));
    }
    if (ordered.contains(draw.spreadId)) {
      final seq = [for (final c in cards) if (!c.card.isMajor && !c.card.isCourt) c.card.number!];
      if (seq.length == n && n >= 3) {
        var up = true, down = true;
        for (var i = 1; i < seq.length; i++) {
          if (seq[i] <= seq[i - 1]) up = false;
          if (seq[i] >= seq[i - 1]) down = false;
        }
        if (up) out.add(const Observation('numberFlow', trend: Trend.rising));
        if (down) out.add(const Observation('numberFlow', trend: Trend.falling));
      }
    }

    // 宮廷牌
    final courts = [for (var i = 0; i < n; i++) if (cards[i].card.isCourt) i];
    if (n >= 3 && courts.length >= 2) out.add(Observation('courtsMany', count: courts.length, positions: courts));

    // 逆位比例
    final reversed = [for (var i = 0; i < n; i++) if (cards[i].reversed) i];
    if (reversed.length * 2 >= n && reversed.isNotEmpty) {
      out.add(Observation('reversedMany', count: reversed.length, positions: reversed));
    } else if (reversed.isEmpty && n >= 3) {
      out.add(const Observation('allUpright'));
    }

    // 關鍵牌的人物面向：看向哪一個相鄰位置
    final f = facing;
    if (f != null) {
      final k = draw.spread.keyPosition;
      if (k < n) {
        var dir = f(cards[k].cardId);
        if (cards[k].reversed) {
          dir = switch (dir) { Facing.left => Facing.right, Facing.right => Facing.left, _ => dir };
        }
        final target = _neighbour(draw.spread, k, dir);
        if (target != null && target < n) out.add(Observation('facing', positions: [k, target]));
      }
    }
    return out;
  }

  /// 同一列上、往 [dir] 方向最近的位置。
  static int? _neighbour(Spread s, int from, Facing dir) {
    if (dir != Facing.left && dir != Facing.right) return null;
    final p = s.positions[from];
    int? best;
    double? bestDx;
    for (var i = 0; i < s.positions.length; i++) {
      if (i == from) continue;
      final q = s.positions[i];
      if ((q.y - p.y).abs() > 0.5) continue;
      final dx = q.x - p.x;
      if (dir == Facing.left ? dx >= -0.01 : dx <= 0.01) continue;
      if (bestDx == null || dx.abs() < bestDx) {
        best = i;
        bestDx = dx.abs();
      }
    }
    return best;
  }
}
