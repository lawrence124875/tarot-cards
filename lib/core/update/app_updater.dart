/// 新版本提示（HANDOFF §2：從加入的這一版起，每一版都要保留）。
/// 畫面只認這個介面；Google Play In-App Updates 只出現在 `play_app_updater.dart`。
abstract class AppUpdater {
  /// 商店有比目前安裝更新的版本嗎。查不到（離線、非 Play 安裝、iOS）回傳 false，不拋例外。
  Future<bool> updateAvailable();

  /// 使用者按「立即更新」：開始更新（Play 的全螢幕更新流程，或開商店頁）。
  Future<void> startUpdate();
}

/// 不檢查更新（測試、iOS、非 Play 安裝）。
class NoUpdater implements AppUpdater {
  const NoUpdater();

  @override
  Future<bool> updateAvailable() async => false;

  @override
  Future<void> startUpdate() async {}
}

/// 每次啟動最多提示一次（純邏輯，可單獨測試）。
class UpdatePromptGate {
  bool _asked = false;

  /// 這次啟動還沒問過、且有新版時回傳 true（並記為已問過）。
  Future<bool> shouldPrompt(AppUpdater updater) async {
    if (_asked) return false;
    _asked = true;
    return updater.updateAvailable();
  }
}
