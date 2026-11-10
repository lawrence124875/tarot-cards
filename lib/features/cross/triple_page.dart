import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/reading_area.dart';
import '../../core/cross/cross_composer.dart';
import '../../core/cross/cross_engine.dart';
import '../../core/cross/triple_composer.dart';
import '../../core/cross/triple_engine.dart';
import '../../core/events/event_bus.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/lenormand/lenormand.dart';
import '../../core/monetization/cast_quota.dart';
import '../../core/runes/runes.dart';
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
import '../runes/rune_widgets.dart';
import 'cross_intro.dart';
import 'cross_page.dart';

/// Remote Config：免費版能否抽牌並看核心指引標題（1＝可以，0＝直接開付費牆）。
const tripleFreePreviewKey = 'tr_triple_free_preview';

/// 塔羅 × 雷諾曼 × 盧恩三系統交叉（訂閱專屬；免費版可抽牌並看核心指引標題，付費牆來源 `triple_preview`）。
/// 流程：輸入問題（可選主題）→ 塔羅三張（內在）＋雷諾曼三張（事件）＋盧恩一顆（核心之石）→ 五段式結果。
/// 扣一般抽牌額度 1 次。現有塔羅 × 雷諾曼維持原狀。
class TriplePage extends StatefulWidget {
  const TriplePage({super.key});

  @override
  State<TriplePage> createState() => _TriplePageState();
}

class _TriplePageState extends State<TriplePage> {
  late final Services _s = AppServices.of(context);
  final _question = TextEditingController();
  List<DrawnCard> _tarot = const [];
  List<int> _lenormand = const [];
  DrawnRune? _rune;
  bool _revealed = false;
  bool _busy = false;
  bool _saved = false;
  CastGrant? _grant;
  CrossScores? _scores;
  CrossTemplates? _templates;
  TripleTemplates? _triple;
  Map<int, LenormandText> _lenTexts = const {};
  Map<int, RuneText> _runeTexts = const {};
  String _area = '';
  TripleCards? _cards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scores = await loadCrossScores();
      final templates = await loadCrossTemplates(L10n.contentFolder);
      final triple = await loadTripleTemplates(L10n.contentFolder);
      final len = await _s.lenormand.cards();
      final runes = await _s.runes.runes();
      if (!mounted) return;
      setState(() {
        _scores = scores;
        _templates = templates;
        _triple = triple;
        _lenTexts = len;
        _runeTexts = runes;
      });
      final intro = _s.tripleIntro;
      if (intro != null && !await intro.seen() && mounted) {
        await showCrossIntro(context, triple: true);
        await intro.markSeen();
      }
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  bool get _freePreview => _s.flags.intValue(tripleFreePreviewKey, 1) != 0;

