import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/runes/rune_glyphs.dart';
import 'package:tarot_cards/core/runes/runes.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

String _runes(String name) => jsonEncode({
      'runes': [
        {'id': 1, 'key': 'fehu', 'name': name, 'tags': ['money'], 'keywords': ['a'], 'meaning': 'm', 'reversed': 'r'},
        {'id': 11, 'key': 'isa', 'name': 'I', 'tags': ['self'], 'reversed': ''},
      ],
    });

void main() {
  test('24 個符文：代號不重複、三族各 8 個、15 個可逆位、每個都有線條', () {
    expect(RuneStone.all.length, 24);
    expect(RuneStone.keys.toSet().length, 24);
    expect(RuneStone.byId(1).key, 'fehu');
    expect(RuneStone.byId(24).key, 'othala');
    expect(RuneStone.all.where((r) => r.reversible).length, 15);
    expect(RuneStone.byId(11).reversible, isFalse);
    expect(RuneStone.byId(8).aett, 'freyr');
    expect(RuneStone.byId(9).aett, 'hagal');
    expect(RuneStone.byId(24).aett, 'tyr');
    for (final k in RuneStone.keys) {
      expect(runeStrokes[k], isNotNull, reason: k);
      for (final line in runeStrokes[k]!) {
        expect(line.length, greaterThanOrEqualTo(2), reason: k);
        for (final o in line) {
          expect(o.dx >= 0 && o.dx <= 1 && o.dy >= 0 && o.dy <= 1, isTrue, reason: k);
        }
      }
    }
  });

  test('抽符文：不重複、對稱符文不逆位、帶號整數可還原', () {
    final r = Random(7);
    var reversedSeen = false;
    for (var i = 0; i < 300; i++) {
      final runes = drawRunes(r, 3);
      expect(runes.length, 3);
      expect(runes.map((x) => x.id).toSet().length, 3);
      for (final x in runes) {
        if (!x.stone.reversible) expect(x.reversed, isFalse);
        reversedSeen |= x.reversed;
        expect(DrawnRune.fromCode(x.code), x);
      }
    }
    expect(reversedSeen, isTrue);
    expect(DrawnRune.fromCode(-11), const DrawnRune(11)); // Isa 沒有逆位
    expect(DrawnRune.fromCode(0), isNull);
    expect(DrawnRune.fromCode(25), isNull);
    expect(RuneSpread.byId('rune_three'), RuneSpread.three);
    expect(RuneSpread.three.keyPosition, 1);
  });

  test('內容讀取：其他語言退回英文', () async {
    final bundle = _MapBundle({
      'assets/runes/en/runes.json': _runes('Fehu'),
      'assets/runes/zh-Hant/runes.json': _runes('菲胡'),
    });
    final ja = await AssetRuneSource(folder: () => 'ja', bundle: bundle).runes();
    expect(ja[1]!.name, 'Fehu');
    expect(ja[1]!.reversedMeaning, 'r');
    expect(ja[11]!.reversedMeaning, '');
    final zh = await AssetRuneSource(folder: () => 'zh-Hant', bundle: bundle).runes();
    expect(zh[1]!.name, '菲胡');
    expect(AssetRuneSource.folderFor('fr'), 'en');
  });

  test('盧恩日記：類型、關鍵符文、存取還原、數量不符略過', () {
    final e = JournalEntry.fromRunes(spreadId: 'rune_three', runes: [1, -5, 11], now: DateTime(2026, 11, 10), question: 'q');
    expect(e.kind, JournalKind.runes);
    expect(e.isRunes, isTrue);
    expect(e.isLenormand, isFalse);
    expect(e.keyRune, -5);
    final back = JournalEntry.tryFromJson(e.toJson())!;
    expect(back.kind, JournalKind.runes);
    expect(back.runes, [1, -5, 11]);
    expect(back.spreadId, 'rune_three');
    final bad = Map<String, dynamic>.from(e.toJson())..['runes'] = [1];
    expect(JournalEntry.tryFromJson(bad), isNull);
    final one = JournalEntry.fromRunes(spreadId: 'rune_one', runes: [24], now: DateTime(2026, 11, 10));
    expect(JournalEntry.tryFromJson(one.toJson())!.keyRune, 24);
  });
}
