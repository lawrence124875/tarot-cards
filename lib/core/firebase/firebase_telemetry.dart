import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../telemetry/analytics.dart';
import '../monetization/free_limits.dart';
import '../telemetry/remote_flags.dart';

/// Firebase（Analytics、Crashlytics、Remote Config）只在這個檔案出現（HANDOFF §18）。
/// 其他程式只認得 [Analytics] 與 [RemoteFlags] 介面；拔掉 Firebase＝main.dart 不呼叫 [init]。
///
/// Firebase 專案與智慧聽覺巡航共用（帳號專案數已滿）：本 App 是同專案的第二個 Android App
/// `com.lclab.tarot`。統計事件與 Remote Config 參數一律 `tr_` 開頭。
class FirebaseTelemetry {
  FirebaseTelemetry._(this.analytics, this.flags, {bool available = false}) : _available = available;

  final Analytics analytics;
  final RemoteFlags flags;

  /// 初始化；任何失敗（沒有 google-services.json、沒網路、逾時）都退回替代實作，不影響 App 啟動。
  /// [featureIds]：功能註冊表的 id，用來設定 Remote Config 的 App 內預設值（全部開啟）。
  /// [sharing]：使用者的「分享匿名使用統計與當機報告」設定；false 時 Analytics、Crashlytics 都不蒐集。
  static Future<FirebaseTelemetry> init({required Iterable<String> featureIds, bool sharing = true}) async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Firebase 初始化失敗，統計與遠端開關停用：$e');
      return FirebaseTelemetry._(const NoopAnalytics(), const DefaultRemoteFlags()); // 統計不送、開關全照預設
    }

    // 當機回報：release 版才收集。
    try {
      final crash = FirebaseCrashlytics.instance;
      await crash.setCrashlyticsCollectionEnabled(!kDebugMode && sharing);
      FlutterError.onError = crash.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        crash.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Crashlytics 設定失敗：$e');
    }

    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(sharing);
      // 共用 Firebase 專案：每個事件都帶 app=tarot（另有內建的「App／串流」維度可篩選）
      await FirebaseAnalytics.instance.setDefaultEventParameters({'app': 'tarot'});
    } catch (e) {
      debugPrint('Analytics 設定失敗：$e');
    }

    final RemoteFlags flags = await _FirebaseRemoteFlags.init(featureIds);
    return FirebaseTelemetry._(const _FirebaseAnalytics(), flags, available: true);
  }

  final bool _available;

  /// Firebase 是否初始化成功（意見回饋等需要 Firebase 的功能據此決定是否顯示）。
  bool get available => _available;

  /// 使用者切換「分享匿名使用統計與當機報告」時呼叫；立即生效。Firebase 沒初始化時什麼都不做。
  Future<void> setSharing(bool enabled) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode && enabled);
    } catch (e) {
      debugPrint('切換使用統計失敗：$e');
    }
  }
}

class _FirebaseAnalytics implements Analytics {
  const _FirebaseAnalytics();

  @override
  Future<void> log(String name, [Map<String, Object> params = const {}]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params.isEmpty ? null : params);
    } catch (_) {
      // 統計失敗不影響使用
    }
  }
}

/// 「下次啟動才生效」的讀法：啟動時先套用上次抓到的值（不等網路），
/// 再在背景抓新值，下次啟動生效。首頁不會因為網路慢而卡住或在使用中突然變動。
class _FirebaseRemoteFlags implements RemoteFlags {
  _FirebaseRemoteFlags(this._rc);

  final FirebaseRemoteConfig? _rc;

  static Future<RemoteFlags> init(Iterable<String> featureIds) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Spark 免費方案；開關不必即時，12 小時抓一次即可（官方預設值）
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 12),
      ));
      await rc.setDefaults({
        for (final id in featureIds) featureFlagKey(id): true,
        ...FreeLimits.remoteDefaults,
      });
      await rc.activate();
      unawaited(rc.fetch().catchError((Object e) => debugPrint('Remote Config 抓取失敗：$e')));
      return _FirebaseRemoteFlags(rc);
    } catch (e) {
      debugPrint('Remote Config 初始化失敗，開關全照預設：$e');
      return const DefaultRemoteFlags();
    }
  }

  @override
  int intValue(String key, int fallback) {
    try {
      final rc = _rc;
      if (rc == null) return fallback;
      final v = rc.getValue(key);
      return v.source == ValueSource.valueStatic ? fallback : v.asInt();
    } catch (_) {
      return fallback;
    }
  }

  @override
  bool featureEnabled(String featureId) {
    try {
      return _rc?.getBool(featureFlagKey(featureId)) ?? true;
    } catch (_) {
      return true;
    }
  }
}
