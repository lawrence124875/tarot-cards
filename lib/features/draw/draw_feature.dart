import '../../app/app_feature.dart';
import 'spread_picker_page.dart';

/// 抽牌：選牌陣 → 寫下問題 → 快速抽牌或親手洗牌、切牌、挑牌 → 一張張翻開 → 第一眼印象 → 解讀。
final drawFeature = AppFeature(
  id: 'draw',
  label: (l) => l.featureDraw,
  placement: FeaturePlacement.primary,
  builder: (_) => const SpreadPickerPage(),
);
