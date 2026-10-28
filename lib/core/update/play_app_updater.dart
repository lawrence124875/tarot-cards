import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_updater.dart';

/// Google Play In-App Updates 實作。**唯一 import in_app_update 的檔案**。
/// 只有從 Play 安裝的 App 查得到新版；側載的 APK 查詢會失敗，視為沒有新版。
class PlayAppUpdater implements AppUpdater {
  const PlayAppUpdater();

  static const _storeUrl = 'https://play.google.com/store/apps/details?id=com.lclab.tarot';

  @override
  Future<bool> updateAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      debugPrint('檢查新版失敗，略過：$e');
      return false;
    }
  }

  @override
  Future<void> startUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
    } catch (e) {
      debugPrint('App 內更新失敗，改開商店頁：$e');
    }
    await launchUrl(Uri.parse(_storeUrl), mode: LaunchMode.externalApplication);
  }
}
