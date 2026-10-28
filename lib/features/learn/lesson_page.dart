import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/events/event_bus.dart';
import '../../l10n/l10n.dart';
import '../../reading/card_detail_page.dart';
import '../../reading/section.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';

/// 一個單元的課程列表；讀完的課打勾。免費版在付費單元只開第 1 課（試讀），其餘上鎖。
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

  Future<void> _open(int i) async {
    final s = AppServices.of(context);
    if (!widget.unit.lessonFree(i) && !s.isPremium) {
      s.events.emit(const HitFreeLimit(type: 'lesson'));
      if (!await openPaywall(context, source: 'lesson_${widget.unit.id}') || !mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonPage(unit: widget.unit, index: i)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final unit = widget.unit;
    final premium = AppServices.of(context).isPremium;
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      bottomNavigationBar: const AdBanner(),
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
                    : Icon(!premium && !unit.lessonFree(i) ? Icons.lock_outline : Icons.chevron_right,
                        color: TarotColors.textSub),
                onTap: () => _open(i),
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

  Future<void> _goNext(BuildContext context) async {
    await _markDone(context);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => LessonPage(unit: unit, index: index + 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final lesson = unit.lessons[index];
    final hasNext = index + 1 < unit.lessons.length;
    // 試讀課（付費單元第 1 課）讀完：引導解鎖本單元其餘課
    final preview = hasNext && !AppServices.of(context).isPremium && !unit.lessonFree(index + 1);
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
          if (preview)
            _UnlockRest(unit: unit, onUnlocked: () => _goNext(context))
          else if (hasNext)
            Center(
              child: FilledButton(
                onPressed: () => _goNext(context),
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

/// 試讀課結尾：「解鎖本單元其餘 N 課」→ 付費牆（來源 lesson_preview_<unitId>）。
class _UnlockRest extends StatelessWidget {
  const _UnlockRest({required this.unit, required this.onUnlocked});

  final LessonUnit unit;
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(l.lessonPreviewEnd, style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: const Icon(Icons.lock_open_outlined, size: 18),
            label: Text(l.lessonUnlockRest(unit.lockedCount)),
            onPressed: () async {
              AppServices.of(context).events.emit(const HitFreeLimit(type: 'lesson'));
              if (await openPaywall(context, source: 'lesson_preview_${unit.id}') && context.mounted) onUnlocked();
            },
          ),
        ]),
      ),
    );
  }
}
