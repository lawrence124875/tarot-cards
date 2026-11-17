import '../settings/json_file.dart';

/// 免費版「第一次完整體驗」（Lawrence 2026-11-16）：塔羅 × 雷諾曼、三系統交叉、流日 × 今日一牌各一次。
/// 記下那一次的牌面種子，同一組牌之後在日記回顧時也維持完整顯示。存在 free_trials.json。
class FreeTrials {
  FreeTrials({KeyValueFile? store}) : _store = store ?? FileKeyValue('free_trials.json');

  static const cross = 'cross';
  static const triple = 'triple';

  /// 流日 × 今日一牌（Lawrence 2026-11-17：比照塔羅 × 雷諾曼）；種子為 numdaySeed（那天那張牌）。
  static const numday = 'numday';

  final KeyValueFile _store;
  Map<String, dynamic> _data = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _data = await _store.read();
    _loaded = true;
  }

  /// 這一種還沒用過免費完整體驗。
  bool available(String kind) => _loaded && !_data.containsKey(kind);

  /// 這組牌（種子）是當初免費完整體驗的那一次。
  bool unlocked(String kind, int seed) => _data[kind] == seed;

  /// 用掉這一種的免費完整體驗，記下牌面種子。
  Future<void> use(String kind, int seed) async {
    if (_data.containsKey(kind)) return;
    _data = {..._data, kind: seed};
    await _store.write(_data);
  }
}
