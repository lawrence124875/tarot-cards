import 'package:flutter/material.dart';

import '../../app/app_feature.dart';
import '../../core/daily/daily_card.dart';
import 'daily_page.dart';

/// 今日一張：每天一張牌與一句肯定語（不計入每日抽牌次數），可設定每日提醒。
final dailyFeature = AppFeature(
  id: 'daily',
  label: (l) => l.featureDaily,
  placement: FeaturePlacement.primary,
  builder: (_) => const DailyPage(),
  openPayload: (nav, payload) {
    if (payload != DailyReminders.payload) return false;
    nav.push(MaterialPageRoute<void>(builder: (_) => const DailyPage()));
    return true;
  },
);
