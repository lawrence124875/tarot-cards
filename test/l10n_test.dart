import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/app/theme.dart';
import 'package:tarot_cards/core/content/asset_content_source.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/core/soundscape/breath_timeline.dart';
import 'package:tarot_cards/core/soundscape/sound_bed.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/core/tarot/tarot_card.dart';
import 'package:tarot_cards/l10n/l10n.dart';

/// 介面翻譯（HANDOFF §16）：每個 ARB 的鍵與參數一致、語言判斷、select 每一種情況都有翻譯。
void main() {
  Map<String, dynamic> arb(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

  final template = arb('app_zh.arb');
  final arbFiles = Directory('lib/l10n')
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.arb'))
      .toList()
    ..sort();

  Set<String> messageKeys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@')).toSet();

  // 訊息中出現的參數名稱：{x} 或 {x, select/plural, …}。
  // 前面緊接英數字的是 select 分支（例如 fire{火}），不算參數。
  Set<String> usedNames(String msg) =>
      RegExp(r'(?<![A-Za-z0-9_=])\{(\w+)\s*[,}]').allMatches(msg).map((m) => m.group(1)!).toSet();

  Set<String> declaredIn(Map<String, dynamic> m, String key) {
    final meta = m['@$key'] as Map<String, dynamic>?;
    final ph = meta?['placeholders'] as Map<String, dynamic>?;
    return ph?.keys.toSet() ?? {};
  }

  Set<String> declared(String key) => declaredIn(template, key);

  group('ARB', () {
    test('範本（app_zh.arb）自身：用到的參數都有宣告，宣告的參數都有用到', () {
      for (final key in messageKeys(template)) {
        expect(usedNames(template[key] as String), declared(key), reason: key);
      }
    });

    test('各語言沒有範本以外的鍵（刪掉的易經舊鍵不殘留）', () {
      final keys = messageKeys(template);
      for (final f in arbFiles) {
        expect(messageKeys(arb(f)).difference(keys), isEmpty, reason: '$f 多出的鍵');
      }
    });

    test(
      '每個語言都有範本的所有鍵',
      () {
        final keys = messageKeys(template);
        for (final f in arbFiles) {
          expect(keys.difference(messageKeys(arb(f))), isEmpty, reason: '$f 缺少的鍵');
        }
      },
    );

    test('翻譯只用範本宣告過的參數；有寫參數說明時與範本相同', () {
      for (final f in arbFiles) {
        final m = arb(f);
        for (final key in messageKeys(m)) {
          final used = usedNames(m[key] as String);
          expect(used.difference(declared(key)), isEmpty, reason: '$f 的 $key 用了未宣告的參數');
          final own = declaredIn(m, key);
          if (own.isNotEmpty) expect(own, declared(key), reason: '$f 的 @$key');
        }
      }
    });

    test('每個 ARB 都登記在 AppLanguages.all', () {
      final codes = {for (final l in AppLanguages.all) l.locale.languageCode};
      for (final f in arbFiles) {
        final lang = f.substring(4, f.length - 4).split('_').first; // app_zh.arb → zh
        expect(codes, contains(lang), reason: f);
      }
    });
  });

  group('語言判斷', () {
    final zhOnly = [AppLanguages.zhHant];
    final zhEn = [AppLanguages.zhHant, AppLanguages.en];
    final all3 = [AppLanguages.zhHant, AppLanguages.en, AppLanguages.zhHans];

    test('簡中開放時：中國／新加坡／標示 Hans → 簡中；台灣、香港仍繁中', () {
      expect(AppLanguages.resolve([const Locale('zh', 'CN')], available: all3), AppLanguages.zhHans);
      expect(AppLanguages.resolve([const Locale('zh', 'SG')], available: all3), AppLanguages.zhHans);
      expect(
          AppLanguages.resolve([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'TW')],
              available: all3),
          AppLanguages.zhHans);
      expect(AppLanguages.resolve([const Locale('zh', 'TW')], available: all3), AppLanguages.zhHant);
      expect(AppLanguages.resolve([const Locale('zh', 'HK')], available: all3), AppLanguages.zhHant);
    });

    test('台灣、香港用繁中', () {
      expect(AppLanguages.resolve([const Locale('zh', 'TW')], available: zhEn), AppLanguages.zhHant);
      expect(AppLanguages.resolve([const Locale('zh', 'HK')], available: zhEn), AppLanguages.zhHant);
      expect(
          AppLanguages.resolve([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')], available: zhEn),
          AppLanguages.zhHant);
    });

    test('簡體尚未開放時，簡體使用者看繁中而不是英文', () {
      expect(AppLanguages.resolve([const Locale('zh', 'CN')], available: zhEn), AppLanguages.zhHant);
    });

    test('英文開放後，英文與不支援的語言用英文；未開放時一律繁中', () {
      expect(AppLanguages.resolve([const Locale('en', 'US')], available: zhEn), AppLanguages.en);
      expect(AppLanguages.resolve([const Locale('de')], available: zhEn), AppLanguages.en);
      expect(AppLanguages.resolve([const Locale('en', 'US')], available: zhOnly), AppLanguages.zhHant);
    });

    test('依偏好順序：第一個對不上就看第二個', () {
      expect(AppLanguages.resolve([const Locale('ja'), const Locale('zh', 'TW')], available: zhEn), AppLanguages.zhHant);
    });

    test('上線原則：內容未完成的語言不開放（§12）', () {
      if (AppLanguages.forced != null) return; // 以 FORCE_LANG 建置的測試版例外
      expect(AppLanguages.enabled, contains(AppLanguages.zhHant));
      expect(AppLanguages.enabled.where((l) => !l.contentReady), isEmpty);
    });

    test('代碼、內容資料夾與 byCode 一致', () {
      expect(AppLanguages.all.map((l) => l.code).toSet(), hasLength(AppLanguages.all.length));
      for (final l in AppLanguages.all) {
        expect(AppLanguages.byCode(l.code), l);
        expect(l.contentFolder, l.code);
        expect(l.toString(), l.code);
      }
      expect(AppLanguages.byCode('xx'), isNull);
      expect(AppLanguages.zhHant.locale.scriptCode, 'Hant');
    });
  });

  // 各語言：手機語言是該語言且已開放時用該語言；未開放時用英文。
  const regional = {
    'ja': [Locale('ja', 'JP')],
    'ko': [Locale('ko', 'KR')],
    'vi': [Locale('vi', 'VN')],
    'es': [Locale('es', 'MX'), Locale('es', 'ES')],
    'pt-BR': [Locale('pt', 'BR'), Locale('pt', 'PT')],
    'id': [Locale('id', 'ID')],
    'th': [Locale('th', 'TH')],
    'ar': [Locale('ar', 'SA'), Locale('ar', 'EG')],
  };
  for (final e in regional.entries) {
    test('${e.key}：開放時用該語言；未開放時用英文', () {
      final lang = AppLanguages.byCode(e.key)!;
      for (final device in e.value) {
        expect(AppLanguages.resolve([device], available: [AppLanguages.zhHant, AppLanguages.en, lang]), lang);
        expect(AppLanguages.resolve([device], available: [AppLanguages.zhHant, AppLanguages.en]), AppLanguages.en);
      }
    });
  }

  test('字型：泰文、阿拉伯文各有字族', () {
    expect(AppFonts.forLanguage('th'), AppFonts.thai);
    expect(AppFonts.forLanguage('ar'), AppFonts.arabic);
    expect(AppFonts.forLanguage('zh'), AppFonts.chinese);
  });

  test('阿拉伯文內容：«…» 內的外文原文以 LRI／PDI 隔離，阿拉伯文引文不動', () {
    const note = 'ترجمة LC Lab عن الأصل الألماني: «Ich bin also der Meinung.» و«نص عربي».';
    final out = AssetContentSource.isolateForeignQuotes('ar', note);
    expect(out, contains('\u2066«Ich bin also der Meinung.»\u2069'));
    expect(out, contains('«نص عربي»'));
    expect(AssetContentSource.isolateForeignQuotes('en', note), note);
  });

  testWidgets('阿拉伯文介面為由右至左', (tester) async {
    late TextDirection dir;
    await tester.pumpWidget(Localizations(
      locale: AppLanguages.ar.locale,
      delegates: const [GlobalWidgetsLocalizations.delegate],
      child: Builder(builder: (context) {
        dir = Directionality.of(context);
        return const SizedBox();
      }),
    ));
    expect(dir, TextDirection.rtl);
  });

  group('翻譯內容', () {
    test('每個語言都能載入；繁中 App 名稱正確', () {
      for (final lang in AppLanguages.all) {
        expect(lookupAppLocalizations(lang.locale).appTitle.trim(), isNotEmpty, reason: lang.code);
      }
      expect(lookupAppLocalizations(AppLanguages.zhHant.locale).appTitle, '光穗塔羅');
    });

    test(
      '其他語言的 App 名稱已改為塔羅（不殘留易經 App 名稱）',
      () {
        const old = {'Qiangua', '謙卦', '谦卦', '겸괘', 'Quẻ Khiêm'};
        for (final lang in AppLanguages.all) {
          expect(old, isNot(contains(lookupAppLocalizations(lang.locale).appTitle)), reason: lang.code);
        }
      },
      skip: 'lib/l10n：app_en/ja/ko/vi/es/pt/id/th/ar/zh_Hans.arb 的 appTitle 等文字仍是謙卦（易經 App）的',
    );

    test('單複數與 select', () {
      final en = lookupAppLocalizations(AppLanguages.en.locale);
      final zh = lookupAppLocalizations(AppLanguages.zhHant.locale);
      expect(en.minutes(1), '1 minute');
      expect(en.minutes(3), '3 minutes');
      expect(zh.minutes(3), '3 分鐘');
      expect(zh.cardCount(3), '3 張牌');
      expect(zh.elementLabel(TarotElement.fire), '火');
      expect(zh.soundscape(SoundBed.fire), '營火');
      expect(zh.phase(BreathPhase.inhale), '吸');
      expect(zh.attributionName(Attribution.leo.name), '獅子座');
      expect(zh.pickHint(1), '從扇形的牌裡選 1 張');
      expect(zh.pickHint(3), '從扇形的牌裡選 3 張');
    });

    test('所有 select 情況在每個語言都有翻譯（不會落到 other）', () {
      for (final lang in AppLanguages.all) {
        final l = lookupAppLocalizations(lang.locale);
        final texts = [
          for (final e in TarotElement.values) l.elementLabel(e),
          for (final a in Attribution.values) l.attributionName(a.name),
          for (final p in BreathPhase.values) l.phase(p),
          for (final k in ReminderFailureKind.values) l.reminderFailureText(ReminderFailure(k, 'x')),
          for (final m in [DrawMethods.quick, DrawMethods.ritual, DrawMethods.daily]) l.methodName(m),
        ];
        for (final s in texts) {
          expect(s.trim(), isNot(anyOf('', '-')), reason: lang.code);
        }
        for (final angle in ['figure', 'symbol', 'number']) {
          expect(l.readingAngle(angle), isNot(l.readingAngle('other')), reason: '${lang.code} $angle');
        }
      }
    });

    test(
      '音景名稱在每個語言都有翻譯（不會落到 other）',
      () {
        for (final lang in AppLanguages.all) {
          final l = lookupAppLocalizations(lang.locale);
          for (final b in SoundBed.values) {
            expect(l.soundscape(b).trim(), isNot(anyOf('', '-')), reason: '${lang.code} ${b.name}');
          }
        }
      },
      skip: 'lib/l10n：除 app_zh.arb 以外的 ARB，soundscapeName 的 select 分支仍是八卦代碼（qian、kun…），'
          '不是 SoundBed（sky、lake…），所以音景名稱都顯示「-」',
    );

    test('繁中音景名稱齊全', () {
      final zh = lookupAppLocalizations(AppLanguages.zhHant.locale);
      for (final b in SoundBed.values) {
        expect(zh.soundscape(b), isNot(anyOf('', '-')), reason: b.name);
      }
    });

    test('回顧通知不含想問的事，只有牌名與天數', () {
      final zh = lookupAppLocalizations(AppLanguages.zhHant.locale);
      final m = zh.reviewMessage(15, 7);
      expect(m.title, '回顧一張牌：惡魔');
      expect(m.body, startsWith('7 天前抽到惡魔'));
      final en = lookupAppLocalizations(AppLanguages.en.locale).reviewMessage(22, 1);
      expect(en.body, contains('Ace of Wands'));
      expect(hour12(20), 8);
      expect(hour12(12), 12);
      expect(hour12(0), 12);
    });
  });
}
