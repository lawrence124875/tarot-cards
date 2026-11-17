import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/numerology/numerology.dart';
import 'package:tarot_cards/core/settings/json_file.dart';

void main() {
  test('化簡：主數保留、流日用的個位數不保留、0 維持 0', () {
    expect(Numerology.reduce(29), 11);
    expect(Numerology.reduce(39), 3);
    expect(Numerology.reduce(22), 22);
    expect(Numerology.reduce(33), 33);
    expect(Numerology.reduce(48), 3);
    expect(Numerology.single(29), 2);
    expect(Numerology.single(33), 6);
    expect(Numerology.reduce(0), 0);
    // 年月日各段只保留 11、22
    expect(Numerology.part(1990), 1);
    expect(Numerology.part(1993), 22);
    expect(Numerology.part(2009), 11);
    expect(Numerology.part(12), 3);
  });

  test('生命靈數：年、月、日各自化簡再相加', () {
    expect(Numerology.lifePath(DateTime(1990, 5, 23)), 11); // 1 + 5 + 5
    expect(Numerology.lifePath(DateTime(1985, 11, 29)), 9); // 5 + 11 + 11 = 27
    expect(Numerology.lifePath(DateTime(1975, 2, 9)), 33); // 22 + 2 + 9
    expect(Numerology.lifePath(DateTime(2000, 1, 1)), 4);
    // 與「全部數字直接相加」不同的例子：1993/11/2 → 22 + 11 + 2 = 35 → 8（直接相加 26 → 8 相同個位，但途中主數不同）
    expect(Numerology.lifePath(DateTime(1993, 11, 2)), 8);
  });

  test('生日數：出生日化簡，11、22 保留', () {
    expect(Numerology.birthday(DateTime(1990, 5, 29)), 11);
    expect(Numerology.birthday(DateTime(1990, 5, 22)), 22);
    expect(Numerology.birthday(DateTime(1990, 5, 23)), 5);
    expect(Numerology.birthday(DateTime(1990, 5, 10)), 1);
  });

  test('流年（元旦切換）、流月、流日（1–9）', () {
    final b = DateTime(1990, 5, 23);
    expect(Numerology.personalYear(b, DateTime(2026, 11, 17)), 11); // 5 + 5 + 1
    expect(Numerology.personalYear(b, DateTime(2026, 1, 1)), 11);
    expect(Numerology.personalYear(b, DateTime(2025, 12, 31)), 1); // 5 + 5 + 9 = 19 → 1
    expect(Numerology.personalMonth(b, DateTime(2026, 11, 17)), 22); // 11 + 11
    expect(Numerology.personalDay(b, DateTime(2026, 11, 17)), 3); // 22 + 17 = 39 → 3
    for (var d = 1; d <= 31; d++) {
      final n = Numerology.personalDay(b, DateTime(2026, 1, d));
      expect(n >= 1 && n <= 9, isTrue, reason: '$d');
    }
  });

  test('高峰數與挑戰數：四期、年齡由 36 − 生命靈數個位起算', () {
    final b = DateTime(1990, 5, 23); // 月 5、日 5、年 1；生命靈數 11 → 個位 2
    final p = Numerology.pinnacles(b);
    expect([for (final x in p) x.number], [1, 6, 7, 6]);
    expect([for (final x in p) x.fromAge], [0, 35, 44, 53]);
    expect([for (final x in p) x.toAge], [34, 43, 52, null]);
    final c = Numerology.challenges(b);
    expect([for (final x in c) x.number], [0, 4, 4, 4]);
    expect(Numerology.age(b, DateTime(2026, 5, 22)), 35);
    expect(Numerology.age(b, DateTime(2026, 5, 23)), 36);
    expect(Numerology.currentPeriod(p, 34), 0);
    expect(Numerology.currentPeriod(p, 35), 1);
    expect(Numerology.currentPeriod(p, 80), 3);
  });

  test('生日只存本機，可清除', () async {
    final kv = MemoryKeyValue();
    final s = BirthdayStore(store: kv);
    expect(await s.load(), isNull);
    await s.save(DateTime(1990, 5, 23, 14, 30));
    expect(kv.data['birth'], '1990-05-23');
    expect(await BirthdayStore(store: kv).load(), DateTime(1990, 5, 23));
    await s.clear();
    expect(s.birthday.value, isNull);
    expect(await BirthdayStore(store: kv).load(), isNull);
  });
}
