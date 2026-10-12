import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 翻開牌後、看解讀前：「你第一眼注意到什麼？」（直覺在解讀之前）。
/// 回傳寫下的文字；略過回傳 null。寫下的內容會跟著存進日記。
Future<String?> askFirstImpression(BuildContext context) {
  final l = context.l10n;
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.firstImpressionTitle, style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l.firstImpressionBody, style: t.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(hintText: l.firstImpressionHint),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l.firstImpressionSave),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.firstImpressionSkip)),
            ],
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
