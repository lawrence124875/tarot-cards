import 'package:flutter/material.dart';

import '../core/content/card_content.dart';
import '../l10n/l10n.dart';
import 'section.dart';

/// 東西相映：一句東方經典＋一個心理學概念，接到這張牌。
class EastWestSection extends StatelessWidget {
  const EastWestSection({super.key, required this.ew});

  final EastWestContent ew;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    return Section(
      title: l.sectionEastWest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ew.hasQuote) ...[
            Text(l.quoteMarks(ew.quoteText), style: t.bodyLarge),
            const SizedBox(height: 4),
            Text(l.quoteAttribution(ew.quoteAuthor, ew.quoteSource), style: t.bodySmall),
            if (ew.quoteTranslationNote.isNotEmpty) Text(ew.quoteTranslationNote, style: t.bodySmall),
            const SizedBox(height: 8),
            Text(ew.quoteNote),
          ],
          if (ew.hasQuote && ew.hasPsychology) const SizedBox(height: 20),
          if (ew.hasPsychology) ...[
            Text(ew.psyName, style: t.titleMedium),
            Text(ew.psyOrigin, style: t.bodySmall),
            const SizedBox(height: 8),
            Text(ew.psyNote),
            if (ew.psyEvidence.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ew.psyEvidence, style: t.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}
