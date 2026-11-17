import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/numerology/numerology.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../learn/lesson_page.dart';
import 'numerology_widgets.dart';

/// 生命靈數首頁：沒有生日先請輸入；有生日顯示生命靈數、生日數、今日流日（免費）、
/// 流月／流年／高峰數與挑戰數（訂閱），下方是數字圖鑑與課程。
class NumerologyHubPage extends StatefulWidget {
  const NumerologyHubPage({super.key});

  @override
  State<NumerologyHubPage> createState() => _NumerologyHubPageState();
}

class _NumerologyHubPageState extends State<NumerologyHubPage> {
  late final Services _s = AppServices.of(context);
  NumerologyTexts _texts = const NumerologyTexts();
  LessonBook? _book;
  Map<String, int> _unitDone = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await _s.birthdays.load();
    final texts = await _s.numerology.texts();
    final book = await _s.numerology.lessons();
    final done = {
      for (final u in book?.units ?? const <LessonUnit>[])
        u.id: await _s.lessonProgress.doneIn(u.id, [for (final x in u.lessons) x.id]),
    };
    if (!mounted) return;
    setState(() {
      _texts = texts;
      _book = book;
      _unitDone = done;
      _loaded = true;
    });
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) => _load());

  Future<void> _premium(String item, Widget page) async {
    if (_s.isPremium || await openPaywall(context, source: 'numerology_$item')) {
      if (mounted) _push(page);
    }
  }

  Future<void> _clear() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.numClearBirthday),
        content: Text(l.numClearConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) await _s.birthdays.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _s.birthdays.birthday,
      builder: (context, birth, _) => Scaffold(
        appBar: AppBar(
          title: Text(l.featureNumerology),
          actions: [
            if (birth != null)
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? pickBirthday(context) : _clear(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.numEditBirthday)),
                  PopupMenuItem(value: 'clear', child: Text(l.numClearBirthday)),
                ],
              ),
          ],
        ),
        bottomNavigationBar: const AdBanner(),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: readablePadding(context, top: 8, bottom: 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(l.numHubIntro, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                  ),
                  if (birth == null)
                    BirthdayPrompt(onSaved: () {})
                  else
                    ..._numbers(context, birth),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                    child: Text(l.numLibrary, style: t.titleMedium),
                  ),
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final n in Numerology.numbers)
                        NumberBadge(
                          number: n,
                          onTap: () => _push(NumberDetailPage(number: n, kind: NumberKind.library, texts: _texts)),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                    child: Text(l.numLessons, style: t.titleMedium),
                  ),
                  if (_book == null || _book!.units.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l.learnComingSoon, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                    )
                  else
                    for (final u in _book!.units)
                      NumTile(
                        icon: Icons.menu_book_outlined,
                        title: u.title,
                        subtitle: [
                          if ((_unitDone[u.id] ?? 0) > 0) l.learnUnitProgress(_unitDone[u.id]!, u.lessons.length),
                          if (!u.free && !_s.isPremium) l.learnPreviewFree,
                          u.summary,
                        ].join('\n'),
                        onTap: () {
                          if (!u.ready) return;
                          _push(LessonUnitPage(unit: u, cardTile: numberLessonTile));
                        },
                      ),
                ],
              ),
      ),
    );
  }

  List<Widget> _numbers(BuildContext context, DateTime birth) {
    final l = context.l10n;
    final now = DateTime.now();
    final premium = _s.isPremium;
    final lp = Numerology.lifePath(birth);
    final bd = Numerology.birthday(birth);
    final pd = Numerology.personalDay(birth, now);
    final pm = Numerology.personalMonth(birth, now);
    final py = Numerology.personalYear(birth, now);
    String name(int n) => _texts.numbers[n]?.name ?? '';
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(l.numBirthdayLabel(MaterialLocalizations.of(context).formatMediumDate(birth)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TarotColors.textSub)),
      ),
      NumTile(
        number: lp,
        title: l.numLifePath,
        subtitle: name(lp),
        onTap: () => _push(NumberDetailPage(number: lp, kind: NumberKind.lifePath, texts: _texts)),
      ),
      NumTile(
        number: bd,
        title: l.numBirthdayNumber,
        subtitle: name(bd),
        onTap: () => _push(NumberDetailPage(number: bd, kind: NumberKind.birthday, texts: _texts)),
      ),
      NumTile(
        number: pd,
        title: l.numPersonalDay,
        subtitle: _texts.numbers[pd]?.dayTheme ?? '',
        onTap: () => _push(NumberDetailPage(number: pd, kind: NumberKind.day, texts: _texts)),
      ),
      NumTile(
        number: premium ? pm : null,
        locked: !premium,
        title: l.numPersonalMonth,
        subtitle: premium ? name(pm) : l.numPremiumHint,
        onTap: () => _premium('month', NumberDetailPage(number: pm, kind: NumberKind.month, texts: _texts)),
      ),
      NumTile(
        number: premium ? py : null,
        locked: !premium,
        title: l.numPersonalYear,
        subtitle: premium ? (_texts.numbers[py]?.yearTheme ?? '') : l.numPremiumHint,
        onTap: () => _premium('year', NumberDetailPage(number: py, kind: NumberKind.year, texts: _texts)),
      ),
      NumTile(
        icon: Icons.timeline_outlined,
        locked: !premium,
        title: l.numPinnacles,
        subtitle: premium ? null : l.numPremiumHint,
        onTap: () => _premium('pinnacles', PinnaclePage(birth: birth, texts: _texts)),
      ),
    ];
  }
}
