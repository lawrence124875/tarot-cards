import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/monetization/free_trials.dart';
import 'package:tarot_cards/core/settings/json_file.dart';

/// 免費版交叉解讀：雙系統、三系統各有一次完整體驗，記住那一組牌。
void main() {
  test('各一次、記住種子、重開後仍記得', () async {
    final store = MemoryKeyValue();
    final t = FreeTrials(store: store);
    expect(t.available(FreeTrials.cross), isFalse); // 還沒載入前不給
    await t.load();
    expect(t.available(FreeTrials.cross), isTrue);
    expect(t.available(FreeTrials.triple), isTrue);
    await t.use(FreeTrials.cross, 42);
    expect(t.available(FreeTrials.cross), isFalse);
    expect(t.unlocked(FreeTrials.cross, 42), isTrue);
    expect(t.unlocked(FreeTrials.cross, 43), isFalse);
    expect(t.available(FreeTrials.triple), isTrue);
    await t.use(FreeTrials.cross, 99); // 不會覆蓋
    expect(t.unlocked(FreeTrials.cross, 42), isTrue);

    final again = FreeTrials(store: store);
    await again.load();
    expect(again.available(FreeTrials.cross), isFalse);
    expect(again.unlocked(FreeTrials.cross, 42), isTrue);
  });
}
