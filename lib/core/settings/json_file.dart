import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// App 文件資料夾裡的一個小 JSON 檔（設定、今日一張、學習進度）。讀寫失敗都不拋例外。
/// 先寫暫存檔再改名，避免寫到一半當掉而毀損。
class JsonFile {
  JsonFile(this.name);

  final String name;
  Future<void> _writing = Future.value();

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/$name');

  Future<Map<String, dynamic>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final data = jsonDecode(await f.readAsString());
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, dynamic> data) {
    final text = jsonEncode(data);
    return _writing = _writing.then((_) async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(text);
        await tmp.rename(f.path);
      } catch (_) {}
    });
  }
}

/// 鍵值儲存介面（測試用記憶體版、手機上用檔案版）。
abstract class KeyValueFile {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> data);
}

class FileKeyValue implements KeyValueFile {
  FileKeyValue(String name) : _file = JsonFile(name);

  final JsonFile _file;

  @override
  Future<Map<String, dynamic>> read() => _file.read();

  @override
  Future<void> write(Map<String, dynamic> data) => _file.write(data);
}

class MemoryKeyValue implements KeyValueFile {
  MemoryKeyValue([Map<String, dynamic>? initial]) : data = {...?initial};

  Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> read() async => {...data};

  @override
  Future<void> write(Map<String, dynamic> d) async => data = {...d};
}
