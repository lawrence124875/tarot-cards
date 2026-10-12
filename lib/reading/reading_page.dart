import 'package:flutter/material.dart';

import '../app/feature_registry.dart';
import '../app/services.dart';
import '../app/theme.dart';
import '../core/content/card_content.dart';
import '../core/deck/deck.dart';
import '../core/events/event_bus.dart';
import '../core/tarot/atmosphere.dart';
import '../core/tarot/draw.dart';
import '../features/share/share.dart';
import '../l10n/l10n.dart';
import '../shared/premium/paywall_page.dart';
import '../shared/widgets/adaptive_layout.dart';
import '../shared/widgets/card_face.dart';
import '../shared/widgets/spread_layout.dart';
import 'atmosphere_view.dart';
import 'card_detail_page.dart';
import 'east_west.dart';
import 'save_reading_sheet.dart';
import 'section.dart';

/// 這次抽牌載入的內容：每張牌的解讀、牌陣文字、整體氛圍文字。
class _Loaded {
  _Loaded(this.cards, this.spread, this.atmosphere);

  final List<CardContent?> cards;
  final SpreadText? spread;
  final AtmosphereTexts? atmosphere;
}

/// 解讀頁：問題 → 牌陣（點牌跳到該張）→ 第一眼印象 → 整體氛圍 → 每個位置的牌與一組解讀
/// →（單張或關鍵牌）東西相映、今日小行動、反思提問 → 靜心呼吸 → 記下這次抽牌。
/// 每張牌從正位或逆位的三組解讀中隨機顯示一組；[review] 為 true 時是從日記回看：
/// 顯示當時那幾組（[readingIndexes]），不發事件、不顯示儲存。
class ReadingPage extends StatefulWidget {
  const ReadingPage({
    super.key,
    required this.draw,
    this.question = '',
    this.firstImpression = '',
    this.area = '',
    this.readingIndexes,
    this.review = false,
    this.deck,
  });

  final SpreadDraw draw;
  final String question;
  final String firstImpression;

  /// 問題類型（ReadingAreas）；有選時每張牌多顯示該面向的一句。
  final String area;
  final List<int?>? readingIndexes;
  final bool review;

  /// 日記回看時用當時的牌面組；省略＝目前設定的。
  final Deck? deck;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late final Services _s = AppServices.of(context);
  late final Future<_Loaded> _loaded = _load();
  late final List<int> _seeds = [
    for (var i = 0; i < widget.draw.cards.length; i++)
      (widget.readingIndexes != null && i < widget.readingIndexes!.length ? widget.readingIndexes![i] : null) ??
          _s.random.nextInt(1 << 30),
  ];
  late final List<GlobalKey> _keys = [for (final _ in widget.draw.cards) GlobalKey()];
  int? _selected;
  bool _saved = false;

  SpreadDraw get _draw => widget.draw;
  bool get _single => _draw.cards.length == 1;

  Future<_Loaded> _load() async {
    final cards = await Future.wait([for (final c in _draw.cards) _s.content.card(c.cardId)]);
    final spreads = await _s.content.spreads();
    final atmosphere = await _s.content.atmosphere();
    return _Loaded(cards, spreads?[_draw.spreadId], atmosphere);
  }

