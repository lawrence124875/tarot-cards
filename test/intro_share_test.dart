import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/app.dart';
import 'package:tarot_cards/app/services.dart';
import 'package:tarot_cards/core/onboarding/intro_store.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/app/home_tabs.dart';
import 'package:tarot_cards/features/daily/daily_page.dart';
import 'package:tarot_cards/features/draw/spread_picker_page.dart';
import 'package:tarot_cards/features/intro/intro_page.dart';
import 'package:tarot_cards/features/intro/onboarding_page.dart';
import 'package:tarot_cards/features/learn/learn_hub_page.dart';
import 'package:tarot_cards/features/share/share.dart';
import 'package:tarot_cards/l10n/l10n.dart';

import 'helpers.dart';

final _single = SpreadDraw(spreadId: 'one', methodId: DrawMethods.quick, cards: const [DrawnCard(15, reversed: true)]);
final _three = SpreadDraw(
  spreadId: 'three',
  methodId: DrawMethods.ritual,
  cards: const [DrawnCard(0), DrawnCard(40, reversed: true), DrawnCard(77)],
);
final _celtic = SpreadDraw(
  spreadId: 'celtic',
  methodId: DrawMethods.quick,
  cards: [for (var i = 0; i < 10; i++) DrawnCard(i * 7, reversed: i.isOdd)],
);

void main() {
  group('新手引導', () {
    Future<MemoryIntroStore> open(WidgetTester tester) async {
      final store = MemoryIntroStore();
      await tester.pumpWidget(AppServices(services: testServices(intro: store), child: const TarotApp()));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(IntroPage), findsNothing); // 功能介紹改放設定頁
      return store;
    }

    testWidgets('選「學塔羅」切到學習分頁，記為已看過', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const ValueKey('onboard_learn')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(LearnHubPage), findsOneWidget);
      expect(store.value, isTrue);
    });

    testWidgets('選「問一件事」直接進抽牌', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const ValueKey('onboard_ask')));
      await tester.pumpAndSettle();
      expect(find.byType(SpreadPickerPage), findsOneWidget);
      expect(store.value, isTrue);
    });

    testWidgets('選「每日覺察」直接進今日一張', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const ValueKey('onboard_daily')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(DailyPage), findsOneWidget);
      expect(store.value, isTrue);
    });

    testWidgets('看過就不再自動顯示', (tester) async {
      await tester.pumpWidget(
          AppServices(services: testServices(intro: MemoryIntroStore(value: true)), child: const TarotApp()));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
    });

    testWidgets('略過也記為已看過，停在首頁', (tester) async {
      final store = await open(tester);
      await tester.tap(find.descendant(of: find.byType(OnboardingPage), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(TodayTab), findsOneWidget);
      expect(store.value, isTrue);
    });
  });

  group('分享卡片', () {
    for (final lang in AppLanguages.all) {
      testWidgets('${lang.code}：卡片（單張、三張、凱爾特十字）、介紹頁與新手引導排版不溢出', (tester) async {
        L10n.language = lang;
        Widget app(Widget home) => testApp(testServices(), home, locale: lang.locale);
        for (final d in [_single, _three, _celtic]) {
          await tester.pumpWidget(app(Scaffold(
            body: Center(
              child: FittedBox(
                child: ShareCard(draw: d, title: 'W' * 60, image: 'W ' * 400),
              ),
            ),
          )));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(ShareCard), findsOneWidget);
        }
        // 沒有解讀內容時（內容檔未匯入）也不溢出
        await tester.pumpWidget(app(Scaffold(body: Center(child: FittedBox(child: ShareCard(draw: _three))))));
        await tester.pump();
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(360 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(const IntroPage()));
        for (var i = 0; i < 6; i++) {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (i < 5) await tester.tap(find.byType(FilledButton));
        }
        await tester.pumpWidget(app(const OnboardingPage()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('橫放與平板', () {
    const sizes = [Size(392, 850), Size(850, 392), Size(640, 360), Size(1280, 800)];
    for (final size in sizes) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}：介紹頁、新手引導與分享預覽不溢出', (tester) async {
        L10n.language = AppLanguages.zhHant;
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(testApp(
          testServices(),
          Builder(
            builder: (context) => Scaffold(
              body: Column(children: [
                TextButton(
                  onPressed: () => showShareReading(context, draw: _three, title: 'W' * 30, image: 'W ' * 200),
                  child: const Text('share'),
                ),
                TextButton(onPressed: () => showIntro(Navigator.of(context)), child: const Text('intro')),
              ]),
            ),
          ),
        ));
        await tester.tap(find.text('share'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ShareCard), findsOneWidget);
        await tester.tap(find.byType(TextButton).last); // 取消
        await tester.pumpAndSettle();
        expect(find.byType(ShareCard), findsNothing);
        await tester.tap(find.text('intro'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }
        expect(find.byType(IntroPage), findsNothing);
        await tester.pumpWidget(testApp(testServices(), const OnboardingPage()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