  Future<void> _start() async {
    final l = context.l10n;
    if (_question.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.crossQuestionNeeded)));
      return;
    }
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_s.isPremium && !_freePreview) {
      if (!await openPaywall(context, source: 'triple_preview') || !mounted) return;
    }
    _busy = true;
    final grant = await ensureCanCast(context, spreadId: 'triple');
    _busy = false;
    if (grant == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _grant = grant;
      _tarot = ShuffledDeck.shuffle(_s.random, reversals: _s.settings.reversals).top(3);
      _lenormand = drawLenormand(_s.random, 3);
      _rune = drawRunes(_s.random, 1).first;
      _revealed = false;
      _saved = false;
      _cards = null;
    });
    final cards = await loadTripleCards(context, _scores, _tarot, _lenormand, _rune!, _area);
    if (mounted) setState(() => _cards = cards);
  }

  Future<void> _reveal() async {
    if (_grant?.wantsInterstitial ?? false) {
      _grant = null;
      await playReadingInterstitial(context);
      if (!mounted) return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _revealed = true);
    final r = _result;
    if (r != null) _s.events.emit(TripleShown(relation: r.relation.name, full: _s.isPremium));
  }

  TripleResult? get _result => (_scores == null || _tarot.isEmpty || _rune == null)
      ? null
      : evaluateTriple(_scores!, _tarot, _lenormand, _rune!);

  Future<void> _save() async {
    final journal = _s.journal;
    if (journal == null || _saved || _rune == null) return;
    if (!_s.isPremium && (await journal.all()).length >= _s.limits.journalMax) {
      _s.events.emit(const HitFreeLimit(type: 'journal'));
      if (!mounted || !await openPaywall(context, source: 'journal_limit')) return;
    }
    final entry = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'three', methodId: DrawMethods.quick, cards: _tarot),
      now: DateTime.now(),
      question: _question.text.trim(),
      area: _area,
      deckId: _s.deck.value?.id ?? '',
      lenormand: _lenormand,
      runes: [_rune!.code],
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
        title: Text(l.featureTriple),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l.crossIntroInfo,
            onPressed: () => showCrossIntro(context, triple: true),
          ),
        ],
      ),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          if (_tarot.isEmpty) ...[
            Text(l.tripleIntroBody1, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              maxLength: 120,
              decoration: InputDecoration(labelText: l.crossQuestionLabel, border: const OutlineInputBorder()),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in ['', ...ReadingAreas.all])
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l.areaName(a.isEmpty ? 'none' : a)),
                    selected: _area == a,
                    onSelected: (_) => setState(() => _area = a),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: FilledButton(onPressed: _start, child: Text(l.crossStart))),
          ] else ...[
            Text('「${_question.text.trim()}」', style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            CrossCardRow(
              title: l.crossTarotRow,
              aspect: kCardAspect,
              names: _revealed ? [for (final c in _tarot) l.drawnName(c)] : null,
              children: [
                for (final c in _tarot)
                  FlipCard(
                    flipped: _revealed,
                    back: const CardBack(),
                    front: CardFace(cardId: c.cardId, reversed: c.reversed),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CrossCardRow(
              title: l.crossLenormandRow,
              aspect: kLenormandAspect,
              names: _revealed ? [for (final id in _lenormand) _lenTexts[id]?.name ?? '$id'] : null,
              children: [
                for (final id in _lenormand)
                  FlipCard(
                    flipped: _revealed,
                    back: const LenormandBack(),
                    front: LenormandFace(cardId: id, name: _lenTexts[id]?.name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_rune case final r?)
              Column(children: [
                Text(l.tripleRuneRow, style: t.labelLarge?.copyWith(color: TarotColors.earth)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 84,
                  child: AspectRatio(
                    aspectRatio: kRuneAspect,
                    child: FlipCard(
                      flipped: _revealed,
                      back: const RuneStoneBack(),
                      front: RuneStoneFace(runeId: r.id, reversed: r.reversed, name: _runeTexts[r.id]?.name),
                    ),
                  ),
                ),
                if (_revealed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(runeDisplayName(l, _runeTexts, r), style: t.bodySmall, textAlign: TextAlign.center),
                  ),
              ]),
            const SizedBox(height: 16),
            if (!_revealed)
              Center(child: FilledButton(onPressed: _reveal, child: Text(l.crossSeeResult)))
            else if (_result case final r?) ...[
              TripleResultView(
                result: r,
                templates: _templates ?? CrossTemplates(const {}),
                triple: _triple ?? TripleTemplates(const {}),
                seed: tripleSeed([for (final c in _tarot) c.cardId], _lenormand, _rune!.code),
                cards: _cards,
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
                    _rune = null;
                    _cards = null;
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

/// 三系統結果區（交叉頁與紀錄回顧共用）。免費版只顯示核心指引標題（關係），其餘需訂閱。
class TripleResultView extends StatelessWidget {
  const TripleResultView({
    super.key,
    required this.result,
    required this.templates,
    required this.triple,
    required this.seed,
    this.cards,
    this.onUnlocked,
  });

  final TripleResult result;
  final CrossTemplates templates;
  final TripleTemplates triple;
  final TripleCards? cards;
  final int seed;
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final s = AppServices.of(context);
    final rep = triple.compose(result, seed, base: templates, cards: cards);
    String title(String key, String fallback) {
      final v = triple.sectionTitle(key);
      return v.isEmpty ? fallback : v;
    }

    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(title('core', ''), style: t.labelLarge?.copyWith(color: TarotColors.textSub)),
          Text(rep.relationName, style: t.headlineSmall?.copyWith(color: TarotColors.earth)),
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
              Text(l.tripleLockedBody, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  s.events.emit(const HitFreeLimit(type: 'triple'));
                  if (await openPaywall(context, source: 'triple_preview')) onUnlocked?.call();
                },
                child: Text(l.tripleUnlock),
              ),
            ]),
          ),
        ),
      ]);
    }
    final c = rep.cross;
    final cd = c.detail;
    final d = rep.detail;
    final italic = t.bodyLarge?.copyWith(fontStyle: FontStyle.italic);
    final chips = Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      Chip(label: Text('${l.crossOverall}：${rep.overall}')),
      for (final tag in c.tags) Chip(label: Text(tag)),
      if (c.timing.isNotEmpty) Chip(avatar: const Icon(Icons.schedule, size: 16), label: Text(c.timing)),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 8),
      chips,
      if (d == null || cd == null)
        Section(title: rep.relationName, child: Text(c.relationText))
      else ...[
        Section(title: title('core', l.featureTriple), child: Text(d.core)),
        Section(
          title: '${title('tarot', l.crossTarotSide)}・${c.tarotLevel}',
          child: CrossLinesView(lines: cd.tarotLines, after: [cd.tarotSummary]),
        ),
        Section(
          title: '${title('lenormand', l.crossLenormandSide)}・${c.lenormandLevel}',
          child: CrossLinesView(lines: cd.lenormandLines, after: [...cd.pairs, cd.lenormandTiming]),
        ),
        Section(
          title: '${title('rune', l.featureRunes)}・${rep.runeLevel}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: d.runeTitle, style: t.titleSmall),
              if (d.runeKeywords.isNotEmpty)
                TextSpan(text: '  ${d.runeKeywords}', style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
            ])),
            const SizedBox(height: 6),
            if (d.poem.isNotEmpty) CrossLabeled(label: d.poemLabel, text: d.poem, style: italic),
            if (d.reminder.isNotEmpty) CrossLabeled(label: d.reminderLabel, text: d.reminder),
            if (d.runeReversedNote.isNotEmpty)
              CrossLabeled(label: d.runeReversedNote, text: d.runeReversedText),
            if (d.aettText.isNotEmpty) Text(d.aettText),
          ]),
        ),
        Section(
          title: title('breakthrough', l.crossActionTitle),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (cd.inner.isNotEmpty) CrossLabeled(label: cd.innerLabel, text: cd.inner),
            if (cd.outer.isNotEmpty) CrossLabeled(label: cd.outerLabel, text: cd.outer),
            if (d.coreAction.isNotEmpty) CrossLabeled(label: d.coreActionLabel, text: d.coreAction),
            if (rep.reflection.isNotEmpty) CrossLabeled(label: cd.reflectLabel, text: rep.reflection, style: italic),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Text(rep.disclaimer.isEmpty ? l.lenormandNotice : rep.disclaimer,
          style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
    ]);
  }
}

/// 準備五段式需要的文字：塔羅、雷諾曼沿用雙系統（[loadCrossCards]），再加盧恩核心之石。
Future<TripleCards?> loadTripleCards(
  BuildContext context,
  CrossScores? scores,
  List<DrawnCard> tarot,
  List<int> lenormand,
  DrawnRune rune,
  String area,
) async {
  final s = AppServices.of(context);
  final sc = scores ?? CrossScores();
  final cross = await loadCrossCards(context, scores, tarot, lenormand, area);
  final runes = await s.runes.runes();
  if (cross == null) return null;
  final x = runes[rune.id];
  return TripleCards(
    cross: cross,
    tarotIds: [for (final c in tarot) c.cardId],
    lenormandIds: lenormand,
    lenormandTags: [for (final id in lenormand) sc.lenormand(id).tags],
    rune: TripleRuneCard(
      id: rune.id,
      name: x?.name ?? RuneStone.byId(rune.id).key,
      reversed: rune.reversed,
      aett: RuneStone.byId(rune.id).aett,
      keywords: x?.keywords ?? const [],
      poem: x?.poem ?? '',
      reminder: x?.reminder ?? '',
      reversedText: x?.reversedMeaning ?? '',
      advice: x?.advice ?? '',
    ),
  );
}
