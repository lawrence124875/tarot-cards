import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/cross/cross_composer.dart';
import '../../core/cross/cross_engine.dart';
import '../../core/events/event_bus.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/lenormand/lenormand.dart';
import '../../core/monetization/cast_quota.dart';
import '../../core/tarot/draw.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/premium/cast_gate.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/premium/reading_interstitial.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_back.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/flip_card.dart';
import '../lenormand/lenormand_widgets.dart';
import 'cross_intro.dart';

/// Remote Config：免費版能否抽牌並看共識／分歧標題（1＝可以，0＝直接開付費牆）。
const crossFreePreviewKey = 'tr_cross_free_preview';

/// 塔羅 × 雷諾曼交叉解讀（訂閱專屬；免費版可抽牌並看標題）。
/// 流程：輸入一個問題 → 塔羅三張（心理面）＋雷諾曼三張（事件面）→ 交叉頁。扣一般抽牌額度 1 次。
class CrossPage extends StatefulWidget {
  const CrossPage({super.key});

  @override
  State<CrossPage> createState() => _CrossPageState();
}

class _CrossPageState extends State<CrossPage> {
  late final Services _s = AppServices.of(context);
  final _question = TextEditingController();
  List<DrawnCard> _tarot = const [];
  List<int> _lenormand = const [];
  bool _revealed = false;
  bool _busy = false;
  bool _saved = false;
  CastGrant? _grant;
  CrossScores? _scores;
  CrossTemplates? _templates;
  Map<int, LenormandText> _lenTexts = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scores = await loadCrossScores();
      final templates = await loadCrossTemplates(L10n.contentFolder);
      final len = await _s.lenormand.cards();
      if (!mounted) return;
      setState(() {
        _scores = scores;
        _templates = templates;
        _lenTexts = len;
      });
      final intro = _s.crossIntro;
      if (intro != null && !await intro.seen() && mounted) {
        await showCrossIntro(context);
        await intro.markSeen();
      }
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  bool get _freePreview => _s.flags.intValue(crossFreePreviewKey, 1) != 0;

  Future<void> _start() async {
    final l = context.l10n;
    if (_question.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.crossQuestionNeeded)));
      return;
    }
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_s.isPremium && !_freePreview) {
      // 遠端關閉免費預覽：直接開付費牆
      if (!await openPaywall(context, source: 'cross_preview') || !mounted) return;
    }
    _busy = true;
    final grant = await ensureCanCast(context, spreadId: 'cross');
    _busy = false;
    if (grant == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _grant = grant;
      _tarot = ShuffledDeck.shuffle(_s.random, reversals: _s.settings.reversals).top(3);
      _lenormand = drawLenormand(_s.random, 3);
      _revealed = false;
      _saved = false;
    });
  }

  Future<void> _reveal() async {
    if (_grant?.wantsInterstitial ?? false) {
      _grant = null; // 只播一次
      await playReadingInterstitial(context);
      if (!mounted) return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _revealed = true);
    final r = _result;
    if (r != null) _s.events.emit(CrossShown(relation: r.relation.name, full: _s.isPremium));
  }

  CrossResult? get _result =>
      (_scores == null || _tarot.isEmpty) ? null : evaluateCross(_scores!, _tarot, _lenormand);

  Future<void> _save() async {
    final journal = _s.journal;
    if (journal == null || _saved) return;
    if (!_s.isPremium && (await journal.all()).length >= _s.limits.journalMax) {
      _s.events.emit(const HitFreeLimit(type: 'journal'));
      if (!mounted || !await openPaywall(context, source: 'journal_limit')) return;
    }
    final entry = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'three', methodId: DrawMethods.quick, cards: _tarot),
      now: DateTime.now(),
      question: _question.text.trim(),
      deckId: _s.deck.value?.id ?? '',
      lenormand: _lenormand,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l.featureCross),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l.crossIntroInfo,
            onPressed: () => showCrossIntro(context),
          ),
        ],
      ),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          if (_tarot.isEmpty) ...[
            Text(l.crossIntroBody1, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              maxLength: 120,
              decoration: InputDecoration(labelText: l.crossQuestionLabel, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Center(child: FilledButton(onPressed: _start, child: Text(l.crossStart))),
          ] else ...[
            Text('「${_question.text.trim()}」', style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _Row(
              title: l.crossTarotRow,
              children: [
                for (final c in _tarot)
                  FlipCard(
                    flipped: _revealed,
                    back: const CardBack(),
                    front: CardFace(cardId: c.cardId, reversed: c.reversed),
                  ),
              ],
              aspect: kCardAspect,
              names: _revealed ? [for (final c in _tarot) l.drawnName(c)] : null,
            ),
            const SizedBox(height: 12),
            _Row(
              title: l.crossLenormandRow,
              children: [
                for (final id in _lenormand)
                  FlipCard(
                    flipped: _revealed,
                    back: const LenormandBack(),
                    front: LenormandFace(cardId: id, name: _lenTexts[id]?.name),
                  ),
              ],
              aspect: kLenormandAspect,
              names: _revealed ? [for (final id in _lenormand) _lenTexts[id]?.name ?? '$id'] : null,
            ),
            const SizedBox(height: 16),
            if (!_revealed)
              Center(child: FilledButton(onPressed: _reveal, child: Text(l.crossSeeResult)))
            else if (_result case final r?) ...[
              CrossResultView(
                result: r,
                templates: _templates ?? CrossTemplates(const {}),
                seed: crossSeed([for (final c in _tarot) c.cardId], _lenormand),
                onUnlocked: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
                if (_s.journal != null)
                  OutlinedButton.icon(
                    icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined, size: 18),
                    label: Text(_saved ? l.crossSaved : l.crossSave),
                    onPressed: _saved ? null : _save,
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    _tarot = const [];
                    _lenormand = const [];
                    _question.clear();
                  }),
                  child: Text(l.crossAgain),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.children, required this.aspect, this.names});

  final String title;
  final List<Widget> children;
  final double aspect;
  final List<String>? names;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: t.labelLarge?.copyWith(color: TarotColors.earth)),
      const SizedBox(height: 6),
      Row(children: [
        for (final (i, c) in children.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: AspectRatio(aspectRatio: aspect, child: c),
                ),
                if (names != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(names![i], style: t.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                  ),
              ]),
            ),
          ),
      ]),
    ]);
  }
}

