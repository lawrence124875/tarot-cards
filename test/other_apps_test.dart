import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/features/settings/other_apps.dart';
import 'package:tarot_cards/l10n/l10n.dart';

import 'helpers.dart';

/// 設定頁「LC Lab 其他 App」：兩列、Play 連結、11 語都有名稱與說明、圖示缺檔不壞。
void main() {
  test('連結為 Play 商店頁、不帶追蹤參數', () {
    expect(otherApps.map((a) => a.url), [
      'https://play.google.com/store/apps/details?id=com.lclab.qiangua',
      'https://play.google.com/store/apps/details?id=tw.bcc.englishapp',
    ]);
  });

  test('11 語都有名稱與說明', () {
    for (final lang in AppLanguages.all) {
      final l = lookupAppLocalizations(lang.locale);
      expect(l.otherAppsTitle, isNotEmpty);
      for (final a in otherApps) {
        expect(a.name(l), isNotEmpty);
        expect(a.desc(l), isNotEmpty);
      }
    }
  });

  testWidgets('顯示兩列（含阿拉伯文由右至左）', (tester) async {
    for (final locale in [AppLanguages.zhHant.locale, AppLanguages.ar.locale]) {
      await tester.pumpWidget(testApp(testServices(), const Scaffold(body: OtherAppsSection()), locale: locale));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });
}
