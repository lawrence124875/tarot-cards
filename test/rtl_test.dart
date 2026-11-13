import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/app.dart';
import 'package:tarot_cards/app/services.dart';
import 'package:tarot_cards/core/onboarding/intro_store.dart';
import 'package:tarot_cards/core/tarot/spread.dart';
import 'package:tarot_cards/features/intro/onboarding_page.dart';
import 'package:tarot_cards/l10n/l10n.dart';
import 'package:tarot_cards/shared/widgets/spread_layout.dart';

import 'helpers.dart';

/// 0.4.0 P4：阿拉伯文（由右至左）的牌陣方向與新手引導版面。
void main() {
  Future<List<double>> slotXs(WidgetTester tester, Locale locale, Spread spread) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(testApp(
      testServices(),
      Scaffold(body: SizedBox(width: 390, height: 500, child: SpreadLayout(spread: spread, cards: const [], revealed: const {}))),
      locale: locale,
    ));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(locale);
    final xs = [
      for (var i = 0; i < spread.positions.length; i++) tester.getCenter(find.bySemanticsLabel(l.pickCardLabel(i + 1))).dx
    ];
    handle.dispose();
    return xs;
  }

  testWidgets('三張牌陣：由左至右語言第 1 張在左，阿拉伯文鏡像為第 1 張在右', (tester) async {
    final ltr = await slotXs(tester, AppLanguages.zhHant.locale, Spreads.three);
    expect(ltr[0], lessThan(ltr[1]));
    expect(ltr[1], lessThan(ltr[2]));
    final rtl = await slotXs(tester, AppLanguages.ar.locale, Spreads.three);
    expect(rtl[0], greaterThan(rtl[1]));
    expect(rtl[1], greaterThan(rtl[2]));
    // 鏡像：左右對稱
    expect(rtl[0] + ltr[0], moreOrLessEquals(rtl[2] + ltr[2], epsilon: 0.5));
  });

  testWidgets('凱爾特十字在阿拉伯文也是鏡像、號碼不變', (tester) async {
    final ltr = await slotXs(tester, AppLanguages.zhHant.locale, Spreads.celtic);
    final rtl = await slotXs(tester, AppLanguages.ar.locale, Spreads.celtic);
    final center = (ltr.reduce((a, b) => a < b ? a : b) + ltr.reduce((a, b) => a > b ? a : b)) / 2;
    for (var i = 0; i < ltr.length; i++) {
      expect(rtl[i], moreOrLessEquals(2 * center - ltr[i], epsilon: 0.5), reason: 'position ${i + 1}');
    }
  });

  testWidgets('阿拉伯文新手引導：手機直向不溢出、由右至左', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    L10n.language = AppLanguages.ar;
    tester.platformDispatcher.localesTestValue = [AppLanguages.ar.locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => L10n.language = AppLanguages.zhHant);
    await tester.pumpWidget(AppServices(services: testServices(intro: MemoryIntroStore()), child: const TarotApp()));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(OnboardingPage))), TextDirection.rtl);
    expect(find.text(lookupAppLocalizations(AppLanguages.ar.locale).onboardTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
