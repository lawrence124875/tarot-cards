/// 四元素（黃金黎明 Book T 的元素對應）。介面名稱在 l10n（TarotTerms.elementName）。
enum TarotElement { fire, water, air, earth }

/// 小阿爾克那四花色與元素：權杖火、聖杯水、寶劍風、錢幣土（Waite 與黃金黎明通行的對應）。
enum Suit {
  wands(TarotElement.fire),
  cups(TarotElement.water),
  swords(TarotElement.air),
  pentacles(TarotElement.earth);

  const Suit(this.element);

  final TarotElement element;
}

/// 小阿爾克那的牌階：Ace＝1 … 10，接著侍者、騎士、皇后、國王。
enum Rank {
  ace(1),
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  page(11),
  knight(12),
  queen(13),
  king(14);

  const Rank(this.value);

  /// 1–14；數字牌 1–10。
  final int value;

  bool get isCourt => value > 10;
}

/// 大阿爾克那的占星／元素對應（黃金黎明，1888 年後的會內文件，經 Waite 牌序調整：8 力量、11 正義）。
/// 行星牌的元素取該行星守護星座的元素，只用於音景與元素互動（App 的設定，見 HANDOFF）。
enum Attribution {
  air(TarotElement.air),
  water(TarotElement.water),
  fire(TarotElement.fire),
  mercury(TarotElement.air),
  moon(TarotElement.water),
  venus(TarotElement.earth),
  jupiter(TarotElement.fire),
  mars(TarotElement.fire),
  sun(TarotElement.fire),
  saturn(TarotElement.earth),
  aries(TarotElement.fire),
  taurus(TarotElement.earth),
  gemini(TarotElement.air),
  cancer(TarotElement.water),
  leo(TarotElement.fire),
  virgo(TarotElement.earth),
  libra(TarotElement.air),
  scorpio(TarotElement.water),
  sagittarius(TarotElement.fire),
  capricorn(TarotElement.earth),
  aquarius(TarotElement.air),
  pisces(TarotElement.water);

  const Attribution(this.element);

  final TarotElement element;
}

/// 一張牌的基本資料（不含解讀；解讀由 ContentSource 依語言提供）。
/// [id]：00–21 大阿爾克那；22–35 權杖 Ace…King；36–49 聖杯；50–63 寶劍；64–77 錢幣。
/// 內容檔與圖檔都以兩位數 [code] 命名（00.json、22.webp）。
class TarotCard {
  const TarotCard._(this.id, this.key, {this.suit, this.rank, this.attribution});

  final int id;

  /// 英文代號（內容與術語表對照用）：fool、magician…、wands-ace、cups-king。
  final String key;
  final Suit? suit;
  final Rank? rank;

  /// 只有大阿爾克那有。
  final Attribution? attribution;

  bool get isMajor => suit == null;
  bool get isCourt => rank?.isCourt ?? false;

  /// 大阿爾克那的牌號 0–21。
  int? get majorNumber => isMajor ? id : null;

  /// 數字（大阿爾克那為牌號；小阿爾克那 Ace＝1…10，宮廷牌為 null）。數字重複、數字流動用。
  int? get number => isMajor ? id : (isCourt ? null : rank!.value);

  TarotElement get element => isMajor ? attribution!.element : suit!.element;

  String get code => id.toString().padLeft(2, '0');

  static const _majorKeys = [
    'fool', 'magician', 'high-priestess', 'empress', 'emperor', 'hierophant', 'lovers',
    'chariot', 'strength', 'hermit', 'wheel-of-fortune', 'justice', 'hanged-man', 'death',
    'temperance', 'devil', 'tower', 'star', 'moon', 'sun', 'judgement', 'world',
  ];

  static const _majorAttributions = [
    Attribution.air, Attribution.mercury, Attribution.moon, Attribution.venus, Attribution.aries,
    Attribution.taurus, Attribution.gemini, Attribution.cancer, Attribution.leo, Attribution.virgo,
    Attribution.jupiter, Attribution.libra, Attribution.water, Attribution.scorpio, Attribution.sagittarius,
    Attribution.capricorn, Attribution.mars, Attribution.aquarius, Attribution.pisces, Attribution.sun,
    Attribution.fire, Attribution.saturn,
  ];

  static const count = 78;

  static final List<TarotCard> all = List.unmodifiable([
    for (var i = 0; i < 22; i++) TarotCard._(i, _majorKeys[i], attribution: _majorAttributions[i]),
    for (final s in Suit.values)
      for (final r in Rank.values) TarotCard._(22 + s.index * 14 + r.index, '${s.name}-${r.name}', suit: s, rank: r),
  ]);

  static TarotCard byId(int id) => all[id];

  static Iterable<TarotCard> get majors => all.take(22);

  static Iterable<TarotCard> ofSuit(Suit s) => all.skip(22 + s.index * 14).take(14);
}
