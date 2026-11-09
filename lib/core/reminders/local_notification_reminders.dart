import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../settings/json_file.dart';
import 'reminder_service.dart';

/// 以 flutter_local_notifications 實作的一次性提醒。
/// - 時間一律換成 UTC 時間點排程（TZDateTime.from 取絕對時間，不可再扣時區偏移），
///   不依賴任何查詢時區名稱的原生外掛（智慧聽覺巡航的經驗）。
/// - 一律用 inexactAllowWhileIdle（省電時可能延後幾分鐘）。不使用精確鬧鐘：
///   Play 限制 SCHEDULE_EXACT_ALARM，2026-11-02 Lawrence 決定移除該權限。
/// - 所有呼叫都不拋例外：通知失敗不能影響主流程。
/// - Android 需要 AndroidManifest 的兩個 receiver 與 core library desugaring
///  （scripts/patch_android.sh 處理），少了 receiver 排程會成功但永遠不會跳出。
class LocalNotificationReminders implements ReminderService {
  /// [channelName]、[channelDescription]：通知類別在系統設定中顯示的文字（由 l10n 提供，跟著 App 語言）。
  LocalNotificationReminders({required this.channelName, required this.channelDescription});

  static const _channelId = 'com.lclab.tarot.review';

  final String Function() channelName;
  final String Function() channelDescription;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? _launchPayload;
  bool _ready = false;
  ReminderFailure? _lastFailure;

  @override
  ReminderFailure? get lastFailure => _lastFailure;

  @override
  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_tarot'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) _taps.add(p);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
      _lastFailure = null;
    } catch (e) {
      _ready = false;
      _lastFailure = ReminderFailure(ReminderFailureKind.initFailed, '$e');
    }
  }

  static final _permissionFile = JsonFile('notify_permission.json');
  Future<void>? _asking;

  /// 通知權限只問一次（Lawrence 2026-11-09）：第一次排程（第一次啟動或抽牌）時跳對話框，之後不再問。
  /// 使用者拒絕也照樣排程：系統不會顯示通知，App 設定仍維持開啟。
  Future<void> _askPermissionOnce() => _asking ??= () async {
        if ((await _permissionFile.read())['asked'] == true) return;
        await _permissionFile.write({'asked': true});
        await _requestPermission();
      }();

  Future<bool> _requestPermission() async {
    try {
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      // 已允許就不再跳權限對話框
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_ready) await init(); // 啟動時失敗就再試一次
    if (!_ready) return false;
    await _askPermissionOnce();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.UTC),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channelName(),
            channelDescription: channelDescription(),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      _lastFailure = null;
      return true;
    } catch (e) {
      // 例：release 版被 R8 砍掉 Gson 泛型資訊時會在這裡失敗（見 patch_android.sh 的 ProGuard 規則）
      _lastFailure = ReminderFailure(ReminderFailureKind.scheduleFailed, '$e');
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }
}