  @override
  void initState() {
    super.initState();
    if (widget.review) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _s.events.emit(ReadingShown(
        methodId: _draw.methodId,
        spreadId: _draw.spreadId,
        keyCard: _draw.keyCard.cardId,
        reversed: _draw.cards.where((c) => c.reversed).length,
      ));
    });
  }

  ReadingContent? _reading(int pos, CardContent? c) {
    if (c == null) return null;
    final list = c.readings(_draw.cards[pos].reversed);
    return list.isEmpty ? null : list[_seeds[pos] % list.length];
  }

  /// 存進日記用：每張牌顯示的是第幾組。
  List<int?> _indexes(_Loaded d) => [
        for (var i = 0; i < _draw.cards.length; i++)
          () {
            final c = d.cards[i];
            final list = c?.readings(_draw.cards[i].reversed) ?? const [];
            return list.isEmpty ? null : _seeds[i] % list.length;
          }(),
      ];

  void _jumpTo(int pos) {
    setState(() => _selected = pos);
    final ctx = _keys[pos].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut, alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_single ? l.drawnName(_draw.cards.first) : l.readingTitle),
        actions: [
          IconButton(tooltip: l.shareReading, icon: const Icon(Icons.ios_share), onPressed: _share),
        ],
      ),
      body: FutureBuilder<_Loaded>(
        future: _loaded,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final keyPos = _draw.spread.keyPosition.clamp(0, _draw.cards.length - 1);
          final keyContent = d.cards[keyPos];
          final keyReading = _reading(keyPos, keyContent);
          final lines = d.atmosphere == null
              ? const <String>[]
              : atmosphereLines(
                  observations: _s.atmosphere.observe(_draw, facing: (id) => (widget.deck ?? _s.deck.value)?.annotation(id).facing ?? Facing.none),
                  texts: d.atmosphere!,
                  draw: _draw,
                  spreadText: d.spread,
                  l: l,
                );
          return ListView(
            padding: readablePadding(context, top: 8, bottom: 40),
            children: [
              if (widget.question.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l.questionShown(widget.question), textAlign: TextAlign.center, style: t.bodyMedium),
                ),
              if (_single)
                Center(
                  child: SizedBox(
                    width: 220,
                    child: AspectRatio(
                      aspectRatio: kCardAspect,
                      child: CardFace(cardId: _draw.cards.first.cardId, reversed: _draw.cards.first.reversed, zoomable: true, deck: widget.deck),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: _draw.cards.length > 5 ? 420 : 300,
                  child: SpreadLayout(
                    spread: _draw.spread,
                    cards: _draw.cards,
                    revealed: {for (var i = 0; i < _draw.cards.length; i++) i},
                    onTap: _jumpTo,
                    selected: _selected,
                  ),
                ),
              if (!_single)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.readingTapCardHint, textAlign: TextAlign.center, style: t.bodySmall),
                ),
              if (widget.firstImpression.isNotEmpty)
                Section(title: l.firstImpressionSection, child: Text(widget.firstImpression)),
              if (d.atmosphere != null) AtmosphereSection(lines: lines, texts: d.atmosphere!),
              for (var i = 0; i < _draw.cards.length; i++)
                KeyedSubtree(
                  key: _keys[i],
                  child: _CardReading(
                    position: i,
                    drawn: _draw.cards[i],
                    content: d.cards[i],
                    reading: _reading(i, d.cards[i]),
                    positionText: d.spread?.positions[_draw.spread.positions[i].key],
                    single: _single,
                    deck: widget.deck,
                    area: widget.area,
                  ),
                ),
              if (keyContent?.eastWest != null) EastWestSection(ew: keyContent!.eastWest!),
              if (keyReading != null) ...[
                Section(title: l.sectionAction, child: Text(keyReading.action)),
                Section(title: l.sectionQuestion, child: Text(keyReading.question)),
              ],
              for (final action in activeFeatures(_s.flags).map((f) => f.readingAction).whereType<ReadingAction>())
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => action.open(context, _draw.keyCard.cardId),
                      icon: Icon(action.icon),
                      label: Text(action.label(l)),
                    ),
                  ),
                ),
              if (!widget.review && _s.journal != null && _s.flags.featureEnabled('journal')) ...[
                const SizedBox(height: 24),
                Center(
                  child: _saved
                      ? Text(l.savedToJournalHint, style: t.bodySmall, textAlign: TextAlign.center)
                      : FilledButton.icon(
                          onPressed: () => _save(d),
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: Text(l.saveThisReading),
                        ),
                ),
              ],
              const SizedBox(height: 32),
              Text(l.readingDisclaimer, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          );
        },
      ),
    );
  }

  /// 分享：用關鍵牌與它這一組解讀的標題與象的畫面做卡片（不放問題）。
  Future<void> _share() async {
    final d = await _loaded;
    if (!mounted) return;
    final pos = _draw.spread.keyPosition.clamp(0, _draw.cards.length - 1);
    final r = _reading(pos, d.cards[pos]);
    await showShareReading(context, draw: _draw, title: r?.title, image: r?.image);
  }

  Future<void> _save(_Loaded d) async {
    // 免費版日記上限：已存的不刪，只是不能再新增
    final journal = _s.journal;
    if (!_s.isPremium && journal != null && (await journal.all()).length >= _s.limits.journalMax) {
      if (!mounted || !await _journalLimit()) return;
      if (!mounted) return;
    }
    final entry = await showSaveReadingSheet(
      context,
      draw: _draw,
      question: widget.question,
      firstImpression: widget.firstImpression,
      readingIndexes: _indexes(d),
      area: widget.area,
    );
    if (entry == null) return;
    _s.events.emit(JournalSaved(hasReminder: entry.reminderAt != null));
    if (mounted) setState(() => _saved = true);
  }

  /// 日記上限說明。成為會員、或看完獎勵廣告（只換存這一則）回傳 true。
  Future<bool> _journalLimit() async {
    final l = context.l10n;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.journalLimitTitle(_s.limits.journalMax)),
        content: Text(l.journalLimitBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.notNow)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'watch'), child: Text(l.journalWatchAd)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'premium'), child: Text(l.menuPremium)),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'premium') return openPaywall(context, source: 'journal_limit');
    if (choice != 'watch') return false;
    final ready = await _s.ads.prepareRewarded();
    if (!mounted) return false;
    if (!ready || !await _s.ads.showRewarded()) {
      if (mounted && !ready) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.castAdNotReady)));
      return false;
    }
    _s.events.emit(const RewardedEarned(source: 'journal'));
    return true;
  }
}

