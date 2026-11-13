import 'package:flutter/material.dart';

import '../core/tarot/draw.dart';
import '../features/cross/cross_hub_feature.dart';
import '../features/daily/daily_feature.dart';
import '../features/daily/daily_page.dart';
import '../features/draw/draw_feature.dart';
import '../features/lenormand/lenormand_feature.dart';
import '../features/runes/rune_feature.dart';
import '../features/settings/settings_page.dart';
import '../l10n/l10n.dart';
import '../shared/premium/ad_banner.dart';
import '../shared/premium/paywall_page.dart';
import '../shared/widgets/adaptive_layout.dart';
import '../shared/widgets/card_back.dart';
import '../shared/widgets/card_face.dart';
import 'feature_registry.dart';
import 'services.dart';
import 'theme.dart';

/// 占卜系統入口（塔羅／雷諾曼／盧恩／交叉解讀），首頁與「占卜」分頁共用。遠端關掉的不顯示。
class _System {
  const _System(this.feature, this.icon, this.title, this.desc);

  final AppFeature feature;
  final IconData icon;
  final LocalizedText title;
  final LocalizedText desc;

  void open(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: feature.builder!));
}

List<_System> _systems(BuildContext context) {
  final ids = activeFeatures(AppServices.of(context).flags).map((f) => f.id).toSet();
  return [
    _System(drawFeature, Icons.style_outlined, (l) => l.homeSystemTarot, (l) => l.homeTarotDesc),
    _System(lenormandFeature, Icons.grid_view_outlined, (l) => l.featureLenormand, (l) => l.homeLenormandDesc),
    _System(runeFeature, Icons.hexagon_outlined, (l) => l.featureRunes, (l) => l.homeRunesDesc),
    _System(crossHubFeature, Icons.join_inner, (l) => l.featureCrossHub, (l) => l.homeCrossDesc),
  ].where((s) => ids.contains(s.feature.id)).toList();
}

/// 「今日」分頁（首頁）：品牌＋設定、今日一張大卡（是否已抽、連續天數）、會員入口（免費版）、
/// 三張系統卡＋交叉解讀、箴言與免責聲明。內容可捲動，不再整頁縮放（字放大、阿拉伯文也不會變小）。
class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final s = AppServices.of(context);
    final daily = activeFeatures(s.flags).any((f) => f.id == dailyFeature.id);
    final systems = _systems(context);
    final singles = systems.where((x) => x.feature.id != crossHubFeature.id).toList();
    final cross = systems.where((x) => x.feature.id == crossHubFeature.id);

    return Scaffold(
      bottomNavigationBar: const AdBanner(), // 免費版底部橫幅（§4 H：首頁）
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: readablePadding(context, horizontal: 20, top: 8, bottom: 24, maxWidth: 560),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.appTitle, style: t.headlineSmall),
                  const SizedBox(height: 2),
                  Text(l.appSubtitle, style: t.titleSmall?.copyWith(color: TarotColors.earth, letterSpacing: tracking(2))),
                ]),
              ),
              IconButton(
                tooltip: l.homeSettings,
                icon: Icon(Icons.settings_outlined, color: TarotColors.textSub),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
              ),
            ]),
            const SizedBox(height: 16),
            if (daily) const _TodayCard(),
            ValueListenableBuilder<bool>(
              valueListenable: s.premium.isPremium,
              builder: (context, premium, _) => premium ? const SizedBox.shrink() : const _PremiumCard(),
            ),
            if (systems.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                child: Text(l.navDivination, style: t.titleMedium),
              ),
              if (singles.isNotEmpty)
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final x in singles) Expanded(child: _SystemTile(system: x)),
                  ]),
                ),
              for (final x in cross) _SystemListTile(system: x),
            ],
            const SizedBox(height: 28),
            Text(l.homeMotto,
                textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: TarotColors.textSub, fontSize: 15)),
            const SizedBox(height: 16),
            Text(
              l.homeDisclaimer,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(fontSize: 11, color: TarotColors.textSub.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「占卜」分頁：各系統一張卡，附一句說明。
class DivinationTab extends StatelessWidget {
  const DivinationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.navDivination)),
      bottomNavigationBar: const AdBanner(),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [for (final x in _systems(context)) _SystemListTile(system: x)],
      ),
    );
  }
}

/// 今日一張大卡：還沒抽顯示牌背與「翻開今天的牌」；抽過顯示今天那張；連續天數 ≥ 1 時顯示。
/// 從今日一張頁回來時重新讀取。
class _TodayCard extends StatefulWidget {
  const _TodayCard();

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  late final Services _s = AppServices.of(context);
  DrawnCard? _card;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final card = await _s.daily.today(now);
    final streak = await _s.daily.streak(now);
    if (!mounted) return;
    setState(() {
      _card = card;
      _streak = streak;
    });
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DailyPage()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = _card;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(
              width: 76,
              child: AspectRatio(
                aspectRatio: kCardAspect,
                child: c == null ? const CardBack() : CardFace(cardId: c.cardId, reversed: c.reversed, nameless: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.featureDaily, style: t.titleLarge),
                const SizedBox(height: 6),
                if (c == null)
                  Text(l.dailyPrompt, style: t.bodyMedium?.copyWith(color: TarotColors.textSub))
                else ...[
                  Text(l.homeTodayDrawn, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
                  Text(c.reversed ? l.cardReversedName(l.cardName(c.cardId)) : l.cardName(c.cardId),
                      style: t.titleMedium?.copyWith(color: TarotColors.earth)),
                ],
                if (_streak > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.local_fire_department_outlined, size: 18, color: TarotColors.earth),
                    const SizedBox(width: 4),
                    Flexible(child: Text(l.homeStreak(_streak), style: t.bodySmall)),
                  ]),
                ],
                if (c == null) ...[
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _open, child: Text(l.dailyFlip)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 會員入口（只在免費版顯示）。
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(Icons.workspace_premium_outlined, color: TarotColors.earth),
        title: Text(l.menuPremium),
        subtitle: Text(l.homePremiumDesc, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
        onTap: () => openPaywall(context, source: 'home'),
      ),
    );
  }
}

Widget _avatar(IconData icon) => CircleAvatar(
      backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
      foregroundColor: TarotColors.earth,
      child: Icon(icon),
    );

/// 首頁的小系統卡（三張並排）。
class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.system});

  final _System system;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => system.open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _avatar(system.icon),
            const SizedBox(height: 8),
            Text(system.title(l),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall),
          ]),
        ),
      ),
    );
  }
}

/// 一列一個系統，附說明（「占卜」分頁、首頁的交叉解讀）。
class _SystemListTile extends StatelessWidget {
  const _SystemListTile({required this.system});

  final _System system;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _avatar(system.icon),
        title: Text(system.title(l)),
        subtitle: Text(system.desc(l), maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
        onTap: () => system.open(context),
      ),
    );
  }
}
