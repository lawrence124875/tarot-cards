import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/journal/journal_store.dart';
import 'package:tarot_cards/core/monetization/free_limits.dart';
import 'package:tarot_cards/core/monetization/premium_service.dart';
import 'package:tarot_cards/core/tarot/draw.dart';
import 'package:tarot_cards/features/journal/journal_list_page.dart';
import 'package:tarot_cards/l10n/l10n.dart';

import 'helpers.dart';

/// 日記列表：近 30 天（免費）、搜尋、篩選、左滑刪除＋確認＋復原、多選全選刪除。
void main() {
  final one = SpreadDraw(spreadId: 'one', methodId: DrawMethods.quick, cards: const [DrawnCard(0)]);
  JournalEntry entry(String q, DateTime at) => JournalEntry.fromDraw(draw: one, now: at, question: q);
  final l = lookupAppLocalizations(AppLanguages.zhHant.locale);

  Future<MemoryJournalStore> seed() async {
    final store = MemoryJournalStore();
    final now = DateTime.now();
    await store.save(entry('換工作嗎', now.subtract(const Duration(hours: 1))));
    await store.save(entry('搬家好嗎', now.subtract(const Duration(days: 3))));
    await store.save(entry('很久以前', now.subtract(const Duration(days: 45))));
    return store;
  }

  test('免費版預設：最多 10 則、只看 30 天；遠端值不合理退回預設', () {
    expect(const FreeLimits().journalMax, 10);
    expect(const FreeLimits().journalDays, 30);
    expect(FreeLimits.remoteDefaults['tr_free_journal_days'], 30);
    expect(FreeLimits.from((k, d) => k == 'tr_free_journal_days' ? 0 : d).journalDays, 30);
    expect(FreeLimits.from((k, d) => k == 'tr_free_journal_days' ? 60 : d).journalDays, 60);
  });

  test('篩選：交叉包含雙系統與三系統', () {
    final now = DateTime(2026, 11, 1);
    final cross = JournalEntry.fromDraw(draw: one, now: now, lenormand: const [1]);
    final triple = JournalEntry.fromDraw(draw: one, now: now, lenormand: const [1], runes: const [2]);
    final len = JournalEntry.fromLenormand(spreadId: 'len_one', cards: const [3], now: now);
    expect(JournalFilter.cross.matches(cross), isTrue);
    expect(JournalFilter.cross.matches(triple), isTrue);
    expect(JournalFilter.cross.matches(len), isFalse);
    expect(JournalFilter.lenormand.matches(len), isTrue);
    expect(JournalFilter.tarot.matches(entry('x', now)), isTrue);
  });

  test('deleteMany 一次刪多筆', () async {
    final store = await seed();
    final ids = [for (final e in await store.all()) e.id];
    await store.deleteMany(ids.take(2));
    expect((await store.all()).length, 1);
  });

  testWidgets('免費版收起 30 天前的紀錄並提示；會員全部顯示；收起的不佔 10 則名額', (tester) async {
    final store = await seed();
    final premium = FreePremium();
    final s = testServices(journal: store, premium: premium);
    await tester.pumpWidget(testApp(s, const JournalListPage()));
    await tester.pumpAndSettle();
    expect(find.text('換工作嗎'), findsOneWidget);
    expect(find.text('很久以前'), findsNothing);
    expect(find.text(l.journalHiddenOld(1, 30)), findsOneWidget);
    expect(await s.journalFull(), isFalse);

    premium.isPremium.value = true;
    await tester.pumpAndSettle();
    expect(find.text('很久以前'), findsOneWidget);
    expect(find.text(l.journalHiddenOld(1, 30)), findsNothing);
  });

  testWidgets('關鍵字搜尋問題與牌名', (tester) async {
    final store = await seed();
    await tester.pumpWidget(testApp(testServices(journal: store), const JournalListPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '搬家');
    await tester.pumpAndSettle();
    expect(find.text('搬家好嗎'), findsOneWidget);
    expect(find.text('換工作嗎'), findsNothing);
    await tester.enterText(find.byType(TextField), l.cardName(0));
    await tester.pumpAndSettle();
    expect(find.text('搬家好嗎'), findsOneWidget);
    expect(find.text('換工作嗎'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(l.journalNoResults), findsOneWidget);
  });

  testWidgets('左滑刪除先確認，刪除後可復原', (tester) async {
    final store = await seed();
    await tester.pumpWidget(testApp(testServices(journal: store), const JournalListPage()));
    await tester.pumpAndSettle();
    await tester.drag(find.text('換工作嗎'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text(l.journalDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(find.text('換工作嗎'), findsOneWidget);
    expect((await store.all()).length, 3);

    await tester.drag(find.text('換工作嗎'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l.delete));
    await tester.pumpAndSettle();
    expect((await store.all()).length, 2);
    expect(find.text('換工作嗎'), findsNothing);
    await tester.tap(find.text(l.undo));
    await tester.pumpAndSettle();
    expect((await store.all()).length, 3);
    expect(find.text('換工作嗎'), findsOneWidget);
  });

  testWidgets('長按多選、全選（只含看得到的），刪除前確認', (tester) async {
    final store = await seed();
    await tester.pumpWidget(testApp(testServices(journal: store), const JournalListPage()));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('換工作嗎'));
    await tester.pumpAndSettle();
    expect(find.text(l.journalSelectedCount(1)), findsOneWidget);
    await tester.tap(find.byTooltip(l.journalSelectAll));
    await tester.pumpAndSettle();
    expect(find.text(l.journalSelectedCount(2)), findsOneWidget);
    await tester.tap(find.byTooltip(l.delete));
    await tester.pumpAndSettle();
    expect(find.text(l.journalDeleteManyTitle(2)), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l.delete));
    await tester.pumpAndSettle();
    final left = await store.all();
    expect(left.map((e) => e.question), ['很久以前']); // 收起的舊紀錄不受影響
  });

  testWidgets('阿拉伯文由右至左也能顯示', (tester) async {
    final store = await seed();
    await tester.pumpWidget(testApp(testServices(journal: store), const JournalListPage(), locale: AppLanguages.ar.locale));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Directionality.of(tester.element(find.byType(TextField))), TextDirection.rtl);
  });
}
