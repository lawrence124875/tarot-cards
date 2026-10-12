import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/features/draw/first_impression_sheet.dart';
import 'package:tarot_cards/l10n/l10n.dart';

import 'helpers.dart';

/// 翻牌後、看解讀前的「第一眼印象」面板。
void main() {
  Future<void> open(WidgetTester tester, Size size, {FakeViewPadding padding = FakeViewPadding.zero}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..padding = padding
      ..viewPadding = padding;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      testServices(),
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => askFirstImpression(context), child: const Text('open')),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final l = lookupAppLocalizations(AppLanguages.zhHant.locale);

  testWidgets(
    '按「記下」或「略過」關閉面板時沒有例外',
    (tester) async {
      await open(tester, const Size(392, 850));
      expect(find.text(l.firstImpressionTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  杯子倒了  ');
      await tester.tap(find.text(l.firstImpressionSave));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l.firstImpressionTitle), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.firstImpressionSkip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  // 手機橫放、側邊瀏海與底部導覽列（同 adaptive_layout_test.dart）
  const landscape = [
    (Size(640, 360), FakeViewPadding(left: 24, bottom: 24)),
  ];
  for (final (size, padding) in landscape) {
    testWidgets(
      '${size.width.toInt()}×${size.height.toInt()}（手機橫放、有系統區域）：面板不溢出',
      (tester) async {
        await open(tester, size, padding: padding);
        expect(find.text(l.firstImpressionTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in const [Size(392, 850), Size(800, 1280), Size(640, 360), Size(850, 392)]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}：面板顯示不溢出', (tester) async {
      await open(tester, size);
      expect(find.text(l.firstImpressionTitle), findsOneWidget);
      expect(find.text(l.firstImpressionSave), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
