import '../../app/app_feature.dart';
import 'lenormand_hub_page.dart';

/// 雷諾曼：36 張牌、單張／三張抽牌、課程（第 1 課免費試讀）。
/// 遠端開關 `tr_feature_lenormand`；共用一般抽牌額度與訂閱 `premium`。
final lenormandFeature = AppFeature(
  id: 'lenormand',
  label: (l) => l.featureLenormand,
  placement: FeaturePlacement.secondary,
  builder: (_) => const LenormandHubPage(),
);
