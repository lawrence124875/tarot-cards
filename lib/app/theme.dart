import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 塔羅主題配色（App 精神：光明、豐盛、療愈、快樂）：晨光奶油底、琥珀金主色、日出珊瑚點綴，
/// 牌背用暮光紫。欄位名稱沿用謙卦（ink＝底色、inkCard＝卡片底…），換配色只改這裡。
/// 深色模式（2026-10-19）：同一組欄位換成夜空配色；[current] 由 app.dart 依設定與系統切換，
/// 所以各頁取色時不能放在 const 裡。
class TarotPalette {
  const TarotPalette({
    required this.brightness,
    required this.ink,
    required this.inkCard,
    required this.earth,
    required this.rice,
    required this.mountain,
    required this.text,
    required this.textSub,
    required this.paper,
    required this.twilight,
    required this.dawn,
    required this.sage,
  });

  final Brightness brightness;
  final Color ink, inkCard, earth, rice, mountain, text, textSub, paper, twilight, dawn, sage;

  bool get isDark => brightness == Brightness.dark;

  static const light = TarotPalette(
    brightness: Brightness.light,
    ink: Color(0xFFFBF4E8), // 晨光奶油：主背景
    inkCard: Color(0xFFFFFBF4), // 象牙白：卡片底
    earth: Color(0xFFBE8128), // 琥珀金：主色
    rice: Color(0xFFE0784C), // 日出珊瑚：點綴、強調
    mountain: Color(0xFFD9C4A2), // 沙色：線條、輔色
    text: Color(0xFF3E2C23), // 暖棕：主文字
    textSub: Color(0xFF8A725E), // 淺棕：次文字
    paper: Color(0xFFFFFFFF),
    twilight: Color(0xFF4A3E73), // 暮光紫：牌背
    dawn: Color(0xFFF3C66E), // 晨光金：牌背的光
    sage: Color(0xFF7FA58C), // 鼠尾草綠：成長、正向標示
  );

  /// 夜空：深藍紫底（接近桌面圖示的深藍）、金色更亮一點，文字用暖象牙色。
  static const dark = TarotPalette(
    brightness: Brightness.dark,
    ink: Color(0xFF15182A),
    inkCard: Color(0xFF1F2338),
    earth: Color(0xFFE2AE5C),
    rice: Color(0xFFF0936A),
    mountain: Color(0xFF3D4260),
    text: Color(0xFFF2E8D8),
    textSub: Color(0xFFB5A895),
    paper: Color(0xFF262A40),
    twilight: Color(0xFFB0A4E6),
    dawn: Color(0xFFF3C66E),
    sage: Color(0xFF8FB89C),
  );
}

class TarotColors {
  TarotColors._();

  static TarotPalette current = TarotPalette.light;

  static Color get ink => current.ink;
  static Color get inkCard => current.inkCard;
  static Color get earth => current.earth;
  static Color get rice => current.rice;
  static Color get mountain => current.mountain;
  static Color get text => current.text;
  static Color get textSub => current.textSub;
  static Color get paper => current.paper;
  static Color get twilight => current.twilight;
  static Color get dawn => current.dawn;
  static Color get sage => current.sage;
}

/// 字體：牌名、標題、引文用宋體；白話解讀與介面用黑體（沿用謙卦）。
/// 0.1.0+17 起打包思源宋體／黑體子集（HANDOFF §15）；子集外的罕用字由系統字體補上。
///
/// 依介面語言選字族（[AppFonts.current]，MaterialApp 的 builder 依語言設定）：
/// - 中文、英文…：思源 TC 為主，簡體字由 SC 子集補（只含 TC 缺的字，2026-10-05）。
/// - 日文（2026-10-05）：思源 JP 為主（日本字形），JP 子集沒有的字再由 TC、SC 補。
/// - 韓文（2026-10-05）：思源 KR 為主（韓文音節與韓式漢字字形），其餘同日文。
/// 每個指定 [kSerif]／[kSans] 的地方都要帶對應的 fallback，否則 copyWith 會沿用黑體的 fallback。
/// 經文的漢字原文（非中文語言時顯示在譯文上方）一律用 [AppFonts.chinese]：那是中文經文，用中文字形。
class AppFonts {
  const AppFonts._(this.serif, this.sans, this.serifFallback, this.sansFallback, {this.tracking = true});

  final String serif;
  final String sans;
  final List<String> serifFallback;
  final List<String> sansFallback;

  /// 是否加字距（[tracking]）。泰文字母間加距會把上方的母音、聲調符號拆離字母（例「อี้จิง」），
  /// 擲錢頁、首頁副標都會出現，所以泰文一律不加（2026-10-07 商店截圖發現）。
  final bool tracking;

