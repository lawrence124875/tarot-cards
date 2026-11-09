import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/cross/cross_composer.dart';
import '../../core/cross/cross_engine.dart';
import '../../core/events/event_bus.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/lenormand/lenormand.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../lenormand/lenormand_widgets.dart';
import 'cross_page.dart';

/// 紀錄回顧中的交叉解讀：雷諾曼三張、當時的交叉結果、「事後應驗了嗎？」（應驗／部分／沒有）。
class CrossJournalSection extends StatefulWidget {
  const CrossJournalSection({super.key, required this.entry, required this.onChanged});

  final JournalEntry entry;
  final Future<void> Function(JournalEntry) onChanged;

  @override
  State<CrossJournalSection> createState() => _CrossJournalSectionState();
}

class _CrossJournalSectionState extends State<CrossJournalSection> {
  CrossScores? _scores;
  CrossTemplates? _templates;
  Map<int, LenormandText> _names = const {};
  CrossCards? _cards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = AppServices.of(context);
      final scores = await loadCrossScores();
      final templates = await loadCrossTemplates(L10n.contentFolder);
      final names = await s.lenormand.cards();
      if (!mounted) return;
      final e = widget.entry;
      final cards = await loadCrossCards(context, scores, e.cards, e.lenormand, e.area);
      if (mounted) {
        setState(() {
          _scores = scores;
          _templates = templates;
          _names = names;
          _cards = cards;
        });
      }
    });
  }

  Future<void> _verdict(String v) async {
    AppServices.of(context).events.emit(CrossVerified(result: v));
    await widget.onChanged(widget.entry.copyWith(verdict: v));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final e = widget.entry;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Section(
        title: l.crossLenormandRow,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final id in e.lenormand)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(children: [
                SizedBox(
                  width: 72,
                  child: AspectRatio(aspectRatio: kLenormandAspect, child: LenormandFace(cardId: id, name: _names[id]?.name)),
                ),
                const SizedBox(height: 4),
                Text(_names[id]?.name ?? '$id', style: t.bodySmall),
              ]),
            ),
        ]),
      ),
      if (_scores != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CrossResultView(
            result: evaluateCross(_scores!, e.cards, e.lenormand),
            templates: _templates ?? CrossTemplates(const {}),
            seed: crossSeed([for (final c in e.cards) c.cardId], e.lenormand),
            cards: _cards,
            onUnlocked: () => setState(() {}),
          ),
        ),
      Section(
        title: l.crossVerifyTitle,
        child: SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'yes', label: Text(l.crossVerifyYes)),
            ButtonSegment(value: 'partial', label: Text(l.crossVerifyPartial)),
            ButtonSegment(value: 'no', label: Text(l.crossVerifyNo)),
          ],
          selected: {if (e.verdict.isNotEmpty) e.verdict},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) _verdict(s.first);
          },
        ),
      ),
    ]);
  }
}
