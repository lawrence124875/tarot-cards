import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/feedback/feedback_page.dart';
import '../features/intro/intro_page.dart';
import '../features/settings/settings_page.dart';
import '../features/share/share.dart';
import '../shared/premium/ad_banner.dart';
import '../shared/premium/paywall_page.dart';

import '../shared/widgets/adaptive_layout.dart';
import '../shared/widgets/card_back.dart';
import '../shared/widgets/card_face.dart';
import '../l10n/l10n.dart';
import 'feature_registry.dart';
import 'services.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final features = activeFeatures(AppServices.of(context).flags).toList();
    final primary = features.where((f) => f.placement == FeaturePlacement.primary && f.builder != null);
    final secondary = features.where((f) => f.placement == FeaturePlacement.secondary && f.builder != null);

    void open(AppFeature f) => Navigator.of(context).push(MaterialPageRoute<void>(builder: f.builder!));

    final brand = [
      const SizedBox(
        width: 150,
        child: AspectRatio(aspectRatio: kCardAspect, child: CardBack()),
      ),
      const SizedBox(height: 32),
      Text(l.appTitle, style: t.displaySmall),
      const SizedBox(height: 6),
      Text(l.appSubtitle, style: t.titleSmall?.copyWith(color: TarotColors.earth, letterSpacing: tracking(4))),
    ];
    final motto = Text(l.homeMotto,
        textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: TarotColors.textSub, fontSize: 15));
    final actions = [
      for (final f in primary)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton(onPressed: () => open(f), child: Text(f.label(l))),
        ),
      // 次要功能用 Wrap：字較長的語言（如阿拉伯文）在橫放的窄欄裡自動換行，不溢出
      Wrap(
        alignment: WrapAlignment.center,
        children: [for (final f in secondary) TextButton(onPressed: () => open(f), child: Text(f.label(l)))],
      ),
    ];

    // 0.1.0+16：整頁一定一屏顯示完（不捲動）。主內容放在 FittedBox 裡，螢幕矮或系統字體放大時
    // 等比縮小；免責聲明固定貼在底部，不會被擠到畫面外。
    return Scaffold(
      bottomNavigationBar: const AdBanner(), // 免費版底部橫幅（§23）
      body: SafeArea(
        child: Stack(children: [
          LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      // 手機橫放（矮而寬）：牌與標題在左、箴言與按鈕在右，不必縮得太小
                      child: isShortWide(box.biggest)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(mainAxisSize: MainAxisSize.min, children: brand),
                                const SizedBox(width: 56),
                                SizedBox(
                                  width: 320,
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [motto, ...actions]),
                                ),
                              ],
                            )
                          : SizedBox(
                              // 平板、摺疊機：不隨螢幕無限加寬
                              width: (box.maxWidth - 56).clamp(0, 480).toDouble(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [...brand, const SizedBox(height: 16), motto, const SizedBox(height: 32), ...actions],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.homeDisclaimer,
                  style: t.bodySmall?.copyWith(fontSize: 11, color: TarotColors.textSub.withValues(alpha: 0.75)),
                ),
              ),
            ],
          ),
        ),
          const PositionedDirectional(top: 4, end: 4, child: _HomeMenu()),
        ]),
      ),
    );
  }
}

enum _MenuItem { premium, settings, intro, shareApp, feedback, usage, adPrivacy, privacyPolicy }

/// 首頁右上角選單：會員、設定、功能介紹、推薦給朋友、意見回饋、分享使用統計（勾選開關）、廣告隱私設定（需要同意的地區才出現）、隱私權政策。
class _HomeMenu extends StatelessWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppServices.of(context);
    return PopupMenuButton<_MenuItem>(
      icon: Icon(Icons.more_vert, color: TarotColors.textSub),
      onSelected: (item) {
        switch (item) {
          case _MenuItem.premium:
            openPaywall(context, source: 'menu');
          case _MenuItem.settings:
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
          case _MenuItem.intro:
            showIntro(Navigator.of(context));
          case _MenuItem.shareApp:
            shareApp(context);
          case _MenuItem.feedback:
            openFeedback(context);
          case _MenuItem.usage:
            final u = s.usage!;
            u.set(!u.enabled.value);
          case _MenuItem.adPrivacy:
            s.ads.showPrivacyOptions();
          case _MenuItem.privacyPolicy:
            launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: _MenuItem.premium, child: Text(l.menuPremium)),
        PopupMenuItem(value: _MenuItem.settings, child: Text(l.settingsTitle)),
        PopupMenuItem(value: _MenuItem.intro, child: Text(l.menuIntro)),
        PopupMenuItem(value: _MenuItem.shareApp, child: Text(l.menuShareApp)),
        if (s.feedback != null) PopupMenuItem(value: _MenuItem.feedback, child: Text(l.menuFeedback)),
        if (s.usage != null)
          CheckedPopupMenuItem(
            value: _MenuItem.usage,
            checked: s.usage!.enabled.value,
            child: Text(l.menuShareUsage),
          ),
        if (s.ads.privacyOptionsRequired && !s.isPremium)
          PopupMenuItem(value: _MenuItem.adPrivacy, child: Text(l.menuAdPrivacy)),
        PopupMenuItem(value: _MenuItem.privacyPolicy, child: Text(l.menuPrivacyPolicy)),
      ],
    );
  }
}

/// 隱私權政策（本 repo GitHub Pages，§20）。
const privacyPolicyUrl = 'https://lawrence124875.github.io/tarot-cards/privacy.html';
