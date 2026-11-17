import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../content/card_content.dart';
import '../settings/json_file.dart';

/// 生命靈數計算（tarot-content `numerology/`，Lawrence 2026-11-17 確認的規則）。
///
/// - 化簡：各位數相加直到 1–9；途中出現主數（11、22、33）就停。
/// - 生命靈數：年、月、日各自化簡（各段遇 11、22 保留）再相加，總和再化簡（主數保留）。
/// - 生日數：出生「日」化簡（11、22 保留）。
/// - 個人流年：出生月＋出生日＋今年（各自化簡）→ 化簡（元旦切換）。流月＝流年＋本月；流日＝流月＋今天，一律化簡為 1–9。
/// - 高峰數：月＋日、日＋年、前兩者相加、月＋年；第 1 期到「36 − 生命靈數個位」歲，之後每期 9 年。
/// - 挑戰數：月、日、年的個位數兩兩相減（0–8）：|月−日|、|日−年|、兩者再相減、|月−年|。
class Numerology {
  Numerology._();

  static const masters = {11, 22, 33};

  /// 所有可能出現的數字（生命靈數、流年等）：1–9 與主數。
  static const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22, 33];

  static int _digitSum(int n) {
    var s = 0;
    for (var x = n.abs(); x > 0; x ~/= 10) {
      s += x % 10;
    }
    return s;
  }

  /// 化簡到 1–9；[keep] 裡的主數遇到就停。0 維持 0（挑戰數用）。
  static int reduce(int n, {Set<int> keep = masters}) {
    var x = n.abs();
    while (x > 9 && !keep.contains(x)) {
      x = _digitSum(x);
    }
    return x;
  }

  /// 化簡到個位數（1–9，不保留主數）。
  static int single(int n) => reduce(n, keep: const {});

  /// 年、月、日各段的化簡（各段遇 11、22 保留）。
  static int part(int n) => reduce(n, keep: const {11, 22});

  static int lifePath(DateTime birth) => reduce(part(birth.year) + part(birth.month) + part(birth.day));

  static int birthday(DateTime birth) => reduce(birth.day);

  static int personalYear(DateTime birth, DateTime now) =>
      reduce(part(birth.month) + part(birth.day) + part(now.year));

  static int personalMonth(DateTime birth, DateTime now) => reduce(personalYear(birth, now) + now.month);

  static int personalDay(DateTime birth, DateTime now) => single(personalMonth(birth, now) + now.day);

  /// 四個高峰期（數字與起訖年齡；最後一期 [Period.toAge] 為 null）。
  static List<Period> pinnacles(DateTime birth) {
    final m = part(birth.month), d = part(birth.day), y = part(birth.year);
    final p1 = reduce(m + d), p2 = reduce(d + y);
    final nums = [p1, p2, reduce(p1 + p2), reduce(m + y)];
    return _periods(birth, nums);
  }

  /// 四個挑戰期（數字 0–8，年齡與高峰期相同）。
  static List<Period> challenges(DateTime birth) {
    final m = single(birth.month), d = single(birth.day), y = single(birth.year);
    final c1 = (m - d).abs(), c2 = (d - y).abs();
    return _periods(birth, [c1, c2, (c1 - c2).abs(), (m - y).abs()]);
  }

  static List<Period> _periods(DateTime birth, List<int> nums) {
    final end1 = 36 - single(lifePath(birth));
    final ends = [end1, end1 + 9, end1 + 18, null];
    var from = 0;
    return [
      for (var i = 0; i < 4; i++)
        () {
          final p = Period(index: i, number: nums[i], fromAge: from, toAge: ends[i]);
          from = (ends[i] ?? 0) + 1;
          return p;
        }(),
    ];
  }

  /// 目前滿幾歲（手機當地日期）。
  static int age(DateTime birth, DateTime now) {
    var a = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) a--;
    return a < 0 ? 0 : a;
  }

  /// 目前所在的期（0–3）。
  static int currentPeriod(List<Period> periods, int age) {
    for (final p in periods) {
      if (p.toAge == null || age <= p.toAge!) return p.index;
    }
    return periods.length - 1;
  }
}

/// 高峰期／挑戰期。
@immutable
class Period {
  const Period({required this.index, required this.number, required this.fromAge, this.toAge});

  final int index;
  final int number;
  final int fromAge;
  final int? toAge;
}

/// 生日只存本機 `numerology.json`（不上傳、不進統計，日記備份也不含）。
class BirthdayStore {
  BirthdayStore({KeyValueFile? store}) : _store = store ?? FileKeyValue('numerology.json');

  final KeyValueFile _store;

  /// 生日變動時通知（靈數首頁、每日一牌）。
  final ValueNotifier<DateTime?> birthday = ValueNotifier(null);
  bool _loaded = false;

