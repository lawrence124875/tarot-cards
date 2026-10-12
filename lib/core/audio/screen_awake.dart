import 'package:wakelock_plus/wakelock_plus.dart';

/// 練習時保持螢幕亮著（平台相關，包在介面後面）。
abstract class ScreenAwake {
  Future<void> set(bool on);
}

class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // 取不到也不影響練習
    }
  }
}

class NoopScreenAwake implements ScreenAwake {
  @override
  Future<void> set(bool on) async {}
}
