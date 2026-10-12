import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/deck/deck.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';
import '../daily/daily_page.dart';

/// 設定：牌面組（1909 原版／AI 繪製版）、是否使用逆位、今日一張的提醒。
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
            Text(l.settingsDeck, style: t.titleMedium),
            const SizedBox(height: 8),
            if (_decks.isEmpty)
              Text(l.settingsNoDeck, style: t.bodySmall?.copyWith(color: TarotColors.textSub))
            else
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
                          const Icon(Icons.check_circle, color: TarotColors.rice)
                        else if (d.premium && !_s.isPremium)
                          const Icon(Icons.lock_outline, color: TarotColors.textSub),
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
          ],
        ),
      ),
    );
  }
}
