import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../lenormand/lenormand.dart';
import 'cross_engine.dart';

/// 交叉解讀模板（tarot-content `cross/<語言>/templates.json`，11 語；缺的語言退回英文）。
class CrossTemplates {
  CrossTemplates(this._j);

  factory CrossTemplates.fromJson(Map<String, dynamic> j) => CrossTemplates(j);

  final Map<String, dynamic> _j;

  bool get isEmpty => _j.isEmpty;

  String _str(String section, String key) {
    final m = _j[section];
    return m is Map ? (m[key] ?? '').toString() : '';
  }

  List<String> _list(String section, String key) {
    final m = _j[section];
    final v = m is Map ? m[key] : null;
    return v is List ? [for (final x in v) x.toString()] : const [];
  }

  String level(TrendLevel l) => _str('levels', '${l.score}');
  String tag(String t) => _str('tags', t).isEmpty ? t : _str('tags', t);
  String timing(CrossTiming t) => _str('timing', t.name);
  String relationName(CrossRelation r) => _str('relationNames', r.name);
  String relationLead(CrossRelation r) => _str('relationLead', r.name);
  String get disclaimer => (_j['disclaimer'] ?? '').toString();

  String _pick(List<String> xs, int seed) => xs.isEmpty ? '' : xs[seed.abs() % xs.length];

  String _fill(String tpl, Map<String, String> v) =>
      v.entries.fold(tpl, (s, e) => s.replaceAll('{${e.key}}', e.value));

  /// 牌名加上語言的括號格式（例：〈愚者〉）。
  String quote(String name) =>
      _fill(_str('format', 'name').isEmpty ? '{name}' : _str('format', 'name'), {'name': name});

  /// format 區的字串（coreTiming、lenTiming…）。
  String formatText(String key) => _str('format', key);

  /// 關鍵詞之間的分隔符號。
  String get keywordSep => (_j['keywordSep'] ?? '、').toString();

  /// 四段標題（core／tarot／lenormand／breakthrough）。
  String sectionTitle(String key) => _str('sections', key);

  /// 依判斷結果拼出完整內容。[seed] 由抽到的牌決定，同一筆紀錄回看時文字不變。
  /// 有 [cards]（各張牌的文字）時，另外拼出四段式內容（核心指引／塔羅內在／雷諾曼外在／雙軌破局）。
  CrossReport compose(CrossResult r, int seed, {CrossCards? cards}) {
    final rel = r.relation;
    final situation = switch (rel) {
      CrossRelation.consensus => 'consensus_${_dir(r.overall.sign)}',
      CrossRelation.partial => r.tarotLevel.sign == 0
          ? 'partial_tarotflat_${r.lenormandLevel.sign > 0 ? 'pos' : 'neg'}'
          : 'partial_lenflat_${r.tarotLevel.sign > 0 ? 'pos' : 'neg'}',
      CrossRelation.divergent => 'divergent_tarot${r.tarotLevel.sign > 0 ? 'pos' : 'neg'}',
    };
    final direction = rel == CrossRelation.divergent ? 'div' : _dir(r.overall.sign);
    final prefix = (_j['actionPrefix'] ?? '').toString();
    final firstTag = r.tags.isEmpty ? '' : tag(r.tags.first);
    final action = _pick(_list('action', direction), seed);
    return CrossReport(
      relationName: relationName(rel),
      relationLead: relationLead(rel),
      overall: level(r.overall),
      tarotLevel: level(r.tarotLevel),
      lenormandLevel: level(r.lenormandLevel),
      tags: [for (final t in r.tags) tag(t)],
      timing: timing(r.timing),
      tarotText: _pick(_list('tarot', '${r.tarotLevel.score}'), seed),
      lenormandText: _pick(_list('lenormand', '${r.lenormandLevel.score}'), seed),
      relationText: _pick(_list('relation', situation), seed),
      action: firstTag.isEmpty || prefix.isEmpty ? action : '${prefix.replaceAll('{tag}', firstTag)}$action',
      reflection: _pick(_list('reflection', rel.name), seed ~/ 3),
      disclaimer: disclaimer,
      detail: cards == null || cards.tarot.isEmpty || cards.lenormand.isEmpty
          ? null
          : _detail(r, seed, situation, cards),
    );
  }

