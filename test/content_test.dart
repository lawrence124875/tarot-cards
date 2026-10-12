import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/content/asset_content_source.dart';
import 'package:tarot_cards/core/content/card_content.dart';

/// 解讀內容的寬鬆解析（tarot-content/<語言>/NN.json 等）。
void main() {
  test('牌的解讀：關鍵詞、Waite、正逆位各組解讀、象徵物、東西相映', () {
    final c = CardContent.fromJson({
      'id': 19,
      'name': 'The Sun',
      'keywords': {
        'upright': ['joy', 'clarity'],
        'reversed': ['delay'],
      },
      'waite': {'description': 'A naked child...', 'upright': 'Material happiness', 'source': 'Waite 1910'},
      'upright': [
        {'angle': 'figure', 'title': 'Child on a horse', 'meaning': 'm', 'forYou': 'f', 'action': 'a', 'question': 'q'},
        {'angle': 'symbol', 'title': 'Sunflowers'},
      ],
      'reversed': [
        {'angle': 'number', 'title': 'Nineteen'},
      ],
      'symbols': [
        {'id': 'sunflower', 'name': 'Sunflowers', 'meaning': 'growth'},
      ],
      'affirmation': 'I let light in.',
      'eastWest': {
        'quote': {'text': 'Q', 'author': 'A'},
        'psychology': {'name': ''},
      },
      'future': 'ignored',
    });
    expect(c.id, 19);
    expect(c.keywords(false), ['joy', 'clarity']);
    expect(c.keywords(true), ['delay']);
    expect(c.waite.isEmpty, isFalse);
    expect(c.waite.reversed, '');
    expect(c.readings(false).map((r) => r.angle), ['figure', 'symbol']);
    expect(c.readings(false).first.question, 'q');
    expect(c.readings(true).single.title, 'Nineteen');
    expect(c.symbol('sunflower')!.meaning, 'growth');
    expect(c.symbol('nope'), isNull);
    expect(c.affirmation, 'I let light in.');
    expect(c.eastWest!.hasQuote, isTrue);
    expect(c.eastWest!.hasPsychology, isFalse);
  });

  test('缺欄位給空值，不拋例外', () {
    final c = CardContent.fromJson({'upright': 'bad', 'symbols': [3]});
    expect(c.id, 0);
    expect(c.name, '');
    expect(c.upright, isEmpty);
    expect(c.symbols.single.id, '');
    expect(c.waite.isEmpty, isTrue);
    expect(c.eastWest, isNull);
  });

  test('牌陣文字、整體氛圍文字、課程', () {
    final s = SpreadTexts.fromJson({
      'spreads': {
        'three': {
          'name': 'Past, present, future',
          'positions': {
            'past': {'name': 'Past', 'meaning': 'What led here'},
          },
        },
      },
    });
    expect(s['three']!.name, 'Past, present, future');
    expect(s['three']!.positions['past']!.meaning, 'What led here');
    expect(s['one'], isNull);

    final a = AtmosphereTexts.fromJson({
      'intro': 'Overall',
      'elementDominant': {'fire': 'Lots of fire ({count})'},
    });
    expect(a.intro, 'Overall');
    expect(a.note, '');
    expect(a.text('elementDominant', 'fire'), 'Lots of fire ({count})');
    expect(a.text('elementDominant', 'water'), '');
    expect(a.text('elementDominant'), '');
    expect(a.text('missing'), '');

    final b = LessonBook.fromJson({
      'units': [
        {
          'id': 'basics',
          'free': true,
          'lessons': [
            {
              'id': 'l1',
              'title': 'Majors',
              'sections': [
                {'heading': 'h', 'body': 'b'},
              ],
              'cards': [0, 1, 'x'],
            },
          ],
        },
        {'id': 'later'},
      ],
    });
    expect(b.units.first.free, isTrue);
    expect(b.units.first.ready, isTrue);
    expect(b.units.first.lessons.single.cards, [0, 1]);
    expect(b.units.last.ready, isFalse);
    expect(b.units.last.free, isFalse);
  });

  testWidgets('內容檔不在 repo 時：AssetContentSource 回傳 null，不拋例外', (tester) async {
    final source = AssetContentSource(folder: () => 'en', bundle: _EmptyBundle());
    await tester.runAsync(() async {
      expect(await source.card(0), isNull);
      expect(await source.spreads(), isNull);
      expect(await source.atmosphere(), isNull);
      expect(await source.lessons(), isNull);
    });
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('no asset $key');
}
