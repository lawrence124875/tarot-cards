import '../../app/app_feature.dart';
import 'numerology_hub_page.dart';

/// 生命靈數：生命靈數、生日數、今日流日（免費）；流月、流年、高峰數與挑戰數（訂閱 `premium`）；
/// 數字圖鑑、課程（每單元第 1 課免費試讀）。生日只存本機。遠端開關 `tr_feature_numerology`。
final numerologyFeature = AppFeature(
  id: 'numerology',
  label: (l) => l.featureNumerology,
  placement: FeaturePlacement.secondary,
  builder: (_) => const NumerologyHubPage(),
);