  CrossDetail _detail(CrossResult r, int seed, String situation, CrossCards c) {
    final sep = (_j['keywordSep'] ?? '、').toString();
    String q(String name) => _fill(_str('format', 'name').isEmpty ? '{name}' : _str('format', 'name'), {'name': name});
    String kw(List<String> k, [int n = 2]) => k.take(n).join(sep);
    final mt = mainIndex([for (final t in c.tarot) t.score]);
    final ml = mainIndex([for (final x in c.lenormand) x.score]);
    final timing = this.timing(r.timing);
    final core = [
      _fill(_pick(_list('core', situation), seed), {
        'tarot': q(c.tarot[mt].name),
        'tarotKw': kw(c.tarot[mt].keywords, 1),
        'len': q(c.lenormand[ml].name),
        'lenKw': kw(c.lenormand[ml].keywords, 1),
      }),
      _pick(_list('relation', situation), seed),
      if (timing.isNotEmpty) _fill(_str('format', 'coreTiming'), {'timing': timing}),
    ].where((x) => x.isNotEmpty).join('');
    final blind = _list('blindSpot', 'labels');
    final tarotLines = [
      for (final (i, t) in c.tarot.indexed)
        CrossLine(
          title: q(t.name),
          keywords: kw(t.keywords),
          label: (t.reversed || t.score < 0) ? _pick(blind, seed + i) : '',
          text: t.text,
        ),
    ];
    final lenLines = [
      for (final x in c.lenormand) CrossLine(title: q(x.name), keywords: kw(x.keywords), label: '', text: x.text),
    ];
    final pairs = <String>[
      for (var i = 0; i + 1 < c.lenormand.length; i++)
        _fill(_pick(_list('pair', _dir((c.lenormand[i].score + c.lenormand[i + 1].score).sign)), seed + i), {
          'a': q(c.lenormand[i].name),
          'b': q(c.lenormand[i + 1].name),
          'ka': kw(c.lenormand[i].keywords, 1),
          'kb': kw(c.lenormand[i + 1].keywords, 1),
        }),
    ].where((x) => x.isNotEmpty).toList();
    // 內在一步：分數最低（最需要轉念）的塔羅牌肯定語；外在一步：主雷諾曼牌的建議。
    var low = 0;
    for (var i = 1; i < c.tarot.length; i++) {
      if (c.tarot[i].score < c.tarot[low].score) low = i;
    }
    return CrossDetail(
      core: core,
      tarotLines: tarotLines,
      tarotSummary: _pick(_list('tarot', '${r.tarotLevel.score}'), seed),
      lenormandLines: lenLines,
      pairs: pairs,
      lenormandTiming: timing.isEmpty ? '' : _fill(_str('format', 'lenTiming'), {'timing': timing}),
      innerLabel: _str('format', 'inner'),
      inner: c.tarot[low].affirmation,
      outerLabel: _str('format', 'outer'),
      outer: c.lenormand[ml].advice,
      reflectLabel: _str('format', 'reflect'),
    );
  }

  /// 主牌：分數絕對值最大的一張；同分時中間那張（三張牌陣的「現在」）優先，再依序。
  static int mainIndex(List<int> scores) {
    if (scores.isEmpty) return 0;
    final order = [if (scores.length == 3) 1, for (var i = 0; i < scores.length; i++) if (!(scores.length == 3 && i == 1)) i];
    var best = order.first;
    for (final i in order) {
      if (scores[i].abs() > scores[best].abs()) best = i;
    }
    return best;
  }

  static String _dir(int sign) => sign > 0 ? 'pos' : (sign < 0 ? 'neg' : 'flat');
}

/// 拼好的交叉頁內容。
class CrossReport {
  const CrossReport({
    required this.relationName,
    required this.relationLead,
    required this.overall,
    required this.tarotLevel,
    required this.lenormandLevel,
    required this.tags,
    required this.timing,
    required this.tarotText,
    required this.lenormandText,
    required this.relationText,
    required this.action,
    required this.reflection,
    required this.disclaimer,
    this.detail,
  });

  /// 四段式內容；沒有牌的文字時為 null（退回舊版版面）。
  final CrossDetail? detail;

  final String relationName, relationLead, overall, tarotLevel, lenormandLevel, timing;
  final List<String> tags;
  final String tarotText, lenormandText, relationText, action, reflection, disclaimer;
}

/// 一張塔羅牌在交叉解讀用到的文字（[text]＝該主題的內在解釋）。
class CrossTarotCard {
  const CrossTarotCard({
    required this.name,
    required this.reversed,
    required this.score,
    this.keywords = const [],
    this.text = '',
    this.affirmation = '',
  });

  final String name, text, affirmation;
  final bool reversed;
  final int score;
  final List<String> keywords;
}

/// 一張雷諾曼牌在交叉解讀用到的文字（[text]＝該主題的實際影響）。
class CrossLenormandCard {
  const CrossLenormandCard({required this.name, required this.score, this.keywords = const [], this.text = '', this.advice = ''});

  final String name, text, advice;
  final int score;
  final List<String> keywords;
}

class CrossCards {
  const CrossCards({required this.tarot, required this.lenormand});

  final List<CrossTarotCard> tarot;
  final List<CrossLenormandCard> lenormand;
}

/// 一張牌在段落裡的一行：牌名、關鍵字、（盲點標籤）、解釋。
class CrossLine {
  const CrossLine({required this.title, required this.keywords, required this.label, required this.text});

  final String title, keywords, label, text;
}

/// 四段式內容。
class CrossDetail {
  const CrossDetail({
    required this.core,
    required this.tarotLines,
    required this.tarotSummary,
    required this.lenormandLines,
    required this.pairs,
    required this.lenormandTiming,
    required this.innerLabel,
    required this.inner,
    required this.outerLabel,
    required this.outer,
    required this.reflectLabel,
  });

  final String core, tarotSummary, lenormandTiming, innerLabel, inner, outerLabel, outer, reflectLabel;
  final List<CrossLine> tarotLines, lenormandLines;
  final List<String> pairs;
}

/// 從 App 資產讀模板：assets/cross/<語言>/templates.json（其他語言退回英文）。
Future<CrossTemplates> loadCrossTemplates(String contentFolder, {AssetBundle? bundle}) async {
  final f = AssetLenormandSource.folderFor(contentFolder);
  for (final dir in {f, 'en'}) {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/cross/$dir/templates.json');
      return CrossTemplates.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      debugPrint('交叉模板讀取失敗：$dir');
    }
  }
  return CrossTemplates(const {});
}

/// 由抽到的牌算出固定的模板版本序號。
int crossSeed(List<int> tarotIds, List<int> lenormandIds) =>
    [...tarotIds, ...lenormandIds].fold(17, (a, b) => (a * 31 + b) & 0x3fffffff);
