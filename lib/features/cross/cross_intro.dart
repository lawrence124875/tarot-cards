import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// 交叉解讀的 3 頁引導：為什麼用兩套／怎麼讀結果／提醒。首次進入自動顯示，之後從右上「ⓘ」重看。
/// [triple]＝三系統（塔羅 × 雷諾曼 × 盧恩）版：三系統分工／怎麼讀／核心之石。
Future<void> showCrossIntro(BuildContext context, {bool triple = false}) => showDialog<void>(
      context: context,
      builder: (_) => _CrossIntroDialog(triple: triple),
    );

class _CrossIntroDialog extends StatefulWidget {
  const _CrossIntroDialog({this.triple = false});

  final bool triple;

  @override
  State<_CrossIntroDialog> createState() => _CrossIntroDialogState();
}

class _CrossIntroDialogState extends State<_CrossIntroDialog> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final pages = widget.triple
        ? [
            (Icons.layers_outlined, l.tripleIntroTitle1, l.tripleIntroBody1),
            (Icons.join_inner, l.tripleIntroTitle2, l.tripleIntroBody2),
            (Icons.diamond_outlined, l.tripleIntroTitle3, l.tripleIntroBody3),
          ]
        : [
            (Icons.compare_arrows, l.crossIntroTitle1, l.crossIntroBody1),
            (Icons.join_inner, l.crossIntroTitle2, l.crossIntroBody2),
            (Icons.lightbulb_outline, l.crossIntroTitle3, l.crossIntroBody3),
          ];
    final (icon, title, body) = pages[_page];
    final last = _page == pages.length - 1;
    return AlertDialog(
      icon: Icon(icon, color: TarotColors.earth),
      title: Text(title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(body, style: t.bodyMedium),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < pages.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? TarotColors.earth : TarotColors.textSub.withValues(alpha: 0.3),
                ),
              ),
          ]),
        ]),
      ),
      actions: [
        if (_page > 0) TextButton(onPressed: () => setState(() => _page--), child: Text(l.crossIntroBack)),
        FilledButton(
          onPressed: () => last ? Navigator.pop(context) : setState(() => _page++),
          child: Text(last ? l.crossIntroDone : l.crossIntroNext),
        ),
      ],
    );
  }
}
