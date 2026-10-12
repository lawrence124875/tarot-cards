import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/core/tarot/tarot_card.dart';
import 'package:tarot_cards/l10n/card_names.dart';
import 'package:tarot_cards/l10n/l10n.dart';

void main() {
  test('每個語言：22 張大阿爾克那、4 花色、14 個含 {s} 的牌階樣板', () {
    for (final code in CardNames.languages) {
      final n = CardNames.of(code);
      expect(n.majors, hasLength(22), reason: code);
      expect(n.suits, hasLength(4), reason: code);
      expect(n.ranks, hasLength(14), reason: code);
      for (final r in n.ranks) {
        expect(r, contains('{s}'), reason: '$code: $r');
      }
      for (final s in [...n.majors, ...n.suits]) {
        expect(s.trim(), isNotEmpty, reason: code);
      }
      // 78 張牌名都不重複，也不殘留 {s}
      final all = [for (var i = 0; i < TarotCard.count; i++) n.card(i)];
      expect(all.toSet(), hasLength(78), reason: code);
      expect(all.where((s) => s.contains('{s}')), isEmpty, reason: code);
    }
  });

  test('每個 App 語言都有牌名表', () {
    expect(CardNames.languages.toSet(), {for (final l in AppLanguages.all) l.code});
  });

  test('牌名組合', () {
    final en = CardNames.of('en');
    expect(en.card(0), 'The Fool');
    expect(en.card(22), 'Ace of Wands');
    expect(en.card(49), 'King of Cups');
    expect(en.card(77), 'King of Pentacles');
    expect(CardNames.of('zh-Hant').card(36 + 9), '聖杯十');
    expect(CardNames.of('xx').card(0), CardNames.of(CardNames.fallback).card(0));
  });

  test('TarotTerms：依介面語言取牌名與正逆位', () {
    final en = lookupAppLocalizations(AppLanguages.en.locale);
    final zh = lookupAppLocalizations(AppLanguages.zhHant.locale);
    final hans = lookupAppLocalizations(AppLanguages.zhHans.locale);
    final pt = lookupAppLocalizations(AppLanguages.pt.locale);
    expect(en.langCode, 'en');
    expect(zh.langCode, 'zh-Hant');
    expect(hans.langCode, 'zh-Hans');
    expect(pt.langCode, 'pt-BR');
    expect(en.cardName(1), 'The Magician');
    expect(hans.cardName(1), '魔术师');
    expect(zh.drawnName(const DrawnCard(0)), '愚者');
    expect(zh.drawnName(const DrawnCard(0, reversed: true)), '愚者（逆位）');
    expect(en.suitName(Suit.swords), 'Swords');
    expect(zh.cardCorner(TarotCard.byId(21)), 'XXI');
    expect(zh.cardCorner(TarotCard.byId(0)), '0');
    expect(zh.cardCorner(TarotCard.byId(22)), zh.elementLabel(TarotElement.fire));
  });

  test('羅馬數字', () {
    const expected = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV',
      'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI'];
    expect([for (var i = 0; i < 22; i++) roman(i)], expected);
  });
}
