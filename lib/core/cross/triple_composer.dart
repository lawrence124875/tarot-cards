import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../lenormand/lenormand.dart';
import 'cross_composer.dart';
import 'cross_engine.dart';
import 'triple_engine.dart';

/// 三系統交叉模板（tarot-content `cross/<語言>/triple.json`，schemaVersion 3；缺的語言退回英文）。
/// 塔羅、雷諾曼逐張段落沿用雙系統 [CrossTemplates]；這裡拼核心指引（分層組合拳矩陣）、盧恩段落與三軌破局。
class TripleTemplates {
  TripleTemplates(this._j);

  factory TripleTemplates.fromJson(Map<String, dynamic> j) => TripleTemplates(j);

  final Map<String, dynamic> _j;

  bool get isEmpty => _j.isEmpty;

  Map<String, dynamic> _map(String section) {
    final m = _j[section];
    return m is Map ? m.map((k, v) => MapEntry(k.toString(), v)) : const {};
  }

  String _str(String section, String key) => (_map(section)[key] ?? '').toString();

  List<String> _list(String section, String key) {
    final v = _map(section)[key];
    if (v is List) return [for (final x in v) x.toString()];
    return v == null ? const [] : [v.toString()];
  }

  static String _pick(List<String> xs, int seed) => xs.isEmpty ? '' : xs[seed.abs() % xs.length];

  static String _fill(String tpl, Map<String, String> v) =>
      v.entries.fold(tpl, (s, e) => s.replaceAll('{${e.key}}', e.value));

  String relationName(TripleRelation r) => _str('relationNames', r.name);
  String relationLead(TripleRelation r) => _str('relationLead', r.name);
  String sectionTitle(String key) => _str('sections', key);
  String format(String key) => _str('format', key);
  String get disclaimer => (_j['disclaimer'] ?? '').toString();

  /// 塔羅牌的組別：major（0–21）、wands、cups、swords、pentacles。
  static String tarotGroup(int cardId) =>
      cardId < 22 ? 'major' : const ['wands', 'cups', 'swords', 'pentacles'][((cardId - 22) ~/ 14).clamp(0, 3)];

  /// 層 4：符合的強組合（元素越多越優先，同數依列出順序）；沒有時為 null。
  /// 回傳 (key, 評語模板)。
  (String, String)? combo(List<int> tarotIds, List<int> lenormandIds, int runeId) {
    (String, String)? best;
    var bestN = 0;
    for (final e in _map('level4').entries) {
      final parts = e.key.split('+');
      final ok = parts.every((p) {
        final id = int.tryParse(p.substring(1));
        if (id == null) return false;
        return switch (p[0]) {
          't' => tarotIds.contains(id),
          'l' => lenormandIds.contains(id),
          'r' => runeId == id,
          _ => false,
        };
      });
      if (ok && parts.length > bestN) {
        best = (e.key, e.value.toString());
        bestN = parts.length;
      }
    }
    return best;
  }

  /// 依判斷結果拼出五段式內容。[base] 是雙系統模板（塔羅、雷諾曼段落與五級、主題、時間文字）。
  TripleReport compose(TripleResult r, int seed, {required CrossTemplates base, TripleCards? cards}) {
    final rel = r.relation;
    final cross = base.compose(r.cross, seed, cards: cards?.cross);
    TripleDetail? detail;
    if (cards != null && cards.cross.tarot.isNotEmpty && cards.cross.lenormand.isNotEmpty) {
      detail = _detail(r, seed, base, cards, cross);
    }
    return TripleReport(
      relationName: relationName(rel).isEmpty ? rel.name : relationName(rel),
      relationLead: relationLead(rel),
      overall: base.level(r.overall),
      runeLevel: base.level(r.runeLevel),
      cross: cross,
      reflection: _pick(_list('reflection', rel.name), seed ~/ 3),
      disclaimer: disclaimer.isEmpty ? cross.disclaimer : disclaimer,
      detail: detail,
    );
  }

