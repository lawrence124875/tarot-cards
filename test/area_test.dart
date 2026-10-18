import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/content/card_content.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/tarot/draw.dart';

void main() {
  test('面向解讀：依正逆位與問題類型取一句，缺的給空字串', () {
    final c = CardContent.fromJson({
      'id': 16,
      'areas': {
        'upright': {'love': '正位感情', 'work': '正位工作', 'self': '正位自己'},
        'reversed': {'love': '逆位感情'},
      },
    });
    expect(c.area(false, 'work'), '正位工作');
    expect(c.area(true, 'love'), '逆位感情');
    expect(c.area(true, 'self'), '');
    expect(CardContent.fromJson({'id': 0}).area(false, 'love'), '');
  });

  test('日記保存問題類型；不認得的值當作不指定', () {
    final e = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'one', methodId: DrawMethods.quick, cards: [const DrawnCard(5)]),
      now: DateTime(2026, 10, 12),
      area: 'work',
    );
    final back = JournalEntry.tryFromJson(e.toJson())!;
    expect(back.area, 'work');
    expect(JournalEntry.tryFromJson({...e.toJson(), 'area': 'money'})!.area, '');
    expect(back.copyWith(question: 'q').area, 'work');
  });
}
