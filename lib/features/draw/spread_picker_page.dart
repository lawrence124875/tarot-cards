import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/events/event_bus.dart';
import '../../core/tarot/spread.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/spread_layout.dart';
import 'draw_page.dart';

/// 選擇牌陣。會員牌陣免費版也看得到（附鎖），點了開訂閱頁。
class SpreadPickerPage extends StatefulWidget {
  const SpreadPickerPage({super.key});

  @override
  State<SpreadPickerPage> createState() => _SpreadPickerPageState();
}

class _SpreadPickerPageState extends State<SpreadPickerPage> {
  late final Services _s = AppServices.of(context);
  late final Future<SpreadTexts?> _texts = _s.content.spreads();

  Future<void> _open(Spread spread) async {
    if (spread.premium && !_s.isPremium) {
      _s.events.emit(const HitFreeLimit(type: 'spread'));
      if (!await openPaywall(context, source: 'spread_${spread.id}') || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DrawPage(spread: spread)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.spreadPickerTitle)),
      bottomNavigationBar: const AdBanner(),
      body: FutureBuilder<SpreadTexts?>(
        future: _texts,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final texts = snap.data;
          return ListView(
            padding: readablePadding(context, horizontal: 16, top: 8, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(l.spreadPickerHint, style: t.bodySmall, textAlign: TextAlign.center),
              ),
              for (final sp in Spreads.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(sp),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: IgnorePointer(
                              child: SpreadLayout(spread: sp, cards: const [], revealed: const {}, maxCardWidth: 40),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(child: Text(texts?[sp.id]?.name ?? sp.id, style: t.titleMedium)),
                                  const SizedBox(width: 6),
                                  Text(l.cardCount(sp.size), style: t.bodySmall),
                                  if (sp.premium && !_s.isPremium) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.lock_outline, size: 16, color: TarotColors.textSub),
                                  ],
                                ]),
                                const SizedBox(height: 4),
                                Text(texts?[sp.id]?.description ?? '', style: t.bodySmall),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
