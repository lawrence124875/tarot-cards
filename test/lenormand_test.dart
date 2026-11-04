import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/lenormand/lenormand.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

String _cards(String name) => jsonEncode({
      'cards': [
        {'id': 1, 'key': 'rider', 'name': name, 'timing': 'fast', 'tags': ['news'], 'keywords': ['a', 'b'], 'meaning': 'm'},
        {'id': 21, 'key': 'mountain', 'name': 'M', 'timing': 'slow', 'tags': ['work']},
      ],
    });

void main() {
  test('36 張牌：牌號 1–36、代號不重複、圖檔路徑兩位數', () {
    expect(LenormandCard.all.length, 36);
    expect(LenormandCard.keys.toSet().length, 36);
    expect(LenormandCard.byId(1).key, 'rider');
    expect(LenormandCard.byId(36).key, 'cross');
    expect(LenormandCard.byId(28).key, 'man');
    expect(LenormandCard.byId(7).artAsset, 'assets/lenormand/deck/07.webp');
    expect(LenormandCard.isValid(0), isFalse);
    expect(LenormandCard.isValid(37), isFalse);
  });

  test('抽牌：張數正確、不重複、都在 1–36（沒有逆位）', () {
    final r = Random(7);
    for (var i = 0; i < 200; i++) {
      final cards = drawLenormand(r, 3);
      expect(cards.length, 3);
      expect(cards.toSet().length, 3);
      expect(cards.every(LenormandCard.isValid), isTrue);
    }
    expect(drawLenormand(r, 1).length, 1);
  });

  test('牌陣：單張與三張，三張的關鍵位置是中間', () {
    expect(LenormandSpread.one.size, 1);
    expect(LenormandSpread.three.positions, ['cause', 'core', 'direction']);
    expect(LenormandSpread.three.keyPosition, 1);
    expect(LenormandSpread.byId('nope'), LenormandSpread.one);
  });

  test('語言：繁中、簡中、英文用自己的，其他語言退回英文', () {
    expect(AssetLenormandSource.folderFor('zh-Hant'), 'zh-Hant');
    expect(AssetLenormandSource.folderFor('zh-Hans'), 'zh-Hans');
    expect(AssetLenormandSource.folderFor('en'), 'en');
    for (final f in ['ja', 'ko', 'vi', 'es', 'pt-BR', 'id', 'th', 'ar']) {
      expect(AssetLenormandSource.folderFor(f), 'en', reason: f);
    }
  });

  test('讀內容：日文退回英文；缺欄位給預設值', () async {
    final bundle = _MapBundle({
      'assets/lenormand/en/cards.json': _cards('Rider'),
      'assets/lenormand/zh-Hant/cards.json': _cards('騎士'),
    });
    final ja = await AssetLenormandSource(folder: () => 'ja', bundle: bundle).cards();
    expect(ja[1]!.name, 'Rider');
    expect(ja[1]!.speed, LenormandSpeed.fast);
    expect(ja[1]!.keywords, ['a', 'b']);
    expect(ja[21]!.speed, LenormandSpeed.slow);
    expect(ja[21]!.meaning, '');
    final zh = await AssetLenormandSource(folder: () => 'zh-Hant', bundle: bundle).cards();
    expect(zh[1]!.name, '騎士');
    // 簡中沒有檔案時退回英文
    final hans = await AssetLenormandSource(folder: () => 'zh-Hans', bundle: bundle).cards();
    expect(hans[1]!.name, 'Rider');
    expect(await AssetLenormandSource(folder: () => 'en', bundle: bundle).lessons(), isNull);
  });
}
