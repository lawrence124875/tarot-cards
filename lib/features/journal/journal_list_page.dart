import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/premium/ad_banner.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/journal/journal_stats.dart';
import '../../core/lenormand/lenormand.dart';
import '../../core/runes/runes.dart';
import '../../core/tarot/tarot_card.dart';
import '../../core/journal/journal_reminders.dart';
import '../../shared/premium/paywall_page.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/card_face.dart';
import '../lenormand/lenormand_widgets.dart';
import '../runes/rune_widgets.dart';
import 'journal_backup_menu.dart';
import 'journal_entry_page.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 日記篩選：依系統自動分類（交叉＝雙系統與三系統）。
enum JournalFilter { all, tarot, lenormand, runes, cross }

extension JournalFilterMatch on JournalFilter {
  bool matches(JournalEntry e) => switch (this) {
        JournalFilter.all => true,
        JournalFilter.tarot => e.kind == JournalKind.tarot,
        JournalFilter.lenormand => e.kind == JournalKind.lenormand,
        JournalFilter.runes => e.kind == JournalKind.runes,
        JournalFilter.cross => e.kind == JournalKind.cross || e.kind == JournalKind.triple,
      };
}

/// 列表上的一列：月份標題或一筆日記。
class _Row {
  const _Row.header(this.month) : entry = null;
  const _Row.entry(JournalEntry this.entry) : month = null;

  final DateTime? month;
  final JournalEntry? entry;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// 日記搜尋用的文字：牌名（目前語言）、想問的事、第一眼、回顧。
String journalSearchText(
  JournalEntry e,
  AppLocalizations l, {
  Map<int, LenormandText> lenormand = const {},
  Map<int, RuneText> runes = const {},
}) =>
    [
      e.question,
      e.firstImpression,
      for (final f in e.followUps) f.text,
      for (final c in e.cards) l.cardName(c.cardId),
      for (final id in e.lenormand) lenormand[id]?.name ?? '',
      for (final code in e.runes)
        if (DrawnRune.fromCode(code) case final r?) runeDisplayName(l, runes, r),
    ].join('\n').toLowerCase();

/// 塔羅日記列表：由新到舊，依月份分組；可搜尋、依系統篩選、跳到某一天、左滑或多選刪除。
/// 免費版只顯示最近 [FreeLimits.journalDays] 天（舊紀錄只是收起，匯出仍包含）。
class JournalListPage extends StatefulWidget {
  const JournalListPage({super.key});

  @override
  State<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends State<JournalListPage> {
  late final Services _s = AppServices.of(context);
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _keys = <String, GlobalKey>{};

  bool _loaded = false;
  bool _started = false;
  List<JournalEntry> _entries = const [];
  Map<int, LenormandText> _names = const {};
  Map<String, String> _spreads = const {};
  Map<int, RuneText> _runeNames = const {};
  final _searchText = <String, String>{};

  String _query = '';
  JournalFilter _filter = JournalFilter.all;
  final Set<String> _selected = {};
  bool _selecting = false;
  String? _flash;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _s.journal?.addListener(_reload);
    _s.premium.isPremium.addListener(_onPremium);
    _reload();
  }

  @override
  void dispose() {
    _s.journal?.removeListener(_reload);
    _s.premium.isPremium.removeListener(_onPremium);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onPremium() {
    if (mounted) setState(() {});
  }

  /// 紀錄、雷諾曼牌名、牌陣名（塔羅用原 id，雷諾曼用 len_ 前綴、盧恩用 rune_ 前綴）。
  Future<void> _reload() async {
    final store = _s.journal;
    if (store == null) return;
    final entries = await store.all();
    final anyLen = entries.any((e) => e.lenormand.isNotEmpty);
    final names = anyLen ? await _s.lenormand.cards() : const <int, LenormandText>{};
    final anyRune = entries.any((e) => e.runes.isNotEmpty);
    final runeNames = anyRune ? await _s.runes.runes() : const <int, RuneText>{};
    final spreads = <String, String>{
      for (final e in ((await _s.content.spreads())?.spreads ?? const {}).entries) e.key: e.value.name,
      if (anyLen)
        for (final e in (await _s.lenormand.spreads()).entries) 'len_${e.key}': e.value.name,
      if (anyRune)
        for (final e in (await _s.runes.spreads()).entries) 'rune_${e.key}': e.value.name,
    };
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _names = names;
      _spreads = spreads;
      _runeNames = runeNames;
      _searchText.clear();
      final ids = {for (final e in entries) e.id};
      _selected.retainAll(ids);
      _loaded = true;
    });
  }

