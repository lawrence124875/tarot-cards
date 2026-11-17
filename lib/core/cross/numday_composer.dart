import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../lenormand/lenormand.dart';
import '../numerology/numerology.dart';
import '../tarot/draw.dart';
import '../tarot/tarot_card.dart';

/// 流日數字與今日一牌的關係（tarot-content `cross/src/numday.py`）。
/// - sync 同頻：牌的數字化簡＝流日（愚者 0 除外）
/// - echo 呼應：其他數字牌與大牌
/// - court 宮廷牌：侍者／騎士／王后／國王
enum NumdayRelation { sync, echo, court }

/// 牌的數字：大牌＝牌號（愚者 0）、數字牌＝1–10；宮廷牌沒有數字（null）。
int? numdayCardNumber(TarotCard c) => c.number;

NumdayRelation numdayRelation(TarotCard c, int day) {
  final n = numdayCardNumber(c);
  if (n == null) return NumdayRelation.court;
  if (n != 0 && Numerology.single(n) == day) return NumdayRelation.sync;
  return NumdayRelation.echo;
}

/// 由牌、正逆位與日期算出固定的模板版本序號（同一天同一張牌回看時文字不變；免費體驗也記這個）。
int numdaySeed(DrawnCard c, DateTime date) =>
    [c.cardId, c.reversed ? 1 : 0, date.year, date.month, date.day].fold(23, (a, b) => (a * 31 + b) & 0x3fffffff);

/// 組好的流日 × 今日一牌（四段）。
class NumdayReport {
  const NumdayReport({
    required this.day,
    required this.card,
    required this.relation,
    required this.header,
    required this.relationName,
    required this.relationLead,
    required this.dayTheme,
    required this.dayText,
    required this.cardText,
    required this.affirmation,
    required this.meet,
    required this.practice,
    required this.reflectLabel,
    required this.reflection,
    required this.disclaimer,
  });

  final int day;
  final DrawnCard card;
  final NumdayRelation relation;
  final String header, relationName, relationLead;
  final String dayTheme;
  final List<String> dayText;
  final String cardText, affirmation, meet, practice, reflectLabel, reflection, disclaimer;
}

/// 流日 × 今日一牌模板（tarot-content `cross/<語言>/numday.json`；缺的語言退回英文）。
class NumdayTemplates {
  NumdayTemplates(this._j);

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

  static String _pick(List<String> xs, int seed) => xs.isEmpty ? '' : xs[seed.abs() % xs.length];

  static String _fill(String tpl, Map<String, String> v) =>
      v.entries.fold(tpl, (s, e) => s.replaceAll('{${e.key}}', e.value));

  String sectionTitle(String key) => _str('sections', key);

  String relationName(NumdayRelation r) => _str('relationNames', r.name);

  String get keywordSep => (_j['keywordSep'] ?? '、').toString();

  String get disclaimer => (_j['disclaimer'] ?? '').toString();

  String header(int day) => _fill(_str('format', 'header').isEmpty ? '{n}' : _str('format', 'header'), {'n': '$day'});

  /// [numbers]：numbers.json 的數字文字（流日主題與牌數字的關鍵字）。[cardName]：牌名（含逆位標示由呼叫端決定）。
  NumdayReport compose({
    required int day,
    required DrawnCard card,
    required String cardName,
    required Map<int, NumberText> numbers,
    List<String> keywords = const [],
    String affirmation = '',
    required int seed,
  }) {
    final c = card.card;
    final rel = numdayRelation(c, day);
    final sep = keywordSep;
    final dayNum = numbers[day];
    final dayKw = (dayNum?.keywords ?? const <String>[]).join(sep);
    final n = numdayCardNumber(c);
    final cardKw = n == null
        ? ''
        : n == 0
            ? _str('zero', 'keywords')
            : (numbers[Numerology.single(n)]?.keywords ?? const <String>[]).join(sep);
    final nameTpl = _str('format', 'name').isEmpty ? '{name}' : _str('format', 'name');
    final name = _fill(nameTpl, {'name': cardName});
    final values = {
      'n': '$day',
      'dayKw': dayKw,
      'card': name,
      'cardNum': n == null ? '' : '$n',
      'cardKw': cardKw,
      'kw': keywords.join(sep),
      'role': c.rank == null ? '' : _str('courtRoles', c.rank!.name),
    };
    final affTpl = _str('format', 'affirmation');
    return NumdayReport(
      day: day,
      card: card,
      relation: rel,
      header: header(day),
      relationName: relationName(rel),
      relationLead: _str('relationLead', rel.name),
      dayTheme: dayNum?.dayTheme ?? '',
      dayText: [
        if ((dayNum?.dayText ?? '').isNotEmpty) dayNum!.dayText,
        if (_pick(_list('day', '$day'), seed).isNotEmpty) _pick(_list('day', '$day'), seed),
      ],
      cardText: _fill(_pick(_list('card', card.reversed ? 'reversed' : 'upright'), seed ~/ 3), values),
      affirmation: affirmation.isEmpty ? '' : _fill(affTpl.isEmpty ? '{text}' : affTpl, {'text': affirmation}),
      meet: _fill(_pick(_list('meet', rel.name), seed ~/ 7), values),
      practice: _pick(_list('practice', '$day'), seed ~/ 5),
      reflectLabel: _str('format', 'reflect'),
      reflection: _pick(_list('reflection', rel.name), seed ~/ 11),
      disclaimer: disclaimer,
    );
  }
}

/// 從 App 資產讀模板：assets/cross/<語言>/numday.json（其他語言退回英文）。
Future<NumdayTemplates> loadNumdayTemplates(String contentFolder, {AssetBundle? bundle}) async {
  final f = AssetLenormandSource.folderFor(contentFolder);
  for (final dir in {f, 'en'}) {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/cross/$dir/numday.json');
      return NumdayTemplates(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      debugPrint('流日交叉模板讀取失敗：$dir');
    }
  }
  return NumdayTemplates(const {});
}