/// 交叉頁的結果區（交叉頁與紀錄回顧共用）。免費版只顯示關係標題，其餘需訂閱。
class CrossResultView extends StatelessWidget {
  const CrossResultView({super.key, required this.result, required this.templates, required this.seed, this.onUnlocked});

  final CrossResult result;
  final CrossTemplates templates;
  final int seed;
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final s = AppServices.of(context);
    final rep = templates.compose(result, seed);
    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(rep.relationName.isEmpty ? result.relation.name : rep.relationName,
              style: t.headlineSmall?.copyWith(color: TarotColors.earth)),
          if (rep.relationLead.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(rep.relationLead, textAlign: TextAlign.center)),
        ]),
      ),
    );
    if (!s.isPremium) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Icon(Icons.lock_outline),
              const SizedBox(height: 8),
              Text(l.crossLockedBody, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  s.events.emit(const HitFreeLimit(type: 'cross'));
                  if (await openPaywall(context, source: 'cross_preview')) onUnlocked?.call();
                },
                child: Text(l.crossUnlock),
              ),
            ]),
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        Chip(label: Text('${l.crossOverall}：${rep.overall}')),
        for (final tag in rep.tags) Chip(label: Text(tag)),
        if (rep.timing.isNotEmpty) Chip(avatar: const Icon(Icons.schedule, size: 16), label: Text(rep.timing)),
      ]),
      Section(title: '${l.crossTarotSide}・${rep.tarotLevel}', child: Text(rep.tarotText)),
      Section(title: '${l.crossLenormandSide}・${rep.lenormandLevel}', child: Text(rep.lenormandText)),
      if (rep.relationText.isNotEmpty) Section(title: rep.relationName, child: Text(rep.relationText)),
      if (rep.action.isNotEmpty) Section(title: l.crossActionTitle, child: Text(rep.action)),
      if (rep.reflection.isNotEmpty)
        Section(title: l.crossReflectTitle, child: Text(rep.reflection, style: t.bodyLarge?.copyWith(fontStyle: FontStyle.italic))),
      const SizedBox(height: 12),
      Text(rep.disclaimer.isEmpty ? l.lenormandNotice : rep.disclaimer,
          style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
    ]);
  }
}
