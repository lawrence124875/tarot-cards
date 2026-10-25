import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import '../features/intro/intro_page.dart';
import 'feature_registry.dart';
import 'home_page.dart';
import 'services.dart';
import 'theme.dart';

class TarotApp extends StatefulWidget {
  const TarotApp({super.key});

  @override
  State<TarotApp> createState() => _TarotAppState();
}

class _TarotAppState extends State<TarotApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _taps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_taps != null) return;
    final services = AppServices.of(context);
    final reminders = services.reminders;
    _taps = reminders.taps.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = reminders.takeLaunchPayload();
      if (p != null) {
        _open(p);
        return;
      }
      // 首次開啟顯示功能介紹（從通知打開時不打斷）
      final intro = services.intro;
      if (intro == null || await intro.seen()) return;
      final nav = _navigatorKey.currentState;
      if (nav != null) await showIntro(nav);
    });
  }

  /// 通知帶來的 payload 交給認得它的功能（例如日記開啟該筆紀錄）。
  void _open(String payload) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    for (final f in registeredFeatures) {
      if (f.openPayload?.call(nav, payload) ?? false) return;
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  /// 深淺色切換：TarotColors 是全域取色，沒有依賴 Theme 的元件不會自己重畫，
  /// 所以換色後把整棵樹標記重建一次（不重建狀態，頁面堆疊與捲動位置都保留）。
  void _applyPalette(TarotPalette p) {
    if (identical(TarotColors.current, p)) return;
    TarotColors.current = p;
    SystemChrome.setSystemUIOverlayStyle(systemBarsFor(p));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      final root = WidgetsBinding.instance.rootElement;
      if (root != null) mark(root);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppServices.of(context).settings;
    return ListenableBuilder(listenable: settings, builder: (context, _) => _app(settings.themeMode));
  }

  Widget _app(String themeMode) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      // 介面語言（HANDOFF §16）：只開放內容已完整翻譯的語言（AppLanguages.enabled），
      // 依手機語言設定選擇；同步給 L10n.language，讓通知等沒有 context 的地方用同一語言。
      supportedLocales: [for (final l in AppLanguages.enabled) l.locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, _) {
        final lang = AppLanguages.resolve(locales ?? const []);
        L10n.language = lang;
        return lang.locale;
      },
      theme: buildTheme(),
      // 字族依介面語言（日文用思源 JP，HANDOFF §15）：Localizations 決定語言後才知道，所以在 builder 換主題。
      builder: (context, child) {
        final fonts = AppFonts.forLanguage(Localizations.localeOf(context).languageCode);
        AppFonts.current = fonts;
        // 外觀：跟隨系統／淺色／深色（設定頁）。
        final dark = switch (themeMode) {
          'dark' => true,
          'light' => false,
          _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        final palette = dark ? TarotPalette.dark : TarotPalette.light;
        _applyPalette(palette);
        // 底部系統導覽列（三鍵列、手勢條）：所有頁面、對話框、底部面板都停在它上方，不畫在它後面。
        // 頁面各自留邊容易漏（2026-10-10 實機：首頁、解讀、音景底部被三鍵列蓋住），所以在這裡統一處理；
        // SafeArea 會把底部高度從下層的 MediaQuery 拿掉，各頁的 SafeArea／readablePadding 不會重複留白。
        // 頂端狀態列維持無邊框（AppBar 自己處理）；鍵盤開啟時底部高度由 viewInsets 處理。
        return Theme(
          data: buildTheme(fonts, palette),
          child: ColoredBox(
            color: palette.ink,
            child: SafeArea(top: false, left: false, right: false, child: child!),
          ),
        );
      },
      home: const HomePage(),
    );
  }
}
