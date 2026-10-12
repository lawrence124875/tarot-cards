import 'package:flutter/material.dart';

/// 解讀頁的一個段落：小標題＋內容。
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodyMedium, child: child),
        ],
      ),
    );
  }
}
