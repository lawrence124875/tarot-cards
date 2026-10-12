import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'deck.dart';

/// 牌面組來源（依賴反轉）：可用的牌面組、目前選的那組、牌面圖。
abstract class DeckSource {
  /// 圖檔齊全（78 張）的牌面組，依 decks.json 的順序。
  Future<List<Deck>> decks();

  /// 依 id 找；找不到時回傳第一組（沒有任何牌面組時為 null，畫面顯示程式畫的牌面）。
  Future<Deck?> deck(String id);

  Future<ImageProvider?> cardArt(Deck? deck, int cardId);

  Future<Uint8List?> cardArtBytes(Deck? deck, int cardId);
}

/// 讀 assets/decks/decks.json 與各資料夾的 deck.json（由 CI 從私人 repo 匯入；圖檔不進公開 repo）。
class AssetDeckSource implements DeckSource {
  AssetDeckSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<List<Deck>>? _decks;
  Future<Set<String>>? _assets;

  Future<Set<String>> _assetList() => _assets ??= _loadAssetList();

  Future<Set<String>> _loadAssetList() async {
    try {
      return (await AssetManifest.loadFromAssetBundle(_bundle)).listAssets().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<List<Deck>> decks() => _decks ??= _load();

  Future<List<Deck>> _load() async {
    final assets = await _assetList();
    if (!assets.contains('assets/decks/decks.json')) return const [];
    try {
      final index = jsonDecode(await _bundle.loadString('assets/decks/decks.json')) as Map<String, dynamic>;
      final out = <Deck>[];
      for (final id in (index['decks'] as List? ?? const [])) {
        final path = 'assets/decks/$id/deck.json';
        if (!assets.contains(path)) continue;
        try {
          final d = Deck.fromJson(jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>);
          // 圖檔不齊的牌面組（例如 AI 牌面還在生成）不開放
          final complete = [for (var i = 0; i < 78; i++) d.artPath(i)].every(assets.contains);
          if (complete) out.add(d);
        } catch (e) {
          debugPrint('牌面組解析失敗：$path（$e）');
        }
      }
      return out;
    } catch (e) {
      debugPrint('decks.json 解析失敗（$e）');
      return const [];
    }
  }

  @override
  Future<Deck?> deck(String id) async {
    final all = await decks();
    for (final d in all) {
      if (d.id == id) return d;
    }
    return all.firstOrNull;
  }

  @override
  Future<ImageProvider?> cardArt(Deck? deck, int cardId) async {
    if (deck == null) return null;
    final path = deck.artPath(cardId);
    return (await _assetList()).contains(path) ? AssetImage(path, bundle: _bundle) : null;
  }

  @override
  Future<Uint8List?> cardArtBytes(Deck? deck, int cardId) async {
    if (deck == null) return null;
    final path = deck.artPath(cardId);
    if (!(await _assetList()).contains(path)) return null;
    final data = await _bundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
