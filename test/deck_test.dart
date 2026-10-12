import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/deck/deck.dart';
import 'package:tarot_cards/core/deck/deck_source.dart';
import 'package:tarot_cards/core/tarot/atmosphere.dart';

void main() {
  final json = <String, dynamic>{
    'id': 'rws1909',
    'name': {'zh-Hant': '1909 經典牌面', 'en': 'Classic 1909'},
    'credit': {'en': 'Pamela Colman Smith, 1909 (public domain)'},
    'premium': false,
    'aiGenerated': false,
    'aspect': 0.57,
    'back': 'back.webp',
    'cards': {
      '0': {
        'facing': 'left',
        'symbols': [
          {'id': 'dog', 'x': 0.7, 'y': 0.8, 'r': 0.1},
          {'id': 'sun', 'x': 0.2, 'y': 0.1},
          {'id': 5, 'x': 0.1, 'y': 0.1}, // id 不是字串：略過
          'bad',
        ],
      },
      '19': {'facing': 'front'},
      '20': {'facing': 'sideways'},
      'x': {'facing': 'left'},
      '21': 'bad',
    },
  };

  test('解析 deck.json：名稱、出處、比例、牌背', () {
    final d = Deck.fromJson(json);
    expect(d.id, 'rws1909');
    expect(d.name('zh-Hant'), '1909 經典牌面');
    expect(d.name('ja'), 'Classic 1909'); // 沒有該語言時用英文
    expect(d.credit('ko'), startsWith('Pamela'));
    expect(d.premium, isFalse);
    expect(d.aiGenerated, isFalse);
    expect(d.aspect, 0.57);
    expect(d.backAsset, 'assets/decks/rws1909/back.webp');
    expect(d.artPath(5), 'assets/decks/rws1909/05.webp');
    expect(d.artPath(77), 'assets/decks/rws1909/77.webp');
  });

  test('標註：人物面向與象徵物', () {
    final d = Deck.fromJson(json);
    final fool = d.annotation(0);
    expect(fool.facing, Facing.left);
    expect(fool.symbols.map((s) => s.id), ['dog', 'sun']);
    expect(fool.symbols.first.r, 0.1);
    expect(fool.symbols.last.r, 0.07); // 預設點擊範圍
    expect(fool.symbols.first.x, 0.7);
    expect(d.annotation(19).facing, Facing.front);
    expect(d.annotation(20).facing, Facing.none); // 認不得的面向
    expect(d.annotation(21).facing, Facing.none);
    expect(d.annotation(21).symbols, isEmpty);
    expect(d.annotations.keys.toSet(), {0, 19, 20});
  });

  test('缺欄位時給預設值', () {
    final d = Deck.fromJson({'id': 'gemini', 'premium': true, 'aiGenerated': true});
    expect(d.premium, isTrue);
    expect(d.aiGenerated, isTrue);
    expect(d.aspect, 0.58);
    expect(d.backAsset, isNull);
    expect(d.name('en'), 'gemini');
    expect(d.credit('en'), '');
    expect(d.annotation(3).facing, Facing.none);
    expect(Deck.fromJson({'id': 'x', 'back': ''}).backAsset, isNull);
    expect(Deck.fromJson({'id': 'x', 'name': {'ja': '日'}}).name('en'), '日');
  });

  test('SymbolSpot.tryFromJson', () {
    expect(SymbolSpot.tryFromJson({'id': 'a', 'x': 1, 'y': 0})!.x, 1.0);
    expect(SymbolSpot.tryFromJson({'id': 'a', 'x': '1', 'y': 0}), isNull);
    expect(SymbolSpot.tryFromJson(null), isNull);
  });

  group('AssetDeckSource', () {
    testWidgets('沒有牌面組資產時：沒有牌面組、沒有圖', (tester) async {
      final source = AssetDeckSource(bundle: _EmptyBundle());
      await tester.runAsync(() async {
        expect(await source.decks(), isEmpty);
        expect(await source.deck('rws1909'), isNull);
        expect(await source.cardArt(null, 0), isNull);
        expect(await source.cardArtBytes(Deck.fromJson(json), 0), isNull);
      });
    });
  });
}

/// 沒有任何資產（讀資產清單失敗）的 bundle。
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('no asset $key');
}
