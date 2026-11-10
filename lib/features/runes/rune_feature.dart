import '../../app/app_feature.dart';
import 'rune_hub_page.dart';

/// 盧恩：24 個符文、一顆／三顆抽法、符文庫、課程（每單元第 1 課免費試讀）。
/// 遠端開關 `tr_feature_runes`；共用一般抽牌額度與訂閱 `premium`。
final runeFeature = AppFeature(
  id: 'runes',
  label: (l) => l.featureRunes,
  placement: FeaturePlacement.secondary,
  builder: (_) => const RuneHubPage(),
);
