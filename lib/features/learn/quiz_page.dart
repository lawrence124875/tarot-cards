import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/tarot/tarot_card.dart';
import '../../l10n/l10n.dart';
import '../../reading/card_detail_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_face.dart';

/// 認牌練習的範圍。
enum QuizPool { all, majors, wands, cups, swords, pentacles }

Iterable<int> quizPoolIds(QuizPool p) => switch (p) {
      QuizPool.all => [for (var i = 0; i < TarotCard.count; i++) i],
      QuizPool.majors => TarotCard.majors.map((c) => c.id),
      QuizPool.wands => TarotCard.ofSuit(Suit.wands).map((c) => c.id),
      QuizPool.cups => TarotCard.ofSuit(Suit.cups).map((c) => c.id),
      QuizPool.swords => TarotCard.ofSuit(Suit.swords).map((c) => c.id),
      QuizPool.pentacles => TarotCard.ofSuit(Suit.pentacles).map((c) => c.id),
    };

/// 選擇練習範圍。
class QuizSetupPage extends StatelessWidget {
  const QuizSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    String label(QuizPool p) => switch (p) {
          QuizPool.all => l.quizPoolAll,
          QuizPool.majors => l.arcanaMajor,
          QuizPool.wands => l.suitName(Suit.wands),
          QuizPool.cups => l.suitName(Suit.cups),
          QuizPool.swords => l.suitName(Suit.swords),
          QuizPool.pentacles => l.suitName(Suit.pentacles),
        };
    return Scaffold(
      appBar: AppBar(title: Text(l.learnQuiz)),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Text(l.quizIntro, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
          const SizedBox(height: 20),
          for (final p in QuizPool.values)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(label(p)),
                trailing: const Icon(Icons.chevron_right, color: TarotColors.textSub),
                onTap: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute<void>(builder: (_) => QuizPage(pool: p))),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一輪認牌：看牌面選牌名（四選一）。答完顯示關鍵詞，可點開牌義。
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.pool});

  final QuizPool pool;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final Services _s = AppServices.of(context);
  List<int> _round = const [];
  int _index = 0, _correct = 0;
  List<int> _options = const [];
  int? _picked;
  CardContent? _content;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final r = await _s.quiz.round(DateTime.now(), pool: quizPoolIds(widget.pool), random: _s.random);
    if (!mounted) return;
    setState(() {
      _round = r;
      _index = 0;
      _correct = 0;
      _loading = false;
    });
    _prepare();
  }

  /// 干擾選項優先取同組（同花色或同為大阿爾克那），練得到真正容易混淆的地方。
  void _prepare() {
    if (_index >= _round.length) return;
    final id = _round[_index];
    final card = TarotCard.byId(id);
    final rnd = _s.random;
    final same = [
      for (final c in TarotCard.all)
        if (c.id != id && (card.isMajor ? c.isMajor : c.suit == card.suit || c.rank == card.rank)) c.id,
    ]..shuffle(rnd);
    final options = <int>{id, ...same.take(3)};
    while (options.length < 4) {
      options.add(rnd.nextInt(TarotCard.count));
    }
    setState(() {
      _options = options.toList()..shuffle(rnd);
      _picked = null;
      _content = null;
    });
  }

  Future<void> _answer(int id) async {
    if (_picked != null) return;
    final target = _round[_index];
    final ok = id == target;
    setState(() {
      _picked = id;
      if (ok) _correct++;
    });
    await _s.quiz.answer(target, ok, DateTime.now());
    final content = await _s.content.card(target);
    if (mounted) setState(() => _content = content);
  }

  void _next() {
    setState(() => _index++);
    _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    if (_loading) return Scaffold(appBar: AppBar(title: Text(l.learnQuiz)), body: const Center(child: CircularProgressIndicator()));
    if (_round.isEmpty || _index >= _round.length) {
      return Scaffold(
        appBar: AppBar(title: Text(l.learnQuiz)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wb_sunny_outlined, size: 48, color: TarotColors.dawn),
              const SizedBox(height: 16),
              Text(_round.isEmpty ? l.quizNothingDue : l.quizDone(_correct, _round.length),
                  textAlign: TextAlign.center, style: t.titleMedium),
              const SizedBox(height: 24),
              if (_round.isNotEmpty) FilledButton(onPressed: _start, child: Text(l.quizAgain)),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.back)),
            ]),
          ),
        ),
      );
    }
    final target = _round[_index];
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: Text(l.quizProgress(_index + 1, _round.length))),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Text(l.quizQuestion, textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: min(200, MediaQuery.sizeOf(context).width * 0.5),
              child: AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: target, nameless: true)),
            ),
          ),
          const SizedBox(height: 20),
          for (final id in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: picked == null
                      ? null
                      : id == target
                          ? TarotColors.sage.withValues(alpha: 0.25)
                          : id == picked
                              ? TarotColors.rice.withValues(alpha: 0.18)
                              : null,
                ),
                onPressed: () => _answer(id),
                child: Text(l.cardName(id)),
              ),
            ),
          if (picked != null) ...[
            const SizedBox(height: 12),
            Text(picked == target ? l.quizRight : l.quizWrong(l.cardName(target)),
                textAlign: TextAlign.center, style: t.titleSmall),
            if (_content != null) ...[
              const SizedBox(height: 8),
              Text(_content!.keywords(false).join(l.separator),
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.earth)),
            ],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => CardDetailPage(cardId: target))),
                child: Text(l.cardDetailButton(l.cardName(target))),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _next, child: Text(l.quizNext)),
            ]),
          ],
        ],
      ),
    );
  }
}
