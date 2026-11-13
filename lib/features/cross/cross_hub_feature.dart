import '../../app/app_feature.dart';
import 'cross_hub_page.dart';

/// 首頁的「交叉解讀」入口（0.4.0 P1 合併雙系統、三系統兩顆按鈕）。遠端開關 `tr_feature_cross_hub`；
/// 雙、三系統都關掉時首頁不顯示（見 feature_registry.dart）。
final crossHubFeature = AppFeature(
  id: 'cross_hub',
  label: (l) => l.featureCrossHub,
  placement: FeaturePlacement.secondary,
  builder: (_) => const CrossHubPage(),
);
