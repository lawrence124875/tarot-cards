/// 一張牌的解讀內容（對應 tarot-content/<語言>/NN.json，結構見 tarot-content/README.md）。
/// 解析採寬鬆模式：缺欄位給空字串，多出的欄位忽略，日後新增欄位不會讓舊版壞掉。
class CardContent {
  CardContent({
    required this.id,
    required this.name,
    required this.keywordsUpright,
    required this.keywordsReversed,
    required this.waite,
    required this.upright,
    required this.reversed,
    required this.symbols,
    required this.affirmation,
    this.eastWest,
    this.areas = const {},
  });

  final int id;

  /// 內容檔裡的牌名（介面一律用 l10n 的牌名表；這裡只供檢查）。
  final String name;
  final List<String> keywordsUpright, keywordsReversed;
  final WaiteText waite;

  /// 正位三組、逆位三組解讀（每組從不同角度看象：人物動作／象徵與顏色／數字與元素）。
  final List<ReadingContent> upright, reversed;

  /// 牌面上可點的象徵物（位置由牌面組 deck.json 提供，依 id 對應）。
  final List<SymbolContent> symbols;

  /// 今日一張的肯定語。
  final String affirmation;
  final EastWestContent? eastWest;

  /// 面向解讀：`upright`／`reversed` → `love`、`work`、`self` 各一句（使用者選了問題類型時顯示）。
  final Map<String, Map<String, String>> areas;

  /// 該面向的一句；沒寫時回傳空字串。
  String area(bool isReversed, String area) => areas[isReversed ? 'reversed' : 'upright']?[area] ?? '';

  List<ReadingContent> readings(bool isReversed) => isReversed ? reversed : upright;

  List<String> keywords(bool isReversed) => isReversed ? keywordsReversed : keywordsUpright;

  SymbolContent? symbol(String id) {
    for (final s in symbols) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory CardContent.fromJson(Map<String, dynamic> j) {
    final kw = _map(j['keywords']);
    return CardContent(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: _s(j, 'name'),
      keywordsUpright: _strings(kw['upright']),
      keywordsReversed: _strings(kw['reversed']),
      waite: WaiteText.fromJson(_map(j['waite'])),
      upright: [for (final r in _list(j['upright'])) ReadingContent.fromJson(_map(r))],
      reversed: [for (final r in _list(j['reversed'])) ReadingContent.fromJson(_map(r))],
      symbols: [for (final s in _list(j['symbols'])) SymbolContent.fromJson(_map(s))],
      affirmation: _s(j, 'affirmation'),
      eastWest: j['eastWest'] is Map ? EastWestContent.fromJson(_map(j['eastWest'])) : null,
      areas: {
        for (final e in _map(j['areas']).entries)
          e.key: {for (final a in _map(e.value).entries) a.key: a.value.toString()},
      },
    );
  }
}

/// Waite《The Pictorial Key to the Tarot》（1910，公有領域）的牌面描述與占卜意義，依原著自行翻譯。
class WaiteText {
  WaiteText.fromJson(Map<String, dynamic> j)
      : description = _s(j, 'description'),
        upright = _s(j, 'upright'),
        reversed = _s(j, 'reversed'),
        source = _s(j, 'source'),
        translationNote = _s(j, 'translationNote');

  final String description, upright, reversed, source, translationNote;

  bool get isEmpty => description.isEmpty && upright.isEmpty;
}

/// 一組解讀。[angle]：figure（人物與動作）、symbol（象徵與顏色）、number（數字與元素）。
class ReadingContent {
  ReadingContent.fromJson(Map<String, dynamic> j)
      : angle = _s(j, 'angle'),
        title = _s(j, 'title'),
        image = _s(j, 'image'),
        source = _s(j, 'source'),
        meaning = _s(j, 'meaning'),
        forYou = _s(j, 'forYou'),
        action = _s(j, 'action'),
        question = _s(j, 'question');

  final String angle, title, image, source, meaning, forYou, action, question;
}

class SymbolContent {
  SymbolContent.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        name = _s(j, 'name'),
        meaning = _s(j, 'meaning');

