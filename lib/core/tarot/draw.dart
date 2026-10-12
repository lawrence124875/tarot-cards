import 'dart:math';

import 'spread.dart';
import 'tarot_card.dart';

/// 抽到的一張牌：哪一張、正位或逆位。
class DrawnCard {
  const DrawnCard(this.cardId, {this.reversed = false});

  final int cardId;
  final bool reversed;

  TarotCard get card => TarotCard.byId(cardId);

  Map<String, dynamic> toJson() => {'id': cardId, if (reversed) 'r': 1};

  static DrawnCard? tryFromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! int || id < 0 || id >= TarotCard.count) return null;
    return DrawnCard(id, reversed: j['r'] == 1 || j['r'] == true);
  }

  @override
  bool operator ==(Object other) => other is DrawnCard && other.cardId == cardId && other.reversed == reversed;

  @override
  int get hashCode => Object.hash(cardId, reversed);
}

/// 一次抽牌的結果：牌陣、抽牌方式、依位置排列的牌。
class SpreadDraw {
  SpreadDraw({required this.spreadId, required this.methodId, required List<DrawnCard> cards})
      : cards = List.unmodifiable(cards);

  final String spreadId;
  final String methodId;
  final List<DrawnCard> cards;

  Spread get spread => Spreads.byId(spreadId);

  /// 代表這次抽牌的那張（牌陣的關鍵位置）。
  DrawnCard get keyCard => cards[spread.keyPosition.clamp(0, cards.length - 1)];
}

/// 一副洗好的牌（每張牌只出現一次）。洗牌、切牌、抽牌都在這裡進行，畫面只負責動畫。
class ShuffledDeck {
  ShuffledDeck._(this._order, this._reversed);

  /// 洗一副新牌。[reversals] 為 false 時一律正位（設定可關閉逆位）。
  factory ShuffledDeck.shuffle(Random random, {bool reversals = true}) {
    final order = List<int>.generate(TarotCard.count, (i) => i)..shuffle(random);
    // 逆位約一半：與實體牌洗牌時部分牌被轉向相同
    final reversed = [for (var i = 0; i < TarotCard.count; i++) reversals && random.nextBool()];
    return ShuffledDeck._(order, reversed);
  }

  final List<int> _order;
  final List<bool> _reversed;

  int get length => _order.length;

  /// 再洗一次（使用者每點一下「洗牌」）。
  void reshuffle(Random random, {bool reversals = true}) {
    _order.shuffle(random);
    if (!reversals) return;
    // 實體洗牌時只有部分牌被轉向：每次洗約三分之一的牌改變方向
    for (var i = 0; i < _reversed.length; i++) {
      if (random.nextInt(3) == 0) _reversed[i] = !_reversed[i];
    }
  }

  /// 切牌：分成三疊後，以 [pile]（0–2）那一疊放到最上面（常見做法：左手切三疊再合起）。
  void cut(int pile) {
    final size = (_order.length / 3).ceil();
    final start = (pile.clamp(0, 2) * size).clamp(0, _order.length);
    final end = (start + size).clamp(0, _order.length);
    final moved = _order.sublist(start, end);
    final movedR = _reversed.sublist(start, end);
    _order.removeRange(start, end);
    _reversed.removeRange(start, end);
    _order.insertAll(0, moved);
    _reversed.insertAll(0, movedR);
  }

  /// 牌堆第 [index] 張（扇形展開時由左而右）。
  DrawnCard at(int index) => DrawnCard(_order[index], reversed: _reversed[index]);

  /// 從上面依序取 [n] 張（快速抽牌）。
  List<DrawnCard> top(int n) => [for (var i = 0; i < n; i++) at(i)];
}

/// 抽牌方式（策略）：quick＝系統洗好直接抽；ritual＝自己洗牌、切牌、從扇形中挑牌；daily＝今日一張。
class DrawMethods {
  DrawMethods._();

  static const quick = 'quick';
  static const ritual = 'ritual';
  static const daily = 'daily';
}
