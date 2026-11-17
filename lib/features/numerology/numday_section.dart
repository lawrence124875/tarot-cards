import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/cross/numday_composer.dart';
import '../../core/events/event_bus.dart';
import '../../core/monetization/free_trials.dart';
import '../../core/numerology/numerology.dart';
import '../../core/tarot/draw.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/premium/paywall_page.dart';
import 'numerology_widgets.dart';

/// 流日 × 今日一牌（今日一牌翻牌後、日記回顧共用）。
///
/// - 遠端開關 `tr_feature_numday` 關閉時不顯示。
/// - 沒有生日：[live] 時顯示「輸入生日，看今天的流日怎麼呼應這張牌」；日記回顧不顯示。
/// - 免費／付費比照塔羅 × 雷諾曼（Lawrence 2026-11-17）：免費一次完整（記住那天那張牌，回看仍完整），
///   之後只顯示標題列（流日數字＋牌名＋關係名稱）＋付費牆（來源 numday）；Premium 全部完整。
class NumdaySection extends StatefulWidget {
  const NumdaySection({super.key, required this.card, required this.date, this.day, this.live = true, this.templates});

  final DrawnCard card;

  /// 那一天（今日一牌＝今天；日記＝存檔日期）。
  final DateTime date;

  /// 固定的流日數字（日記回顧用當時記下的數字）；null＝依生日計算。
  final int? day;

  /// 今日一牌畫面（可輸入生日、可用掉免費體驗）。
  final bool live;

  /// 測試用：直接給模板（不讀資產）。
  final NumdayTemplates? templates;

  static const featureId = 'numday';

  @override
  State<NumdaySection> createState() => _NumdaySectionState();
}

class _NumdaySectionState extends State<NumdaySection> {
  late final Services _s = AppServices.of(context);
  NumdayTemplates? _templates;
  NumerologyTexts? _numbers;
  List<String> _keywords = const [];
  String _affirmation = '';
  bool _ready = false;
  int? _shownDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await _s.birthdays.load();
    final templates = widget.templates ?? await loadNumdayTemplates(L10n.contentFolder);
    final numbers = await _s.numerology.texts();
    final content = await _s.content.card(widget.card.cardId);
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _numbers = numbers;
      _keywords = content?.keywords(widget.card.reversed) ?? const [];
      _affirmation = content?.affirmation ?? '';
      _ready = true;
    });
  }

  int get _seed => numdaySeed(widget.card, widget.date);

  /// 免費版第一次：今日一牌畫面上用掉一次完整體驗（記下那天那張牌）。
  bool _full() {
    if (_s.isPremium) return true;
    if (_s.trials.unlocked(FreeTrials.numday, _seed)) return true;
    if (widget.live && _s.trials.available(FreeTrials.numday)) {
      unawaited(_s.trials.use(FreeTrials.numday, _seed));
      return true;
    }
    return false;
  }

  void _emit(NumdayReport r, bool full) {
    if (!widget.live || _shownDay == r.day) return;
    _shownDay = r.day;
    _s.events.emit(NumdayShown(relation: r.relation.name, day: r.day, full: full));
  }

  @override
  Widget build(BuildContext context) {
    if (!_s.flags.featureEnabled(NumdaySection.featureId) || !_ready) return const SizedBox.shrink();
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _s.birthdays.birthday,
      builder: (context, birth, _) {
        final day = widget.day ?? (birth == null ? null : Numerology.personalDay(birth, widget.date));
        if (day == null || day < 1 || day > 9) {
          if (!widget.live) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: BirthdayPrompt(message: context.l10n.numdayPrompt, onSaved: () => setState(() {})),
          );
        }
        final r = _templates!.compose(
          day: day,
          card: widget.card,
          cardName: context.l10n.drawnName(widget.card),
          numbers: _numbers?.numbers ?? const {},
          keywords: _keywords,
          affirmation: _affirmation,
          seed: _seed,
        );
        final full = _full();
        _emit(r, full);
        return NumdayResultView(
          report: r,
          templates: _templates!,
          full: full,
          trial: full && !_s.isPremium,
          onUnlocked: () => setState(() {}),
        );
      },
    );
  }
}

/// 流日 × 今日一牌的內容（標題列＋四段，或標題列＋付費牆）。
class NumdayResultView extends StatelessWidget {
  const NumdayResultView({
    super.key,
    required this.report,
    required this.templates,
    required this.full,
    this.trial = false,
    this.onUnlocked,
  });

  final NumdayReport report;
  final NumdayTemplates templates;
  final bool full;
  final bool trial;
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final s = AppServices.of(context);
    final r = report;
    String title(String key, String fallback) {
      final v = templates.sectionTitle(key);
      return v.isEmpty ? fallback : v;
    }

    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(l.numdayTitle, style: t.labelLarge?.copyWith(color: TarotColors.textSub)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            NumberBadge(number: r.day, size: 40),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.dayTheme.isEmpty ? r.header : '${r.header}・${r.dayTheme}', style: t.titleMedium),
                Text('${l.drawnName(r.card)}・${r.relationName.isEmpty ? r.relation.name : r.relationName}',
                    style: t.bodyMedium?.copyWith(color: TarotColors.earth)),
              ]),
            ),
          ]),
          if (full && r.relationLead.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(r.relationLead, textAlign: TextAlign.center)),
        ]),
      ),
    );
    if (!full) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.lock_outline),
                const SizedBox(height: 8),
                Text(l.numdayLockedBody, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    s.events.emit(const HitFreeLimit(type: 'numday'));
                    if (await openPaywall(context, source: 'numday')) onUnlocked?.call();
                  },
                  child: Text(l.numdayUnlock),
                ),
              ]),
            ),
          ),
        ]),
      );
    }
    final italic = t.bodyLarge?.copyWith(fontStyle: FontStyle.italic);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        if (trial)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.numdayTrialNote, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
          ),
        Section(
          title: title('day', l.numPersonalDay),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final x in r.dayText) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x)),
          ]),
        ),
        Section(
          title: title('card', l.featureDaily),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.cardText),
            if (r.affirmation.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.affirmation, style: italic)),
          ]),
        ),
        if (r.meet.isNotEmpty) Section(title: title('meet', r.relationName), child: Text(r.meet)),
        Section(
          title: title('practice', l.numPractice),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (r.practice.isNotEmpty) Text(r.practice),
            if (r.reflection.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(r.reflectLabel.isEmpty ? l.numQuestion : r.reflectLabel,
                  style: t.labelLarge?.copyWith(color: TarotColors.earth)),
              Text(r.reflection, style: italic),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Text(r.disclaimer.isEmpty ? l.numDisclaimer : r.disclaimer,
            style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
      ]),
    );
  }
}
