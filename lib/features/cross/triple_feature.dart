import '../../app/app_feature.dart';
import 'triple_page.dart';

/// 塔羅 × 雷諾曼 × 盧恩三系統交叉（訂閱專屬，免費版可抽牌看核心指引標題）。遠端開關 `tr_feature_triple`；
/// 免費預覽開關 `tr_triple_free_preview`（見 triple_page.dart）。盧恩首頁也有入口。
final tripleFeature = AppFeature(
  id: 'triple',
  label: (l) => l.featureTriple,
  placement: FeaturePlacement.secondary,
  builder: (_) => const TriplePage(),
);
