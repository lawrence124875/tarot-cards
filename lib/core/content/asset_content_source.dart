import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'card_content.dart';
import 'content_source.dart';

/// 從 App 內資產讀取：assets/content/<語言資料夾>/NN.json、spreads.json、atmosphere.json、lessons.json。
/// 這些檔案由 CI 從私人 repo tarot-content 匯入（scripts/import_content.sh）。
/// [folder] 每次讀取時取值，App 語言改變後自動讀對應語言。該語言某檔尚未撰寫時退回繁中（只會在測試版發生）。
class AssetContentSource implements ContentSource {
  AssetContentSource({required this.folder, this.fallbackFolder = 'zh-Hant', AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final String Function() folder;
  final String fallbackFolder;

  /// 由右至左的語言（阿拉伯文）：段落裡整段外文原文的引文（«…»）用 LRI…PDI 隔離，
  /// 讓它整段由左至右顯示（同謙卦，內容檔本身不放方向控制字元）。
  static const _rtlFolders = {'ar'};
  static final _foreignQuote = RegExp(r'«([^«»؀-ۿ]*[A-Za-zͰ-Ͽ][^«»؀-ۿ]*)»');

  static String isolateForeignQuotes(String folder, String text) => _rtlFolders.contains(folder)
      ? text.replaceAllMapped(_foreignQuote, (m) => '⁦«${m[1]}»⁩')
      : text;

  final AssetBundle _bundle;
  final Map<String, Object?> _cache = {};
  Future<Set<String>>? _assets;

  Future<Set<String>> _assetList() => _assets ??= _loadAssetList();

  // 用 try/catch，不可改回 .then().catchError()：資產清單已在快取時 Flutter 回傳 SynchronousFuture，
  // 它的 catchError 會回傳永遠不完成的 Future（謙卦 2026-10-05 發現）。
  Future<Set<String>> _loadAssetList() async {
    try {
      return (await AssetManifest.loadFromAssetBundle(_bundle)).listAssets().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<T?> _load<T>(String name, T Function(Map<String, dynamic>) parse) async {
    final f = folder();
    final result = await _loadFrom<T>(f, name, parse);
    if (result != null || f == fallbackFolder) return result;
    return _loadFrom<T>(fallbackFolder, name, parse);
  }

  Future<T?> _loadFrom<T>(String f, String name, T Function(Map<String, dynamic>) parse) async {
    final path = 'assets/content/$f/$name';
    if (_cache.containsKey(path)) return _cache[path] as T?;
    T? result;
    if ((await _assetList()).contains(path)) {
      try {
        final raw = isolateForeignQuotes(f, await _bundle.loadString(path));
        result = parse(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('內容解析失敗：$path（$e）');
      }
    }
    _cache[path] = result;
    return result;
  }

  @override
  Future<CardContent?> card(int id) => _load('${id.toString().padLeft(2, '0')}.json', CardContent.fromJson);

  @override
  Future<SpreadTexts?> spreads() => _load('spreads.json', SpreadTexts.fromJson);

  @override
  Future<AtmosphereTexts?> atmosphere() => _load('atmosphere.json', AtmosphereTexts.fromJson);

  @override
  Future<LessonBook?> lessons() => _load('lessons.json', LessonBook.fromJson);
}
