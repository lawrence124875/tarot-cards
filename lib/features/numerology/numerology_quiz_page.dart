import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/numerology/numerology.dart';
import '../../core/numerology/numerology_quiz.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive_layout.dart';
import 'numerology_widgets.dart';

/// 靈數練習：一輪 10 題，「數字 → 關鍵字」與「日期 → 生命靈數」交錯，答完顯示解說。
class NumerologyQuizPage extends StatefulWidget {
  const NumerologyQuizPage({super.key, this.texts});

  /// 測試可直接注入；null 時從內容檔讀取。
  final NumerologyTexts? texts;

  @override
  State<NumerologyQuizPage> createState() => _NumerologyQuizPageState();
}

class _NumerologyQuizPageState extends State<NumerologyQuizPage> {
  late final Services _s = AppServices.of(context);
  NumerologyTexts _texts = const NumerologyTexts();
  List<NumQuizQuestion> _round = const [];
  int _index = 0, _correct = 0;
  int? _picked;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final texts = widget.texts ?? await _s.numerology.texts();
    if (!mounted) return;
    setState(() {
      _texts = texts;
      _round = NumerologyQuiz.round(_s.random, keywords: !texts.isEmpty);
      _index = 0;
      _correct = 0;
      _picked = null;
      _loading = false;
    });
  }

  String _keywords(int n) => (_texts.numbers[n]?.keywords ?? const <String>[]).join(context.l10n.separator);

  void _answer(int n) {
    if (_picked != null) return;
    setState(() {
      _picked = n;
      if (n == _round[_index].answer) _correct++;
    });
  }

  void _next() => setState(() {
        _index++;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    if (_loading) return Scaffold(appBar: AppBar(title: Text(l.numQuiz)), body: const Center(child: CircularProgressIndicator()));
    if (_index >= _round.length) {
      return Scaffold(
        appBar: AppBar(title: Text(l.numQuiz)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wb_sunny_outlined, size: 48, color: TarotColors.dawn),
              const SizedBox(height: 16),
              Text(l.numQuizDone(_correct, _round.length), textAlign: TextAlign.center, style: t.titleMedium),
              const SizedBox(height: 24),
              FilledButton(onPressed: _start, child: Text(l.quizAgain)),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.back)),
            ]),
          ),
        ),
      );
    }
    final q = _round[_index];
    final picked = _picked;
    final keyword = q.kind == NumQuizKind.keyword;
    Color? bg(int n) => picked == null
        ? null
        : n == q.answer
            ? TarotColors.sage.withValues(alpha: 0.25)
            : n == picked
                ? TarotColors.rice.withValues(alpha: 0.18)
                : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.numQuizProgress(_index + 1, _round.length))),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Text(keyword ? l.numQuizKeyword : l.numQuizLifePath, textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: 16),
          if (keyword)
            NumberBadge(number: q.answer, size: 88)
          else
            Text(MaterialLocalizations.of(context).formatFullDate(q.date!),
                textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(color: TarotColors.earth)),
          const SizedBox(height: 20),
          for (final n in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(backgroundColor: bg(n)),
                onPressed: () => _answer(n),
                child: Text(keyword ? _keywords(n) : '$n'),
              ),
            ),
          if (picked != null) ...[
            const SizedBox(height: 12),
            Text(picked == q.answer ? l.quizRight : l.numQuizAnswer('${q.answer}'),
                textAlign: TextAlign.center, style: t.titleSmall),
            const SizedBox(height: 8),
            Text(
              keyword ? (_texts.numbers[q.answer]?.name ?? '') : NumerologyQuiz.steps(q.date!),
              textAlign: TextAlign.center,
              textDirection: keyword ? null : TextDirection.ltr,
              style: t.bodyMedium?.copyWith(color: TarotColors.earth),
            ),
            if (!keyword && Numerology.masters.contains(q.answer)) ...[
              const SizedBox(height: 4),
              Text(l.numQuizMasterHint, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
            ],
            const SizedBox(height: 16),
            Center(child: FilledButton(onPressed: _next, child: Text(l.numQuizNext))),
          ],
        ],
      ),
    );
  }
}
