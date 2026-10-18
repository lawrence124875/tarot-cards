import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/deck/deck.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/journal/journal_reminders.dart';
import '../../l10n/l10n.dart';
import '../../reading/reading_page.dart';
import '../../reading/section.dart';
import '../../shared/format.dart';
import '../../shared/widgets/spread_layout.dart';
import '../../shared/widgets/question_dialog.dart';
import '../../shared/widgets/reminder_picker.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 一筆塔羅日記：當時的牌與問題、第一眼印象 → 當時的解讀 → 回顧（後來發生了什麼、象怎麼對上）→ 提醒。
class JournalEntryPage extends StatefulWidget {
  const JournalEntryPage({super.key, required this.entryId});

  final String entryId;

  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  late final Services _services = AppServices.of(context);
  JournalEntry? _entry;
  CardContent? _content;
  SpreadText? _spreadText;
  Deck? _deck;
  bool _loaded = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    _loaded = true;
    final e = await _services.journal?.byId(widget.entryId);
    final c = e == null ? null : await _services.content.card(e.keyCard.cardId);
    final sp = e == null ? null : (await _services.content.spreads())?[e.spreadId];
    final deck = (e == null || e.deckId.isEmpty) ? null : await _services.decks.deck(e.deckId);
    if (!mounted) return;
    setState(() {
      _entry = e;
      _content = c;
      _spreadText = sp;
      _deck = deck;
      _ready = true;
    });
  }

  Future<void> _update(JournalEntry e) async {
    setState(() => _entry = e);
    await _services.journal?.save(e);
  }

  Future<void> _editQuestion() async {
    final q = await askQuestion(context, initial: _entry!.question);
    if (q != null) await _update(_entry!.copyWith(question: q));
  }

  Future<void> _editImpression() async {
    final q = await askQuestion(context, initial: _entry!.firstImpression, title: context.l10n.firstImpressionSection);
    if (q != null) await _update(_entry!.copyWith(firstImpression: q));
  }

  Future<void> _editFollowUp([int? index]) async {
    final e = _entry!;
    final old = index == null ? null : e.followUps[index];
    final text = await askQuestion(
      context,
      initial: old?.text ?? '',
      title: index == null ? context.l10n.journalReviewDialogTitle : context.l10n.journalEditReview,
    );
    if (text == null) return;
    final list = [...e.followUps];
    if (index == null) {
      if (text.isEmpty) return;
      list.add(FollowUp(at: DateTime.now(), text: text));
    } else if (text.isEmpty) {
      list.removeAt(index);
    } else {
      list[index] = FollowUp(at: old!.at, text: text);
    }
    await _update(e.copyWith(followUps: list));
  }

  Future<void> _changeReminder(int? days) async {
    final e = _entry!;
    await _applyReminder(days == null
        ? e.copyWith(clearReminder: true)
        : e.copyWith(reminderAt: JournalReminders.reviewTime(DateTime.now(), days)));
  }

  Future<void> _applyReminder(JournalEntry next) async {
    final l = context.l10n;
    final ok = await JournalReminders.apply(_services.reminders, next, l.reviewMessage);
    if (!ok) next = next.copyWith(clearReminder: true);
    await _update(next);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.reminderFailed(l.reminderFailureText(_services.reminders.lastFailure))),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.journalDeleteTitle),
        content: Text(l.journalDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (yes != true) return;
    await _services.reminders.cancel(_entry!.notificationId);
    await _services.journal?.delete(_entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.featureJournal),
        actions: [
          if (e != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: l.delete),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : e == null
              ? Center(child: Text(l.journalNotFound))
              : _body(context, e),
    );
  }

  Widget _body(BuildContext context, JournalEntry e) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final key = e.keyCard;
    final keyPos = e.spread.keyPosition.clamp(0, e.cards.length - 1);
    final readings = _content?.readings(key.reversed) ?? const [];
    final idx = e.readingIndex(keyPos);
    final reading = (idx == null || readings.isEmpty) ? null : readings[idx % readings.length];
    final now = DateTime.now();
    final pending = e.reminderAt != null && e.reminderAt!.isAfter(now);
    final pendingDays = pending
        ? DateTime(e.reminderAt!.year, e.reminderAt!.month, e.reminderAt!.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays
        : null;

    return ListView(
      padding: readablePadding(context, top: 8, bottom: 40),
      children: [
        Text(
            [formatDateTime(e.createdAt), _spreadText?.name ?? '', l.methodName(e.methodId)]
                .where((x) => x.isNotEmpty)
                .join(l.separator),
            textAlign: TextAlign.center,
            style: t.bodySmall),
        const SizedBox(height: 16),
        SizedBox(
          height: e.cards.length == 1 ? 220 : (e.cards.length > 5 ? 360 : 240),
          child: SpreadLayout(
            spread: e.spread,
            cards: e.cards,
            revealed: {for (var i = 0; i < e.cards.length; i++) i},
            maxCardWidth: 130,
          ),
        ),
        const SizedBox(height: 12),
        Text([for (final c in e.cards) l.drawnName(c)].join(l.listSeparator),
            textAlign: TextAlign.center, style: t.titleMedium),
        if (reading != null) ...[
          const SizedBox(height: 8),
          Text(l.journalReadingThen, textAlign: TextAlign.center, style: t.bodySmall),
          Text(reading.title, textAlign: TextAlign.center, style: t.bodyLarge),
        ],
        Section(
          title: l.questionTitle,
          child: InkWell(
            onTap: _editQuestion,
            child: Row(children: [
              Expanded(
                child: Text(e.question.isEmpty ? l.journalQuestionEmpty : e.question,
                    style: e.question.isEmpty ? t.bodyMedium?.copyWith(color: TarotColors.textSub) : null),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: TarotColors.textSub),
            ]),
          ),
        ),
        Section(
          title: l.firstImpressionSection,
          child: InkWell(
            onTap: _editImpression,
            child: Row(children: [
              Expanded(
                child: Text(e.firstImpression.isEmpty ? l.journalQuestionEmpty : e.firstImpression,
                    style: e.firstImpression.isEmpty ? t.bodyMedium?.copyWith(color: TarotColors.textSub) : null),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: TarotColors.textSub),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ReadingPage(
              draw: e.draw,
              question: e.question,
              firstImpression: e.firstImpression,
              area: e.area,
              readingIndexes: e.readingIndexes,
              review: true,
              deck: _deck,
            ),
          )),
          child: Text(l.journalViewReading),
        ),
        Section(
          title: l.journalReviews,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.journalReviewPrompt, style: t.bodySmall),
              for (var i = 0; i < e.followUps.length; i++)
                InkWell(
                  onTap: () => _editFollowUp(i),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    decoration: const BoxDecoration(
                      border: BorderDirectional(start: BorderSide(color: TarotColors.rice, width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatDate(e.followUps[i].at), style: t.bodySmall),
                        Text(e.followUps[i].text),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => _editFollowUp(),
                  icon: const Icon(Icons.add),
                  label: Text(l.journalAddReview),
                ),
              ),
            ],
          ),
        ),
        Section(
          title: l.journalReminderSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pending
                    ? l.journalReminderPending(formatDate(e.reminderAt!), hour12(JournalReminders.reviewHour))
                    : l.journalReminderNone,
                style: t.bodySmall,
              ),
              const SizedBox(height: 8),
              ReminderPicker(days: pendingDays, onChanged: _changeReminder),
            ],
          ),
        ),
      ],
    );
  }
}
