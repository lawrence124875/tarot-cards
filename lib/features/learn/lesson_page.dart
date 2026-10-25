import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../l10n/l10n.dart';
import '../../reading/card_detail_page.dart';
import '../../reading/section.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';

/// 一個單元的課程列表；讀完的課打勾。
class LessonUnitPage extends StatefulWidget {
  const LessonUnitPage({super.key, required this.unit});

  final LessonUnit unit;

  @override
  State<LessonUnitPage> createState() => _LessonUnitPageState();
}

class _LessonUnitPageState extends State<LessonUnitPage> {
  Set<String> _done = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = AppServices.of(context).lessonProgress;
    final done = <String>{
      for (final l in widget.unit.lessons)
        if (await p.isDone(widget.unit.id, l.id)) l.id,
    };
    if (mounted) setState(() => _done = done);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final unit = widget.unit;
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          if (unit.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(unit.summary, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
            ),
          for (final (i, lesson) in unit.lessons.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Text('${i + 1}', style: t.titleMedium?.copyWith(color: TarotColors.earth)),
                title: Text(lesson.title),
                trailing: _done.contains(lesson.id)
                    ? Icon(Icons.check_circle_outline, color: TarotColors.earth, semanticLabel: l.lessonRead)
                    : Icon(Icons.chevron_right, color: TarotColors.textSub),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => LessonPage(unit: unit, index: i)))
                    .then((_) => _load()),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一課：各段落、課中提到的牌、出處；底部可到下一課。
class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.unit, required this.index});

  final LessonUnit unit;
  final int index;

  Future<void> _markDone(BuildContext context) =>
      AppServices.of(context).lessonProgress.markDone(unit.id, unit.lessons[index].id);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final lesson = unit.lessons[index];
    final hasNext = index + 1 < unit.lessons.length;
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Text(lesson.title, style: t.headlineSmall),
          for (final s in lesson.sections)
            if (s.heading.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 16), child: Text(s.body))
            else
              Section(title: s.heading, child: Text(s.body)),
          if (lesson.cards.isNotEmpty)
            Section(
              title: l.lessonCards,
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: lesson.cards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final id = lesson.cards[i];
                    return InkWell(
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => CardDetailPage(cardId: id))),
                      child: SizedBox(
                        width: 70,
                        child: Column(children: [
                          AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: id)),
                          const SizedBox(height: 4),
                          Text(l.cardName(id),
                              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.bodySmall),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (lesson.sources.isNotEmpty)
            Section(
              title: l.lessonSources,
              child: Text(lesson.sources.join('\n'), style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
            ),
          const SizedBox(height: 28),
          if (hasNext)
            Center(
              child: FilledButton(
                onPressed: () async {
                  await _markDone(context);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                    builder: (_) => LessonPage(unit: unit, index: index + 1),
                  ));
                },
                child: Text(l.lessonNext),
              ),
            )
          else
            Center(
              child: OutlinedButton(
                onPressed: () async {
                  await _markDone(context);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(l.lessonDone),
              ),
            ),
        ],
      ),
    );
  }
}