/// 牌陣中一個位置的牌與解讀。
class _CardReading extends StatelessWidget {
  const _CardReading({
    required this.position,
    required this.drawn,
    required this.content,
    required this.reading,
    required this.positionText,
    required this.single,
    this.deck,
    this.area = '',
  });

  final String area;

  final int position;
  final DrawnCard drawn;
  final CardContent? content;
  final ReadingContent? reading;
  final PositionText? positionText;
  final bool single;
  final Deck? deck;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final r = reading;
    final heading = single
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 72,
                child: AspectRatio(
                  aspectRatio: kCardAspect,
                  child: CardFace(cardId: drawn.cardId, reversed: drawn.reversed, zoomable: true, deck: deck),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.positionHeading(position + 1, positionText?.name ?? ''), style: t.bodySmall),
                  Text(l.drawnName(drawn), style: t.headlineSmall?.copyWith(fontSize: 21)),
                  if (positionText != null && positionText!.meaning.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(positionText!.meaning, style: t.bodySmall),
                  ],
                  if (positionText != null && positionText!.prompt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(positionText!.prompt, style: t.bodySmall?.copyWith(color: TarotColors.twilight)),
                  ],
                ]),
              ),
            ]),
          );
    final keywords = content?.keywords(drawn.reversed) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null) heading,
        if (single && keywords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(keywords.join(l.separator), textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.earth)),
          ),
        if (r == null)
          Section(title: l.sectionReading, child: Text(l.readingNotWritten))
        else ...[
          Padding(
            padding: EdgeInsets.only(top: single ? 20 : 16),
            child: Text(r.title, textAlign: single ? TextAlign.center : TextAlign.start, style: t.headlineSmall),
          ),
          if (!single && keywords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(keywords.join(l.separator), style: t.bodySmall?.copyWith(color: TarotColors.earth)),
            ),
          Section(title: l.sectionImage, child: Text(r.image, style: t.bodyLarge)),
          if (single) Section(title: l.sectionSource, child: Text(r.source)),
          Section(title: l.sectionMeaning, child: Text(r.meaning)),
          if (area.isNotEmpty && (content?.area(drawn.reversed, area).isNotEmpty ?? false))
            Section(title: l.sectionArea(area), child: Text(content!.area(drawn.reversed, area))),
          Section(title: l.sectionForYou, child: Text(r.forYou)),
          if (!single)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(l.sectionSource, style: t.titleMedium),
                children: [Text(r.source)],
              ),
            ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => CardDetailPage(cardId: drawn.cardId, reversed: drawn.reversed),
            )),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(l.cardDetailButton(l.cardName(drawn.cardId))),
          ),
        ),
        if (!single) const Divider(height: 24, color: TarotColors.mountain),
      ],
    );
  }
}
