import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../monetization/ad_service.dart';

/// AdMob 實作（HANDOFF §23）。**唯一 import google_mobile_ads 的檔案**；拔除廣告＝
/// Services 改用 NoAds、移除套件與 patch_android.sh 的 APPLICATION_ID。
///
/// - 同意（Google UMP）：歐洲等地區先顯示同意表單，`canRequestAds` 為 true 才載入廣告；
///   表單內容在 AdMob →「隱私權與訊息」設定（使用者操作）。
/// - 廣告單元 ID 由 CI 以 --dart-define 注入（GitHub Secrets）；沒注入時用 Google 官方測試 ID。
/// - 廣告內容分級上限 PG；敏感類別（酒精、賭博等）在 AdMob 後台封鎖（PLAY_CONSOLE.md §5 第 6 項）。
class AdMobAds implements AdService {
  AdMobAds._();

  static const _bannerId = String.fromEnvironment('ADMOB_BANNER_AD_UNIT_ID');
  static const _interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_AD_UNIT_ID');
  static const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID');

  // Google 官方測試廣告單元（Android 與 iOS 各一組）。正式單元由 CI 以 dart-define 傳入（iOS 建置傳 iOS 的單元）。
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String? get bannerUnit => resolveUnit(_bannerId,
      testId: _ios ? 'ca-app-pub-3940256099942544/2934735716' : 'ca-app-pub-3940256099942544/6300978111');
  static String? get _interstitialUnit => resolveUnit(_interstitialId,
      testId: _ios ? 'ca-app-pub-3940256099942544/4411468910' : 'ca-app-pub-3940256099942544/1033173712');
  static String? get _rewardedUnit => resolveUnit(_rewardedId,
      testId: _ios ? 'ca-app-pub-3940256099942544/1712485313' : 'ca-app-pub-3940256099942544/5224354917');

  /// 空值防呆：ID 去空白後為空、"null"、"undefined" 或不是 ca-app-pub- 開頭都算沒設定，
  /// 改用測試單元（畫面標 Test Ad，一看就知道沒注入；與謙卦相同）。測試單元也無效時回傳 null＝略過不載入。
  @visibleForTesting
  static String? resolveUnit(String? raw, {required String testId}) {
    if (_valid(raw)) return raw!.trim();
    return _valid(testId) ? testId : null;
  }

  static bool _valid(String? raw) {
    final id = raw?.trim() ?? '';
    final lower = id.toLowerCase();
    return id.isNotEmpty && lower != 'null' && lower != 'undefined' && id.startsWith('ca-app-pub-');
  }

  /// 是否用正式廣告單元（Release 說明顯示用）。
  static bool get usingRealUnits => _valid(_bannerId);

  bool _started = false;
  bool _enabled = false;
  bool _sdkReady = false;
  bool _privacyRequired = false;
  bool _fullScreenShowing = false;
  InterstitialAd? _interstitial;
  Completer<void>? _interstitialLoad; // 載入中時不為 null，載入結束（成功或失敗）時完成
  RewardedAd? _rewarded;
  final ValueNotifier<int> _bannerEpoch = ValueNotifier(0);

  /// 建立後立刻可用（還不顯示廣告）；[start] 在 runApp 之後於背景執行，
  /// 不讓同意表單或網路拖慢啟動。
  static AdMobAds create() => AdMobAds._();

