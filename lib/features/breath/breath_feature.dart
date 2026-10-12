import 'package:flutter/material.dart';

import '../../app/app_feature.dart';
import 'breath_setup_sheet.dart';

/// 以此牌靜心呼吸：依牌的元素（火、水、風、土；大阿爾克那依黃金黎明對應）程式合成自然音景，
/// 引導吸 4 吐 6 的呼吸（沿用謙卦音景引擎）。牌陣用關鍵位置那張牌的元素。
/// 只從解讀頁進入（解讀頁顯示所有功能的 readingAction）；拔除＝移出註冊表一行。
final breathFeature = AppFeature(
  id: 'breath',
  label: (l) => l.featureBreath,
  placement: FeaturePlacement.none,
  readingAction: ReadingAction(
    label: (l) => l.readingActionBreath,
    icon: Icons.air,
    open: (context, cardId) => showBreathSetup(context, cardId),
  ),
);
