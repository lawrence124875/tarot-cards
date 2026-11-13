import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/home_page.dart' show privacyPolicyUrl, termsOfServiceUrl;
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/deck/deck.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';
import '../daily/daily_page.dart';
import '../feedback/feedback_page.dart';
import '../intro/intro_page.dart';
import '../share/share.dart';

/// 設定：外觀（跟隨系統／淺色／深色）、牌面組（只有一組時不顯示）、是否使用逆位、今日一張的提醒；
/// 關於與隱私（功能介紹、推薦、回饋、使用統計、廣告隱私、條款與隱私權政策）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Services _s = AppServices.of(context);
  List<Deck> _decks = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final d = await _s.decks.decks();
      if (mounted) setState(() => _decks = d);
    });
  }

  Future<void> _pick(Deck d) async {
    if (d.premium && !_s.isPremium) {
      final ok = await openPaywall(context, source: 'deck_${d.id}');
      if (!ok) return;
    }
    await _s.settings.update(deckId: d.id);
    await _s.loadDeck();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final current = _s.deck.value?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: _s.settings,
        builder: (context, _) => ListView(
          padding: readablePadding(context, top: 8, bottom: 40),
          children: [
            Text(l.settingsTheme, style: t.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(l.settingsThemeSystem), icon: const Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: 'light', label: Text(l.settingsThemeLight), icon: const Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: 'dark', label: Text(l.settingsThemeDark), icon: const Icon(Icons.dark_mode_outlined)),
              ],
              selected: {_s.settings.themeMode},
              onSelectionChanged: (v) => _s.settings.update(themeMode: v.first),
            ),
            const SizedBox(height: 20),
            if (_decks.length > 1) ...[
              Text(l.settingsDeck, style: t.titleMedium),
              const SizedBox(height: 8),
            ],
            if (_decks.isEmpty)
              Text(l.settingsNoDeck, style: t.bodySmall?.copyWith(color: TarotColors.textSub))
            else if (_decks.length > 1)
              for (final d in _decks)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: d.id == current ? TarotColors.rice : Colors.transparent, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _pick(d),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        SizedBox(
                          width: 56,
                          child: AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: 0, deck: d)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.name(l.langCode), style: t.titleSmall),
                            const SizedBox(height: 4),
                            Text(d.credit(l.langCode), style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
                            if (d.aiGenerated) ...[
                              const SizedBox(height: 6),
                              Text(l.settingsDeckAi, style: t.bodySmall?.copyWith(color: TarotColors.twilight)),
                            ],
                          ]),
                        ),
                        if (d.id == current)
                          Icon(Icons.check_circle, color: TarotColors.rice)
                        else if (d.premium && !_s.isPremium)
                          Icon(Icons.lock_outline, color: TarotColors.textSub),
                      ]),
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                title: Text(l.settingsReversals),
                subtitle: Text(l.settingsReversalsHint),
                value: _s.settings.reversals,
                onChanged: (v) => _s.settings.update(reversals: v),
              ),
            ),
            const SizedBox(height: 10),
            const DailyReminderTile(),
            const SizedBox(height: 24),
            Text(l.settingsAbout, style: t.titleMedium),
            const SizedBox(height: 8),
            // 0.4.0：原本首頁右上選單的項目收到這裡（會員入口移到首頁）
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: Text(l.menuIntro),
                  onTap: () => showIntro(Navigator.of(context)),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l.menuShareApp),
                  onTap: () => shareApp(context),
                ),
                if (_s.feedback != null)
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(l.menuFeedback),
                    onTap: () => openFeedback(context),
                  ),
                if (_s.usage != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: _s.usage!.enabled,
                    builder: (context, on, _) => SwitchListTile(
                      secondary: const Icon(Icons.insights_outlined),
                      title: Text(l.menuShareUsage),
                      value: on,
                      onChanged: (v) => _s.usage!.set(v),
                    ),
                  ),
                if (_s.ads.privacyOptionsRequired && !_s.isPremium)
                  ListTile(
                    leading: const Icon(Icons.ads_click_outlined),
                    title: Text(l.menuAdPrivacy),
                    onTap: () => _s.ads.showPrivacyOptions(),
                  ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l.menuTermsOfService),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(termsOfServiceUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.menuPrivacyPolicy),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(privacyPolicyUrl),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