  Future<DateTime?> load() async {
    if (_loaded) return birthday.value;
    final j = await _store.read();
    final s = j['birth'];
    birthday.value = s is String ? DateTime.tryParse(s) : null;
    _loaded = true;
    return birthday.value;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> save(DateTime d) async {
    final day = DateTime(d.year, d.month, d.day);
    await _store.write({'birth': _fmt(day)});
    _loaded = true;
    birthday.value = day;
  }

  Future<void> clear() async {
    await _store.write({});
    _loaded = true;
    birthday.value = null;
  }
}

/// 一個數字的文字（`numerology/<語言>/numbers.json` 的 numbers[]）。
class NumberText {
  NumberText.fromJson(Map<String, dynamic> j)
      : n = (j['n'] as num?)?.toInt() ?? 0,
        name = _s(j, 'name'),
        keywords = _strings(j['keywords']),
        essence = _s(j, 'essence'),
        lifeGift = _s(_map(j['lifePath']), 'gift'),
        lifeInnerWork = _s(_map(j['lifePath']), 'innerWork'),
        lifePractice = _s(_map(j['lifePath']), 'practice'),
        lifeQuestion = _s(_map(j['lifePath']), 'question'),
        birthday = _s(_map(j['birthday']), 'text'),
        yearTheme = _s(_map(j['year']), 'theme'),
        yearText = _s(_map(j['year']), 'text'),
        yearPractice = _s(_map(j['year']), 'practice'),
        month = _s(_map(j['month']), 'text'),
        dayTheme = _s(_map(j['day']), 'theme'),
        dayText = _s(_map(j['day']), 'text'),
        pinnacle = _s(_map(j['pinnacle']), 'text');

  final int n;
  final String name, essence;
  final List<String> keywords;
  final String lifeGift, lifeInnerWork, lifePractice, lifeQuestion;
  final String birthday;
  final String yearTheme, yearText, yearPractice;
  final String month;
  final String dayTheme, dayText;
  final String pinnacle;
}

/// 挑戰數 0–8 的文字（numbers.json 的 challenges[]）。
class ChallengeText {
  ChallengeText.fromJson(Map<String, dynamic> j)
      : n = (j['n'] as num?)?.toInt() ?? 0,
        text = _s(j, 'text'),
        practice = _s(j, 'practice');

  final int n;
  final String text, practice;
}

class NumerologyTexts {
  const NumerologyTexts({this.numbers = const {}, this.challenges = const {}});

  final Map<int, NumberText> numbers;
  final Map<int, ChallengeText> challenges;

  bool get isEmpty => numbers.isEmpty;
}

abstract class NumerologySource {
  Future<NumerologyTexts> texts();
  Future<LessonBook?> lessons();
}

/// 從 App 資產讀取：assets/numerology/<語言資料夾>/numbers.json、lessons.json；讀不到時退回英文。
class AssetNumerologySource implements NumerologySource {
  AssetNumerologySource({required this.folder, AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final String Function() folder;
  final AssetBundle _bundle;
  final Map<String, Object?> _cache = {};

  static const contentFolders = {'zh-Hant', 'zh-Hans', 'en', 'ja', 'ko', 'vi', 'id', 'es', 'pt-BR', 'th', 'ar'};

  static String folderFor(String contentFolder) => contentFolders.contains(contentFolder) ? contentFolder : 'en';

  Future<Map<String, dynamic>?> _json(String name) async {
    final f = folderFor(folder());
    for (final dir in {f, 'en'}) {
      final path = 'assets/numerology/$dir/$name';
      if (_cache.containsKey(path)) {
        final v = _cache[path];
        if (v != null) return v as Map<String, dynamic>;
        continue;
      }
      Map<String, dynamic>? result;
      try {
        result = jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('生命靈數內容讀取失敗：$path');
      }
      _cache[path] = result;
      if (result != null) return result;
    }
    return null;
  }

  @override
  Future<NumerologyTexts> texts() async {
    final j = await _json('numbers.json');
    return NumerologyTexts(
      numbers: {
        for (final x in _list(j?['numbers']))
          if (_map(x)['n'] is num) (_map(x)['n'] as num).toInt(): NumberText.fromJson(_map(x)),
      },
      challenges: {
        for (final x in _list(j?['challenges']))
          if (_map(x)['n'] is num) (_map(x)['n'] as num).toInt(): ChallengeText.fromJson(_map(x)),
      },
    );
  }

  @override
  Future<LessonBook?> lessons() async {
    final j = await _json('lessons.json');
    return j == null ? null : LessonBook.fromJson(j);
  }
}

/// 測試與沒有內容時：全部空的。
class EmptyNumerologySource implements NumerologySource {
  const EmptyNumerologySource();

  @override
  Future<NumerologyTexts> texts() async => const NumerologyTexts();

  @override
  Future<LessonBook?> lessons() async => null;
}

String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();

Map<String, dynamic> _map(Object? o) =>
    o is Map ? o.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};

List<Object?> _list(Object? o) => o is List ? o : const [];

List<String> _strings(Object? o) => [for (final x in _list(o)) if (x != null) x.toString()];
