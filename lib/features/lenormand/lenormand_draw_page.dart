import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/events/event_bus.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/lenormand/lenormand.dart';
import '../../core/monetization/cast_quota.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/premium/cast_gate.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/premium/reading_interstitial.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/flip_card.dart';
import 'lenormand_widgets.dart';

/// 雷諾曼抽牌：寫下問題（可不填）→ 抽牌（扣一般抽牌額度 1 次）→ 一張張翻開 → 解讀。
class LenormandDrawPage extends StatefulWidget {
  const LenormandDrawPage({super.key, required this.spread});

  final LenormandSpread spread;

  @override
  State<LenormandDrawPage> createState() => _LenormandDrawPageState();
}

class _LenormandDrawPageState extends State<LenormandDrawPage> {
  late final Services _s = AppServices.of(context);
  final _question = TextEditingController();
  List<int> _cards = const [];
  final Set<int> _revealed = {};
  Map<int, LenormandText> _texts = const {};
  Map<String, LenormandSpreadText> _spreads = const {};
  CastGrant? _grant;
  bool _busy = false;
  bool _interstitialPlayed = false;
  bool _saved = false;

  LenormandSpread get _spread => widget.spread;
  bool get _allRevealed => _cards.isNotEmpty && _revealed.length == _cards.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final texts = await _s.lenormand.cards();
      final spreads = await _s.lenormand.spreads();
      if (mounted) {
        setState(() {
          _texts = texts;
          _spreads = spreads;
        });
      }
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_busy) return;
    _busy = true;
    final grant = await ensureCanCast(context, spreadId: 'len_${_spread.id}');
    _busy = false;
    if (grant == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _grant = grant;
      _interstitialPlayed = false;
      _saved = false;
      _cards = drawLenormand(_s.random, _spread.size);
      _revealed.clear();
    });
  }

  Future<void> _reveal(Set<int> positions) async {
    // 每日第 1 次免費抽牌：最後一張翻開前播插頁（與塔羅相同規則）
    final completes = _revealed.union(positions).length == _cards.length;
    if (completes && (_grant?.wantsInterstitial ?? false) && !_interstitialPlayed) {
      _interstitialPlayed = true;
      await playReadingInterstitial(context);
      if (!mounted) return;
    }
    HapticFeedback.lightImpact();
    setState(() => _revealed.addAll(positions));
  }

  Future<void> _save() async {
    final journal = _s.journal;
    if (journal == null || _saved) return;
    if (!_s.isPremium && (await journal.all()).length >= _s.limits.journalMax) {
      _s.events.emit(const HitFreeLimit(type: 'journal'));
      if (!mounted || !await openPaywall(context, source: 'journal_limit')) return;
    }
    final entry = JournalEntry.fromLenormand(
      spreadId: 'len_${_spread.id}',
      cards: _cards,
      now: DateTime.now(),
      question: _question.text.trim(),
    );
    await journal.save(entry);
    _s.events.emit(const JournalSaved(hasReminder: false));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.crossSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final spreadText = _spreads[_spread.id];
    return Scaffold(
      appBar: AppBar(title: Text(spreadText?.name ?? (_spread.size == 1 ? l.lenormandDrawOne : l.lenormandDrawThree))),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          if (spreadText != null && _cards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(spreadText.description, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
            ),
          if (_cards.isEmpty) ...[
            TextField(
              controller: _question,
              maxLength: 120,
              decoration: InputDecoration(labelText: l.lenormandQuestionHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Center(child: FilledButton(onPressed: _draw, child: Text(l.lenormandDraw))),
          ] else ...[
            if (_question.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('「${_question.text.trim()}」', style: t.titleMedium, textAlign: TextAlign.center),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, id) in _cards.indexed)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Column(children: [
                          Text(spreadText?.positions[_spread.positions[i]]?.name ?? '', style: t.labelMedium),
                          const SizedBox(height: 4),
                          // 讀屏：「第 N 張牌」，未翻開提示「點兩下翻牌」；翻開後牌名由下方文字唸出。
                          Semantics(
                            button: !_revealed.contains(i),
                            label: l.pickCardLabel(i + 1),
                            onTapHint: _revealed.contains(i) ? null : l.flipHint,
                            onTap: () => _reveal({i}),
                            excludeSemantics: true,
                            child: GestureDetector(
                            onTap: () => _reveal({i}),
                            child: AspectRatio(
                              aspectRatio: kLenormandAspect,
                              child: FlipCard(
                                flipped: _revealed.contains(i),
                                back: const LenormandBack(),
                                front: LenormandFace(cardId: id, name: _texts[id]?.name),
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(height: 4),
                          Text(_revealed.contains(i) ? (_texts[id]?.name ?? '') : '', style: t.bodySmall),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_allRevealed)
              Center(
                child: TextButton(
                  onPressed: () => _reveal({for (var i = 0; i < _cards.length; i++) i}),
                  child: Text(l.lenormandRevealAll),
                ),
              )
            else ...[
              if (_cards.length == 3) _Sentence(cards: _cards, texts: _texts),
              for (final (i, id) in _cards.indexed)
                if (_texts[id] case final text?)
                  Section(
                    title: [spreadText?.positions[_spread.positions[i]]?.name, text.name]
                        .whereType<String>()
                        .where((x) => x.isNotEmpty)
                        .join('・'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (spreadText?.positions[_spread.positions[i]]?.prompt case final p? when p.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(p, style: t.bodyMedium?.copyWith(color: TarotColors.textSub, fontStyle: FontStyle.italic)),
                        ),
                      LenormandTextView(text: text),
                    ]),
                  ),
              if (_texts.isEmpty) Text(l.lenormandContentMissing),
              const SizedBox(height: 16),
              Text(l.lenormandNotice, style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
                if (_s.journal != null)
                  OutlinedButton.icon(
                    icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined, size: 18),
                    label: Text(_saved ? l.crossSaved : l.crossSave),
                    onPressed: _saved ? null : _save,
                  ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _cards = const [];
                    _revealed.clear();
                  }),
                  child: Text(l.lenormandAgain),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

/// 三張牌讀成一句話：每張取第一個關鍵詞，依起因 → 核心 → 走向串起來。
class _Sentence extends StatelessWidget {
  const _Sentence({required this.cards, required this.texts});

  final List<int> cards;
  final Map<int, LenormandText> texts;

  @override
  Widget build(BuildContext context) {
    final words = [for (final id in cards) texts[id]?.keywords.firstOrNull ?? texts[id]?.name ?? ''];
    if (words.any((w) => w.isEmpty)) return const SizedBox.shrink();
    return Section(
      title: context.l10n.lenormandSentence,
      child: Text(words.join('  →  '), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
    );
  }
}
