import '../tarot/tarot_card.dart';
import 'journal_entry.dart';

/// 日記統計：常出現的牌、大阿爾克那與各花色的張數、逆位比例。
/// 只是使用者自己紀錄的整理，不代表任何預測。
class JournalStats {
  JournalStats._(this.total, this.reversed, this.majors, this.suits, this.top);

  factory JournalStats.from(Iterable<JournalEntry> entries, {int topCount = 3}) {
    var total = 0, reversed = 0, majors = 0;
    final suits = {for (final s in Suit.values) s: 0};
    final perCard = <int, int>{};
    for (final e in entries) {
      for (final c in e.cards) {
        total++;
        if (c.reversed) reversed++;
        final card = TarotCard.byId(c.cardId);
        if (card.isMajor) {
          majors++;
        } else {
          suits[card.suit!] = suits[card.suit!]! + 1;
        }
        perCard[c.cardId] = (perCard[c.cardId] ?? 0) + 1;
      }
    }
    final top = perCard.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return JournalStats._(total, reversed, majors, suits,
        [for (final e in top.take(topCount)) (cardId: e.key, count: e.value)]);
  }

  final int total, reversed, majors;
  final Map<Suit, int> suits;

  /// 出現兩次以上的牌，次數多的在前。
  final List<({int cardId, int count})> top;
}
