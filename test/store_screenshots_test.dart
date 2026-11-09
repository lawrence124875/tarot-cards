// 商店截圖（tarot-content store_screenshots.yml 以 --update-goldens 執行）：11 語各 5 張，
// 1080×1920。需要 CI 匯入的內容、牌圖與字型；一般 flutter test 會略過（沒有內容檔）。

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/app.dart';
import 'package:tarot_cards/app/services.dart';
import 'package:tarot_cards/core/content/asset_content_source.dart';
import 'package:tarot_cards/core/deck/deck_source.dart';
import 'package:tarot_cards/core/events/event_bus.dart';
import 'package:tarot_cards/core/lenormand/lenormand.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/features/learn/learn_hub_page.dart';
import 'package:tarot_cards/features/lenormand/lenormand_hub_page.dart';
import 'package:tarot_cards/l10n/l10n.dart';
import 'package:tarot_cards/reading/card_detail_page.dart';
import 'package:tarot_cards/reading/reading_page.dart';

const _codes = ['en', 'zh-Hant', 'zh-Hans', 'ja', 'ko', 'vi', 'id', 'es', 'pt-BR', 'th', 'ar'];

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(f['family'] as String);
    for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (root != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

void main() {
  final dir = Directory('assets/content/en');
  final hasContent = dir.existsSync() && dir.listSync(recursive: true).any((f) => f.path.endsWith('.json'));
  final shotKey = GlobalKey();

  for (final code in _codes) {
    testWidgets('商店截圖 $code', (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 1920)
        ..devicePixelRatio = 2.625
        ..padding = const FakeViewPadding(top: 63, bottom: 63)
        ..viewPadding = const FakeViewPadding(top: 63, bottom: 63);
      addTearDown(tester.view.reset);
      L10n.language = AppLanguages.byCode(code)!;
      tester.platformDispatcher.localesTestValue = [L10n.language.locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.runAsync(_loadFonts);

      final services = Services(
        content: AssetContentSource(folder: () => L10n.contentFolder),
        decks: AssetDeckSource(),
        lenormand: AssetLenormandSource(folder: () => L10n.contentFolder),
        events: EventBus(),
        random: Random(7),
        reminders: NoopReminderService(),
      );
      await tester.runAsync(services.loadDeck);
      await tester.pumpWidget(RepaintBoundary(key: shotKey, child: AppServices(services: services, child: const TarotApp())));

      Future<void> settle() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            for (final e in find.byType(Image).evaluate().toList()) {
              await precacheImage((e.widget as Image).image, e);
            }
          });
          await tester.pump(const Duration(milliseconds: 600));
        }
        await tester.pump(const Duration(seconds: 3));
      }

      Future<void> shot(String name) async {
        await settle();
        // matchesGoldenFile 只輸出邏輯像素（412×732）；這裡用裝置倍率直接輸出 1080×1920
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('test/screenshots/${code}_$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      NavigatorState nav() => tester.state<NavigatorState>(find.byType(Navigator).first);
      Future<void> page(String name, Widget w) async {
        nav().push(MaterialPageRoute<void>(builder: (_) => w));
        await shot(name);
        nav().pop();
        await tester.pump(const Duration(seconds: 1));
      }

      await shot('01_home');
      await page(
        '02_reading',
        ReadingPage(
          draw: SpreadDraw(
            spreadId: 'three',
            methodId: DrawMethods.quick,
            cards: const [DrawnCard(17), DrawnCard(19), DrawnCard(21)],
          ),
          readingIndexes: const [0, 0, 0],
        ),
      );
      await page('03_card', const CardDetailPage(cardId: 17));
      await page('04_learn', const LearnHubPage());
      await page('05_lenormand', const LenormandHubPage());
    }, skip: !hasContent, timeout: const Timeout(Duration(minutes: 5)));
  }
}
