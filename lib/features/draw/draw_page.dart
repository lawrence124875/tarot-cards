import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/tarot/draw.dart';
import '../../core/tarot/spread.dart';
import '../../l10n/l10n.dart';
import '../../reading/reading_page.dart';
import '../../shared/premium/cast_gate.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_back.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/question_dialog.dart';
import '../../shared/widgets/spread_layout.dart';
import 'first_impression_sheet.dart';

enum _Stage { question, shuffle, cut, pick, reveal }

/// 一次抽牌的儀式。
/// 1. 寫下想問的事（可不填），選「快速抽牌」或「親手洗牌」。
/// 2. 親手洗牌：點「洗牌」幾次 → 從三疊中選一疊切牌 → 從扇形展開的牌中一張張挑。
///    快速抽牌：系統洗好，依位置發牌。
/// 3. 一張張點開（或全部翻開）。
/// 4. 全部翻開後先問「你第一眼注意到什麼？」，再看解讀（直覺在解讀之前）。
class DrawPage extends StatefulWidget {
  const DrawPage({super.key, required this.spread});

  final Spread spread;

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  late final Services _s = AppServices.of(context);
  _Stage _stage = _Stage.question;
  String _question = '';
  String _method = DrawMethods.quick;
  ShuffledDeck? _deck;
  int _shuffles = 0;
  final List<DrawnCard> _picked = [];
  final Set<int> _pickedFromFan = {};
  final Set<int> _revealed = {};
  bool _checking = false;
  bool _shaking = false;
  String _impression = '';
  bool _askedImpression = false;

  Spread get _spread => widget.spread;
  bool get _allRevealed => _revealed.length == _spread.size && _picked.length == _spread.size;

  Future<bool> _gate() async {
    if (_checking) return false;
    _checking = true;
    final ok = await ensureCanCast(context); // 免費版每日次數
    _checking = false;
    return ok && mounted;
  }

  Future<void> _quick() async {
    if (!await _gate()) return;
    final reversals = _s.settings.reversals;
    setState(() {
      _method = DrawMethods.quick;
      _deck = ShuffledDeck.shuffle(_s.random, reversals: reversals);
      _picked
        ..clear()
        ..addAll(_deck!.top(_spread.size));
      _stage = _Stage.reveal;
    });
  }

  Future<void> _ritual() async {
    if (!await _gate()) return;
    setState(() {
      _method = DrawMethods.ritual;
      _deck = ShuffledDeck.shuffle(_s.random, reversals: _s.settings.reversals);
      _shuffles = 0;
      _stage = _Stage.shuffle;
    });
  }

