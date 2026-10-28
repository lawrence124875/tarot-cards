import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/events/event_bus.dart';
import '../../core/monetization/ad_service.dart';
import '../../core/monetization/cast_quota.dart';
import '../../l10n/l10n.dart';
import 'paywall_page.dart';

/// 抽牌前呼叫。可以抽就回傳 [CastGrant]（已記一次），不行回傳 null。
/// 訂閱戶不計次。免費次數用完時顯示選擇：看獎勵廣告再抽一次／成為會員／明天再來；
/// 獎勵次數也用完時直接開付費牆。
/// 獎勵廣告載入失敗或無填充時仍給予這一次（計入每日獎勵上限，HANDOFF H 第 1 點）；
/// 使用者中途關掉廣告則不給。
Future<CastGrant?> ensureCanCast(BuildContext context, {required String spreadId}) async {
  final s = AppServices.of(context);
  Future<CastGrant> record({bool premium = false, bool rewarded = false}) async {
    final g = await s.quota.recordCast(premium: premium, rewarded: rewarded);
    if (g.firstEver) s.events.emit(FirstDraw(spreadId: spreadId));
    return g;
  }

  if (s.isPremium) return record(premium: true);
  var allowance = await s.quota.check();
  if (allowance == CastAllowance.free) return record();
  s.events.emit(const HitFreeLimit(type: 'draw'));
  if (!context.mounted) return null;
  if (allowance == CastAllowance.exhausted) {
    // 免費與獎勵次數都用完：直接開付費牆，上方說明明天會恢復
    if (!await openPaywall(context, source: 'cast_limit', note: context.l10n.castLimitBodyExhausted)) return null;
    return record(premium: true);
  }
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true, // 手機橫放時面板矮，內容改可捲動
    builder: (ctx) => const _LimitSheet(),
  );
  if (!context.mounted) return null;
  switch (choice) {
    case _Choice.watch:
      final ready = await s.ads.prepareRewarded();
      final result = ready ? await s.ads.showRewarded() : AdResult.failed;
      switch (result) {
        case AdResult.earned || AdResult.dismissed || AdResult.shown:
          s.events.emit(RewardedAdShown(source: 'cast', earned: result == AdResult.earned));
        case AdResult.failed || AdResult.skipped:
          s.events.emit(const RewardedAdFailed(source: 'cast'));
      }
      if (result == AdResult.dismissed) return null; // 沒看完：不給
      await s.quota.grantReward();
      allowance = await s.quota.check();
      if (allowance != CastAllowance.free) return null;
      return record(rewarded: true);
    case _Choice.subscribe:
      if (!await openPaywall(context, source: 'cast_limit')) return null;
      return record(premium: true);
    case null:
      return null;
  }
}

enum _Choice { watch, subscribe }

/// 免費次數用完、還能看獎勵廣告時的選擇。
class _LimitSheet extends StatelessWidget {
  const _LimitSheet();

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
            Text(l.castLimitBody, style: t.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, _Choice.watch), child: Text(l.castWatchAd)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context, _Choice.subscribe), child: Text(l.menuPremium)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.castComeTomorrow)),
          ],
        ),
      ),
    );
  }
}
