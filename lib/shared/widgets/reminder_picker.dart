import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 選擇幾天後提醒回顧：不提醒／3／7／14／30 天／自訂。value 為 null 表示不提醒。
class ReminderPicker extends StatelessWidget {
  const ReminderPicker({super.key, required this.days, required this.onChanged});

  static const presets = [3, 7, 14, 30];

  final int? days;
  final ValueChanged<int?> onChanged;

  Future<void> _custom(BuildContext context) async {
    final l = context.l10n;
    final c = TextEditingController(text: days?.toString() ?? '');
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.reminderPickerTitle),
        content: TextField(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: l.daysSuffix, hintText: l.daysHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          TextButton(
            onPressed: () {
              final n = int.tryParse(c.text.trim());
              if (n != null && n >= 1 && n <= 365) Navigator.pop(context, n);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null) onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final custom = days != null && !presets.contains(days);
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: TarotColors.earth,
          labelStyle: TextStyle(color: selected ? TarotColors.ink : TarotColors.text),
          showCheckmark: false,
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip(l.reminderOff, days == null, () => onChanged(null)),
        for (final d in presets) chip(l.reminderDays(d), days == d, () => onChanged(d)),
        chip(custom ? l.reminderDays(days!) : l.reminderCustom, custom, () => _custom(context)),
      ],
    );
  }
}
