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
  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/intro.json');

  @override
  Future<bool> seen() async {
    try {
      final f = await _file();
      if (!await f.exists()) return false;
      return (jsonDecode(await f.readAsString()) as Map)['seen'] == true;
    } catch (_) {
      // 讀不到就當作看過，避免每次開啟都跳出介紹
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await (await _file()).writeAsString(jsonEncode({'seen': true}));
    } catch (_) {
      // 寫不進去只會讓介紹下次再出現一次
    }
  }
}
