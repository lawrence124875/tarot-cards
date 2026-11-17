import 'package:flutter/material.dart';

import '../../app/feature_registry.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/numerology/numerology.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/paywall_page.dart';
import 'numerology_feature.dart';
import 'numerology_hub_page.dart';
import 'numerology_widgets.dart';

/// 今天的流日主題（numbers.json day.theme）；沒有生日或沒有內容時為 null。
Future<String?> numdayTheme(Services s, int day) async {
  final texts = await s.numerology.texts();
  final theme = texts.numbers[day]?.dayTheme ?? '';
  return theme.isEmpty ? null : theme;
}

bool _numerologyOn(Services s) => activeFeatures(s.flags).any((f) => f.id == numerologyFeature.id);

void _openHub(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NumerologyHubPage()));

mixin _NumdayLoader<T extends StatefulWidget> on State<T> {
  late final Services s = AppServices.of(context);
  NumerologyTexts texts = const NumerologyTexts();
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await s.birthdays.load();
    final t = await s.numerology.texts();
    if (!mounted) return;
    setState(() {
      texts = t;
      loaded = true;
    });
  }
}

/// 首頁今日一牌上方的小橫幅（0.5.1，Lawrence 2026-11-17）：
/// 「流日 5・流月 3・流年 8」＋今天的流日主題，點一下進靈數頁。
/// 免費版流月、流年顯示鎖頭，點鎖頭開付費牆（來源 numerology_banner）。沒有生日顯示「輸入生日看今日流日」。
/// 生命靈數遠端開關關閉時不顯示。
class NumdayBanner extends StatefulWidget {
  const NumdayBanner({super.key, this.now});

  /// 測試用：固定今天。
  final DateTime? now;

  @override
  State<NumdayBanner> createState() => _NumdayBannerState();
}

class _NumdayBannerState extends State<NumdayBanner> with _NumdayLoader {
  Future<void> _locked() async {
    if (await openPaywall(context, source: 'numerology_banner') && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_numerologyOn(s) || !loaded) return const SizedBox.shrink();
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<bool>(
      valueListenable: s.premium.isPremium,
      builder: (context, premium, _) => ValueListenableBuilder<DateTime?>(
        valueListenable: s.birthdays.birthday,
        builder: (context, birth, _) {
          final now = widget.now ?? DateTime.now();
          Widget body;
          if (birth == null) {
            body = Row(children: [
              Icon(Icons.pin_outlined, color: TarotColors.earth),
              const SizedBox(width: 12),
              Expanded(child: Text(l.numBannerPrompt, style: t.bodyLarge)),
              Icon(Icons.chevron_right, color: TarotColors.textSub),
            ]);
          } else {
            final day = Numerology.personalDay(birth, now);
            final theme = texts.numbers[day]?.dayTheme ?? '';
            Widget item(String label, int? n, {bool locked = false}) => InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: locked ? _locked : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(label, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
                      const SizedBox(width: 6),
                      if (locked)
                        Icon(Icons.lock_outline, size: 18, color: TarotColors.textSub, semanticLabel: l.numPremiumHint)
                      else
                        NumberBadge(number: n!, size: 28),
                    ]),
                  ),
                );
            body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                item(l.numShortDay, day),
                item(l.numShortMonth, Numerology.personalMonth(birth, now), locked: !premium),
                item(l.numShortYear, Numerology.personalYear(birth, now), locked: !premium),
              ]),
              if (theme.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(theme, style: t.bodyMedium?.copyWith(color: TarotColors.earth)),
              ],
            ]);
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              key: const ValueKey('numday-banner'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openHub(context),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: body),
            ),
          );
        },
      ),
    );
  }
}

/// 交叉解讀（塔羅 × 雷諾曼、三系統）結果底部一行「今天的流日提醒」（0.5.1）：
/// 流日數字＋主題，點擊進靈數頁；沒有生日顯示「輸入生日看今日流日」。生命靈數關閉時不顯示。
class NumdayHint extends StatefulWidget {
  const NumdayHint({super.key, this.now});

  final DateTime? now;

  @override
  State<NumdayHint> createState() => _NumdayHintState();
}

class _NumdayHintState extends State<NumdayHint> with _NumdayLoader {
  @override
  Widget build(BuildContext context) {
    if (!_numerologyOn(s) || !loaded) return const SizedBox.shrink();
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<DateTime?>(
      valueListenable: s.birthdays.birthday,
      builder: (context, birth, _) {
        String text;
        if (birth == null) {
          text = l.numBannerPrompt;
        } else {
          final day = Numerology.personalDay(birth, widget.now ?? DateTime.now());
          final theme = texts.numbers[day]?.dayTheme ?? '';
          text = theme.isEmpty ? '${l.numPersonalDay} $day' : l.numCrossFooter(day, theme);
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            key: const ValueKey('numday-hint'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openHub(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                Icon(Icons.pin_outlined, size: 20, color: TarotColors.earth),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: t.bodyMedium?.copyWith(color: TarotColors.textSub))),
                Icon(Icons.chevron_right, size: 20, color: TarotColors.textSub),
              ]),
            ),
          ),
        );
      },
    );
  }
}
