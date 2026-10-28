import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/update/app_updater.dart';

class _Fake implements AppUpdater {
  _Fake(this.available);

  final bool available;
  int checks = 0;

  @override
  Future<bool> updateAvailable() async {
    checks++;
    return available;
  }

  @override
  Future<void> startUpdate() async {}
}

void main() {
  test('有新版：每次啟動只提示一次', () async {
    final gate = UpdatePromptGate();
    final u = _Fake(true);
    expect(await gate.shouldPrompt(u), isTrue);
    expect(await gate.shouldPrompt(u), isFalse);
    expect(u.checks, 1);
  });

  test('沒有新版、或查不到（NoUpdater）不提示', () async {
    expect(await UpdatePromptGate().shouldPrompt(_Fake(false)), isFalse);
    expect(await UpdatePromptGate().shouldPrompt(const NoUpdater()), isFalse);
  });
}