  /// 先查同意狀態（需要時顯示表單），可以請求廣告才初始化 SDK。任何失敗都只是不顯示廣告。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _gatherConsent().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('廣告同意流程失敗：$e');
    }
    try {
      if (await ConsentInformation.instance.canRequestAds()) await _startSdk();
    } catch (e) {
      debugPrint('AdMob 初始化失敗，不顯示廣告：$e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) async {
        try {
          _privacyRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      }),
      (FormError e) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  Future<void> _startSdk() async {
    if (_sdkReady) return;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
    );
    _sdkReady = true;
    _bannerEpoch.value++;
    if (_enabled) _loadInterstitial();
  }

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _bannerEpoch.value++; // 讓畫面上的橫幅重建（訂閱後立刻消失）
    if (value && _sdkReady) {
      _loadInterstitial();
    } else if (!value) {
      _interstitial?.dispose();
      _interstitial = null;
      _rewarded?.dispose();
      _rewarded = null;
    }
  }

  bool get _canShow => _enabled && _sdkReady;

  // ---------------- 橫幅 ----------------

  @override
  Widget? banner() => _BannerSlot(ads: this);

  // ---------------- 插頁 ----------------

  void _loadInterstitial() {
    if (!_canShow || _interstitial != null || _interstitialLoad != null) return;
    final unit = _interstitialUnit;
    if (unit == null) return;
    final load = _interstitialLoad = Completer<void>();
    void done() {
      if (identical(_interstitialLoad, load)) _interstitialLoad = null;
      if (!load.isCompleted) load.complete();
    }

    try {
      InterstitialAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!_canShow) {
              ad.dispose();
            } else {
              _interstitial = ad;
            }
            done();
          },
          onAdFailedToLoad: (_) {
            _interstitial = null;
            done();
          },
        ),
      );
    } catch (e) {
      done();
      debugPrint('插頁廣告載入失敗，略過：$e');
    }
  }

  @override
  Future<AdResult> showInterstitial({Duration loadTimeout = const Duration(seconds: 3)}) async {
    if (!_canShow) return AdResult.skipped;
    if (_fullScreenShowing) return AdResult.failed;
    if (_interstitial == null) {
      _loadInterstitial();
      final load = _interstitialLoad;
      if (load != null) await load.future.timeout(loadTimeout, onTimeout: () {});
    }
    final ad = _interstitial;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (ad == null || !_canShow || _fullScreenShowing || !foreground) return AdResult.failed;
    _interstitial = null;
    final closed = Completer<AdResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        _fullScreenShowing = false;
        a.dispose();
        _loadInterstitial(); // 先備好明天的（過期由 SDK 處理，載入失敗明天會再試）
        if (!closed.isCompleted) closed.complete(AdResult.shown);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        _fullScreenShowing = false;
        a.dispose();
        _loadInterstitial();
        if (!closed.isCompleted) closed.complete(AdResult.failed);
      },
    );
    _fullScreenShowing = true;
    try {
      await ad.show();
    } catch (e) {
      _fullScreenShowing = false;
      ad.dispose();
      debugPrint('插頁廣告顯示失敗，略過：$e');
      return AdResult.failed;
    }
    return closed.future.timeout(const Duration(minutes: 3), onTimeout: () => AdResult.shown);
  }

  // ---------------- 獎勵 ----------------

  @override
  Future<bool> prepareRewarded() async {
    if (!_canShow) return false;
    if (_rewarded != null) return true;
    final unit = _rewardedUnit;
    if (unit == null) return false;
    final c = Completer<bool>();
    try {
      RewardedAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!_canShow || c.isCompleted) {
              ad.dispose(); // 已逾時或已訂閱：不留著
              if (!c.isCompleted) c.complete(false);
              return;
            }
            _rewarded?.dispose();
            _rewarded = ad;
            c.complete(true);
          },
          onAdFailedToLoad: (_) {
            if (!c.isCompleted) c.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('獎勵廣告載入失敗，略過：$e');
      return false;
    }
    return c.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
  }

  @override
  Future<AdResult> showRewarded() async {
    final ad = _rewarded;
    if (ad == null || _fullScreenShowing) return AdResult.failed;
    _rewarded = null;
    final closed = Completer<void>();
    var earned = false;
    var failed = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        _fullScreenShowing = false;
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        _fullScreenShowing = false;
        failed = true;
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    _fullScreenShowing = true;
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (e) {
      _fullScreenShowing = false;
      ad.dispose();
      debugPrint('獎勵廣告顯示失敗，略過：$e');
      return AdResult.failed;
    }
    await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return earned ? AdResult.earned : (failed ? AdResult.failed : AdResult.dismissed);
  }

  // ---------------- 隱私選項 ----------------

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    final c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) async {
      try {
        if (await ConsentInformation.instance.canRequestAds()) await _startSdk();
      } catch (_) {}
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }
}

/// 底部橫幅：載入成功才佔位；訂閱後（enabled＝false）自動消失。
class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.ads});

  final AdMobAds ads;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.ads._bannerEpoch.addListener(_refresh);
    _load();
  }

  void _refresh() {
    if (!widget.ads._canShow) {
      _ad?.dispose();
      _ad = null;
      if (mounted) setState(() => _loaded = false);
    } else if (_ad == null) {
      _load();
    }
  }

  void _load() {
    if (!widget.ads._canShow) return;
    final unit = AdMobAds.bannerUnit;
    if (unit == null) return;
    try {
      _ad = BannerAd(
        adUnitId: unit,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted || !identical(ad, _ad)) return; // 已被替換或畫面已關，舊的已釋放
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (identical(ad, _ad)) _ad = null;
            if (mounted) setState(() => _loaded = false);
          },
        ),
      )..load();
    } catch (e) {
      _ad?.dispose();
      _ad = null;
      debugPrint('橫幅廣告載入失敗，略過：$e');
    }
  }

  @override
  void dispose() {
    widget.ads._bannerEpoch.removeListener(_refresh);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad)),
        ),
      ),
    );
  }
}
