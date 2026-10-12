import '../tarot/atmosphere.dart';

/// 牌面上一個可點的象徵物：以牌面圖寬高為 1 的相對座標，[r] 為點擊範圍半徑（相對寬度）。
/// 名稱與意義在解讀內容（CardContent.symbols，依 [id] 對應），座標依牌面組而不同。
class SymbolSpot {
  const SymbolSpot(this.id, this.x, this.y, this.r);

  final String id;
  final double x, y, r;

  static SymbolSpot? tryFromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], x = j['x'], y = j['y'];
    if (id is! String || x is! num || y is! num) return null;
    final r = j['r'];
    return SymbolSpot(id, x.toDouble(), y.toDouble(), r is num ? r.toDouble() : 0.07);
  }
}

/// 一張牌在某牌面組的標註：人物面向與象徵物位置。
class CardAnnotation {
  const CardAnnotation({this.facing = Facing.none, this.symbols = const []});

  final Facing facing;
  final List<SymbolSpot> symbols;
}

/// 牌面組（策略：新增一組牌面＝新增一個資料夾 assets/decks/<id>/，含 deck.json 與 00–77.webp，
/// 再把 id 加進 assets/decks/decks.json）。名稱與出處依語言寫在 deck.json。
class Deck {
  Deck({
    required this.id,
    required Map<String, String> name,
    required Map<String, String> credit,
    required this.premium,
    required this.aiGenerated,
    required this.aspect,
    required this.annotations,
    this.backAsset,
  })  : _name = name,
        _credit = credit;

  final String id;
  final Map<String, String> _name, _credit;

  /// 會員牌面組（免費版看得到但不能選）。
  final bool premium;

  /// AI 生成的圖（商店與牌面組說明需標示）。
  final bool aiGenerated;

  /// 牌面圖寬高比（寬÷高）。
  final double aspect;

  /// 牌背圖（資產路徑）；null＝用程式畫的牌背。
  final String? backAsset;
  final Map<int, CardAnnotation> annotations;

  String name(String lang) => _name[lang] ?? _name['en'] ?? _name.values.firstOrNull ?? id;
  String credit(String lang) => _credit[lang] ?? _credit['en'] ?? _credit.values.firstOrNull ?? '';

  CardAnnotation annotation(int cardId) => annotations[cardId] ?? const CardAnnotation();

  String artPath(int cardId) => 'assets/decks/$id/${cardId.toString().padLeft(2, '0')}.webp';

  factory Deck.fromJson(Map<String, dynamic> j) {
    Map<String, String> strings(Object? o) =>
        o is Map ? {for (final e in o.entries) e.key.toString(): e.value.toString()} : <String, String>{};
    final cards = <int, CardAnnotation>{};
    final raw = j['cards'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final id = int.tryParse(e.key.toString());
        final v = e.value;
        if (id == null || v is! Map) continue;
        cards[id] = CardAnnotation(
          facing: Facing.values.asNameMap()[v['facing']] ?? Facing.none,
          symbols: [
            for (final s in (v['symbols'] is List ? v['symbols'] as List : const [])) SymbolSpot.tryFromJson(s),
          ].whereType<SymbolSpot>().toList(),
        );
      }
    }
    final id = (j['id'] ?? '').toString();
    final back = j['back'];
    return Deck(
      id: id,
      name: strings(j['name']),
      credit: strings(j['credit']),
      premium: j['premium'] == true,
      aiGenerated: j['aiGenerated'] == true,
      aspect: (j['aspect'] is num) ? (j['aspect'] as num).toDouble() : 0.58,
      annotations: cards,
      backAsset: back is String && back.isNotEmpty ? 'assets/decks/$id/$back' : null,
    );
  }
}
