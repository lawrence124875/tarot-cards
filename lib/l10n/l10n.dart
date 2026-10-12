import 'package:flutter/widgets.dart';

import 'app_languages.dart';
import 'app_localizations.dart';

export 'app_languages.dart';
export 'app_localizations.dart';
export 'terms.dart';

/// 介面翻譯的入口（HANDOFF §16）。
///
/// - 畫面裡：`context.l10n.xxx`。
/// - 沒有 BuildContext 的地方（通知、鎖定畫面、啟動時的背景服務）：`L10n.current.xxx`。
///   兩者用同一個語言：MaterialApp 決定語言時會同步更新 [L10n.language]。
class L10n {
  L10n._();

  static AppLanguage? _language;

  /// 目前使用的語言；App 尚未決定前，依手機語言設定判斷。
  static AppLanguage get language =>
      _language ??= AppLanguages.resolve(WidgetsBinding.instance.platformDispatcher.locales);

  static set language(AppLanguage value) => _language = value;

  static AppLocalizations get current => lookupAppLocalizations(language.locale);

  /// 內容資料夾：該語言內容未完成時退回繁中（正式版不會發生，見 AppLanguages.enabled）。
  /// 測試版 FORCE_LANG 指定的語言即使未完成也讀自己的資料夾（未寫的卦由內容來源退回繁中），
  /// 方便邊寫邊看（HANDOFF §22）。
  static String get contentFolder =>
      language.contentReady || language == AppLanguages.forced
          ? language.contentFolder
          : AppLanguages.zhHant.contentFolder;
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
