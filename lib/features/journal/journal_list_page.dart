import 'package:flutter/material.dart';

import '../../shared/premium/ad_banner.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/journal/journal_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/card_face.dart';
import 'journal_backup_menu.dart';
import 'journal_entry_page.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 塔羅日記列表：由新到舊。
class JournalListPage extends StatelessWidget {
  const JournalListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppServices.of(context).journal;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.featureJournal),
        actions: [if (store != null) const JournalBackupMenu()],
      ),
      body: store == null ? const _Empty() : _List(store: store),
      bottomNavigationBar: const AdBanner(),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.store});

  final JournalStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => FutureBuilder<List<JournalEntry>>(
        future: store.all(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snap.data!;
          if (entries.isEmpty) return const _Empty();
          return ListView.separated(
            padding: readablePadding(context, horizontal: 16, top: 8, bottom: 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: TarotColors.mountain),
            itemBuilder: (context, i) => _Tile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final key = entry.keyCard;
    final reviews = entry.followUps.length;
    final pending = entry.reminderAt != null && entry.reminderAt!.isAfter(DateTime.now());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      leading: SizedBox(
        width: 40,
        child: AspectRatio(aspectRatio: kCardAspect, child: CardFace(cardId: key.cardId, reversed: key.reversed)),
      ),
      title: Text(
          entry.cards.length == 1
              ? l.drawnName(key)
              : l.journalTitleSpread(l.drawnName(key), entry.cards.length),
          style: t.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      onTap: () => Navigator.of(context).push(
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
