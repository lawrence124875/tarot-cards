import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/audio/audio_playback.dart';
import '../core/audio/just_audio_playback.dart';
import '../core/audio/screen_awake.dart';
import '../core/content/asset_content_source.dart';
import '../core/content/content_source.dart';
import '../core/daily/daily_card.dart';
import '../core/deck/deck.dart';
import '../core/deck/deck_source.dart';
import '../core/learn/card_quiz.dart';
import '../core/learn/lesson_progress.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/json_file.dart';
import '../core/tarot/atmosphere.dart';
import '../core/events/event_bus.dart';
import '../core/feedback/feedback_sender.dart';
import '../core/journal/file_journal_store.dart';
import '../core/onboarding/intro_store.dart';
import '../core/monetization/ad_service.dart';
import '../core/monetization/cast_quota.dart';
import '../core/monetization/free_limits.dart';
import '../core/monetization/premium_service.dart';
import '../core/journal/journal_store.dart';
import '../core/reminders/local_notification_reminders.dart';
import '../core/reminders/reminder_service.dart';
import '../core/soundscape/soundscape_files.dart';
import '../core/telemetry/analytics.dart';
import '../core/telemetry/remote_flags.dart';
import '../core/telemetry/usage_sharing.dart';
import '../core/update/app_updater.dart';
import '../core/update/play_app_updater.dart';
import '../l10n/l10n.dart';

/// App 共用服務。換實作（內容來源、牌面組來源、整體氛圍規則…）只改 Services.standard()。
class Services {
  Services({
    required this.content,
    required this.decks,
    required this.events,
    this.atmosphere = const StandardAtmosphere(),
    required this.random,
    required this.reminders,
    AppSettings? settings,
    DailyCardStore? daily,
    CardQuiz? quiz,
    LessonProgress? lessonProgress,
    this.journal,
    this.breath,
    this.intro,
    this.analytics = const NoopAnalytics(),
    this.flags = const DefaultRemoteFlags(),
    this.usage,
    this.feedback,
    PremiumService? premium,
    AdService? ads,
    FreeLimits? limits,
    CastQuota? quota,
    this.updater = const NoUpdater(),
  })  : settings = settings ?? AppSettings(store: MemoryKeyValue()),
        daily = daily ?? DailyCardStore(store: MemoryKeyValue()),
        quiz = quiz ?? CardQuiz(store: MemoryKeyValue()),
        lessonProgress = lessonProgress ?? LessonProgress(store: MemoryKeyValue()),
        premium = premium ?? FreePremium(),
        ads = ads ?? NoAds(),
        limits = limits ?? const FreeLimits(),
        quota = quota ?? CastQuota(limits: limits ?? const FreeLimits(), storage: MemoryQuotaStorage());

  /// [analytics]、[flags]：main.dart 以 Firebase 初始化後傳入（§18）；不傳＝不統計、功能全開。
  factory Services.standard({
    Analytics analytics = const NoopAnalytics(),
    RemoteFlags flags = const DefaultRemoteFlags(),
    PremiumService? premium,
    AdService? ads,
    FreeLimits limits = const FreeLimits(),
    UsageSharing? usage,
    FeedbackSender? feedback,
  }) =>
      Services(
        content: AssetContentSource(folder: () => L10n.contentFolder),
        decks: AssetDeckSource(),
        events: EventBus(),
        atmosphere: const StandardAtmosphere(),
        random: Random.secure(),
        settings: AppSettings(),
        daily: DailyCardStore(),
        quiz: CardQuiz(),
        lessonProgress: LessonProgress(),
        reminders: LocalNotificationReminders(
          channelName: () => L10n.current.reminderChannelName,
          channelDescription: () => L10n.current.reminderChannelDescription,
        ),
        journal: FileJournalStore(),
        intro: FileIntroStore(),
        breath: BreathServices(
          files: CachedSoundscapeFiles(),
          playback: JustAudioPlayback(),
          screenAwake: WakelockScreenAwake(),
        ),
        analytics: analytics,
        flags: flags,
        usage: usage,
        feedback: feedback,
        premium: premium,
        ads: ads,
        limits: limits,
        quota: CastQuota(limits: limits),
        updater: const PlayAppUpdater(),
      );

  final ContentSource content;

  /// 牌面組與牌面圖（與語言無關）。
  final DeckSource decks;
  final EventBus events;

  /// 整體氛圍規則（元素互動、大牌比例、數字…）。
  final AtmosphereRule atmosphere;
  final Random random;
  final ReminderService reminders;

  /// 使用者設定（牌面組、逆位、每日提醒）。
  final AppSettings settings;

  /// 今日一張。
  final DailyCardStore daily;

  /// 認牌練習進度。
  final CardQuiz quiz;

  /// 課程讀到哪裡。
  final LessonProgress lessonProgress;

  /// 塔羅日記；為 null 時（拔除日記功能）解讀頁不顯示「記下這次抽牌」。
  final JournalStore? journal;

  /// 呼吸音景；為 null 時練習頁直接提供無聲引導。拔除功能請移出註冊表。
  final BreathServices? breath;

  /// 功能介紹是否看過；null＝不自動顯示（測試）。
  final IntroStore? intro;

  /// 使用統計（只由 AnalyticsListener 從事件匯流排轉送，畫面不直接呼叫）。
  final Analytics analytics;

  /// 遠端開關（Firebase Remote Config，§18）。
  final RemoteFlags flags;

  /// 「分享匿名使用統計與當機報告」開關（§18.4）；null＝選單不顯示（測試、沒有 Firebase）。
  final UsageSharing? usage;

  /// 意見回饋（Firestore `tr_feedback`）；null＝選單不顯示（測試、Firebase 沒初始化）。
  final FeedbackSender? feedback;

  /// 訂閱（§23）。不傳＝永遠免費版、不能購買。
  final PremiumService premium;

  /// 廣告（§23）。不傳＝沒有廣告。訂閱戶由 main.dart 關掉（ads.enabled = false）。
  final AdService ads;

  /// 免費版限制（§23.1，可由 Remote Config 調整）。
  final FreeLimits limits;

  /// 每日抽牌次數。
  final CastQuota quota;

  /// 新版本提示（Google Play）；測試用 [NoUpdater]。
  final AppUpdater updater;

  bool get isPremium => premium.isPremium.value;

  /// 目前使用的牌面組（[loadDeck] 後才有值；沒有任何牌面組時為 null，畫面用程式畫的牌面）。
  final ValueNotifier<Deck?> deck = ValueNotifier(null);

  /// 依設定載入牌面組。會員牌面組在非會員時改用第一組免費的。
  Future<void> loadDeck() async {
    await settings.load();
    var d = await decks.deck(settings.deckId);
    if (d != null && d.premium && !isPremium) {
      for (final x in await decks.decks()) {
        if (!x.premium) {
          d = x;
          break;
        }
      }
    }
    deck.value = d;
  }
}

/// 呼吸音景用到的服務（HANDOFF §14）。
class BreathServices {
  BreathServices({required this.files, required this.playback, required this.screenAwake});

  final SoundscapeFiles files;

  /// 全 App 共用一個播放器（背景播放套件只支援單一播放器）；練習結束時 stop()。
  final AudioPlayback playback;
  final ScreenAwake screenAwake;
}

class AppServices extends InheritedWidget {
  const AppServices({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppServices>()!.services;

  static Services? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<AppServices>()?.services;

  @override
  bool updateShouldNotify(AppServices oldWidget) => services != oldWidget.services;
}
