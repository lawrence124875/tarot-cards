import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/events/event_bus.dart';
import '../../core/monetization/ad_service.dart';
import '../../l10n/l10n.dart';

/// 每日第 1 次免費抽牌（HANDOFF H 第 5 點）：翻牌結束、顯示解讀前，
/// 先過場「靜心片刻，解讀即將呈現」，再播一則插頁。
/// 插頁載入失敗、無填充或逾時 3 秒就直接往下（呼叫端接著開解讀）。
Future<void> playReadingInterstitial(BuildContext context) async {
  final s = AppServices.of(context);
  if (!s.ads.enabled) return;
  final nav = Navigator.of(context);
  final text = context.l10n.readingPause;
  final t = Theme.of(context).textTheme;
  unawaited(showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, __) => PopScope(
      canPop: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, style: t.titleLarge, textAlign: TextAlign.center),
        ),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 900)); // 讓過場文字被看見
  final r = await s.ads.showInterstitial(loadTimeout: const Duration(seconds: 3));
  nav.pop();
  switch (r) {
    case AdResult.shown:
      s.events.emit(const InterstitialShown());
    case AdResult.failed:
      s.events.emit(const InterstitialFailed());
    case AdResult.earned || AdResult.dismissed || AdResult.skipped:
      break;
  }
}
