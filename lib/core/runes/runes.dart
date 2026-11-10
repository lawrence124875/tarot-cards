import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/card_content.dart';

/// 盧恩（古弗薩克）24 個符文：1 Fehu … 24 Othala，分三族（aett）各 8 個。
/// 只有 15 個上下顛倒後形狀不同的符文有逆位（merkstave，讀作「向內整理」）。
/// 牌號與內容檔 `assets/runes/<語言>/runes.json` 的 id 一致；符文以線條繪製，沒有圖檔。
class RuneStone {
  const RuneStone._(this.id, this.key, this.reversible);

  static const count = 24;

  static const keys = [
    'fehu', 'uruz', 'thurisaz', 'ansuz', 'raidho', 'kenaz', 'gebo', 'wunjo', //
    'hagalaz', 'naudhiz', 'isa', 'jera', 'eihwaz', 'perthro', 'algiz', 'sowilo',
    'tiwaz', 'berkano', 'ehwaz', 'mannaz', 'laguz', 'ingwaz', 'dagaz', 'othala',
  ];

  /// 上下顛倒後形狀相同、沒有逆位的 9 個符文。
  static const symmetric = {'gebo', 'hagalaz', 'naudhiz', 'isa', 'jera', 'eihwaz', 'sowilo', 'ingwaz', 'dagaz'};

  static const aettir = ['freyr', 'hagal', 'tyr'];

  static final List<RuneStone> all = [
    for (var i = 0; i < count; i++) RuneStone._(i + 1, keys[i], !symmetric.contains(keys[i])),
  ];

  static RuneStone byId(int id) => all[id - 1];

  static bool isValid(int id) => id >= 1 && id <= count;

  /// 1–24。
  final int id;
  final String key;

  /// 可以出現逆位。
  final bool reversible;

  /// 所屬的族：freyr（1–8）、hagal（9–16）、tyr（17–24）。
  String get aett => aettir[(id - 1) ~/ 8];
}

/// 抽到的一顆符文。紀錄裡以帶號整數儲存：正數＝正位，負數＝逆位（例：-5＝Raidho 逆位）。
class DrawnRune {
  const DrawnRune(this.id, {this.reversed = false});

  /// 從帶號整數還原；不合法時回傳 null。不可逆位的符文一律視為正位。
  static DrawnRune? fromCode(int code) {
    final id = code.abs();
    if (!RuneStone.isValid(id)) return null;
    return DrawnRune(id, reversed: code < 0 && RuneStone.byId(id).reversible);
  }

  final int id;
  final bool reversed;

  int get code => reversed ? -id : id;

  RuneStone get stone => RuneStone.byId(id);

  @override
  bool operator ==(Object other) => other is DrawnRune && other.id == id && other.reversed == reversed;

  @override
  int get hashCode => Object.hash(id, reversed);

  @override
  String toString() => 'DrawnRune($code)';
}

/// 從 24 個符文中抽 [n] 個不重複的；可逆位的符文各有一半機會逆位。
List<DrawnRune> drawRunes(Random random, int n) {
  final order = List<int>.generate(RuneStone.count, (i) => i + 1)..shuffle(random);
  return [
    for (final id in order.take(n.clamp(1, RuneStone.count)))
      DrawnRune(id, reversed: RuneStone.byId(id).reversible && random.nextBool()),
  ];
}

/// 盧恩牌陣（一顆、三顆）。位置名稱與說明在內容檔 spreads.json。
class RuneSpread {
  const RuneSpread._(this.id, this.positions);

  final String id;
  final List<String> positions;

  int get size => positions.length;

  /// 關鍵位置：三顆取中間（正在成）。
  int get keyPosition => size == 3 ? 1 : 0;

  /// 紀錄用的牌陣 id（rune_one、rune_three）。
  String get journalId => 'rune_$id';

  static const one = RuneSpread._('one', ['focus']);
  static const three = RuneSpread._('three', ['past', 'present', 'future']);
  static const all = [one, three];

  static RuneSpread byId(String id) =>
      all.firstWhere((s) => s.id == id || s.journalId == id, orElse: () => one);
}