  final String id, name, meaning;
}

class EastWestContent {
  EastWestContent.fromJson(Map<String, dynamic> j)
      : quoteText = _s(_map(j['quote']), 'text'),
        quoteAuthor = _s(_map(j['quote']), 'author'),
        quoteSource = _s(_map(j['quote']), 'source'),
        quoteTranslationNote = _s(_map(j['quote']), 'translationNote'),
        quoteNote = _s(_map(j['quote']), 'note'),
        psyName = _s(_map(j['psychology']), 'name'),
        psyOrigin = _s(_map(j['psychology']), 'origin'),
        psyEvidence = _s(_map(j['psychology']), 'evidenceNote'),
        psyNote = _s(_map(j['psychology']), 'note');

  final String quoteText, quoteAuthor, quoteSource, quoteTranslationNote, quoteNote;
  final String psyName, psyOrigin, psyEvidence, psyNote;

  bool get hasQuote => quoteText.isNotEmpty;
  bool get hasPsychology => psyName.isNotEmpty;
}

/// 牌陣的名稱、說明與各位置的名稱與意義（內容檔 spreads.json）。
class SpreadTexts {
  SpreadTexts.fromJson(Map<String, dynamic> j)
      : spreads = {
          for (final e in _map(j['spreads']).entries) e.key: SpreadText.fromJson(_map(e.value)),
        };

  final Map<String, SpreadText> spreads;

  SpreadText? operator [](String id) => spreads[id];
}

class SpreadText {
  SpreadText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        description = _s(j, 'description'),
        source = _s(j, 'source'),
        positions = {
          for (final e in _map(j['positions']).entries) e.key: PositionText.fromJson(_map(e.value)),
        };

  final String name, description, source;
  final Map<String, PositionText> positions;
}

class PositionText {
  PositionText.fromJson(Map<String, dynamic> j)
      : name = _s(j, 'name'),
        meaning = _s(j, 'meaning'),
        prompt = _s(j, 'prompt');

  final String name, meaning;

  /// 把這個位置放回自己問題裡的引導提問（可為空）。
  final String prompt;
}

/// 整體氛圍各規則的文字（內容檔 atmosphere.json）：鍵為規則代碼，值為字串或依子代碼分的字串表。
/// 文字裡的 {cards}、{count}、{element}、{number}、{a}、{b} 由畫面填入。
class AtmosphereTexts {
  AtmosphereTexts(this._raw);

  factory AtmosphereTexts.fromJson(Map<String, dynamic> j) => AtmosphereTexts(j);

  final Map<String, dynamic> _raw;

  /// [sub] 為子代碼（例如元素 fire、互動 contrary、數字 3）；找不到時回傳空字串。
  String text(String code, [String? sub]) {
    final v = _raw[code];
    if (v is String) return v;
    if (v is Map && sub != null) return (v[sub] ?? '').toString();
    return '';
  }

  String get intro => text('intro');
  String get note => text('note');
}

/// 學習課程（內容檔 lessons.json）：單元 → 課 → 段落。
class LessonBook {
  LessonBook.fromJson(Map<String, dynamic> j)
      : units = [for (final u in _list(j['units'])) LessonUnit.fromJson(_map(u))];

  final List<LessonUnit> units;
}

class LessonUnit {
  LessonUnit.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        title = _s(j, 'title'),
        summary = _s(j, 'summary'),
        free = j['free'] == true,
        lessons = [for (final l in _list(j['lessons'])) Lesson.fromJson(_map(l))];

  final String id, title, summary;
  final bool free;
  final List<Lesson> lessons;

  bool get ready => lessons.isNotEmpty;
}

class Lesson {
  Lesson.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        title = _s(j, 'title'),
        sections = [for (final s in _list(j['sections'])) LessonSection.fromJson(_map(s))],
        sources = _strings(j['sources']),
        cards = [for (final c in _list(j['cards'])) if (c is num) c.toInt()];

  final String id, title;
  final List<LessonSection> sections;
  final List<String> sources;

  /// 這一課提到的牌（課末可點開）。
  final List<int> cards;
}

class LessonSection {
  LessonSection.fromJson(Map<String, dynamic> j)
      : heading = _s(j, 'heading'),
        body = _s(j, 'body');

  final String heading, body;
}

String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();

Map<String, dynamic> _map(Object? o) =>
    o is Map ? o.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};

List<Object?> _list(Object? o) => o is List ? o : const [];

List<String> _strings(Object? o) => [for (final x in _list(o)) if (x != null) x.toString()];
