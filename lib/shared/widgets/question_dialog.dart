import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 寫下或修改「想問的事」。回傳 null 表示取消；空字串表示清除。
/// [title] 省略時為「想問的事」。
Future<String?> askQuestion(BuildContext context, {String initial = '', String? title}) {
  final l = context.l10n;
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? l.questionTitle),
      content: TextField(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 200,
        decoration: InputDecoration(hintText: l.questionHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(l.ok)),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// 起卦前的「想問的事」入口：未填時是一個小連結，填了就顯示內容（點擊可修改）。
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt({super.key, required this.question, required this.onChanged, this.enabled = true});

  final String question;
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _edit(BuildContext context) async {
    final q = await askQuestion(context, initial: question);
    if (q != null) onChanged(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // 0.1.0+19 使用者回饋：連結原本是按鈕字（16、字重 500、字距 2），比頁面上方提示語還大、字體也不一致。
    // 改成與提示語同一套黑體一般字重，字級小一號（提示語 15.5 → 13.5），顏色同提示語。
    final small = t.bodyMedium?.copyWith(fontSize: 13.5, height: 1.4, letterSpacing: tracking(0.5), color: TarotColors.textSub);
    if (question.isEmpty) {
      if (!enabled) return const SizedBox.shrink();
      return TextButton.icon(
        onPressed: () => _edit(context),
        style: TextButton.styleFrom(textStyle: small, iconColor: TarotColors.textSub),
        icon: const Icon(Icons.edit_note, size: 17),
        label: Text(context.l10n.questionPromptLink),
      );
    }
    return InkWell(
      onTap: enabled ? () => _edit(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Text(context.l10n.questionShown(question),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(color: TarotColors.text)),
      ),
    );
  }
}
