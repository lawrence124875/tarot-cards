import 'card_content.dart';

/// 畫面只透過這個介面取得解讀內容（依賴反轉）。目前實作讀 App 內資產；
/// 日後換成其他來源，畫面不必修改。牌面圖在 DeckSource（牌面組與語言無關）。
abstract class ContentSource {
  /// 該牌的解讀；尚未撰寫時回傳 null。
  Future<CardContent?> card(int id);

  /// 牌陣名稱與位置意義。
  Future<SpreadTexts?> spreads();

  /// 整體氛圍規則的文字。
  Future<AtmosphereTexts?> atmosphere();

  /// 學習課程。
  Future<LessonBook?> lessons();
}