/// 一個符文的文字（內容檔 runes.json）。
class RuneText {
  RuneText.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        key = _s(j, 'key'),
        name = _s(j, 'name'),
        tags = _strings(j['tags']),
        keywords = _strings(j['keywords']),
        meaning = _s(j, 'meaning'),
        reversedMeaning = _s(j, 'reversed'),
        love = _s(j, 'love'),
        work = _s(j, 'work'),
        advice = _s(j, 'advice'),
        poem = _s(j, 'poem'),
        reminder = _s(j, 'reminder');

  final int id;
  final String key, name, meaning, reversedMeaning, love, work, advice, poem;

  /// 核心提醒（一句；三系統交叉的盧恩段落用）。
  final String reminder;

  /// 主題標籤代碼（與雷諾曼相同：news、love、work、money、home、health、social、self、travel）。
  final List<String> tags;
  final List<String> keywords;
}

/// 牌陣與位置文字。
class RuneSpreadText {
  RuneSpreadText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        description = _s(j, 'description'),
        positions = {
          for (final e in _map(j['positions']).entries) e.key: RunePositionText.fromJson(_map(e.value)),
        };

  final String name, description;
  final Map<String, RunePositionText> positions;
}

class RunePositionText {
  RunePositionText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        meaning = _s(j, 'meaning'),
        prompt = _s(j, 'prompt');

  final String name, meaning, prompt;
}

/// 盧恩內容（依語言）。
abstract class RuneSource {
  Future<Map<int, RuneText>> runes();
  Future<Map<String, RuneSpreadText>> spreads();
  Future<LessonBook?> lessons();
}

/// 從 App 資產讀取：assets/runes/<語言資料夾>/runes.json、spreads.json、lessons.json；讀不到時退回英文。
class AssetRuneSource implements RuneSource {
  AssetRuneSource({required this.folder, AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final String Function() folder;
  final AssetBundle _bundle;
  final Map<String, Object?> _cache = {};

  static const contentFolders = {'zh-Hant', 'zh-Hans', 'en', 'ja', 'ko', 'vi', 'id', 'es', 'pt-BR', 'th', 'ar'};

  static String folderFor(String contentFolder) => contentFolders.contains(contentFolder) ? contentFolder : 'en';

  Future<Map<String, dynamic>?> _json(String name) async {
    final f = folderFor(folder());
    for (final dir in {f, 'en'}) {
      final path = 'assets/runes/$dir/$name';
      if (_cache.containsKey(path)) {
        final v = _cache[path];
        if (v != null) return v as Map<String, dynamic>;
        continue;
      }
      Map<String, dynamic>? result;
      try {
        result = jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('盧恩內容讀取失敗：$path');
      }
      _cache[path] = result;
      if (result != null) return result;
    }
    return null;
  }

  @override
  Future<Map<int, RuneText>> runes() async {
    final j = await _json('runes.json');
    return {
      for (final c in _list(j?['runes']))
        if (_map(c)['id'] is num) (_map(c)['id'] as num).toInt(): RuneText.fromJson(_map(c)),
    };
  }

  @override
  Future<Map<String, RuneSpreadText>> spreads() async {
    final j = await _json('spreads.json');
    return {for (final e in _map(j?['spreads']).entries) e.key: RuneSpreadText.fromJson(_map(e.value))};
  }

  @override
  Future<LessonBook?> lessons() async {
    final j = await _json('lessons.json');
    return j == null ? null : LessonBook.fromJson(j);
  }
}

/// 測試與沒有內容時：全部空的。
class EmptyRuneSource implements RuneSource {
  const EmptyRuneSource();

  @override
  Future<Map<int, RuneText>> runes() async => const {};

  @override
  Future<Map<String, RuneSpreadText>> spreads() async => const {};

  @override
  Future<LessonBook?> lessons() async => null;
}

String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();

Map<String, dynamic> _map(Object? o) =>
    o is Map ? o.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};

List<Object?> _list(Object? o) => o is List ? o : const [];

List<String> _strings(Object? o) => [for (final x in _list(o)) if (x != null) x.toString()];
