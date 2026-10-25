import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/admob/admob_ads.dart';

void main() {
  group('廣告單元 ID 空值防呆', () {
    const testId = 'ca-app-pub-3940256099942544/6300978111';
    const real = 'ca-app-pub-1234567890123456/1234567890';

    test('有效 ID 原樣使用（去空白）', () {
      expect(AdMobAds.resolveUnit(' $real\n', testId: testId), real);
    });

    test('空、null、"null"、格式錯 → 測試單元（與謙卦相同，畫面標 Test Ad）', () {
      for (final raw in [null, '', '   ', 'null', 'NULL', 'undefined', 'tr_banner', '123']) {
        expect(AdMobAds.resolveUnit(raw, testId: testId), testId, reason: '$raw');
      }
    });

    test('連測試單元都無效 → null（略過不載入）', () {
      expect(AdMobAds.resolveUnit('', testId: ''), isNull);
    });
  });
}
