import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 「分享匿名使用統計與當機報告」開關（HANDOFF §18.4）。預設開；關掉後 Analytics 與 Crashlytics 都停止蒐集。
/// 實際開關 Firebase 由 [apply] 處理（main.dart 傳入 FirebaseTelemetry.setSharing），本類別不碰 Firebase。
class UsageSharing {
  UsageSharing({required bool initial, required UsageSharingStore store, this.apply})
      : _store = store,
        enabled = ValueNotifier(initial);

  final ValueNotifier<bool> enabled;
  final UsageSharingStore _store;
  final Future<void> Function(bool enabled)? apply;

  Future<void> set(bool value) async {
    if (enabled.value == value) return;
    enabled.value = value;
    await _store.save(value);
    await apply?.call(value);
  }
}

abstract class UsageSharingStore {
  /// 沒存過＝true（預設分享，可隨時關掉）。
  Future<bool> load();
  Future<void> save(bool enabled);
}

class MemoryUsageSharingStore implements UsageSharingStore {
  MemoryUsageSharingStore([this.value = true]);

  bool value;

  @override
  Future<bool> load() async => value;

  @override
  Future<void> save(bool enabled) async => value = enabled;
}

/// 存在 App 文件資料夾的 `usage_sharing.json`。
class FileUsageSharingStore implements UsageSharingStore {
  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/usage_sharing.json');

  @override
  Future<bool> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return true;
      return (jsonDecode(await f.readAsString()) as Map)['enabled'] != false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> save(bool enabled) async {
    try {
      await (await _file()).writeAsString(jsonEncode({'enabled': enabled}));
    } catch (_) {
      // 寫不進去：本次仍生效，下次啟動回到預設
    }
  }
}
