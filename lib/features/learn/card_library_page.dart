import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/tarot/tarot_card.dart';
import '../../l10n/l10n.dart';
import '../../reading/card_detail_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';

/// 牌庫：大阿爾克那與四個花色分組，點牌看完整牌義（不鎖）。
class CardLibraryPage extends StatelessWidget {
  const CardLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = <(String, List<TarotCard>)>[
      (l.arcanaMajor, TarotCard.majors.toList()),
      for (final s in Suit.values) (l.suitGroup(l.suitName(s), l.elementLabel(s.element)), TarotCard.ofSuit(s).toList()),
    ];
    return DefaultTabController(
      length: groups.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.learnLibrary),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: TarotColors.text,
            indicatorColor: TarotColors.rice,
            tabs: [for (final g in groups) Tab(text: g.$1)],
          ),
        ),
        body: TabBarView(children: [for (final g in groups) _Grid(cards: g.$2)]),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cards});

  final List<TarotCard> cards;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final deck = AppServices.of(context).deck;
    return ValueListenableBuilder(
      valueListenable: deck,
      builder: (context, d, _) => GridView.builder(
        padding: readablePadding(context, top: 16, bottom: 40),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.48,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final c = cards[i];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => CardDetailPage(cardId: c.id))),
            child: Column(
              children: [
                AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: c.id, deck: d)),
                const SizedBox(height: 6),
                Text(l.cardName(c.id),
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}
