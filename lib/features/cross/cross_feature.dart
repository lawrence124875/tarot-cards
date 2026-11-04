import '../../app/app_feature.dart';
import 'cross_page.dart';

/// 塔羅 × 雷諾曼交叉解讀（訂閱專屬，免費版可抽牌看標題）。遠端開關 `tr_feature_cross`；
/// 免費預覽開關 `tr_cross_free_preview`（見 cross_page.dart）。
final crossFeature = AppFeature(
  id: 'cross',
  label: (l) => l.featureCross,
  placement: FeaturePlacement.secondary,
  builder: (_) => const CrossPage(),
);
