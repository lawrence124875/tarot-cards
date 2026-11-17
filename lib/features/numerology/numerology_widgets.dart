import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/numerology/numerology.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 選生日（日期選擇器）並存到本機；取消時回傳 null。
Future<DateTime?> pickBirthday(BuildContext context) async {
  final s = AppServices.of(context);
  final now = DateTime.now();
  final initial = s.birthdays.birthday.value ?? DateTime(now.year - 30, 1, 1);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: now,
    initialEntryMode: DatePickerEntryMode.input,
    helpText: context.l10n.numEnterBirthday,
  );
  if (picked == null) return null;
  await s.birthdays.save(picked);
  return picked;
}

/// 沒有生日時的輸入提示（靈數首頁、每日一牌共用）。
class BirthdayPrompt extends StatelessWidget {
  const BirthdayPrompt({super.key, this.message, required this.onSaved});

  final String? message;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (message != null) ...[Text(message!, style: t.bodyMedium), const SizedBox(height: 12)],
          FilledButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(l.numEnterBirthday),
            onPressed: () async {
              if (await pickBirthday(context) != null) onSaved();
            },
          ),
          const SizedBox(height: 8),
          Text(l.numBirthdayLocal, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
        ]),
      ),
    );
  }
}

/// 圓形數字徽章（主數加外框）。
class NumberBadge extends StatelessWidget {
  const NumberBadge({super.key, required this.number, this.size = 44, this.onTap});

  final int number;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final master = Numerology.masters.contains(number);
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TarotColors.dawn.withValues(alpha: 0.3),
        border: master ? Border.all(color: TarotColors.earth, width: 2) : null,
      ),
      child: Text('$number',
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: TarotColors.earth)),
    );
    if (onTap == null) return Center(child: badge);
    return Semantics(
      button: true,
      label: '$number',
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: badge)),
    );
  }
}

/// 課程內的數字小卡（lessons.json 的 cards 欄放數字 1–9、11、22、33）。
Widget numberLessonTile(BuildContext context, int id) {
  if (!Numerology.numbers.contains(id)) return const SizedBox.shrink();
  return NumberBadge(number: id);
}

/// 靈數首頁的一列。[number] 顯示徽章；[locked] 顯示鎖頭。
class NumTile extends StatelessWidget {
  const NumTile({
    super.key,
    this.number,
    this.icon,
    this.locked = false,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final int? number;
  final IconData? icon;
  final bool locked;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: number != null
              ? SizedBox.square(dimension: 40, child: NumberBadge(number: number!, size: 40))
              : CircleAvatar(
                  backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
                  foregroundColor: TarotColors.earth,
                  child: Icon(locked ? Icons.lock_outline : (icon ?? Icons.tag)),
                ),
          title: Text(title),
          subtitle: subtitle == null || subtitle!.isEmpty
              ? null
              : Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right, color: TarotColors.textSub),
          onTap: onTap,
        ),
      );
}

enum NumberKind { lifePath, birthday, day, month, year, library }

/// 單一數字的說明頁（依用途顯示不同段落）。
class NumberDetailPage extends StatelessWidget {
  const NumberDetailPage({super.key, required this.number, required this.kind, required this.texts});

  final int number;
  final NumberKind kind;
  final NumerologyTexts texts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final x = texts.numbers[number];
    final title = switch (kind) {
      NumberKind.lifePath => l.numLifePath,
      NumberKind.birthday => l.numBirthdayNumber,
      NumberKind.day => l.numPersonalDay,
      NumberKind.month => l.numPersonalMonth,
      NumberKind.year => l.numPersonalYear,
      NumberKind.library => l.numLibrary,
    };
    final sections = x == null
        ? <(String?, String)>[]
        : switch (kind) {
            NumberKind.lifePath => [
                (null, x.essence),
                (l.numGift, x.lifeGift),
                (l.numInnerWork, x.lifeInnerWork),
                (l.numPractice, x.lifePractice),
                (l.numQuestion, x.lifeQuestion),
              ],
            NumberKind.birthday => [(null, x.birthday), (null, x.essence)],
            NumberKind.day => [(x.dayTheme, x.dayText)],
            NumberKind.month => [(null, x.month)],
            NumberKind.year => [(x.yearTheme, x.yearText), (l.numPractice, x.yearPractice)],
            NumberKind.library => [(null, x.essence), (l.numGift, x.lifeGift), (l.numInnerWork, x.lifeInnerWork)],
          };
    final shown = [for (final s in sections) if (s.$2.isNotEmpty) s];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: readablePadding(context, top: 16, bottom: 40),
        children: [
          NumberBadge(number: number, size: 80),
          const SizedBox(height: 12),
          if (x != null && x.name.isNotEmpty) Text(x.name, textAlign: TextAlign.center, style: t.titleLarge),
          if (Numerology.masters.contains(number))
            Text(l.numMaster, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: TarotColors.earth)),
          if (x != null && x.keywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [for (final k in x.keywords) Chip(label: Text(k))],
            ),
          ],
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Text(l.learnComingSoon, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: TarotColors.textSub))
          else
            for (final s in shown) _Section(heading: s.$1, body: s.$2),
          const SizedBox(height: 16),
          Text(l.numDisclaimer, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.heading, required this.body});

  final String? heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (heading != null && heading!.isNotEmpty) ...[
          Text(heading!, style: t.titleSmall?.copyWith(color: TarotColors.earth)),
          const SizedBox(height: 4),
        ],
        Text(body, style: t.bodyLarge),
      ]),
    );
  }
}

/// 高峰數與挑戰數：四期時間軸，標出目前所在的期。
class PinnaclePage extends StatelessWidget {
  const PinnaclePage({super.key, required this.birth, required this.texts});

  final DateTime birth;
  final NumerologyTexts texts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final pins = Numerology.pinnacles(birth);
    final chs = Numerology.challenges(birth);
    final now = Numerology.currentPeriod(pins, Numerology.age(birth, DateTime.now()));
    String period(Period p) =>
        p.toAge == null ? l.numPeriodLast(p.index + 1, p.fromAge) : l.numPeriod(p.index + 1, p.fromAge, p.toAge!);
    return Scaffold(
      appBar: AppBar(title: Text(l.numPinnacles)),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          for (final p in pins)
            Card(
              shape: p.index == now
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), side: BorderSide(color: TarotColors.earth, width: 2))
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(period(p), style: t.titleSmall)),
                    if (p.index == now) Chip(label: Text(l.numNow), visualDensity: VisualDensity.compact),
                  ]),
                  const SizedBox(height: 8),
                  _PeriodRow(
                    label: l.numPinnacle,
                    number: p.number,
                    title: texts.numbers[p.number]?.name ?? '',
                    body: texts.numbers[p.number]?.pinnacle ?? '',
                  ),
                  const Divider(height: 20),
                  _PeriodRow(
                    label: l.numChallenge,
                    number: chs[p.index].number,
                    title: '',
                    body: [
                      texts.challenges[chs[p.index].number]?.text ?? '',
                      texts.challenges[chs[p.index].number]?.practice ?? '',
                    ].where((s) => s.isNotEmpty).join('\n'),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Text(l.numDisclaimer, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.label, required this.number, required this.title, required this.body});

  final String label;
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NumberBadge(number: number, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.isEmpty ? label : '$label · $title', style: t.labelLarge?.copyWith(color: TarotColors.earth)),
          if (body.isNotEmpty) ...[const SizedBox(height: 4), Text(body, style: t.bodyMedium)],
        ]),
      ),
    ]);
  }
}
