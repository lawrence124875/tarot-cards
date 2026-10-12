import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/journal/journal_backup.dart';
import 'package:tarot_cards/core/journal/journal_entry.dart';
import 'package:tarot_cards/core/journal/journal_reminders.dart';
import 'package:tarot_cards/core/journal/journal_store.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/core/tarot/draw.dart';

class _RecordingReminders extends NoopReminderService {
  final scheduled = <({int id, DateTime at, String title, String body, String payload})>[];
  final cancelled = <int>[];

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled.add((id: id, at: at, title: title, body: body, payload: payload));
    return true;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  final three = SpreadDraw(
    spreadId: 'three',
    methodId: DrawMethods.ritual,
    cards: const [DrawnCard(0), DrawnCard(40, reversed: true), DrawnCard(77)],
  );

  test('日記 JSON 來回轉換不失真，牌與正逆位一致', () {
    final now = DateTime(2026, 10, 2, 21, 5);
    final e = JournalEntry.fromDraw(
      draw: three,
      now: now,
      question: '要不要換工作？',
      firstImpression: '中間那張的杯子倒了',
      readingIndexes: const [2, null, 0],
      deckId: 'rws1909',
      reminderAt: JournalReminders.reviewTime(now, 7),
    ).copyWith(followUps: [FollowUp(at: DateTime(2026, 10, 9), text: '果然要先放下')]);

    final back = JournalEntry.tryFromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>)!;
    expect(back.id, e.id);
    expect(back.createdAt, now);
    expect(back.question, '要不要換工作？');
    expect(back.firstImpression, '中間那張的杯子倒了');
    expect(back.readingIndexes, [2, null, 0]);
    expect(back.readingIndex(1), isNull);
    expect(back.readingIndex(2), 0);
    expect(back.readingIndex(9), isNull);
    expect(back.deckId, 'rws1909');
    expect(back.reminderAt, DateTime(2026, 10, 9, 20));
    expect(back.followUps.single.text, '果然要先放下');
    expect(back.spreadId, 'three');
    expect(back.methodId, DrawMethods.ritual);
    expect(back.cards, three.cards);
    expect(back.keyCard, const DrawnCard(40, reversed: true));
    expect(back.notificationId, e.notificationId);
  });

  test('copyWith 可清除提醒', () {
    final e = JournalEntry.fromDraw(draw: three, now: DateTime(2026, 10, 2), reminderAt: DateTime(2026, 10, 5, 20));
    expect(e.copyWith(clearReminder: true).reminderAt, isNull);
    expect(e.copyWith(question: 'q').reminderAt, e.reminderAt);
  });

  test('不合法的紀錄被略過', () {
    expect(
        JournalEntry.tryFromJson({
          'cards': [
            {'id': 1},
          ],
        }),
        isNull); // 沒有建立時間
    expect(JournalEntry.tryFromJson({'createdAt': '2026-10-02T00:00:00'}), isNull); // 沒有牌
    expect(JournalEntry.tryFromJson({'createdAt': '2026-10-02T00:00:00', 'cards': []}), isNull);
    expect(
        JournalEntry.tryFromJson({
          'createdAt': '2026-10-02T00:00:00',
          'cards': [
            {'id': 1},
            {'id': 99},
            {'id': 2},
          ],
          'spread': 'three',
        }),
        isNull); // 牌不合法
    expect(
        JournalEntry.tryFromJson({
          'createdAt': '2026-10-02T00:00:00',
          'cards': [
            {'id': 1},
            {'id': 2},
          ],
          'spread': 'three',
        }),
        isNull); // 張數與牌陣不符
    // 欄位缺漏給預設值：單張、快速抽牌
    final minimal = JournalEntry.tryFromJson({
      'createdAt': '2026-10-02T00:00:00',
      'cards': [
        {'id': 5},
      ],
    })!;
    expect(minimal.spreadId, 'one');
    expect(minimal.methodId, DrawMethods.quick);
    expect(minimal.question, '');
    expect(minimal.followUps, isEmpty);
  });

  test('回顧時間為 N 天後晚上八點，跨月正確', () {
    expect(JournalReminders.reviewTime(DateTime(2026, 10, 30, 9), 3), DateTime(2026, 11, 2, 20));
  });

  test('payload 對應紀錄 id', () {
    final e = JournalEntry.fromDraw(draw: three, now: DateTime(2026, 10, 2));
    expect(JournalReminders.entryIdFrom(JournalReminders.payloadFor(e)), e.id);
    expect(JournalReminders.entryIdFrom('other:1'), isNull);
    expect(JournalReminders.entryIdFrom('daily'), isNull);
  });

  test('排程回顧提醒：以關鍵牌與天數產生通知，不放想問的事', () async {
    final created = DateTime.now();
    final e = JournalEntry.fromDraw(
      draw: three,
      now: created,
      question: '秘密',
      reminderAt: JournalReminders.reviewTime(created, 3),
    );
    final r = _RecordingReminders();
    final ok = await JournalReminders.apply(r, e, (card, days) => (title: 'card $card', body: '$days days'));
    expect(ok, isTrue);
    expect(r.cancelled, [e.notificationId]);
    final s = r.scheduled.single;
    expect(s.id, e.notificationId);
    expect(s.title, 'card 40');
    expect(s.body, '3 days');
    expect(s.payload, JournalReminders.payloadFor(e));
    expect('${s.title}${s.body}', isNot(contains('秘密')));

    // 沒有提醒或時間已過：只取消
    final past = _RecordingReminders();
    await JournalReminders.apply(past, e.copyWith(reminderAt: DateTime(2000)), (_, __) => (title: '', body: ''));
    expect(past.scheduled, isEmpty);
    expect(past.cancelled, hasLength(1));
  });

  test('記憶體儲存：新到舊、更新、刪除', () async {
    final store = MemoryJournalStore();
    final a = JournalEntry.fromDraw(draw: three, now: DateTime(2026, 10, 1));
    final b = JournalEntry.fromDraw(draw: three, now: DateTime(2026, 10, 2));
    var notified = 0;
    store.addListener(() => notified++);
    await store.save(a);
    await store.save(b);
    expect((await store.all()).map((e) => e.id), [b.id, a.id]);
    await store.save(a.copyWith(question: '新問題'));
    expect((await store.byId(a.id))!.question, '新問題');
    expect((await store.all()).length, 2);
    await store.delete(b.id);
    expect((await store.all()).length, 1);
    expect(await store.byId(b.id), isNull);
    expect(notified, 4);
  });

  group('日記備份', () {
    JournalEntry entry(DateTime at, String q) => JournalEntry.fromDraw(draw: three, now: at, question: q);

    test('匯出再匯入，內容不變；檔名含日期', () {
      final a = entry(DateTime(2026, 10, 1, 9), '甲').copyWith(followUps: [FollowUp(at: DateTime(2026, 10, 5), text: '後來')]);
      final b = entry(DateTime(2026, 10, 2, 9), '乙');
      final text = JournalBackup.encode([a, b], DateTime(2026, 10, 9));
      expect((jsonDecode(text) as Map)['format'], 'tarot-journal');
      final back = JournalBackup.decode(text);
      expect(back.map((e) => e.id), [a.id, b.id]);
      expect(back.first.followUps.single.text, '後來');
      expect(back.last.question, '乙');
      expect(back.last.cards, three.cards);
      expect(JournalBackup.fileName(DateTime(2026, 1, 9)), 'tarot-journal-2026-01-09.json');
    });

    test('也接受 App 內的 journal.json；不是備份檔時丟 FormatException', () {
      final a = entry(DateTime(2026, 10, 1), '');
      expect(
          JournalBackup.decode(jsonEncode({
            'schemaVersion': 1,
            'entries': [a.toJson()],
          })).single.id,
          a.id);
      expect(() => JournalBackup.decode('not json'), throwsFormatException);
      expect(() => JournalBackup.decode('[1,2]'), throwsFormatException);
      expect(() => JournalBackup.decode(jsonEncode({'format': 'other', 'entries': []})), throwsFormatException);
      expect(() => JournalBackup.decode(jsonEncode({'format': 'tarot-journal'})), throwsFormatException);
      // 個別壞掉的紀錄略過，其餘照常還原
      final mixed = jsonEncode({
        'entries': [
          a.toJson(),
          {
            'cards': [1],
          },
          'x',
        ],
      });
      expect(JournalBackup.decode(mixed).single.id, a.id);
    });

    test('還原只加入手機上沒有的，已有的不覆蓋', () async {
      final store = MemoryJournalStore();
      final a = entry(DateTime(2026, 10, 1), '手機上的');
      final b = entry(DateTime(2026, 10, 2), '備份才有');
      await store.save(a);
      final added = await store.addMissing([a.copyWith(question: '備份裡的舊版'), b]);
      expect(added.map((e) => e.id), [b.id]);
      final all = await store.all();
      expect(all.length, 2);
      expect(all.firstWhere((e) => e.id == a.id).question, '手機上的');
      expect(await store.addMissing([a, b]), isEmpty);
    });
  });
}
