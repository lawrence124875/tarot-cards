import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// 以 flutter_local_notifications 實作的一次性提醒。
/// - 時間一律換成 UTC 時間點排程（TZDateTime.from 取絕對時間，不可再扣時區偏移），
///   不依賴任何查詢時區名稱的原生外掛（智慧聽覺巡航的經驗）。
/// - 準時模式（比照智慧聽覺巡航，0.1.0+11）：使用者允許「鬧鐘與提醒」就用 exactAllowWhileIdle 準時跳出；
///   不允許才退回 inexactAllowWhileIdle（省電時可能延後）。第一次設定提醒時開一次系統設定頁請使用者允許，
///   之後不再主動開（記在 App 私有資料夾的 exact_alarm_asked 檔），使用者可自行到系統設定開啟。
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

  /// 能準時就準時；第一次設定提醒時請使用者允許「鬧鐘與提醒」。
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle; // iOS 不使用此設定
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;
      var can = await android.canScheduleExactNotifications() ?? false;
      if (!can) {
        final flag = File('${(await getApplicationSupportDirectory()).path}/exact_alarm_asked');
        if (!await flag.exists()) {
          await flag.writeAsString(DateTime.now().toIso8601String());
          await android.requestExactAlarmsPermission(); // 開系統設定頁，使用者返回後才繼續
          can = await android.canScheduleExactNotifications() ?? false;
        }
      }
      return can ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// 上一次排程是否為準時模式。
  bool lastExact = false;

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
    if (!await _requestPermission()) {
      _lastFailure = const ReminderFailure(ReminderFailureKind.permissionDenied);
      return false;
    }
    final mode = await _scheduleMode();
    lastExact = mode == AndroidScheduleMode.exactAllowWhileIdle;
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
        androidScheduleMode: mode,
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