  /// 免費版看得到的紀錄（最近 N 天）。
  List<JournalEntry> get _visible {
    final cutoff = _s.journalCutoff();
    return cutoff == null ? _entries : [for (final e in _entries) if (!e.createdAt.isBefore(cutoff)) e];
  }

  List<JournalEntry> _filtered(List<JournalEntry> visible) {
    final q = _query.trim().toLowerCase();
    final l = context.l10n;
    return [
      for (final e in visible)
        if (_filter.matches(e) &&
            (q.isEmpty ||
                (_searchText[e.id] ??= journalSearchText(e, l, lenormand: _names, runes: _runeNames)).contains(q)))
          e,
    ];
  }

  List<_Row> _rows(List<JournalEntry> list) {
    final rows = <_Row>[];
    DateTime? month;
    for (final e in list) {
      final m = DateTime(e.createdAt.year, e.createdAt.month);
      if (month != m) {
        rows.add(_Row.header(m));
        month = m;
      }
      rows.add(_Row.entry(e));
    }
    return rows;
  }

  // ── 多選 ──

  void _startSelect(JournalEntry e) {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      _selected.add(e.id);
    });
  }

  void _toggle(JournalEntry e) => setState(() {
        if (!_selected.remove(e.id)) _selected.add(e.id);
        if (_selected.isEmpty) _selecting = false;
      });

  void _endSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  // ── 刪除（一律先確認；刪除後提示可「復原」）──

  Future<bool> _confirmDelete(int count) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(count == 1 ? l.journalDeleteTitle : l.journalDeleteManyTitle(count)),
        content: Text(l.journalDeleteUndoBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<void> _delete(List<JournalEntry> gone) async {
    final store = _s.journal;
    if (store == null || gone.isEmpty) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ids = {for (final e in gone) e.id};
    // 先從畫面移除（左滑的那一列必須立即離開列表）
    setState(() {
      _entries = [for (final e in _entries) if (!ids.contains(e.id)) e];
      _selected.removeAll(ids);
      if (_selected.isEmpty) _selecting = false;
    });
    for (final e in gone) {
      await _s.reminders.cancel(e.notificationId);
    }
    await store.deleteMany(ids);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.journalDeletedCount(gone.length)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            await store.addMissing(gone);
            for (final e in gone) {
              await JournalReminders.apply(_s.reminders, e, l.reviewMessage);
            }
          },
        ),
      ));
  }

  Future<void> _deleteSelected() async {
    final gone = [for (final e in _entries) if (_selected.contains(e.id)) e];
    if (gone.isEmpty || !await _confirmDelete(gone.length)) return;
    await _delete(gone);
  }

  // ── 跳到某一天 ──

  Future<void> _jumpToDate(List<JournalEntry> list, List<_Row> rows) async {
    if (list.isEmpty) return;
    final days = {for (final e in list) DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day)};
    final first = list.last.createdAt;
    final last = list.first.createdAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(last.year, last.month, last.day),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      selectableDayPredicate: (d) => days.contains(DateTime(d.year, d.month, d.day)),
      helpText: context.l10n.journalJumpToDate,
    );
    if (picked == null || !mounted) return;
    final index = rows.indexWhere((r) => r.entry != null && _sameDay(r.entry!.createdAt, picked));
    if (index < 0) return;
    final id = rows[index].entry!.id;
    setState(() => _flash = id);
    // 列表是延遲建立的：先依平均列高估算位置，等那一列建出來後再精準捲到它。
    for (var i = 0; i < 8 && mounted && _scroll.hasClients; i++) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
        break;
      }
      final pos = _scroll.position;
      final avg = (pos.maxScrollExtent + pos.viewportDimension) / (rows.length + 1);
      _scroll.jumpTo((avg * index).clamp(0.0, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted && _flash == id) setState(() => _flash = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = _s.journal;
    final l = context.l10n;
    final visible = _visible;
    final hidden = _entries.length - visible.length;
    final list = _filtered(visible);
    final rows = _rows(list);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _endSelect();
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(icon: const Icon(Icons.close), tooltip: l.cancel, onPressed: _endSelect),
                title: Text(l.journalSelectedCount(_selected.length)),
                actions: [
                  IconButton(
                    tooltip: l.journalSelectAll,
                    icon: const Icon(Icons.select_all),
                    onPressed: () => setState(() {
                      final ids = {for (final e in list) e.id};
                      if (_selected.containsAll(ids)) {
                        _selected.removeAll(ids);
                        if (_selected.isEmpty) _selecting = false;
                      } else {
                        _selected.addAll(ids);
                      }
                    }),
                  ),
                  IconButton(
                    tooltip: l.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                title: Text(l.featureJournal),
                actions: [
                  if (store != null && visible.isNotEmpty)
                    IconButton(
                      tooltip: l.journalJumpToDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () => _jumpToDate(list, rows),
                    ),
                  if (store != null)
                    IconButton(
                      tooltip: l.journalStatsTitle,
                      icon: const Icon(Icons.insights_outlined),
                      onPressed: () => _showStats(context, visible),
                    ),
                  if (store != null) const JournalBackupMenu(),
                ],
              ),
        body: store == null
            ? const _Empty()
            : !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const _Empty()
                    : Column(children: [
                        if (visible.isNotEmpty) _controls(context),
                        Expanded(child: _list(context, rows, hidden, visible.isEmpty)),
                      ]),
        bottomNavigationBar: _selecting ? null : const AdBanner(),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final l = context.l10n;
    final pad = readablePadding(context, horizontal: 16, top: 8);
    String label(JournalFilter f) => switch (f) {
          JournalFilter.all => l.journalFilterAll,
          JournalFilter.tarot => l.journalKindName(JournalKind.tarot),
          JournalFilter.lenormand => l.journalKindName(JournalKind.lenormand),
          JournalFilter.runes => l.journalKindName(JournalKind.runes),
          JournalFilter.cross => l.journalFilterCross,
        };
    final present = {for (final e in _entries) e.kind};
    final filters = [
      JournalFilter.all,
      for (final f in JournalFilter.values.skip(1))
        if (_entries.any(f.matches) || f == _filter) f,
    ];
    return Padding(
      padding: pad,
      child: Column(children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: l.journalSearchHint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l.journalClearSearch,
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        if (present.length > 1 || _filter != JournalFilter.all)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(label(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _list(BuildContext context, List<_Row> rows, int hidden, bool noneVisible) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final footer = hidden > 0 ? 1 : 0;
    final noResults = rows.isEmpty && !noneVisible;
    final ml = MaterialLocalizations.of(context);
    return ListView.builder(
      controller: _scroll,
      padding: readablePadding(context, horizontal: 16, top: 0, bottom: 32),
      itemCount: rows.length + footer + (noResults ? 1 : 0),
      itemBuilder: (context, i) {
        if (noResults && i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(l.journalNoResults, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
          );
        }
        final r = i - (noResults ? 1 : 0);
        if (r >= rows.length) return _HiddenFooter(count: hidden, days: _s.limits.journalDays);
        final row = rows[r];
        if (row.month != null) {
          return Padding(
            padding: EdgeInsetsDirectional.only(top: r == 0 ? 4 : 20, bottom: 4, start: 4),
            child: Semantics(header: true, child: Text(ml.formatMonthYear(row.month!), style: t.titleSmall?.copyWith(color: TarotColors.rice))),
          );
        }
        final e = row.entry!;
        final key = _keys.putIfAbsent(e.id, GlobalKey.new);
        final tile = _Tile(
          key: key,
          entry: e,
          names: _names,
          spreads: _spreads,
          runeNames: _runeNames,
          selecting: _selecting,
          selected: _selected.contains(e.id),
          highlight: _flash == e.id,
          onLongPress: () => _selecting ? _toggle(e) : _startSelect(e),
          onTap: _selecting ? () => _toggle(e) : null,
        );
        final next = r + 1 < rows.length ? rows[r + 1] : null;
        final divided = next?.entry != null
            ? DecoratedBox(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: TarotColors.mountain))),
                child: tile,
              )
            : tile;
        if (_selecting) return divided;
        final cs = Theme.of(context).colorScheme;
        return Dismissible(
          key: ValueKey('dismiss_${e.id}'),
          direction: DismissDirection.endToStart,
          background: const SizedBox.shrink(),
          secondaryBackground: Container(
            color: cs.error,
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 24),
            child: Icon(Icons.delete_outline, color: cs.onError, semanticLabel: l.delete),
          ),
          confirmDismiss: (_) => _confirmDelete(1),
          onDismissed: (_) => _delete([e]),
          child: divided,
        );
      },
    );
  }
}

/// 免費版：較舊的日記先收起，提示升級。
class _HiddenFooter extends StatelessWidget {
  const _HiddenFooter({required this.count, required this.days});

  final int count;
  final int days;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.lock_clock_outlined, color: TarotColors.rice),
              const SizedBox(width: 12),
              Expanded(child: Text(l.journalHiddenOld(count, days), style: t.bodyMedium)),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => openPaywall(context, source: 'journal_history'),
                child: Text(l.journalSeeAllHistory),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.entry,
    required this.names,
    required this.spreads,
    this.runeNames = const {},
    this.selecting = false,
    this.selected = false,
    this.highlight = false,
    this.onLongPress,
    this.onTap,
  });

  final JournalEntry entry;
  final bool selecting;
  final bool selected;
  final bool highlight;
  final VoidCallback? onLongPress;

  /// 多選模式時切換選取；null＝打開日記。
  final VoidCallback? onTap;
  final Map<int, LenormandText> names;
  final Map<int, RuneText> runeNames;
  final Map<String, String> spreads;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final reviews = entry.followUps.length;
    final pending = entry.reminderAt != null && entry.reminderAt!.isAfter(DateTime.now());
    final String title;
    final Widget face;
    if (entry.isRunes) {
      final r = DrawnRune.fromCode(entry.keyRune!) ?? const DrawnRune(1);
      final name = runeDisplayName(l, runeNames, r);
      title = entry.runes.length == 1 ? name : l.journalTitleSpread(name, entry.runes.length);
      face = AspectRatio(aspectRatio: kRuneAspect, child: RuneStoneFace(runeId: r.id, reversed: r.reversed, name: name));
    } else if (entry.isLenormand) {
      final id = entry.keyLenormand!;
      final name = names[id]?.name ?? '$id';
      title = entry.lenormand.length == 1 ? name : l.journalTitleSpread(name, entry.lenormand.length);
      face = AspectRatio(aspectRatio: kLenormandAspect, child: LenormandFace(cardId: id, name: name));
    } else {
      final key = entry.keyCard;
      title = entry.cards.length == 1 ? l.drawnName(key) : l.journalTitleSpread(l.drawnName(key), entry.cards.length);
      face = AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: key.cardId, reversed: key.reversed));
    }
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      selected: selected,
      selectedTileColor: cs.primary.withValues(alpha: 0.12),
      tileColor: highlight ? TarotColors.rice.withValues(alpha: 0.18) : null,
      onLongPress: onLongPress,
      leading: SizedBox(
        width: 40,
        child: selecting
            ? Center(child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? cs.primary : TarotColors.textSub))
            : face,
      ),
      title: Text(title, style: t.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              [
                l.journalKindName(entry.kind),
                // 交叉解讀固定是塔羅三張＋雷諾曼三張，不另標牌陣
                if (!entry.isCross && !entry.isTriple) spreads[entry.spreadId] ?? '',
              ].where((x) => x.isNotEmpty).join('・'),
              style: t.labelMedium?.copyWith(color: TarotColors.rice)),
          Text(
            entry.question.isEmpty ? l.journalNoQuestion : entry.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(color: entry.question.isEmpty ? TarotColors.textSub : null),
          ),
          const SizedBox(height: 2),
          Text(
            [
              formatDate(entry.createdAt),
              if (reviews > 0) l.journalReviewCount(reviews),
              if (pending) l.journalReminderOn(formatDate(entry.reminderAt!)),
            ].join(l.separator),
            style: t.bodySmall,
          ),
        ],
      ),
      onTap: onTap ??
          () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => JournalEntryPage(entryId: entry.id)),
              ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          context.l10n.journalEmpty,
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: TarotColors.textSub),
        ),
      ),
    );
  }
}

