import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 翻開牌後、看解讀前：「你第一眼注意到什麼？」（直覺在解讀之前）。
/// 回傳寫下的文字；略過回傳 null。寫下的內容會跟著存進日記。
Future<String?> askFirstImpression(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FirstImpressionSheet(),
    );

/// 面板自己持有輸入框的 controller：關閉動畫結束、面板移除時才釋放（不會在動畫中被用到已釋放的 controller）。
/// 內容可捲動：手機橫放、畫面很矮時也不會溢出。
class _FirstImpressionSheet extends StatefulWidget {
  const _FirstImpressionSheet();

  @override
  State<_FirstImpressionSheet> createState() => _FirstImpressionSheetState();
}

class _FirstImpressionSheetState extends State<_FirstImpressionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 20 + MediaQuery.of(context).viewInsets.bottom),
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
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(hintText: l.firstImpressionHint),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
              child: Text(l.firstImpressionSave),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.firstImpressionSkip)),
          ],
        ),
      ),
    );
  }
}
