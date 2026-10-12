import 'package:flutter/foundation.dart';

import 'json_file.dart';

/// 使用者設定：牌面組、是否使用逆位、今日一張的每日提醒。存在 settings.json。
class AppSettings extends ChangeNotifier {
  AppSettings({KeyValueFile? store}) : _store = store ?? FileKeyValue('settings.json');

  final KeyValueFile _store;
  bool _loaded = false;

  String deckId = 'rws1909';
  bool reversals = true;
  bool dailyReminder = false;
  int dailyHour = 8;
  int dailyMinute = 0;

  Future<void> load() async {
    if (_loaded) return;
    final j = await _store.read();
    deckId = j['deck'] as String? ?? deckId;
    reversals = j['reversals'] as bool? ?? reversals;
    dailyReminder = j['dailyReminder'] as bool? ?? dailyReminder;
    dailyHour = (j['dailyHour'] as int? ?? dailyHour).clamp(0, 23);
    dailyMinute = (j['dailyMinute'] as int? ?? dailyMinute).clamp(0, 59);
    _loaded = true;
    notifyListeners();
  }

  Future<void> update({String? deckId, bool? reversals, bool? dailyReminder, int? dailyHour, int? dailyMinute}) async {
    this.deckId = deckId ?? this.deckId;
    this.reversals = reversals ?? this.reversals;
    this.dailyReminder = dailyReminder ?? this.dailyReminder;
    this.dailyHour = dailyHour ?? this.dailyHour;
    this.dailyMinute = dailyMinute ?? this.dailyMinute;
    notifyListeners();
    await _store.write({
      'deck': this.deckId,
      'reversals': this.reversals,
      'dailyReminder': this.dailyReminder,
      'dailyHour': this.dailyHour,
      'dailyMinute': this.dailyMinute,
    });
  }
}
