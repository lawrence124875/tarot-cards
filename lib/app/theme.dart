import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 塔羅主題配色（App 精神：光明、豐盛、療愈、快樂）：晨光奶油底、琥珀金主色、日出珊瑚點綴，
/// 牌背用暮光紫。欄位名稱沿用謙卦（ink＝底色、inkCard＝卡片底…），換配色只改這裡。
class TarotColors {
  TarotColors._();

  static const ink = Color(0xFFFBF4E8); // 晨光奶油：主背景
  static const inkCard = Color(0xFFFFFBF4); // 象牙白：卡片底
  static const earth = Color(0xFFBE8128); // 琥珀金：主色
  static const rice = Color(0xFFE0784C); // 日出珊瑚：點綴、強調
  static const mountain = Color(0xFFD9C4A2); // 沙色：線條、輔色
  static const text = Color(0xFF3E2C23); // 暖棕：主文字
  static const textSub = Color(0xFF8A725E); // 淺棕：次文字
  static const paper = Color(0xFFFFFFFF);
  static const twilight = Color(0xFF4A3E73); // 暮光紫：牌背
  static const dawn = Color(0xFFF3C66E); // 晨光金：牌背的光
  static const sage = Color(0xFF7FA58C); // 鼠尾草綠：成長、正向標示
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

/// 系統列（無邊框畫面）：透明、深色圖示（淺色底），導覽列不加系統的半透明遮罩。
/// main() 開機時套用；AppBar 也用同一份，進出各頁不會閃動。
const tarotSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// 字距：寫 `letterSpacing: tracking(2)`，不加字距的文字（泰文）回傳 0。
double tracking(double value) => AppFonts.current.tracking ? value : 0;

ThemeData buildTheme([AppFonts fonts = AppFonts.chinese]) {
  double ls(double value) => fonts.tracking ? value : 0;
  final serif = fonts.serif, serifFallback = fonts.serifFallback;
  final scheme = ColorScheme.fromSeed(
    seedColor: TarotColors.earth,
    brightness: Brightness.light,
  ).copyWith(
    primary: TarotColors.earth,
    onPrimary: Colors.white,
    secondary: TarotColors.rice,
    onSecondary: Colors.white,
    surface: TarotColors.ink,
    onSurface: TarotColors.text,
    surfaceContainerLow: TarotColors.inkCard,
    surfaceContainer: TarotColors.inkCard,
    surfaceContainerHigh: TarotColors.inkCard,
    outline: TarotColors.mountain,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fonts.sans,
    fontFamilyFallback: fonts.sansFallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: TarotColors.ink,
    dividerColor: TarotColors.mountain,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: tarotSystemBars,
      backgroundColor: TarotColors.ink,
      foregroundColor: TarotColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 19, color: TarotColors.text, letterSpacing: ls(2)),
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 40, height: 1.2, letterSpacing: ls(8), color: TarotColors.text),
      headlineSmall: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 24, height: 1.4, letterSpacing: ls(2), color: TarotColors.text),
      titleMedium: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 17, height: 1.5, letterSpacing: ls(1), color: TarotColors.earth, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 17, height: 1.9, color: TarotColors.text),
      bodyMedium: const TextStyle(fontSize: 15.5, height: 1.8, color: TarotColors.text),
      bodySmall: const TextStyle(fontSize: 13, height: 1.6, color: TarotColors.textSub),
      labelLarge: TextStyle(fontSize: 16, letterSpacing: ls(2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TarotColors.earth,
        foregroundColor: Colors.white,
        minimumSize: const Size(200, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TarotColors.earth,
        side: const BorderSide(color: TarotColors.mountain),
        minimumSize: const Size(160, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TarotColors.textSub),
    ),
    cardTheme: CardThemeData(
      color: TarotColors.inkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TarotColors.mountain, width: 0.8),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: TarotColors.inkCard),
    dialogTheme: const DialogThemeData(backgroundColor: TarotColors.inkCard),
    chipTheme: const ChipThemeData(backgroundColor: TarotColors.inkCard, side: BorderSide(color: TarotColors.mountain)),
  );
}