  Future<void> _shuffleOnce() async {
    if (_shaking) return;
    _deck!.reshuffle(_s.random, reversals: _s.settings.reversals);
    HapticFeedback.mediumImpact();
    setState(() {
      _shuffles++;
      _shaking = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _shaking = false);
  }

  void _cut(int pile) {
    _deck!.cut(pile);
    HapticFeedback.lightImpact();
    setState(() => _stage = _Stage.pick);
  }

  void _pickFromFan(int index) {
    if (_pickedFromFan.contains(index) || _picked.length >= _spread.size) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pickedFromFan.add(index);
      _picked.add(_deck!.at(index));
      if (_picked.length == _spread.size) _stage = _Stage.reveal;
    });
  }

  void _reveal(int position) {
    if (position >= _picked.length || _revealed.contains(position)) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed.add(position));
    _maybeAskImpression();
  }

  void _revealAll() {
    HapticFeedback.mediumImpact();
    setState(() => _revealed.addAll(List.generate(_spread.size, (i) => i)));
    _maybeAskImpression();
  }

  /// 全部翻開後（翻牌動畫結束）問一次第一眼印象。
  Future<void> _maybeAskImpression() async {
    if (!_allRevealed || _askedImpression) return;
    _askedImpression = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final text = await askFirstImpression(context);
    if (text != null && mounted) setState(() => _impression = text);
  }

  Future<void> _openReading() async {
    final draw = SpreadDraw(spreadId: _spread.id, methodId: _method, cards: _picked);
    final ads = _s.ads;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReadingPage(draw: draw, question: _question, firstImpression: _impression),
    ));
    ads.readingClosed(); // 看完解讀回來：依限頻規則可能跳插頁（不在儀式與閱讀中跳出）
  }

  void _restart() => setState(() {
        _stage = _Stage.question;
        _deck = null;
        _picked.clear();
        _pickedFromFan.clear();
        _revealed.clear();
        _impression = '';
        _askedImpression = false;
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: KeyedSubtree(key: ValueKey(_stage), child: _body(context, l)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final hint = t.bodyMedium?.copyWith(color: TarotColors.textSub);
    switch (_stage) {
      case _Stage.question:
        return _Column(
          top: [
            Text(l.drawPromptBefore, style: hint, textAlign: TextAlign.center),
            QuestionPrompt(question: _question, onChanged: (q) => setState(() => _question = q)),
          ],
          middle: SpreadLayout(spread: _spread, cards: const [], revealed: const {}, maxCardWidth: 120),
          bottom: [
            FilledButton(onPressed: _quick, child: Text(l.drawQuick)),
            const SizedBox(height: 4),
            TextButton.icon(onPressed: _ritual, icon: const Icon(Icons.back_hand_outlined, size: 18), label: Text(l.drawRitual)),
          ],
        );
      case _Stage.shuffle:
        return _Column(
          top: [
            if (_question.isNotEmpty) QuestionPrompt(question: _question, onChanged: (_) {}, enabled: false),
            Text(l.shuffleHint, style: hint, textAlign: TextAlign.center),
          ],
          middle: GestureDetector(onTap: _shuffleOnce, child: _ShufflePile(shaking: _shaking, seed: _shuffles)),
          bottom: [
            FilledButton(onPressed: _shuffleOnce, child: Text(_shuffles == 0 ? l.shuffle : l.shuffleCount(_shuffles))),
            const SizedBox(height: 4),
            TextButton(onPressed: _shuffles == 0 ? null : () => setState(() => _stage = _Stage.cut), child: Text(l.shuffleDone)),
          ],
        );
      case _Stage.cut:
        return _Column(
          top: [Text(l.cutHint, style: hint, textAlign: TextAlign.center)],
          middle: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Semantics(
                          button: true,
                          label: l.cutPile(i + 1),
                          child: GestureDetector(
                            onTap: () => _cut(i),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const AspectRatio(aspectRatio: kCardAspect, child: _Pile(layers: 4)),
                              const SizedBox(height: 10),
                              Text(l.cutPile(i + 1), style: t.bodySmall),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottom: const [],
        );
      case _Stage.pick:
        return _Column(
          top: [Text(l.pickHint(_spread.size - _picked.length), style: hint, textAlign: TextAlign.center)],
          middle: Column(children: [
            Expanded(
              child: SpreadLayout(spread: _spread, cards: _picked, revealed: const {}, maxCardWidth: 110),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 130, child: _Fan(taken: _pickedFromFan, onPick: _pickFromFan)),
          ]),
          bottom: const [],
        );
      case _Stage.reveal:
        return _Column(
          top: [
            Text(_allRevealed ? l.drawPromptAfter : l.revealHint, style: hint, textAlign: TextAlign.center),
            if (_impression.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.firstImpressionShown(_impression),
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              ),
          ],
          middle: SpreadLayout(spread: _spread, cards: _picked, revealed: _revealed, onTap: _reveal),
          bottom: [
            if (!_allRevealed)
              FilledButton(onPressed: _revealAll, child: Text(l.revealAll))
            else ...[
              FilledButton(onPressed: _openReading, child: Text(l.viewReading)),
              TextButton(onPressed: _restart, child: Text(l.drawAgain)),
            ],
          ],
        );
    }
  }
}

/// 頁面骨架：上方提示、中間主要區域（可伸縮）、下方按鈕。手機橫放時改左右兩欄。
class _Column extends StatelessWidget {
  const _Column({required this.top, required this.middle, required this.bottom});

  final List<Widget> top;
  final Widget middle;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (isShortWide(box.biggest)) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Row(children: [
            Expanded(child: middle),
            const SizedBox(width: 24),
            SizedBox(
              width: 300,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [...top, const SizedBox(height: 16), ...bottom]),
                ),
              ),
            ),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(children: [
          ...top,
          const SizedBox(height: 12),
          Expanded(child: middle),
          const SizedBox(height: 16),
          ...bottom,
        ]),
      );
    });
  }
}

/// 洗牌時的一疊牌：每點一次，幾張牌各自錯開、旋轉，再收回。
class _ShufflePile extends StatelessWidget {
  const _ShufflePile({required this.shaking, required this.seed});

  final bool shaking;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final r = math.Random(seed);
    final still = MediaQuery.of(context).disableAnimations;
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.45,
        child: AspectRatio(
          aspectRatio: kCardAspect,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < 6; i++)
              Positioned.fill(
                child: AnimatedSlide(
                  duration: Duration(milliseconds: 250 + i * 40),
                  curve: Curves.easeOutBack,
                  offset: shaking && !still ? Offset((r.nextDouble() - 0.5) * 0.7, (r.nextDouble() - 0.5) * 0.2) : Offset.zero,
                  child: AnimatedRotation(
                    duration: Duration(milliseconds: 250 + i * 40),
                    turns: shaking && !still ? (r.nextDouble() - 0.5) * 0.08 : (i - 3) * 0.004,
                    child: const CardBack(),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 疊在一起的幾張牌背（切牌時的一疊）。
class _Pile extends StatelessWidget {
  const _Pile({required this.layers});

  final int layers;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      for (var i = 0; i < layers; i++)
        Positioned(left: i * 2.0, top: -i * 2.0, right: -i * 2.0, bottom: i * 2.0, child: const CardBack()),
    ]);
  }
}

/// 78 張牌背排成可左右捲動的弧形，點一張就抽出。
class _Fan extends StatelessWidget {
  const _Fan({required this.taken, required this.onPick});

  final Set<int> taken;
  final void Function(int index) onPick;

  static const _cardW = 62.0, _step = 24.0, _count = 78;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: _cardW + (_count - 1) * _step,
          height: 126,
          child: Stack(children: [
            for (var i = 0; i < _count; i++)
              if (!taken.contains(i))
                Positioned(
                  left: i * _step,
                  // 弧形：中間的牌略高
                  top: 14 - 12 * math.sin(i / (_count - 1) * math.pi),
                  width: _cardW,
                  height: _cardW / kCardAspect,
                  child: Semantics(
                    button: true,
                    label: l.pickCardLabel(i + 1),
                    child: GestureDetector(onTap: () => onPick(i), child: const CardBack()),
                  ),
                ),
          ]),
        ),
      ),
    );
  }
}