  TripleDetail _detail(TripleResult r, int seed, CrossTemplates base, TripleCards c, CrossReport cross) {
    final q = base.quote;
    final sep = base.keywordSep;
    String kw(List<String> k, [int n = 2]) => k.take(n).join(sep);
    final mt = CrossTemplates.mainIndex([for (final t in c.cross.tarot) t.score]);
    final ml = CrossTemplates.mainIndex([for (final x in c.cross.lenormand) x.score]);
    final rune = c.rune;
    final names = {
      'tarot': q(c.cross.tarot[mt].name),
      'tarotKw': kw(c.cross.tarot[mt].keywords, 1),
      'len': q(c.cross.lenormand[ml].name),
      'lenKw': kw(c.cross.lenormand[ml].keywords, 1),
      'rune': q(rune.name),
      'runeKw': kw(rune.keywords, 1),
    };
    String dir(int sign) => sign > 0 ? 'pos' : (sign < 0 ? 'neg' : 'flat');
    // 層 1：三方關係 × 綜合五級
    final l1Key = r.relation == TripleRelation.divergent ? 'divergent' : '${r.relation.name}_${r.overall.score}';
    final parts = <String>[_fill(_pick(_list('level1', l1Key), seed), names)];
    // 二對一：少數方提醒
    if (r.minority case final m?) {
      final text = _str('minority', '${m.name}_${dir(r.levelOf(m).sign)}');
      if (text.isNotEmpty) parts.add('${format('minorityLead')}${_fill(text, names)}');
    }
    // 層 2：主塔羅牌組別 × 主雷諾曼牌主題
    if (c.tarotIds.length > mt && c.lenormandTags.length > ml && c.lenormandTags[ml].isNotEmpty) {
      parts.add(_fill(_str('level2', '${tarotGroup(c.tarotIds[mt])}_${c.lenormandTags[ml].first}'), names));
    }
    // 層 4：強組合專屬評語
    if (combo(c.tarotIds, c.lenormandIds, rune.id) case (final key, final tpl)) {
      String nameOf(String p) {
        final id = int.parse(p.substring(1));
        return switch (p[0]) {
          't' => q(c.cross.tarot[c.tarotIds.indexOf(id)].name),
          'l' => q(c.cross.lenormand[c.lenormandIds.indexOf(id)].name),
          _ => q(rune.name),
        };
      }

      final v = <String, String>{};
      for (final p in key.split('+')) {
        if (c.tarotIds.length == c.cross.tarot.length && c.lenormandIds.length == c.cross.lenormand.length) {
          v[p[0]] = nameOf(p);
        }
      }
      if (v.length == key.split('+').length) parts.add(_fill(tpl, v));
    }
    final timing = cross.timing;
    if (timing.isNotEmpty) parts.add(_fill(base.formatText('coreTiming'), {'timing': timing}));
    return TripleDetail(
      core: parts.where((x) => x.isNotEmpty).join(''),
      runeTitle: q(rune.name),
      runeKeywords: kw(rune.keywords, 3),
      runeReversedNote: rune.reversed ? format('reversedNote') : '',
      runeReversedText: rune.reversed ? rune.reversedText : '',
      poemLabel: format('poem'),
      poem: rune.poem,
      reminderLabel: format('reminder'),
      reminder: rune.reminder,
      aettText: _fill(_str('level3', '${rune.aett}_${r.relation.name}'), names),
      coreActionLabel: format('core'),
      coreAction: rune.advice,
    );
  }
}

/// 核心之石（盧恩一顆）在三系統交叉用到的文字。
class TripleRuneCard {
  const TripleRuneCard({
    required this.id,
    required this.name,
    required this.reversed,
    required this.aett,
    this.keywords = const [],
    this.poem = '',
    this.reminder = '',
    this.reversedText = '',
    this.advice = '',
  });

  final int id;
  final String name, aett, poem, reminder, reversedText, advice;
  final bool reversed;
  final List<String> keywords;
}

class TripleCards {
  const TripleCards({
    required this.cross,
    required this.tarotIds,
    required this.lenormandIds,
    required this.lenormandTags,
    required this.rune,
  });

  final CrossCards cross;
  final List<int> tarotIds, lenormandIds;

  /// 各張雷諾曼牌的主題標籤（scores.json；層 2 用主牌的第一個）。
  final List<List<String>> lenormandTags;
  final TripleRuneCard rune;
}

/// 拼好的三系統交叉內容。[cross] 是塔羅 × 雷諾曼部分（塔羅、雷諾曼段落、內外兩步、主題、時間）。
class TripleReport {
  const TripleReport({
    required this.relationName,
    required this.relationLead,
    required this.overall,
    required this.runeLevel,
    required this.cross,
    required this.reflection,
    required this.disclaimer,
    this.detail,
  });

  final String relationName, relationLead, overall, runeLevel, reflection, disclaimer;
  final CrossReport cross;

  /// 五段式中三系統特有的部分；沒有牌的文字時為 null。
  final TripleDetail? detail;
}

class TripleDetail {
  const TripleDetail({
    required this.core,
    required this.runeTitle,
    required this.runeKeywords,
    required this.runeReversedNote,
    required this.runeReversedText,
    required this.poemLabel,
    required this.poem,
    required this.reminderLabel,
    required this.reminder,
    required this.aettText,
    required this.coreActionLabel,
    required this.coreAction,
  });

  final String core, runeTitle, runeKeywords, runeReversedNote, runeReversedText;
  final String poemLabel, poem, reminderLabel, reminder, aettText, coreActionLabel, coreAction;
}

/// 從 App 資產讀模板：assets/cross/<語言>/triple.json（其他語言退回英文）。
Future<TripleTemplates> loadTripleTemplates(String contentFolder, {AssetBundle? bundle}) async {
  final f = AssetLenormandSource.folderFor(contentFolder);
  for (final dir in {f, 'en'}) {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/cross/$dir/triple.json');
      return TripleTemplates.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      debugPrint('三系統模板讀取失敗：$dir');
    }
  }
  return TripleTemplates(const {});
}

/// 由抽到的牌與符文算出固定的模板版本序號（同一筆紀錄回看時文字不變）。
int tripleSeed(List<int> tarotIds, List<int> lenormandIds, int runeCode) =>
    (crossSeed(tarotIds, lenormandIds) * 31 + runeCode + 100) & 0x3fffffff;
