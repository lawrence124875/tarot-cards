import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/feature_registry.dart';
import 'app/services.dart';
import 'app/theme.dart';
import 'core/audio/just_audio_playback.dart';
import 'core/admob/admob_ads.dart';
import 'core/daily/daily_card.dart';
import 'core/firebase/firebase_feedback.dart';
import 'core/firebase/firebase_telemetry.dart';
import 'core/monetization/ad_service.dart';
import 'core/monetization/free_limits.dart';
import 'core/revenuecat/revenuecat_premium.dart';
import 'core/telemetry/analytics_listener.dart';
import 'core/telemetry/usage_sharing.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase（Analytics、Crashlytics、Remote Config，HANDOFF §18）放最前面，才接得到啟動中的當機；
  // 失敗不影響 App（統計不送、遠端開關全照預設）。
  final sharingStore = FileUsageSharingStore();
  final sharing = await sharingStore.load();
  final telemetry = await FirebaseTelemetry.init(featureIds: registeredFeatures.map((f) => f.id), sharing: sharing);
  final usage = UsageSharing(initial: sharing, store: sharingStore, apply: telemetry.setSharing);
  _registerFontLicenses();
  // 無邊框畫面（Android 15 起 targetSdk 35 的預設；這裡讓舊版 Android 也一致）：
  // 狀態列、導覽列透明，畫面延伸到系統列後面，各頁以 SafeArea／viewPadding 讓出位置。
  // 不再鎖直向（2026-10-07）：Android 16 起大螢幕會忽略方向限制，平板、摺疊機與橫放由各頁版面處理
  // （lib/shared/widgets/adaptive_layout.dart）。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(tarotSystemBars);
  // 呼吸音景的背景播放與通知控制；失敗不影響其他功能
  // 通知類別名稱跟著手機語言（L10n 在 MaterialApp 決定語言前先依手機設定判斷）
  final l = L10n.current;
  await JustAudioPlayback.initBackground(channelName: l.breathChannelName, album: l.appTitle);
  // 訂閱與廣告（HANDOFF §23）：訂閱戶不載入任何廣告；廣告同意表單在 runApp 之後才跑，不拖慢啟動
  final limits = FreeLimits.from(telemetry.flags.intValue);
  final premium = await RevenueCatPremium.init();
  final ads = AdMobAds.create(
    pacer: InterstitialPacer(
      every: limits.interstitialEvery,
      minGap: Duration(minutes: limits.interstitialGapMinutes),
    ),
  );
  var appStarted = false;
  void syncAds() {
    ads.enabled = !premium.isPremium.value;
    if (appStarted && ads.enabled) unawaited(ads.start()); // 只會真的執行一次
  }
  premium.isPremium.addListener(syncAds);
  syncAds();
  final services = Services.standard(
    analytics: telemetry.analytics,
    flags: telemetry.flags,
    premium: premium,
    ads: ads,
    limits: limits,
    usage: usage,
    feedback: telemetry.available ? const FirestoreFeedbackSender() : null,
  );
  AnalyticsListener(services.events, services.analytics); // 全 App 存活期間都在，不需 dispose
  await services.reminders.init(); // 不拋例外；失敗時提醒功能停用
  await services.loadDeck(); // 也會讀取設定
  premium.isPremium.addListener(services.loadDeck); // 會員狀態改變時，會員牌面組跟著開放或收回
  // 今日一張的提醒只排 14 天；每次開啟 App 往後補排
  if (services.settings.dailyReminder) {
    unawaited(DailyReminders.apply(
      services.reminders,
      enabled: true,
      hour: services.settings.dailyHour,
      minute: services.settings.dailyMinute,
      title: l.dailyNotificationTitle,
      body: l.dailyNotificationBody,
    ));
  }
  runApp(AppServices(services: services, child: const TarotApp()));
  appStarted = true;
  syncAds();
}

/// 思源黑體／宋體為 SIL OFL 1.1，散布時須附授權全文（顯示於系統授權頁）。
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final name in ['NotoSansTC', 'NotoSerifTC', 'NotoSansSC', 'NotoSerifSC', 'NotoSansJP', 'NotoSerifJP', 'NotoSansKR', 'NotoSerifKR', 'NotoSansThai', 'NotoSerifThai', 'NotoSansArabic', 'NotoNaskhArabic']) {
      final text = await rootBundle.loadString('assets/licenses/$name-OFL.txt');
      yield LicenseEntryWithLineBreaks([name], text);
    }
    // 真實自然錄音（CC0／公有領域，不要求標示，仍列出作者與來源）
    yield LicenseEntryWithLineBreaks(['Nature recordings'], await rootBundle.loadString('assets/audio/CREDITS.md'));
  });
}
