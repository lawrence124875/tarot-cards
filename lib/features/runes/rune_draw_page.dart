import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/events/event_bus.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/runes/runes.dart';
import '../../core/monetization/cast_quota.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/premium/cast_gate.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/premium/reading_interstitial.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/flip_card.dart';
import 'rune_widgets.dart';

/// 盧恩抽符文：寫下問題（可不填）→ 抽（扣一般抽牌額度 1 次）→ 一顆顆翻開 → 解讀。
class RuneDrawPage extends StatefulWidget {
  const RuneDrawPage({super.key, required this.spread});

  final RuneSpread spread;

  @override
  State<RuneDrawPage> createState() => _RuneDrawPageState();
}

class _RuneDrawPageState extends State<RuneDrawPage> {
  late final Services _s = AppServices.of(context);
  final _question = TextEditingController();
  List<DrawnRune> _cards = const [];
  final Set<int> _revealed = {};
  Map<int, RuneText> _texts = const {};
  Map<String, RuneSpreadText> _spreads = const {};
  CastGrant? _grant;
  bool _busy = false;
  bool _interstitialPlayed = false;
  bool _saved = false;

  RuneSpread get _spread => widget.spread;
  bool get _allRevealed => _cards.isNotEmpty && _revealed.length == _cards.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final texts = await _s.runes.runes();
      final spreads = await _s.runes.spreads();
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
    final grant = await ensureCanCast(context, spreadId: _spread.journalId);
    _busy = false;
    if (grant == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _grant = grant;
      _interstitialPlayed = false;
      _saved = false;
      _cards = drawRunes(_s.random, _spread.size);
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
    final entry = JournalEntry.fromRunes(
      spreadId: _spread.journalId,
      runes: [for (final r in _cards) r.code],
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
      appBar: AppBar(title: Text(spreadText?.name ?? (_spread.size == 1 ? l.runeDrawOne : l.runeDrawThree))),
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
              decoration: InputDecoration(labelText: l.runeQuestionHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Center(child: FilledButton(onPressed: _draw, child: Text(l.runeDraw))),
          ] else ...[
            if (_question.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('「${_question.text.trim()}」', style: t.titleMedium, textAlign: TextAlign.center),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, r) in _cards.indexed)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Column(children: [
                          Text(spreadText?.positions[_spread.positions[i]]?.name ?? '', style: t.labelMedium),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _reveal({i}),
                            child: AspectRatio(
                              aspectRatio: kRuneAspect,
                              child: FlipCard(
                                flipped: _revealed.contains(i),
                                back: const RuneStoneBack(),
                                front: RuneStoneFace(runeId: r.id, reversed: r.reversed, name: _texts[r.id]?.name),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_revealed.contains(i) ? runeDisplayName(l, _texts, r) : '', style: t.bodySmall, textAlign: TextAlign.center),
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
                  child: Text(l.runeRevealAll),
                ),
              )
            else ...[
              for (final (i, r) in _cards.indexed)
                if (_texts[r.id] case final text?)
                  Section(
                    title: [spreadText?.positions[_spread.positions[i]]?.name, runeDisplayName(l, _texts, r)]
                        .whereType<String>()
                        .where((x) => x.isNotEmpty)
                        .join('・'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (spreadText?.positions[_spread.positions[i]]?.prompt case final p? when p.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(p, style: t.bodyMedium?.copyWith(color: TarotColors.textSub, fontStyle: FontStyle.italic)),
                        ),
                      RuneTextView(text: text, reversed: r.reversed),
                    ]),
                  ),
              if (_texts.isEmpty) Text(l.runeContentMissing),
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
                  child: Text(l.runeAgain),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}
