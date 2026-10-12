import 'package:flutter/material.dart';

import '../app/services.dart';
import '../app/theme.dart';
import '../core/content/card_content.dart';
import '../core/tarot/tarot_card.dart';
import '../l10n/l10n.dart';
import '../shared/widgets/adaptive_layout.dart';
import '../shared/widgets/card_face.dart';
import '../shared/widgets/symbol_overlay.dart';
import 'east_west.dart';
import 'section.dart';

/// 一張牌的完整資料（學習用，永遠免費）：牌面（點開可看象徵物）、關鍵詞、元素與對應、
/// 牌面上的象徵、Waite 原著的描述與牌義、正逆位全部三組解讀、東西相映。
class CardDetailPage extends StatefulWidget {
  const CardDetailPage({super.key, required this.cardId, this.reversed = false});

  final int cardId;

  /// 從解讀頁進來時預設展開逆位那一側。
  final bool reversed;

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  late final Future<CardContent?> _content = AppServices.of(context).content.card(widget.cardId);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final card = TarotCard.byId(widget.cardId);
    return Scaffold(
      appBar: AppBar(title: Text(l.cardName(widget.cardId))),
      body: FutureBuilder<CardContent?>(
        future: _content,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final c = snap.data;
          return DefaultTabController(
            length: 2,
            initialIndex: widget.reversed ? 1 : 0,
            child: ListView(
              padding: readablePadding(context, top: 8, bottom: 40),
              children: [
                Center(
                  child: SizedBox(
                    width: 200,
                    child: AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: widget.cardId, zoomable: true)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l.cardFacts(card.isMajor ? l.arcanaMajor : l.arcanaMinor, l.elementLabel(card.element)),
                    textAlign: TextAlign.center, style: t.bodySmall),
                if (card.attribution != null)
                  Text(l.attributionLine(l.attributionName(card.attribution!.name)),
                      textAlign: TextAlign.center, style: t.bodySmall),
                if (c == null)
                  Section(title: l.sectionReading, child: Text(l.readingNotWritten))
                else ...[
                  _Keywords(content: c),
                  if (c.symbols.isNotEmpty)
                    Section(
                      title: l.sectionSymbols,
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final s in c.symbols)
                          ActionChip(label: Text(s.name), onPressed: () => showSymbol(context, s)),
                      ]),
                    ),
                  if (!c.waite.isEmpty) _Waite(w: c.waite),
                  const SizedBox(height: 24),
                  TabBar(
                    labelColor: TarotColors.earth,
                    unselectedLabelColor: TarotColors.textSub,
                    indicatorColor: TarotColors.earth,
                    tabs: [Tab(text: l.upright), Tab(text: l.reversed)],
                  ),
                  Builder(builder: (context) {
                    final tab = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tab,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, r) in c.readings(tab.index == 1).indexed) _ReadingTile(index: i, r: r),
                        ],
                      ),
                    );
                  }),
                  if (c.eastWest != null) EastWestSection(ew: c.eastWest!),
                  if (c.affirmation.isNotEmpty) Section(title: l.sectionAffirmation, child: Text(c.affirmation, style: t.bodyLarge)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Keywords extends StatelessWidget {
  const _Keywords({required this.content});

  final CardContent content;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    Widget row(String label, List<String> words) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 56, child: Text(label, style: t.bodySmall)),
            Expanded(child: Text(words.join(l.separator), style: t.bodyMedium?.copyWith(color: TarotColors.earth))),
          ]),
        );
    return Section(
      title: l.sectionKeywords,
      child: Column(children: [
        row(l.upright, content.keywordsUpright),
        row(l.reversed, content.keywordsReversed),
      ]),
    );
  }
}

class _Waite extends StatelessWidget {
  const _Waite({required this.w});

  final WaiteText w;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Section(
      title: l.sectionWaite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.waiteIntro, style: t.bodySmall),
          const SizedBox(height: 8),
          if (w.description.isNotEmpty) Text(w.description),
          if (w.upright.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.waiteUpright(w.upright)),
          ],
          if (w.reversed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.waiteReversed(w.reversed)),
          ],
          const SizedBox(height: 8),
          Text([w.source, w.translationNote].where((s) => s.isNotEmpty).join(l.separator), style: t.bodySmall),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.index, required this.r});

  final int index;
  final ReadingContent r;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(r.title, style: t.titleMedium),
        subtitle: Text(l.readingAngle(r.angle), style: t.bodySmall),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          Section(title: l.sectionImage, child: Text(r.image)),
          Section(title: l.sectionSource, child: Text(r.source)),
          Section(title: l.sectionMeaning, child: Text(r.meaning)),
          Section(title: l.sectionForYou, child: Text(r.forYou)),
          Section(title: l.sectionAction, child: Text(r.action)),
          Section(title: l.sectionQuestion, child: Text(r.question)),
        ],
      ),
    );
  }
}
