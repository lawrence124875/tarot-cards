import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 大螢幕與橫向共用的版面規則。
///
/// Android 16 起，大螢幕裝置（平板、摺疊機展開）會忽略 App 的直向鎖定與「不可調整大小」，
/// 所以 App 不再鎖直向（2026-10-07），各頁自己處理寬螢幕與矮螢幕：
///   - 文字頁（解讀、卦記…）內容最寬 [kReadableWidth]，置中，兩側留白也能捲動；
///   - 起卦、擲錢、呼吸等「一屏」頁面在矮而寬的畫面（手機橫放）改成左右兩欄。

/// 文字頁的最大內容寬度（含左右留白），超過就置中。
const double kReadableWidth = 680;

/// 手機橫放這類「矮而寬」的畫面：上下放不下一欄，改左右兩欄。
/// 平板與摺疊機展開時高度足夠，維持原本的直式一欄。
bool isShortWide(Size size) => size.width > size.height && size.height < 560;

/// ListView／SingleChildScrollView 用的內距：左右加上瀏海、打孔等系統區域（橫放時在側邊），
/// 寬螢幕時把內容置中、最寬 [maxWidth]；底部加上系統導覽列高度（無邊框畫面下內容會延伸到導覽列後面）。
EdgeInsets readablePadding(
  BuildContext context, {
  double horizontal = 24,
  double top = 0,
  double bottom = 0,
  double maxWidth = kReadableWidth,
}) {
  final size = MediaQuery.sizeOf(context);
  final inset = MediaQuery.viewPaddingOf(context);
  final extra = math.max(0.0, (size.width - inset.left - inset.right - maxWidth) / 2);
  return EdgeInsets.fromLTRB(
    horizontal + inset.left + extra,
    top,
    horizontal + inset.right + extra,
    bottom + inset.bottom,
  );
}
