import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/tarot/atmosphere.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/core/tarot/spread.dart';
import 'package:tarot_cards/core/tarot/tarot_card.dart';

/// 小阿爾克那的 id。
int minor(Suit s, Rank r) => 22 + s.index * 14 + r.index;

SpreadDraw draw(String spreadId, List<int> ids, {Set<int> reversed = const {}}) => SpreadDraw(
      spreadId: spreadId,
      methodId: DrawMethods.quick,
      cards: [for (var i = 0; i < ids.length; i++) DrawnCard(ids[i], reversed: reversed.contains(i))],
    );

List<String> codes(List<Observation> obs) => [for (final o in obs) o.code];

Observation only(List<Observation> obs, String code) => obs.singleWhere((o) => o.code == code);

void main() {
  group('78 張牌', () {
    test('數量、順序與代號', () {
      expect(TarotCard.count, 78);
      expect(TarotCard.all, hasLength(78));
      for (var i = 0; i < 78; i++) {
        expect(TarotCard.byId(i).id, i);
        expect(TarotCard.byId(i).code, i.toString().padLeft(2, '0'));
      }
      expect(TarotCard.all.map((c) => c.key).toSet(), hasLength(78));
      expect(TarotCard.majors.map((c) => c.id), List.generate(22, (i) => i));
      expect(TarotCard.byId(0).key, 'fool');
      expect(TarotCard.byId(21).key, 'world');
      expect(TarotCard.byId(8).key, 'strength'); // Waite 牌序：8 力量、11 正義
      expect(TarotCard.byId(11).key, 'justice');
    });

    test('小阿爾克那：22–35 權杖、36–49 聖杯、50–63 寶劍、64–77 錢幣，各 Ace…King', () {
      const starts = {Suit.wands: 22, Suit.cups: 36, Suit.swords: 50, Suit.pentacles: 64};
      for (final e in starts.entries) {
        final cards = TarotCard.ofSuit(e.key).toList();
        expect(cards.map((c) => c.id), List.generate(14, (i) => e.value + i));
        for (var i = 0; i < 14; i++) {
          expect(cards[i].suit, e.key);
          expect(cards[i].rank, Rank.values[i]);
          expect(cards[i].isMajor, isFalse);
          expect(cards[i].key, '${e.key.name}-${Rank.values[i].name}');
        }
      }
      expect(TarotCard.byId(22).key, 'wands-ace');
      expect(TarotCard.byId(35).key, 'wands-king');
      expect(TarotCard.byId(49).key, 'cups-king');
      expect(TarotCard.byId(50).key, 'swords-ace');
      expect(TarotCard.byId(77).key, 'pentacles-king');
    });

    test('數字與宮廷牌', () {
      expect(TarotCard.byId(0).number, 0);
      expect(TarotCard.byId(15).number, 15);
      expect(TarotCard.byId(15).majorNumber, 15);
      expect(TarotCard.byId(22).number, 1);
      expect(TarotCard.byId(31).number, 10);
      expect(TarotCard.byId(31).isCourt, isFalse);
      for (final r in [Rank.page, Rank.knight, Rank.queen, Rank.king]) {
        final c = TarotCard.byId(minor(Suit.cups, r));
        expect(c.isCourt, isTrue);
        expect(c.number, isNull);
        expect(c.majorNumber, isNull);
      }
    });

    test('元素：花色對應與大阿爾克那（黃金黎明）', () {
      for (final s in Suit.values) {
        for (final c in TarotCard.ofSuit(s)) {
          expect(c.element, s.element);
        }
      }
      expect(Suit.wands.element, TarotElement.fire);
      expect(Suit.cups.element, TarotElement.water);
      expect(Suit.swords.element, TarotElement.air);
      expect(Suit.pentacles.element, TarotElement.earth);
      const majors = {
        0: TarotElement.air, // 愚者：風
        1: TarotElement.air, // 魔術師：水星
        2: TarotElement.water, // 女祭司：月亮
        3: TarotElement.earth, // 皇后：金星
        4: TarotElement.fire, // 皇帝：牡羊
        12: TarotElement.water, // 倒吊人：水
        13: TarotElement.water, // 死神：天蠍
        16: TarotElement.fire, // 高塔：火星
        19: TarotElement.fire, // 太陽
        20: TarotElement.fire, // 審判：火
        21: TarotElement.earth, // 世界：土星
      };
      for (final e in majors.entries) {
        expect(TarotCard.byId(e.key).element, e.value, reason: TarotCard.byId(e.key).key);
      }
      for (final c in TarotCard.majors) {
        expect(c.attribution, isNotNull);
        expect(c.isMajor, isTrue);
      }
    });
  });

  group('牌陣', () {
    test('張數與關鍵位置', () {
      const expected = {'one': (1, 0), 'three': (3, 1), 'advice': (3, 2), 'choice': (5, 0), 'relationship': (5, 2), 'celtic': (10, 0)};
      expect(Spreads.all.map((s) => s.id), expected.keys);
      for (final s in Spreads.all) {
        expect(s.size, expected[s.id]!.$1, reason: s.id);
        expect(s.keyPosition, expected[s.id]!.$2, reason: s.id);
        expect(s.keyPosition, lessThan(s.size));
        expect(s.positions.map((p) => p.key).toSet(), hasLength(s.size), reason: s.id);
      }
    });

    test('免費牌陣、會員牌陣與出處', () {
      expect(Spreads.one.premium, isFalse);
      expect(Spreads.three.premium, isFalse);
      expect(Spreads.advice.premium, isFalse);
      expect(Spreads.celtic.premium, isTrue);
      expect(Spreads.celtic.source, SpreadSource.waite);
      expect(Spreads.celtic.positions[1].crossed, isTrue);
      expect(Spreads.byId('three'), Spreads.three);
      expect(Spreads.byId('nope'), Spreads.one);
    });
  });

  group('洗牌、切牌、抽牌', () {
    test('洗好的牌 78 張不重複；再洗、切牌後仍不重複', () {
      final r = Random(7);
      final deck = ShuffledDeck.shuffle(r);
      expect(deck.length, 78);
      Set<int> ids() => {for (final c in deck.top(78)) c.cardId};
      expect(ids(), hasLength(78));
      deck.reshuffle(r);
      expect(ids(), hasLength(78));
      for (final pile in [0, 1, 2, 5, -1]) {
        deck.cut(pile);
        expect(ids(), hasLength(78));
        expect(deck.length, 78);
      }
      expect(deck.top(3), hasLength(3));
    });

    test('切牌：選的那一疊（每疊 26 張）放到最上面，牌與方向一起移動', () {
      final deck = ShuffledDeck.shuffle(Random(3));
      final before = deck.top(78);
      deck.cut(1);
      final after = deck.top(78);
      expect(after.sublist(0, 26), before.sublist(26, 52));
      expect(after.sublist(26, 52), before.sublist(0, 26));
      expect(after.sublist(52), before.sublist(52));
      deck.cut(2);
      expect(deck.top(26), after.sublist(52));
    });

    test('關閉逆位時一律正位；開啟時約一半逆位', () {
      final upright = ShuffledDeck.shuffle(Random(1), reversals: false);
      upright.reshuffle(Random(2), reversals: false);
      expect(upright.top(78).where((c) => c.reversed), isEmpty);
      final mixed = ShuffledDeck.shuffle(Random(1));
      final n = mixed.top(78).where((c) => c.reversed).length;
      expect(n, inInclusiveRange(20, 58));
    });

    test('同一個亂數種子，結果相同', () {
      expect(ShuffledDeck.shuffle(Random(42)).top(78), ShuffledDeck.shuffle(Random(42)).top(78));
    });
  });

  group('DrawnCard / SpreadDraw', () {
    test('JSON 來回轉換', () {
      for (final c in [const DrawnCard(0), const DrawnCard(77, reversed: true), const DrawnCard(40)]) {
        final back = DrawnCard.tryFromJson(jsonDecode(jsonEncode(c.toJson())));
        expect(back, c);
      }
      expect(const DrawnCard(5).toJson(), {'id': 5});
      expect(const DrawnCard(5, reversed: true).toJson(), {'id': 5, 'r': 1});
      expect(DrawnCard.tryFromJson({'id': 5, 'r': true}), const DrawnCard(5, reversed: true));
    });

    test('不合法的 JSON 回傳 null', () {
      expect(DrawnCard.tryFromJson(null), isNull);
      expect(DrawnCard.tryFromJson('x'), isNull);
      expect(DrawnCard.tryFromJson({'id': 78}), isNull);
      expect(DrawnCard.tryFromJson({'id': -1}), isNull);
      expect(DrawnCard.tryFromJson({'id': '3'}), isNull);
      expect(DrawnCard.tryFromJson({}), isNull);
    });

    test('關鍵牌取牌陣的關鍵位置', () {
      expect(draw('three', [3, 4, 5]).keyCard.cardId, 4);
      expect(draw('one', [9]).keyCard.cardId, 9);
      expect(draw('relationship', [1, 2, 3, 4, 5]).keyCard.cardId, 3);
      expect(draw('three', [3, 4, 5]).spread, Spreads.three);
      expect(() => draw('three', [1, 2, 3]).cards.add(const DrawnCard(4)), throwsUnsupportedError);
    });
  });

  group('元素互動', () {
    test('同元素、相助、相剋、中性', () {
      expect(dignityOf(TarotElement.fire, TarotElement.fire), Dignity.same);
      expect(dignityOf(TarotElement.fire, TarotElement.air), Dignity.friendly);
      expect(dignityOf(TarotElement.earth, TarotElement.water), Dignity.friendly);
      expect(dignityOf(TarotElement.water, TarotElement.fire), Dignity.contrary);
      expect(dignityOf(TarotElement.air, TarotElement.earth), Dignity.contrary);
      expect(dignityOf(TarotElement.fire, TarotElement.earth), Dignity.neutral);
      expect(dignityOf(TarotElement.water, TarotElement.air), Dignity.neutral);
      for (final a in TarotElement.values) {
        for (final b in TarotElement.values) {
          expect(dignityOf(a, b), dignityOf(b, a));
        }
      }
    });
  });

  group('整體氛圍（StandardAtmosphere）', () {
    const rule = StandardAtmosphere();

    test('沒有牌：沒有觀察', () {
      expect(rule.observe(SpreadDraw(spreadId: 'three', methodId: 'quick', cards: const [])), isEmpty);
    });

    test('單張：元素與大阿爾克那', () {
      final obs = rule.observe(draw('one', [19]));
      expect(codes(obs), ['elementSingle', 'majorsSingle']);
      expect(obs.first.element, TarotElement.fire);
      final minorObs = rule.observe(draw('one', [minor(Suit.cups, Rank.two)]));
      expect(codes(minorObs), ['elementSingle']);
      expect(minorObs.single.element, TarotElement.water);
    });

    test('三張全是大阿爾克那', () {
      final obs = rule.observe(draw('three', [0, 1, 2]));
      final m = only(obs, 'majorsAll');
      expect(m.count, 3);
      expect(m.positions, [0, 1, 2]);
      expect(codes(obs), isNot(contains('numberStage'))); // 大阿爾克那不算數字牌
      expect(codes(obs), contains('allUpright'));
    });

    test('大阿爾克那過半；沒有大阿爾克那', () {
      expect(only(rule.observe(draw('three', [0, 1, minor(Suit.cups, Rank.two)])), 'majorsMany').count, 2);
      final none = rule.observe(draw('three', [
        minor(Suit.cups, Rank.two),
        minor(Suit.swords, Rank.nine),
        minor(Suit.wands, Rank.king),
      ]));
      expect(codes(none), contains('majorsNone'));
    });

    test('主導元素', () {
      final obs = rule.observe(draw('three', [
        minor(Suit.wands, Rank.ace),
        minor(Suit.wands, Rank.knight),
        minor(Suit.cups, Rank.queen),
      ]));
      final d = only(obs, 'elementDominant');
      expect(d.element, TarotElement.fire);
      expect(d.count, 2);
      expect(d.positions, [0, 1]);
    });

    test('五張以上才看缺少的元素', () {
      final obs = rule.observe(draw('choice', [
        minor(Suit.wands, Rank.ace),
        minor(Suit.wands, Rank.two),
        minor(Suit.wands, Rank.three),
        minor(Suit.cups, Rank.four),
        minor(Suit.cups, Rank.five),
      ]));
      final missing = obs.where((o) => o.code == 'elementMissing').map((o) => o.element).toSet();
      expect(missing, {TarotElement.air, TarotElement.earth});
      expect(only(obs, 'elementDominant').element, TarotElement.fire);
      final three = rule.observe(draw('three', [22, 23, 24]));
      expect(codes(three), isNot(contains('elementMissing')));
    });

    test('相鄰牌的元素互動：相剋與同元素；中性不提', () {
      final obs = rule.observe(draw('three', [
        minor(Suit.wands, Rank.two), // 火
        minor(Suit.cups, Rank.three), // 水
        minor(Suit.cups, Rank.four), // 水
      ]));
      final ds = obs.where((o) => o.code == 'dignity').toList();
      expect(ds, hasLength(2));
      expect(ds[0].dignity, Dignity.contrary);
      expect(ds[0].positions, [0, 1]);
      expect(ds[1].dignity, Dignity.same);
      expect(ds[1].positions, [1, 2]);

      final neutral = rule.observe(draw('three', [
        minor(Suit.wands, Rank.page), // 火
        minor(Suit.pentacles, Rank.page), // 土
        minor(Suit.wands, Rank.queen), // 火
      ]));
      expect(codes(neutral), isNot(contains('dignity')));
    });

    test('數字重複與階段', () {
      final obs = rule.observe(draw('three', [
        minor(Suit.wands, Rank.five),
        minor(Suit.cups, Rank.five),
        minor(Suit.swords, Rank.five),
      ]));
      final r = only(obs, 'numberRepeat');
      expect(r.number, 5);
      expect(r.count, 3);
      expect(r.positions, [0, 1, 2]);
      final s = only(obs, 'numberStage');
      expect(s.stage, NumberStage.middle);
      expect(s.count, 3);
      expect(codes(obs), isNot(contains('numberFlow')));
    });

    test('三張牌陣的數字流動：上升、下降', () {
      final up = rule.observe(draw('three', [
        minor(Suit.wands, Rank.two),
        minor(Suit.cups, Rank.three),
        minor(Suit.cups, Rank.four),
      ]));
      expect(only(up, 'numberFlow').trend, Trend.rising);
      expect(only(up, 'numberStage').stage, NumberStage.beginning);

      final down = rule.observe(draw('three', [
        minor(Suit.swords, Rank.ten),
        minor(Suit.swords, Rank.eight),
        minor(Suit.pentacles, Rank.seven),
      ]));
      expect(only(down, 'numberFlow').trend, Trend.falling);
      expect(only(down, 'numberStage').stage, NumberStage.completion);

      // 有宮廷牌或大阿爾克那時不看流動；非時間順序的牌陣也不看
      expect(codes(rule.observe(draw('three', [22, 23, 0]))), isNot(contains('numberFlow')));
      expect(codes(rule.observe(draw('choice', [22, 23, 24, 25, 26]))), isNot(contains('numberFlow')));
    });

    test('宮廷牌與逆位比例', () {
      final obs = rule.observe(draw('three', [
        minor(Suit.wands, Rank.king),
        minor(Suit.cups, Rank.queen),
        minor(Suit.swords, Rank.ace),
      ], reversed: {0, 2}));
      expect(only(obs, 'courtsMany').positions, [0, 1]);
      final rev = only(obs, 'reversedMany');
      expect(rev.count, 2);
      expect(rev.positions, [0, 2]);
      expect(codes(obs), isNot(contains('allUpright')));
    });

    test('關鍵牌的人物面向（逆位時左右互換）', () {
      final d = draw('three', [0, minor(Suit.cups, Rank.king), 2]);
      Facing f(int id) => id == d.keyCard.cardId ? Facing.left : Facing.none;
      expect(only(rule.observe(d, facing: f), 'facing').positions, [1, 0]);

      final rev = draw('three', [0, minor(Suit.cups, Rank.king), 2], reversed: {1});
      expect(only(rule.observe(rev, facing: f), 'facing').positions, [1, 2]);

      // 正面或沒有提供面向：不提
      expect(codes(rule.observe(d, facing: (_) => Facing.front)), isNot(contains('facing')));
      expect(codes(rule.observe(d)), isNot(contains('facing')));
      // 關鍵牌在最左邊時往左看不到牌
      final choice = draw('three', [minor(Suit.cups, Rank.king), 5, 6]);
      expect(codes(rule.observe(choice, facing: (id) => id == 5 ? Facing.right : Facing.none)), contains('facing'));
    });

    test('凱爾特十字：面向只看同一列', () {
      final d = draw('celtic', List.generate(10, (i) => i));
      // 關鍵位置 0（覆蓋）往右看是 5（面前），往左看是 4（身後）
      expect(only(rule.observe(d, facing: (id) => id == 0 ? Facing.right : Facing.none), 'facing').positions, [0, 5]);
      expect(only(rule.observe(d, facing: (id) => id == 0 ? Facing.left : Facing.none), 'facing').positions, [0, 4]);
    });
  });
}
