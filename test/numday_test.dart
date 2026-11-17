import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/cross/numday_composer.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/monetization/free_trials.dart';
import 'package:tarot_cards/core/numerology/numerology.dart';
import 'package:tarot_cards/core/settings/json_file.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/core/tarot/tarot_card.dart';
import 'package:tarot_cards/features/numerology/numday_section.dart';

import 'helpers.dart';

/// 流日 × 今日一牌（0.5.0 P3）：關係判斷、固定挑句、四段拼接、日記記流日、免費一次完整體驗。
/// 讀資產（模板不存在時的例外）需要真實 I/O：在 runAsync 裡等一下再 settle。
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

void main() {
  test('關係：同頻（化簡相同）、呼應、宮廷牌；愚者 0 一律呼應', () {
    expect(numdayRelation(TarotCard.byId(19), 1), NumdayRelation.sync); // 太陽 19 → 1
    expect(numdayRelation(TarotCard.byId(19), 2), NumdayRelation.echo);
    expect(numdayRelation(TarotCard.byId(0), 9), NumdayRelation.echo);
    expect(numdayRelation(TarotCard.byId(9), 9), NumdayRelation.sync);
    final ace = TarotCard.all.firstWhere((c) => c.rank?.value == 1);
    final ten = TarotCard.all.firstWhere((c) => c.rank?.value == 10);
    expect(numdayRelation(ace, 1), NumdayRelation.sync);
    expect(numdayRelation(ten, 1), NumdayRelation.sync); // 10 → 1
    for (final c in TarotCard.all.where((c) => c.isCourt)) {
      expect(numdayRelation(c, 5), NumdayRelation.court);
    }
    expect(ace.number, 1);
  });

  test('種子：同一天同一張牌固定，換日期或正逆位就不同', () {
    final d = DateTime(2026, 11, 17);
    expect(numdaySeed(const DrawnCard(5), d), numdaySeed(const DrawnCard(5), DateTime(2026, 11, 17, 23, 59)));
    expect(numdaySeed(const DrawnCard(5), d), isNot(numdaySeed(const DrawnCard(5), DateTime(2026, 11, 18))));
    expect(numdaySeed(const DrawnCard(5), d), isNot(numdaySeed(const DrawnCard(5, reversed: true), d)));
  });

  final templates = NumdayTemplates({
    'relationNames': {'sync': '同頻', 'echo': '呼應', 'court': '人物視角'},
    'relationLead': {'sync': 'S', 'echo': 'E', 'court': 'C'},
    'format': {'name': '〈{name}〉', 'header': '流日 {n}', 'affirmation': '肯定語：{text}', 'reflect': '問問自己'},
    'keywordSep': '、',
    'zero': {'keywords': '開放'},
    'day': {
      for (var i = 1; i <= 9; i++) '$i': ['補充$i']
    },
    'card': {
      'upright': ['{card}：{kw}'],
      'reversed': ['{card}逆：{kw}'],
    },
    'meet': {
      'sync': ['{card}同 {n}（{dayKw}）'],
      'echo': ['{card} {cardNum}（{cardKw}）× {n}（{dayKw}）'],
      'court': ['{role}{card} × {n}'],
    },
    'courtRoles': {'page': '侍者。', 'knight': '騎士。', 'queen': '王后。', 'king': '國王。'},
    'practice': {
      for (var i = 1; i <= 9; i++) '$i': ['練習$i']
    },
    'reflection': {
      'sync': ['Q1'],
      'echo': ['Q2'],
      'court': ['Q3'],
    },
    'disclaimer': '免責',
  });
  final numbers = {
    for (final n in Numerology.numbers)
      n: NumberText.fromJson({
        'n': n,
        'keywords': ['k$n', 'm$n'],
        'day': {'theme': '主題$n', 'text': '流日$n'},
      }),
  };

  test('四段拼接：佔位符都填上、宮廷牌帶人物角度', () {
    final r = templates.compose(
      day: 3,
      card: const DrawnCard(0),
      cardName: '愚者',
      numbers: numbers,
      keywords: ['自由'],
      affirmation: '我信任旅程',
      seed: 7,
    );
    expect(r.relation, NumdayRelation.echo);
    expect(r.header, '流日 3');
    expect(r.dayTheme, '主題3');
    expect(r.dayText, ['流日3', '補充3']);
    expect(r.cardText, '〈愚者〉：自由');
    expect(r.affirmation, '肯定語：我信任旅程');
    expect(r.meet, '〈愚者〉 0（開放）× 3（k3、m3）');
    expect(r.practice, '練習3');
    expect(r.reflection, 'Q2');
    expect(r.disclaimer, '免責');

    final queen = TarotCard.all.firstWhere((c) => c.rank?.name == 'queen');
    final q = templates.compose(
        day: 6, card: DrawnCard(queen.id, reversed: true), cardName: 'Q', numbers: numbers, seed: 1);
    expect(q.relation, NumdayRelation.court);
    expect(q.cardText, '〈Q〉逆：');
    expect(q.meet, '王后。〈Q〉 × 6');

    final sun = templates.compose(day: 1, card: const DrawnCard(19), cardName: '太陽', numbers: numbers, seed: 2);
    expect(sun.relation, NumdayRelation.sync);
    expect(sun.meet, '〈太陽〉同 1（k1、m1）');
    expect(sun.meet.contains('{'), isFalse);
  });

  test('日記：今日一牌記流日數字（1–9），舊紀錄或不合法的值當 0', () {
    final e = JournalEntry.fromDraw(
      draw: SpreadDraw(spreadId: 'one', methodId: DrawMethods.daily, cards: [DrawnCard(3)]),
      now: DateTime(2026, 11, 17),
      numday: 4,
    );
    final j = e.toJson();
    expect(j['numday'], 4);
    expect(JournalEntry.tryFromJson(j)!.numday, 4);
    expect(e.copyWith(question: 'x').numday, 4);
    expect(JournalEntry.tryFromJson({...j, 'numday': 11})!.numday, 0);
    final old = Map<String, dynamic>.from(j)..remove('numday');
    expect(JournalEntry.tryFromJson(old)!.numday, 0);
    expect(JournalEntry.fromDraw(draw: e.draw, now: DateTime(2026)).toJson().containsKey('numday'), isFalse);
  });

  test('免費一次完整體驗：記住那天那張牌', () async {
    final t = FreeTrials(store: MemoryKeyValue());
    await t.load();
    final seed = numdaySeed(const DrawnCard(7), DateTime(2026, 11, 17));
    expect(t.available(FreeTrials.numday), isTrue);
    await t.use(FreeTrials.numday, seed);
    expect(t.unlocked(FreeTrials.numday, seed), isTrue);
    expect(t.unlocked(FreeTrials.numday, numdaySeed(const DrawnCard(7), DateTime(2026, 11, 18))), isFalse);
    expect(t.available(FreeTrials.cross), isTrue); // 各自獨立
  });

  testWidgets('沒有生日：今日一牌顯示輸入生日的引導；日記回顧不顯示', (tester) async {
    final s = testServices();
    await tester.pumpWidget(testApp(s, Scaffold(body: ListView(children: [NumdaySection(card: const DrawnCard(1), date: DateTime(2026, 11, 17))]))));
    await settle(tester);
    expect(find.text('輸入生日，看今天的流日怎麼呼應這張牌。'), findsOneWidget);

    await tester.pumpWidget(testApp(
        s, Scaffold(body: ListView(children: [NumdaySection(card: const DrawnCard(1), date: DateTime(2026, 11, 17), live: false)]))));
    await settle(tester);
    expect(find.text('輸入生日，看今天的流日怎麼呼應這張牌。'), findsNothing);
  });

  testWidgets('有生日、免費版：第一次完整，之後別天只顯示標題列＋解鎖按鈕', (tester) async {
    final s = testServices();
    await s.birthdays.save(DateTime(1990, 5, 23));
    Widget page(DateTime d) =>
        testApp(s, Scaffold(body: ListView(children: [NumdaySection(key: ValueKey(d), card: const DrawnCard(1), date: d)])));
    await tester.pumpWidget(page(DateTime(2026, 11, 17)));
    await settle(tester);
    expect(find.text('輸入生日，看今天的流日怎麼呼應這張牌。'), findsNothing, reason: '已有生日');
    expect(find.byType(NumdayResultView), findsOneWidget, reason: '應顯示流日卡');
    expect(find.text('解鎖完整流日 × 今日一牌'), findsNothing, reason: '第一次應完整');
    expect(find.text('這次是免費完整體驗，之後的流日 × 今日一牌完整內容需要訂閱'), findsOneWidget);
    expect(find.text('解鎖完整流日 × 今日一牌'), findsNothing);

    await tester.pumpWidget(page(DateTime(2026, 11, 18)));
    await settle(tester);
    expect(find.text('解鎖完整流日 × 今日一牌'), findsOneWidget);

    // 回到那一天：仍完整
    await tester.pumpWidget(page(DateTime(2026, 11, 17)));
    await settle(tester);
    expect(find.text('解鎖完整流日 × 今日一牌'), findsNothing);
  });
}
