import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/content/card_content.dart';
import 'package:tarot_cards/core/numerology/numerology.dart';
import 'package:tarot_cards/core/numerology/numerology_quiz.dart';
import 'package:tarot_cards/features/numerology/numerology_course_page.dart';
import 'package:tarot_cards/features/numerology/numerology_quiz_page.dart';

import 'helpers.dart';

/// 生命靈數課程與練習（0.5.0 P4）：計算題、選項、解說、課程試讀規則。
void main() {
  test('計算題：答案＝生命靈數（年月日各自化簡），四個選項不重複且含答案', () {
    final r = Random(1);
    for (var i = 0; i < 300; i++) {
      final q = NumerologyQuiz.lifePathQuestion(NumerologyQuiz.randomDate(r), r);
      expect(q.answer, Numerology.lifePath(q.date!));
      expect(q.options.toSet().length, 4);
      expect(q.options, contains(q.answer));
      for (final o in q.options) {
        expect(Numerology.numbers, contains(o));
      }
    }
  });

  test('計算題的干擾選項：主數 ↔ 個位根', () {
    final r = Random(2);
    final q22 = NumerologyQuiz.lifePathQuestion(DateTime(1980, 4, 9), r); // 9 + 4 + 9 = 22
    expect(q22.answer, 22);
    expect(q22.options, contains(4));
    final q2 = NumerologyQuiz.lifePathQuestion(DateTime(1980, 2, 9), r); // 9 + 2 + 9 = 20 → 2（全部相加會是 11）
    expect(q2.answer, 2);
    expect(q2.options, contains(11));
  });

  test('隨機日期都存在（不會出現 2 月 30 日）', () {
    final r = Random(3);
    for (var i = 0; i < 500; i++) {
      final d = NumerologyQuiz.randomDate(r);
      expect(d.year, inInclusiveRange(1950, 2010));
      expect(DateTime(d.year, d.month, d.day), d);
    }
  });

  test('計算過程文字', () {
    expect(NumerologyQuiz.steps(DateTime(1990, 5, 23)), '1990→1 + 5 + 23→5 = 11');
    expect(NumerologyQuiz.steps(DateTime(1985, 11, 29)), '1985→5 + 11 + 29→11 = 27 → 9');
    expect(NumerologyQuiz.steps(DateTime(1980, 4, 9)), '1980→9 + 4 + 9 = 22');
  });

  test('一輪 10 題，兩種題型交錯；沒有內容檔時只出計算題', () {
    final round = NumerologyQuiz.round(Random(4));
    expect(round.length, 10);
    expect(round.where((q) => q.kind == NumQuizKind.keyword).length, 5);
    expect(round.where((q) => q.kind == NumQuizKind.keyword).map((q) => q.answer).toSet().length, 5);
    final noKw = NumerologyQuiz.round(Random(4), keywords: false);
    expect(noKw.every((q) => q.kind == NumQuizKind.lifePath), isTrue);
  });

  LessonBook book() => LessonBook.fromJson({
        'units': [
          for (final (i, free) in [(1, true), (2, false)])
            {
              'id': 'u$i',
              'title': '單元$i',
              'summary': '摘要$i',
              'free': free,
              'lessons': [
                for (var k = 0; k < 2; k++)
                  {
                    'id': 'l$k',
                    'title': '課$i-$k',
                    'sections': [
                      {'heading': '標題', 'body': '內文'}
                    ],
                    'sources': <String>[],
                    'cards': [11],
                  },
              ],
            },
        ],
      });

  testWidgets('課程頁：練習入口；第 1 單元全免費，其他單元標示第 1 課試讀', (tester) async {
    final s = testServices();
    await tester.pumpWidget(testApp(s, NumerologyCoursePage(book: book())));
    await tester.pumpAndSettle();
    expect(find.text('靈數練習'), findsOneWidget);
    expect(find.text('單元1'), findsOneWidget);
    expect(find.text('單元2'), findsOneWidget);
    expect(find.textContaining('第 1 課可免費試讀'), findsOneWidget);
  });

  testWidgets('練習頁：沒有內容檔時出計算題，答完顯示計算過程', (tester) async {
    final s = testServices();
    await tester.pumpWidget(testApp(s, const NumerologyQuizPage(texts: NumerologyTexts())));
    await tester.pumpAndSettle();
    expect(find.text('這一天出生的人，生命靈數是？'), findsOneWidget);
    expect(find.text('靈數練習 1／10'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(' = '), findsOneWidget);
    await tester.tap(find.text('下一題'));
    await tester.pumpAndSettle();
    expect(find.text('靈數練習 2／10'), findsOneWidget);
  });
}
