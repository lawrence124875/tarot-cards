import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/services.dart';
import '../../core/journal/journal_backup.dart';
import '../../core/journal/journal_entry.dart';
import '../../core/journal/journal_reminders.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';

enum _Action { backup, restore }

/// 日記列表右上角選單：備份（匯出成檔案，由使用者選存放位置）、從備份還原。
/// 換手機或重裝 App 時用；App 本身不上傳任何資料。
class JournalBackupMenu extends StatelessWidget {
  const JournalBackupMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<_Action>(
      icon: const Icon(Icons.more_vert),
      onSelected: (a) => a == _Action.backup ? _backup(context) : _restore(context),
      itemBuilder: (_) => [
        PopupMenuItem(value: _Action.backup, child: Text(l.journalMenuBackup)),
        PopupMenuItem(value: _Action.restore, child: Text(l.journalMenuRestore)),
      ],
    );
  }

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _backup(BuildContext context) async {
    final l = context.l10n;
    final store = AppServices.of(context).journal;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final entries = await store?.all() ?? const [];
    if (!context.mounted) return;
    if (entries.isEmpty) return _snack(context, l.journalBackupEmpty);
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.journalMenuBackup),
        content: Text(l.journalBackupBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.journalBackupContinue)),
        ],
      ),
    );
    if (go != true) return;
    try {
      final now = DateTime.now();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${JournalBackup.fileName(now)}');
      await file.writeAsString(JournalBackup.encode(entries, now));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: l.journalBackupSubject(formatDate(now)),
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (context.mounted) _snack(context, l.shareFailed);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final l = context.l10n;
    final services = AppServices.of(context);
    final store = services.journal;
    if (store == null) return;
    final List<JournalEntry> entries;
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return; // 使用者取消
      entries = JournalBackup.decode(utf8.decode(await file.readAsBytes()));
    } catch (_) {
      if (context.mounted) _snack(context, l.journalRestoreFailed);
      return;
    }
    try {
      final added = await store.addMissing(entries);
      // 還原後補排仍在未來的回顧提醒（失敗不影響還原）。
      for (final e in added) {
        try {
          await JournalReminders.apply(services.reminders, e, l.reviewMessage);
        } catch (_) {}
      }
      if (!context.mounted) return;
      _snack(context, added.isEmpty ? l.journalRestoreNone : l.journalRestoreDone(added.length));
    } catch (_) {
      if (context.mounted) _snack(context, l.journalRestoreFailed);
    }
  }
}
