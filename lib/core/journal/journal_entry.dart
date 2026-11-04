import '../content/reading_area.dart';
import '../tarot/draw.dart';
import '../tarot/spread.dart';

/// 事後的一次回顧：後來發生了什麼、牌面的象怎麼對上。
class FollowUp {
  const FollowUp({required this.at, required this.text});

  final DateTime at;
  final String text;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'text': text};

  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        text: j['text'] as String? ?? '',
      );
}

/// 一筆塔羅日記：牌陣與抽到的牌、想問的事、第一眼注意到的、當時看到的那幾組解讀，以及之後的回顧。
/// 只存在手機裡。
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.createdAt,
    required this.spreadId,
    required this.methodId,
    required List<DrawnCard> cards,
    this.question = '',
    this.firstImpression = '',
    this.area = '',
    List<int?> readingIndexes = const [],
    this.deckId = '',
    this.reminderAt,
    List<FollowUp> followUps = const [],
    List<int> lenormand = const [],
    this.verdict = '',
  })  : cards = List.unmodifiable(cards),
        lenormand = List.unmodifiable(lenormand),
        readingIndexes = List.unmodifiable(readingIndexes),
        followUps = List.unmodifiable(followUps);

  factory JournalEntry.fromDraw({
    required SpreadDraw draw,
    required DateTime now,
    String question = '',
    String firstImpression = '',
    String area = '',
    List<int?> readingIndexes = const [],
    String deckId = '',
    DateTime? reminderAt,
    List<int> lenormand = const [],
  }) =>
      JournalEntry(
        id: now.microsecondsSinceEpoch.toRadixString(36),
        createdAt: now,
        spreadId: draw.spreadId,
        methodId: draw.methodId,
        cards: draw.cards,
        question: question,
        firstImpression: firstImpression,
        area: area,
        readingIndexes: readingIndexes,
        deckId: deckId,
        reminderAt: reminderAt,
        lenormand: lenormand,
      );

  final String id;
  final DateTime createdAt;
  final String spreadId;
  final String methodId;
  final List<DrawnCard> cards;
  final String question;

  /// 翻牌後、看解讀前寫下的「第一眼注意到什麼」（直覺）。
  final String firstImpression;

  /// 問題類型（ReadingAreas：love、work、self；空字串＝不指定）。
  final String area;

  /// 每張牌當時隨機顯示的是第幾組解讀；回顧時顯示同一組。內容尚未撰寫時為 null。
  final List<int?> readingIndexes;
  final String deckId;
  final DateTime? reminderAt;
  final List<FollowUp> followUps;

  /// 塔羅 × 雷諾曼交叉解讀時抽到的雷諾曼牌（1–36）；一般塔羅紀錄為空。
  final List<int> lenormand;

  /// 交叉紀錄回顧「事後應驗了嗎？」：yes／partial／no；空字串＝還沒選。
  final String verdict;

  bool get isCross => lenormand.isNotEmpty;

  static const verdicts = ['yes', 'partial', 'no'];

  SpreadDraw get draw => SpreadDraw(spreadId: spreadId, methodId: methodId, cards: cards);

  Spread get spread => Spreads.byId(spreadId);

  DrawnCard get keyCard => draw.keyCard;

  int? readingIndex(int position) => position < readingIndexes.length ? readingIndexes[position] : null;

  /// 通知 id：由建立時間推得，固定不變（取消或改期時用同一個）。
  int get notificationId => (createdAt.millisecondsSinceEpoch ~/ 1000) % 0x7fffffff;

  JournalEntry copyWith({
    String? question,
    String? firstImpression,
    DateTime? reminderAt,
    bool clearReminder = false,
    List<FollowUp>? followUps,
    String? verdict,
  }) =>
      JournalEntry(
        id: id,
        createdAt: createdAt,
        spreadId: spreadId,
        methodId: methodId,
        cards: cards,
        question: question ?? this.question,
        firstImpression: firstImpression ?? this.firstImpression,
        area: area,
        readingIndexes: readingIndexes,
        deckId: deckId,
        reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
        followUps: followUps ?? this.followUps,
        lenormand: lenormand,
        verdict: verdict ?? this.verdict,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'spread': spreadId,
        'methodId': methodId,
        'cards': [for (final c in cards) c.toJson()],
        'question': question,
        if (firstImpression.isNotEmpty) 'firstImpression': firstImpression,
        if (area.isNotEmpty) 'area': area,
        'readingIndexes': readingIndexes,
        if (deckId.isNotEmpty) 'deck': deckId,
        if (reminderAt != null) 'reminderAt': reminderAt!.toIso8601String(),
        'followUps': [for (final f in followUps) f.toJson()],
        if (lenormand.isNotEmpty) 'lenormand': lenormand,
        if (verdict.isNotEmpty) 'verdict': verdict,
      };

  /// 寬鬆解析：欄位缺漏給預設值；牌不合法或數量與牌陣不符時回傳 null（略過該筆）。
  static JournalEntry? tryFromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse(j['createdAt'] as String? ?? '');
    if (created == null) return null;
    final rawCards = j['cards'];
    if (rawCards is! List) return null;
    final cards = [for (final c in rawCards) DrawnCard.tryFromJson(c)];
    if (cards.isEmpty || cards.any((c) => c == null)) return null;
    final spreadId = j['spread'] as String? ?? 'one';
    if (Spreads.byId(spreadId).size != cards.length) return null;
    final idx = j['readingIndexes'];
    return JournalEntry(
      id: j['id'] as String? ?? created.microsecondsSinceEpoch.toRadixString(36),
      createdAt: created,
      spreadId: spreadId,
      methodId: j['methodId'] as String? ?? DrawMethods.quick,
      cards: cards.cast<DrawnCard>(),
      question: j['question'] as String? ?? '',
      firstImpression: j['firstImpression'] as String? ?? '',
      area: ReadingAreas.all.contains(j['area']) ? j['area'] as String : '',
      readingIndexes: idx is List ? [for (final i in idx) i is int ? i : null] : const [],
      deckId: j['deck'] as String? ?? '',
      reminderAt: DateTime.tryParse(j['reminderAt'] as String? ?? ''),
      followUps: [
        for (final f in (j['followUps'] as List? ?? const []))
          if (f is Map<String, dynamic>) FollowUp.fromJson(f),
      ],
      lenormand: [
        for (final x in (j['lenormand'] is List ? j['lenormand'] as List : const []))
          if (x is int && x >= 1 && x <= 36) x,
      ],
      verdict: verdicts.contains(j['verdict']) ? j['verdict'] as String : '',
    );
  }
}
