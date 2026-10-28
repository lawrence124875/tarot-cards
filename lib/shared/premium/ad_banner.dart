import 'package:flutter/material.dart';

import '../../app/services.dart';

/// 頁面底部橫幅（免費版）。訂閱戶、沒有廣告時不佔任何空間。
/// 只放在首頁、卦記列表、牌陣選擇頁、課程列表（HANDOFF H 第 5 點）；
/// **解讀頁、課程內文、呼吸練習不放**（不打擾閱讀與靜心）。
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => AppServices.of(context).ads.banner() ?? const SizedBox.shrink();
}