/// 日記統計（只是紀錄的整理，不是預測）。
Future<void> _showStats(BuildContext context, List<JournalEntry> entries) async {
  final stats = JournalStats.from(entries);
  final l = context.l10n;
  final t = Theme.of(context).textTheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.journalStatsTitle, style: t.titleLarge),
          const SizedBox(height: 12),
          if (stats.total == 0)
            Text(l.journalStatsEmpty)
          else ...[
            Text(l.journalStatsCards(stats.total)),
            const SizedBox(height: 12),
            for (final row in [
              (l.arcanaMajor, stats.majors),
              for (final s in Suit.values) ('${l.suitName(s)}（${l.elementLabel(s.element)}）', stats.suits[s]!),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(row.$1, style: t.bodySmall)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: row.$2 / stats.total,
                        minHeight: 8,
                        color: TarotColors.rice,
                        backgroundColor: TarotColors.mountain.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  SizedBox(width: 36, child: Text('${row.$2}', textAlign: TextAlign.end, style: t.bodySmall)),
                ]),
              ),
            const SizedBox(height: 8),
            Text(l.journalStatsReversed(stats.reversed, stats.total), style: t.bodySmall),
            if (stats.top.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.journalStatsTop, style: t.titleSmall),
              const SizedBox(height: 6),
              for (final c in stats.top) Text('${l.cardName(c.cardId)}　${l.journalStatsTimes(c.count)}'),
            ],
          ],
          const SizedBox(height: 16),
          Text(l.journalStatsNote, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
        ]),
      ),
    ),
  );
}