  static const chinese = AppFonts._('NotoSerifTC', 'NotoSansTC', ['NotoSerifSC'], ['NotoSansSC']);
  static const japanese =
      AppFonts._('NotoSerifJP', 'NotoSansJP', ['NotoSerifTC', 'NotoSerifSC'], ['NotoSansTC', 'NotoSansSC']);
  static const korean =
      AppFonts._('NotoSerifKR', 'NotoSansKR', ['NotoSerifTC', 'NotoSerifSC'], ['NotoSansTC', 'NotoSansSC']);
  static const thai =
      AppFonts._('NotoSerifThai', 'NotoSansThai', ['NotoSerifTC', 'NotoSerifSC'], ['NotoSansTC', 'NotoSansSC'],
          tracking: false);
  /// 阿拉伯文（2026-10-07）：內文 Noto Naskh Arabic（書本常用的 Naskh 體）、介面 Noto Sans Arabic；
  /// 拼音與外文原名的拉丁字母由 TC 補。版面方向（RTL）由 MaterialApp 依 ar locale 自動決定。
  /// 不加字距：阿拉伯字母是連寫體，字距會把字母之間的連筆拆開。
  static const arabic = AppFonts._(
      'NotoNaskhArabic', 'NotoSansArabic', ['NotoSerifTC', 'NotoSerifSC'], ['NotoSansTC', 'NotoSansSC'],
      tracking: false);

  /// 語言代碼（Locale.languageCode）→ 字族組合。
  static AppFonts forLanguage(String languageCode) => switch (languageCode) {
        'ja' => japanese,
        'ko' => korean,
        'th' => thai,
        'ar' => arabic,
        _ => chinese,
      };

  /// 目前介面語言的字族（app.dart 的 builder 設定；沒有 context 的地方也能用）。
  static AppFonts current = chinese;
}

String get kSerif => AppFonts.current.serif;
String get kSans => AppFonts.current.sans;
List<String> get kSerifFallback => AppFonts.current.serifFallback;
List<String> get kSansFallback => AppFonts.current.sansFallback;

/// 系統列（無邊框畫面）：透明、圖示深淺跟著主題，導覽列不加系統的半透明遮罩。
/// main() 開機時與切換深淺色時套用；AppBar 也用同一份，進出各頁不會閃動。
SystemUiOverlayStyle systemBarsFor(TarotPalette p) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: p.brightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );

SystemUiOverlayStyle get tarotSystemBars => systemBarsFor(TarotColors.current);

/// 字距：寫 `letterSpacing: tracking(2)`，不加字距的文字（泰文）回傳 0。
double tracking(double value) => AppFonts.current.tracking ? value : 0;

ThemeData buildTheme([AppFonts fonts = AppFonts.chinese, TarotPalette palette = TarotPalette.light]) {
  final c = palette;
  double ls(double value) => fonts.tracking ? value : 0;
  final serif = fonts.serif, serifFallback = fonts.serifFallback;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.earth,
    brightness: c.brightness,
  ).copyWith(
    primary: c.earth,
    onPrimary: c.isDark ? c.ink : Colors.white,
    secondary: c.rice,
    onSecondary: c.isDark ? c.ink : Colors.white,
    surface: c.ink,
    onSurface: c.text,
    surfaceContainerLow: c.inkCard,
    surfaceContainer: c.inkCard,
    surfaceContainerHigh: c.inkCard,
    outline: c.mountain,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fonts.sans,
    fontFamilyFallback: fonts.sansFallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.ink,
    dividerColor: c.mountain,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: systemBarsFor(c),
      backgroundColor: c.ink,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 19, color: c.text, letterSpacing: ls(2)),
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 40, height: 1.2, letterSpacing: ls(8), color: c.text),
      headlineSmall: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 24, height: 1.4, letterSpacing: ls(2), color: c.text),
      titleMedium: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 17, height: 1.5, letterSpacing: ls(1), color: c.earth, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 17, height: 1.9, color: c.text),
      bodyMedium: TextStyle(fontSize: 15.5, height: 1.8, color: c.text),
      bodySmall: TextStyle(fontSize: 13, height: 1.6, color: c.textSub),
      labelLarge: TextStyle(fontSize: 16, letterSpacing: ls(2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.earth,
        foregroundColor: c.isDark ? c.ink : Colors.white,
        minimumSize: const Size(200, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.earth,
        side: BorderSide(color: c.mountain),
        minimumSize: const Size(160, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.textSub),
    ),
    cardTheme: CardThemeData(
      color: c.inkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.mountain, width: 0.8),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.inkCard),
    dialogTheme: DialogThemeData(backgroundColor: c.inkCard),
    chipTheme: ChipThemeData(backgroundColor: c.inkCard, side: BorderSide(color: c.mountain)),
  );
}
