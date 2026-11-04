import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cross_engine.dart';

/// 交叉解讀模板（tarot-content `cross/<語言>/templates.json`）。只有繁中、簡中、英文，其他語言用英文。
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

  /// 依判斷結果拼出完整內容。[seed] 由抽到的牌決定，同一筆紀錄回看時文字不變。
  CrossReport compose(CrossResult r, int seed) {
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
    );
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
  });

  final String relationName, relationLead, overall, tarotLevel, lenormandLevel, timing;
  final List<String> tags;
  final String tarotText, lenormandText, relationText, action, reflection, disclaimer;
}

/// 從 App 資產讀模板：assets/cross/<語言>/templates.json（其他語言退回英文）。
Future<CrossTemplates> loadCrossTemplates(String contentFolder, {AssetBundle? bundle}) async {
  final f = const {'zh-Hant', 'zh-Hans', 'en'}.contains(contentFolder) ? contentFolder : 'en';
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
