import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/daily/daily_card.dart';
import '../../core/tarot/draw.dart';
import '../../l10n/l10n.dart';
import '../../reading/reading_page.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/card_back.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/flip_card.dart';

/// 今日一張：翻開今天的牌 → 一句肯定語、關鍵詞與一組解讀的「給現在的你」→ 看完整解讀。
/// 同一天再打開看到的是同一張。下方可開關每日提醒。
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  late final Services _s = AppServices.of(context);
  DrawnCard? _card;
  CardContent? _content;
  bool _loading = true;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = await _s.daily.today(DateTime.now());
    final content = c == null ? null : await _s.content.card(c.cardId);
    if (!mounted) return;
    setState(() {
      _card = c;
      _content = content;
      _flipped = c != null;
      _loading = false;
    });
  }

  Future<void> _draw() async {
    if (_card != null) return;
    HapticFeedback.lightImpact();
    final c = await _s.daily.drawToday(DateTime.now(), _s.random, reversals: _s.settings.reversals);
    final content = await _s.content.card(c.cardId);
    if (!mounted) return;
    setState(() {
      _card = c;
      _content = content;
      _flipped = true;
    });
  }

  ReadingContent? get _reading {
    final c = _card, content = _content;
    if (c == null || content == null) return null;
    final list = content.readings(c.reversed);
    if (list.isEmpty) return null;
    return list[DateTime.now().day % list.length];
  }

  void _openReading() {
    final c = _card!;
    final index = (_content?.readings(c.reversed).isNotEmpty ?? false)
        ? DateTime.now().day % _content!.readings(c.reversed).length
        : null;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReadingPage(
        draw: SpreadDraw(spreadId: 'one', methodId: DrawMethods.daily, cards: [c]),
        readingIndexes: [index],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = _card;
    final r = _reading;
    return Scaffold(
      appBar: AppBar(title: Text(l.featureDaily)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readablePadding(context, top: 8, bottom: 40),
              children: [
                Text(c == null ? l.dailyPrompt : l.dailyDate(DateTime.now().month, DateTime.now().day),
                    textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 210,
                    child: AspectRatio(
                      aspectRatio: kCardAspect,
                      child: GestureDetector(
                        onTap: _draw,
                        child: Semantics(
                          button: c == null,
                          label: c == null ? l.dailyFlip : null,
                          child: FlipCard(
                            flipped: _flipped,
                            back: const CardBack(),
                            front: c == null ? const SizedBox.shrink() : CardFace(cardId: c.cardId, reversed: c.reversed, zoomable: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (c == null)
                  Center(child: FilledButton(onPressed: _draw, child: Text(l.dailyFlip)))
                else ...[
                  Text(l.drawnName(c), textAlign: TextAlign.center, style: t.headlineSmall),
                  if (_content != null) ...[
                    const SizedBox(height: 4),
                    Text(_content!.keywords(c.reversed).join(l.separator),
                        textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.earth)),
                    if (_content!.affirmation.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: TarotColors.dawn.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          Text(l.dailyAffirmation, style: t.bodySmall),
                          const SizedBox(height: 6),
                          Text(_content!.affirmation, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(fontSize: 18)),
                        ]),
                      ),
                  ],
                  if (r != null) ...[
                    const SizedBox(height: 20),
                    Text(r.title, textAlign: TextAlign.center, style: t.titleMedium),
                    const SizedBox(height: 8),
                    Text(r.forYou),
                  ],
                  const SizedBox(height: 20),
                  Center(child: OutlinedButton(onPressed: _openReading, child: Text(l.dailyFullReading))),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.dailyComeBack, textAlign: TextAlign.center, style: t.bodySmall),
                  ),
                ],
                const SizedBox(height: 28),
                const DailyReminderTile(),
              ],
            ),
    );
  }
}

/// 每日提醒開關與時間（也出現在設定頁）。
class DailyReminderTile extends StatefulWidget {
  const DailyReminderTile({super.key});

  @override
  State<DailyReminderTile> createState() => _DailyReminderTileState();
}

class _DailyReminderTileState extends State<DailyReminderTile> {
  late final Services _s = AppServices.of(context);

  Future<void> _apply({bool? enabled, int? hour, int? minute}) async {
    final st = _s.settings;
    await st.update(dailyReminder: enabled, dailyHour: hour, dailyMinute: minute);
    if (!mounted) return;
    final l = context.l10n;
    final ok = await DailyReminders.apply(
      _s.reminders,
      enabled: st.dailyReminder,
      hour: st.dailyHour,
      minute: st.dailyMinute,
      title: l.dailyNotificationTitle,
      body: l.dailyNotificationBody,
    );
    if (!ok && mounted) {
      await st.update(dailyReminder: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.reminderFailed(l.reminderFailureText(_s.reminders.lastFailure))),
        duration: const Duration(seconds: 8),
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final st = _s.settings;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: st.dailyHour, minute: st.dailyMinute));
    if (picked != null) await _apply(enabled: true, hour: picked.hour, minute: picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = _s.settings;
    final time = TimeOfDay(hour: st.dailyHour, minute: st.dailyMinute).format(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => Card(
        child: Column(children: [
          SwitchListTile(
            title: Text(l.dailyReminder),
            subtitle: Text(st.dailyReminder ? l.dailyReminderOn(time) : l.dailyReminderOff),
            value: st.dailyReminder,
            onChanged: (v) => _apply(enabled: v),
          ),
          if (st.dailyReminder)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l.dailyReminderTime),
              trailing: Text(time),
              onTap: _pickTime,
            ),
        ]),
      ),
    );
  }
}
