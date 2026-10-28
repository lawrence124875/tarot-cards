import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/widgets/adaptive_layout.dart';
import 'card_library_page.dart';
import 'lesson_page.dart';
import 'quiz_page.dart';

/// 學習首頁：牌庫、認牌練習、課程單元列表。
class LearnHubPage extends StatefulWidget {
  const LearnHubPage({super.key});

  @override
  State<LearnHubPage> createState() => _LearnHubPageState();
}

class _LearnHubPageState extends State<LearnHubPage> {
  late final Services _s = AppServices.of(context);
  LessonBook? _book;
  int _mastered = 0, _seen = 0;
  Map<String, int> _unitDone = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final book = await _s.content.lessons();
    final mastered = await _s.quiz.mastered();
    final seen = await _s.quiz.seen();
    final unitDone = {
      for (final u in book?.units ?? const <LessonUnit>[]) u.id: await _s.lessonProgress.doneIn(u.id, [for (final l in u.lessons) l.id]),
    };
    if (!mounted) return;
    setState(() {
      _book = book;
      _mastered = mastered;
      _seen = seen;
      _unitDone = unitDone;
      _loading = false;
    });
  }

  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .then((_) => _load());

  /// 付費單元也能打開：第 1 課免費試讀，其餘課在單元頁上鎖。
  void _openUnit(LessonUnit u) {
    if (!u.ready) return;
    _push(LessonUnitPage(unit: u));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.featureLearn)),
      bottomNavigationBar: const AdBanner(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readablePadding(context, top: 8, bottom: 40),
              children: [
                _Tile(
                  icon: Icons.grid_view_rounded,
                  title: l.learnLibrary,
                  subtitle: l.learnLibraryHint,
                  onTap: () => _push(const CardLibraryPage()),
                ),
                _Tile(
                  icon: Icons.style_outlined,
                  title: l.learnQuiz,
                  subtitle: _seen == 0 ? l.learnQuizHint : l.learnQuizProgress(_seen, _mastered),
                  onTap: () => _push(const QuizSetupPage()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
                  child: Text(l.learnCourses, style: t.titleMedium),
                ),
                if (_book == null || _book!.units.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l.learnComingSoon, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                  )
                else
                  for (final (i, u) in _book!.units.indexed)
                    _Tile(
                      leadingText: '${i + 1}',
                      title: u.title,
                      subtitle: !u.ready
                          ? l.learnComingSoon
                          : [
                              if ((_unitDone[u.id] ?? 0) > 0) l.learnUnitProgress(_unitDone[u.id]!, u.lessons.length),
                              if (!u.free && !_s.isPremium) l.learnPreviewFree,
                              u.summary,
                            ].join('\n'),
                      enabled: u.ready,
                      onTap: () => _openUnit(u),
                    ),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    this.icon,
    this.leadingText,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData? icon;
  final String? leadingText;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
          foregroundColor: TarotColors.earth,
          child: icon != null ? Icon(icon) : Text(leadingText ?? '', style: t.titleMedium?.copyWith(color: TarotColors.earth)),
        ),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
        onTap: onTap,
      ),
    );
  }
}
