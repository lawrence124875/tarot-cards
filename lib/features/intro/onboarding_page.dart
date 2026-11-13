import 'package:flutter/material.dart';

import '../../app/feature_registry.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../daily/daily_feature.dart';
import '../draw/draw_feature.dart';
import '../learn/learn_feature.dart';

/// 新手引導的三個起點（0.4.0）：每日覺察→今日一張、學塔羅→學習分頁、問一件事→抽牌。
enum StartChoice { daily, learn, ask }

/// 首次開啟時問「你想從哪裡開始？」。回傳選到的起點；略過或返回鍵為 null。
/// 不論怎麼離開都記為看過（PopScope）。原本的功能介紹頁保留在設定「關於與隱私」。
Future<StartChoice?> showOnboarding(NavigatorState navigator) => navigator.push(MaterialPageRoute<StartChoice>(
      fullscreenDialog: true,
      builder: (_) => const OnboardingPage(),
    ));

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final ids = activeFeatures(AppServices.of(context).flags).map((f) => f.id).toSet();
    final options = [
      if (ids.contains(dailyFeature.id))
        (StartChoice.daily, Icons.wb_sunny_outlined, l.onboardDaily, l.onboardDailyDesc),
      if (ids.contains(learnFeature.id))
        (StartChoice.learn, Icons.school_outlined, l.onboardLearn, l.onboardLearnDesc),
      if (ids.contains(drawFeature.id)) (StartChoice.ask, Icons.style_outlined, l.onboardAsk, l.onboardAskDesc),
    ];

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) AppServices.of(context).intro?.markSeen();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: readablePadding(context, horizontal: 24, top: 8, bottom: 24, maxWidth: 520),
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.onboardLater)),
              ),
              const SizedBox(height: 16),
              Icon(Icons.auto_awesome_outlined, size: 56, color: TarotColors.earth),
              const SizedBox(height: 20),
              Text(l.onboardTitle, textAlign: TextAlign.center, style: t.headlineSmall),
              const SizedBox(height: 12),
              Text(l.onboardSubtitle,
                  textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: TarotColors.textSub)),
              const SizedBox(height: 28),
              for (final o in options)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    key: ValueKey('onboard_${o.$1.name}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
                      foregroundColor: TarotColors.earth,
                      child: Icon(o.$2),
                    ),
                    title: Text(o.$3, style: t.titleMedium),
                    subtitle: Text(o.$4),
                    trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
                    onTap: () => Navigator.of(context).pop(o.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
