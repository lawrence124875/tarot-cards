import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// 介面文字：依目前語言取 ARB 字串（例如 `(l) => l.featureDraw`）。
typedef LocalizedText = String Function(AppLocalizations l);

/// 處理通知等外部開啟（payload）；認得就導覽並回傳 true。
typedef PayloadHandler = bool Function(NavigatorState navigator, String payload);

/// primary／secondary：首頁主按鈕／次要連結；none：不在首頁，只從其他地方進入（例如解讀頁）。
enum FeaturePlacement { primary, secondary, none }

/// 解讀頁底部的功能入口（例如「以此卦靜心呼吸」），帶入本卦卦序。
class ReadingAction {
  const ReadingAction({required this.label, required this.icon, required this.open});

  final LocalizedText label;
  final IconData icon;
  final void Function(BuildContext context, int cardId) open;
}

/// 首頁入口。每個功能是 lib/features/ 下的一個資料夾，對外只公開一個 AppFeature。
class AppFeature {
  const AppFeature({
    required this.id,
    required this.label,
    required this.placement,
    this.builder,
    this.openPayload,
    this.readingAction,
  });

  final String id;
  final LocalizedText label;
  final FeaturePlacement placement;
  /// 首頁入口開啟的頁面；placement 為 none 時可不提供。
  final WidgetBuilder? builder;
  final PayloadHandler? openPayload;
  final ReadingAction? readingAction;
}
