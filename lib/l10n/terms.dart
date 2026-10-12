import '../core/reminders/reminder_service.dart';
import '../core/soundscape/breath_timeline.dart';
import '../core/soundscape/sound_bed.dart';
import '../core/tarot/draw.dart';
import '../core/tarot/tarot_card.dart';
import 'app_localizations.dart';
import 'card_names.dart';

/// 塔羅名稱與 core 層代碼 → 介面文字。core 不放介面文字，只回傳代碼（enum）。
/// 牌名一律依 11 語牌名表（[CardNames]）。
extension TarotTerms on AppLocalizations {
  bool get isChinese => localeName.startsWith('zh');

  /// 介面語言對應的內容代碼（AppLocalizations.localeName：zh、zh_Hans、en、pt_BR…）。
  String get langCode {
    final parts = localeName.split(RegExp('[_-]'));
    final lang = parts.first;
    if (lang == 'zh') return parts.contains('Hans') ? 'zh-Hans' : 'zh-Hant';
    if (lang == 'pt') return 'pt-BR';
    return lang;
  }

  CardNames get _names => CardNames.of(langCode);

  String cardName(int id) => _names.card(id);

  /// 牌名加上正逆位：「愚者（逆位）」。
  String drawnName(DrawnCard c) => c.reversed ? cardReversedName(cardName(c.cardId)) : cardName(c.cardId);

  String suitName(Suit s) => _names.suits[s.index];

  String elementLabel(TarotElement e) => elementName(e.name);

  /// 牌面上方的小字：大阿爾克那「0」「XXI」；小阿爾克那為元素。
  String cardCorner(TarotCard c) => c.isMajor ? roman(c.id) : elementLabel(c.element);

  String soundscape(SoundBed b) => soundscapeName(b.name);

  String phase(BreathPhase p) => breathPhase(p.name);

  String methodName(String methodId) => switch (methodId) {
        DrawMethods.ritual => methodRitual,
        DrawMethods.daily => methodDaily,
        _ => methodQuick,
      };

  /// 提醒失敗的原因（給使用者看）。
  String reminderFailureText(ReminderFailure? f) => switch (f?.kind) {
        null => '',
        ReminderFailureKind.permissionDenied => reminderPermissionDenied,
        ReminderFailureKind.initFailed => reminderInitFailed(f!.detail),
        ReminderFailureKind.scheduleFailed => reminderScheduleFailed(f!.detail),
        ReminderFailureKind.unsupported => reminderUnsupported,
      };

  /// 日記回顧通知（內文不放想問的事）。
  ({String title, String body}) reviewMessage(int cardId, int days) {
    final name = cardName(cardId);
    return (title: reviewNotificationTitle(name), body: reviewNotificationBody(days, name));
  }
}

/// 大阿爾克那牌號的羅馬數字（0 寫作 0，與 1909 年牌面相同）。
String roman(int n) {
  if (n == 0) return '0';
  const v = [10, 9, 5, 4, 1];
  const s = ['X', 'IX', 'V', 'IV', 'I'];
  final b = StringBuffer();
  var x = n;
  for (var i = 0; i < v.length; i++) {
    while (x >= v[i]) {
      b.write(s[i]);
      x -= v[i];
    }
  }
  return b.toString();
}

/// 24 小時制 → 12 小時制（晚上 8 點＝8）。
int hour12(int h) => h % 12 == 0 ? 12 : h % 12;
