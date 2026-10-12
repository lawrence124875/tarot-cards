import '../../app/app_feature.dart';
import 'learn_hub_page.dart';

/// 學習：牌庫（78 張逐張看）、課程（入門單元先開放）、認牌練習（間隔重複）。
final learnFeature = AppFeature(
  id: 'learn',
  label: (l) => l.featureLearn,
  placement: FeaturePlacement.secondary,
  builder: (_) => const LearnHubPage(),
);
