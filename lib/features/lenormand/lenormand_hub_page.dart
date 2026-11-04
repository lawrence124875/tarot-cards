import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/lenormand/lenormand.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../learn/lesson_page.dart';
import 'lenormand_draw_page.dart';
import 'lenormand_widgets.dart';

/// 雷諾曼首頁：抽牌（單張、三張）、36 張牌庫、課程。
class LenormandHubPage extends StatefulWidget {
  const LenormandHubPage({super.key});

  @override
  State<LenormandHubPage> createState() => _LenormandHubPageState();
}

class _LenormandHubPageState extends State<LenormandHubPage> {
  late final Services _s = AppServices.of(context);
  LessonBook? _book;
  Map<int, LenormandText> _cards = const {};
  Map<String, int> _unitDone = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final book = await _s.lenormand.lessons();
    final cards = await _s.lenormand.cards();
    final done = {
      for (final u in book?.units ?? const <LessonUnit>[])
        u.id: await _s.lessonProgress.doneIn(u.id, [for (final x in u.lessons) x.id]),
    };
    if (!mounted) return;
    setState(() {
      _book = book;
      _cards = cards;
      _unitDone = done;
    });
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.featureLenormand)),
      bottomNavigationBar: const AdBanner(),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(l.lenormandHubIntro, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
          ),
          _Tile(
            icon: Icons.crop_portrait,
            title: l.lenormandDrawOne,
            onTap: () => _push(const LenormandDrawPage(spread: LenormandSpread.one)),
          ),
          _Tile(
            icon: Icons.view_week_outlined,
            title: l.lenormandDrawThree,
            onTap: () => _push(const LenormandDrawPage(spread: LenormandSpread.three)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text(l.lenormandLibrary, style: t.titleMedium),
          ),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: kLenormandAspect,
            children: [
              for (final c in LenormandCard.all)
                InkWell(
                  onTap: () => _push(LenormandCardPage(cardId: c.id)),
                  child: LenormandFace(cardId: c.id, name: _cards[c.id]?.name),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text(l.lenormandLessons, style: t.titleMedium),
          ),
          if (_book == null || _book!.units.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l.learnComingSoon, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
            )
          else
            for (final u in _book!.units)
              _Tile(
                icon: Icons.menu_book_outlined,
                title: u.title,
                subtitle: [
                  if ((_unitDone[u.id] ?? 0) > 0) l.learnUnitProgress(_unitDone[u.id]!, u.lessons.length),
                  if (!u.free && !_s.isPremium) l.learnPreviewFree,
                  u.summary,
                ].join('\n'),
                onTap: () {
                  if (!u.ready) return;
                  _push(LessonUnitPage(unit: u, cardTile: lenormandLessonTile));
                },
              ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
            foregroundColor: TarotColors.earth,
            child: Icon(icon),
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
          onTap: onTap,
        ),
      );
}
