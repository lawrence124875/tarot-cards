import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../learn/lesson_page.dart';
import 'numerology_quiz_page.dart';
import 'numerology_widgets.dart';

/// 生命靈數課程：7 個單元＋靈數練習。第 1 單元全免費（free=true），其他單元第 1 課免費試讀
/// （LessonUnit.lessonFree，比照塔羅／雷諾曼／盧恩課程）。學習分頁與靈數首頁底部都從這裡進入。
class NumerologyCoursePage extends StatefulWidget {
  const NumerologyCoursePage({super.key, this.book});

  /// 測試可直接注入；null 時從內容檔讀取。
  final LessonBook? book;

  @override
  State<NumerologyCoursePage> createState() => _NumerologyCoursePageState();
}

class _NumerologyCoursePageState extends State<NumerologyCoursePage> {
  late final Services _s = AppServices.of(context);
  LessonBook? _book;
  Map<String, int> _unitDone = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final book = widget.book ?? await _s.numerology.lessons();
    final done = {
      for (final u in book?.units ?? const <LessonUnit>[])
        u.id: await _s.lessonProgress.doneIn(u.id, [for (final x in u.lessons) x.id]),
    };
    if (!mounted) return;
    setState(() {
      _book = book;
      _unitDone = done;
      _loading = false;
    });
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final units = _book?.units ?? const <LessonUnit>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.numLessons)),
      bottomNavigationBar: const AdBanner(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readablePadding(context, top: 8, bottom: 40),
              children: [
                NumTile(
                  icon: Icons.quiz_outlined,
                  title: l.numQuiz,
                  subtitle: l.numQuizHint,
                  onTap: () => _push(const NumerologyQuizPage()),
                ),
                const SizedBox(height: 16),
                if (units.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l.learnComingSoon, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                  )
                else
                  for (final (i, u) in units.indexed)
                    NumTile(
                      number: i + 1,
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
    );
  }
}
