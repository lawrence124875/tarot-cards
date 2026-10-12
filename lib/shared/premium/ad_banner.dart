import 'package:flutter/material.dart';

import '../../app/services.dart';

/// 頁面底部橫幅（免費版）。訂閱戶、沒有廣告時不佔任何空間。
/// 只放在首頁與卦記列表；**呼吸頁、解讀頁不放**（§21.1，不打擾靜心與閱讀）。
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => AppServices.of(context).ads.banner() ?? const SizedBox.shrink();
}
