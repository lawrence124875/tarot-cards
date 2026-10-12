import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/events/event_bus.dart';
import '../../core/monetization/cast_quota.dart';
import '../../l10n/l10n.dart';
import 'paywall_page.dart';

/// 起卦前呼叫（抽一卦翻牌、三枚銅錢第一擲）。可以起卦就回傳 true，並已記一次。
/// 訂閱戶不計次。免費次數用完時顯示選擇：看獎勵廣告再起一卦／成為會員／明天再來。
Future<bool> ensureCanCast(BuildContext context) async {
  final s = AppServices.of(context);
  if (s.isPremium) return true;
  var allowance = await s.quota.check();
  if (allowance == CastAllowance.free) {
    await s.quota.recordCast();
    return true;
  }
  if (!context.mounted) return false;
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true, // 手機橫放時面板矮，內容改可捲動
    builder: (ctx) => _LimitSheet(canWatch: allowance == CastAllowance.needsReward),
  );
  if (!context.mounted) return false;
  switch (choice) {
    case _Choice.watch:
      final l = context.l10n;
      final ready = await s.ads.prepareRewarded();
      if (!context.mounted) return false;
      if (!ready || !await s.ads.showRewarded()) {
        if (context.mounted && !ready) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.castAdNotReady)));
        }
        return false;
      }
      s.events.emit(const RewardedEarned(source: 'cast'));
      await s.quota.grantReward();
      allowance = await s.quota.check();
      if (allowance != CastAllowance.free) return false;
      await s.quota.recordCast();
      return true;
    case _Choice.subscribe:
      return openPaywall(context, source: 'cast_limit');
    case null:
      return false;
  }
}

enum _Choice { watch, subscribe }

class _LimitSheet extends StatelessWidget {
  const _LimitSheet({required this.canWatch});

  final bool canWatch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final limits = AppServices.of(context).limits;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.castLimitTitle(limits.castsPerDay), style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(canWatch ? l.castLimitBody : l.castLimitBodyExhausted, style: t.bodyMedium),
            const SizedBox(height: 20),
            if (canWatch)
              FilledButton(onPressed: () => Navigator.pop(context, _Choice.watch), child: Text(l.castWatchAd)),
            if (canWatch) const SizedBox(height: 8),
            canWatch
                ? OutlinedButton(onPressed: () => Navigator.pop(context, _Choice.subscribe), child: Text(l.menuPremium))
                : FilledButton(onPressed: () => Navigator.pop(context, _Choice.subscribe), child: Text(l.menuPremium)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.castComeTomorrow)),
          ],
        ),
      ),
    );
  }
}
