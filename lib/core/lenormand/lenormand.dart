import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/card_content.dart';

/// 雷諾曼牌的節奏（快／中／慢，現代常見慣例），交叉解讀換算時間區間用。
enum LenormandSpeed { fast, medium, slow }

/// 雷諾曼 36 張牌（1 騎士 … 36 十字架）。沒有逆位。
/// 牌號與內容檔 `assets/lenormand/<語言>/cards.json` 的 id、圖檔 `assets/lenormand/deck/NN.webp` 一致。
class LenormandCard {
  const LenormandCard._(this.id, this.key);

  static const count = 36;

  static const keys = [
    'rider', 'clover', 'ship', 'house', 'tree', 'clouds', 'snake', 'coffin', 'bouquet', //
    'scythe', 'whip', 'birds', 'child', 'fox', 'bear', 'stars', 'stork', 'dog',
    'tower', 'garden', 'mountain', 'crossroads', 'mice', 'heart', 'ring', 'book', 'letter',
    'man', 'woman', 'lily', 'sun', 'moon', 'key', 'fish', 'anchor', 'cross',
  ];

  static final List<LenormandCard> all = [for (var i = 0; i < count; i++) LenormandCard._(i + 1, keys[i])];

  static LenormandCard byId(int id) => all[id - 1];

  static bool isValid(int id) => id >= 1 && id <= count;

  /// 1–36。
  final int id;
  final String key;

  /// 圖檔名用的兩位數牌號（01–36）。
  String get code => id.toString().padLeft(2, '0');

  String get artAsset => 'assets/lenormand/deck/$code.webp';

  static const backAsset = 'assets/lenormand/deck/back.webp';
}

/// 從 36 張中抽 [n] 張不重複的牌（雷諾曼不用逆位）。
List<int> drawLenormand(Random random, int n) {
  final order = List<int>.generate(LenormandCard.count, (i) => i + 1)..shuffle(random);
  return order.take(n.clamp(1, LenormandCard.count)).toList();
}

/// 雷諾曼牌陣（單張、三張）。位置名稱與說明在內容檔 spreads.json。
class LenormandSpread {
  const LenormandSpread._(this.id, this.positions);

  final String id;
  final List<String> positions;

  int get size => positions.length;

  /// 關鍵位置：三張取中間（核心）。
  int get keyPosition => size == 3 ? 1 : 0;

  static const one = LenormandSpread._('one', ['focus']);
  static const three = LenormandSpread._('three', ['cause', 'core', 'direction']);
  static const all = [one, three];

  static LenormandSpread byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => one);
}

/// 一張牌的文字（內容檔 cards.json）。
class LenormandText {
  LenormandText.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        key = _s(j, 'key'),
        name = _s(j, 'name'),
        playing = _s(j, 'playing'),
        speed = LenormandSpeed.values.firstWhere((s) => s.name == j['timing'], orElse: () => LenormandSpeed.medium),
        tags = _strings(j['tags']),
        keywords = _strings(j['keywords']),
        meaning = _s(j, 'meaning'),
        love = _s(j, 'love'),
        work = _s(j, 'work'),
        advice = _s(j, 'advice');

  final int id;
  final String key, name, playing, meaning, love, work, advice;
  final LenormandSpeed speed;

  /// 主題標籤代碼（news、love、work、money、home、health、social、self、travel）。
  final List<String> tags;
  final List<String> keywords;
}

/// 牌陣的位置文字。
class LenormandSpreadText {
  LenormandSpreadText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        description = _s(j, 'description'),
        positions = {
          for (final e in _map(j['positions']).entries) e.key: LenormandPositionText.fromJson(_map(e.value)),
        };

  final String name, description;
  final Map<String, LenormandPositionText> positions;
}

class LenormandPositionText {
  LenormandPositionText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        meaning = _s(j, 'meaning'),
        prompt = _s(j, 'prompt');

  final String name, meaning, prompt;
}

/// 雷諾曼內容（依語言）。
abstract class LenormandSource {
  Future<Map<int, LenormandText>> cards();
  Future<Map<String, LenormandSpreadText>> spreads();
  Future<LessonBook?> lessons();
}

/// 從 App 資產讀取：assets/lenormand/<語言資料夾>/cards.json、spreads.json、lessons.json。
/// 只有繁中、簡中、英文有內容，其他語言退回英文（Lawrence 2026-11-04）。
class AssetLenormandSource implements LenormandSource {
  AssetLenormandSource({required this.folder, AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final String Function() folder;
  final AssetBundle _bundle;
  final Map<String, Object?> _cache = {};

  static const contentFolders = {'zh-Hant', 'zh-Hans', 'en', 'ja', 'ko', 'vi', 'id', 'es', 'pt-BR', 'th', 'ar'};

  /// 語言資料夾 → 雷諾曼內容資料夾（11 語各有資料夾；未知語言用英文，讀不到時也退英文）。
  static String folderFor(String contentFolder) => contentFolders.contains(contentFolder) ? contentFolder : 'en';

  Future<Map<String, dynamic>?> _json(String name) async {
    final f = folderFor(folder());
    for (final dir in {f, 'en'}) {
      final path = 'assets/lenormand/$dir/$name';
      if (_cache.containsKey(path)) {
        final v = _cache[path];
        if (v != null) return v as Map<String, dynamic>;
        continue;
      }
      Map<String, dynamic>? result;
      try {
        result = jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('雷諾曼內容讀取失敗：$path');
      }
      _cache[path] = result;
      if (result != null) return result;
    }
    return null;
  }

  @override
  Future<Map<int, LenormandText>> cards() async {
    final j = await _json('cards.json');
    return {
      for (final c in _list(j?['cards']))
        if (_map(c)['id'] is num) (_map(c)['id'] as num).toInt(): LenormandText.fromJson(_map(c)),
    };
  }

  @override
  Future<Map<String, LenormandSpreadText>> spreads() async {
    final j = await _json('spreads.json');
    return {for (final e in _map(j?['spreads']).entries) e.key: LenormandSpreadText.fromJson(_map(e.value))};
  }

  @override
  Future<LessonBook?> lessons() async {
    final j = await _json('lessons.json');
    return j == null ? null : LessonBook.fromJson(j);
  }
}

/// 測試與沒有內容時：全部空的。
class EmptyLenormandSource implements LenormandSource {
  const EmptyLenormandSource();

  @override
  Future<Map<int, LenormandText>> cards() async => const {};

  @override
  Future<Map<String, LenormandSpreadText>> spreads() async => const {};

  @override
  Future<LessonBook?> lessons() async => null;
}

String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();

Map<String, dynamic> _map(Object? o) =>
    o is Map ? o.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};

List<Object?> _list(Object? o) => o is List ? o : const [];

List<String> _strings(Object? o) => [for (final x in _list(o)) if (x != null) x.toString()];
