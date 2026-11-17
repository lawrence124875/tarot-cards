import 'dart:math';

import 'numerology.dart';

/// 靈數練習的題型：看數字選關鍵字、看日期算生命靈數。
enum NumQuizKind { keyword, lifePath }

class NumQuizQuestion {
  const NumQuizQuestion({required this.kind, required this.answer, required this.options, this.date});

  final NumQuizKind kind;

  /// 正確的數字（1–9、11、22、33）。
  final int answer;

  /// 四個選項（數字，含 [answer]，順序已打亂）。
  final List<int> options;

  /// 計算題的出生日期。
  final DateTime? date;
}

/// 靈數練習題庫（不需要內容檔就能出計算題；關鍵字題需要 numbers.json）。
class NumerologyQuiz {
  /// 一輪 [count] 題，兩種題型交錯。[keywords] 為 false（沒有內容檔）時只出計算題。
  static List<NumQuizQuestion> round(Random r, {int count = 10, bool keywords = true}) {
    final kw = [...Numerology.numbers]..shuffle(r);
    return [
      for (var i = 0; i < count; i++)
        keywords && i.isEven ? keywordQuestion(kw[(i ~/ 2) % kw.length], r) : lifePathQuestion(randomDate(r), r),
    ];
  }

  static NumQuizQuestion keywordQuestion(int n, Random r) =>
      NumQuizQuestion(kind: NumQuizKind.keyword, answer: n, options: options(n, r));

  static NumQuizQuestion lifePathQuestion(DateTime d, Random r) {
    final n = Numerology.lifePath(d);
    return NumQuizQuestion(kind: NumQuizKind.lifePath, answer: n, options: options(n, r, confusable: true), date: d);
  }

  /// 四個不重複的選項。[confusable]：計算題優先放最容易混淆的答案
  /// （主數 ↔ 它的個位根，例如 11 ↔ 2），練到「途中要不要停」。
  static List<int> options(int answer, Random r, {bool confusable = false}) {
    final out = <int>{answer};
    if (confusable) {
      final root = Numerology.single(answer);
      if (root != answer) {
        out.add(root);
      } else {
        final master = {2: 11, 4: 22, 6: 33}[answer];
        if (master != null) out.add(master);
      }
    }
    final rest = [...Numerology.numbers]..shuffle(r);
    for (final n in rest) {
      if (out.length >= 4) break;
      out.add(n);
    }
    return out.toList()..shuffle(r);
  }

  /// 1950–2010 年之間的隨機日期（只用到實際存在的日子）。
  static DateTime randomDate(Random r) {
    final y = 1950 + r.nextInt(61), m = 1 + r.nextInt(12);
    final days = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, 1 + r.nextInt(days));
  }

  /// 計算過程（不分語言）：`1990→1 + 5→5 + 23→5 = 11`。
  static String steps(DateTime d) {
    String seg(int v) {
      final p = Numerology.part(v);
      return p == v ? '$v' : '$v→$p';
    }

    final sum = Numerology.part(d.year) + Numerology.part(d.month) + Numerology.part(d.day);
    final lp = Numerology.lifePath(d);
    return '${seg(d.year)} + ${seg(d.month)} + ${seg(d.day)} = $sum${sum == lp ? '' : ' → $lp'}';
  }
}
