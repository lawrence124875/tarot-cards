// 商店截圖：在 tarot-content 的 store_screenshots.yml 匯入內容與字型後執行
//   flutter test test/store_screenshots_test.dart --update-goldens
// 產生 test/screenshots/*.png（1080×2340）。公開 repo 沒有內容檔，一般測試時自動略過。
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/app.dart';
import 'package:tarot_cards/app/home_page.dart';
import 'package:tarot_cards/app/services.dart';
import 'package:tarot_cards/core/content/asset_content_source.dart';
import 'package:tarot_cards/core/deck/deck_source.dart';
import 'package:tarot_cards/core/events/event_bus.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/features/learn/learn_hub_page.dart';
import 'package:tarot_cards/l10n/l10n.dart';
import 'package:tarot_cards/reading/card_detail_page.dart';
import 'package:tarot_cards/reading/reading_page.dart';

final _hasContent = File('assets/content/zh-Hant/00.json').existsSync();

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final f in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(f['family'] as String);
    for (final a in (f['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

/// 圖片在測試環境要在 runAsync 裡解碼，否則截圖是空白；牌面圖是非同步載入，多等幾輪。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump(const Duration(seconds: 2));
  }
}

void main() {
  final shotKey = GlobalKey();

  Future<NavigatorState> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'TW')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.runAsync(_loadFonts);
    final services = Services(
      content: AssetContentSource(folder: () => L10n.contentFolder),
      decks: AssetDeckSource(),
      events: EventBus(),
      random: Random(7),
      reminders: NoopReminderService(),
    );
    await tester.runAsync(services.loadDeck);
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: AppServices(services: services, child: const TarotApp()),
    ));
    await _settle(tester);
    return Navigator.of(tester.element(find.byType(HomePage)));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await _settle(tester);
    await expectLater(find.byKey(shotKey), matchesGoldenFile('screenshots/$name.png'));
  }

  testWidgets('store screenshots', (tester) async {
    final nav = await start(tester);
    await shot(tester, '01_home');

    nav.push(MaterialPageRoute<void>(
      builder: (_) => ReadingPage(
        draw: SpreadDraw(spreadId: 'three', methodId: DrawMethods.ritual, cards: const [
          DrawnCard(17),
          DrawnCard(19),
          DrawnCard(21),
        ]),
        question: '接下來的方向',
      ),
    ));
    await shot(tester, '02_reading');

    nav.push(MaterialPageRoute<void>(builder: (_) => const CardDetailPage(cardId: 17)));
    await shot(tester, '03_card');

    nav.push(MaterialPageRoute<void>(builder: (_) => const LearnHubPage()));
    await shot(tester, '04_learn');
  }, skip: !_hasContent);
}
