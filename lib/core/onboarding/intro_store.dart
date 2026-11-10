import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 記住使用者是否看過功能介紹（首次開啟時顯示一次）。
abstract class IntroStore {
  Future<bool> seen();
  Future<void> markSeen();
}

class MemoryIntroStore implements IntroStore {
  MemoryIntroStore({this.value = false});

  bool value;

  @override
  Future<bool> seen() async => value;

  @override
  Future<void> markSeen() async => value = true;
}

/// 存在 App 文件資料夾的 `intro.json`（與卦記同一個資料夾，不需權限）。
class FileIntroStore implements IntroStore {
  /// [name]：檔名（交叉解讀引導用 `cross_intro.json`）。
  /// [version]：介紹內容改版時調高，看過舊版的使用者會再看到一次。
  FileIntroStore({this.name = 'intro.json', this.version = 1});

  final String name;
  final int version;

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/$name');

  @override
  Future<bool> seen() async {
    try {
      final f = await _file();
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString()) as Map;
      return m['seen'] == true && ((m['v'] as num?) ?? 1) >= version;
    } catch (_) {
      // 讀不到就當作看過，避免每次開啟都跳出介紹
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await (await _file()).writeAsString(jsonEncode({'seen': true, 'v': version}));
    } catch (_) {
      // 寫不進去只會讓介紹下次再出現一次
    }
  }
}
