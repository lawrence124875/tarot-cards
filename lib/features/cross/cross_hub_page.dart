import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/widgets/adaptive_layout.dart';
import 'cross_page.dart';
import 'triple_page.dart';

/// 交叉解讀入口（0.4.0 P1）：首頁只放一顆「交叉解讀」，進來再選雙系統或三系統。
/// 雙／三系統各自的遠端開關（`tr_feature_cross`、`tr_feature_triple`）照舊；關掉的不列出。
/// 雷諾曼、盧恩頁內原本的直接入口保留。
class CrossHubPage extends StatelessWidget {
  const CrossHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final flags = AppServices.of(context).flags;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: Text(l.featureCrossHub)),
      bottomNavigationBar: const AdBanner(),
      body: ListView(
        padding: readablePadding(context, top: 8, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(l.crossHubIntro, style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
          ),
          if (flags.featureEnabled('cross'))
            _Choice(
              icon: Icons.join_inner,
              title: l.featureCross,
              subtitle: l.crossHubDualDesc,
              onTap: () => push(const CrossPage()),
            ),
          if (flags.featureEnabled('triple'))
            _Choice(
              icon: Icons.change_history,
              title: l.featureTriple,
              subtitle: l.crossHubTripleDesc,
              onTap: () => push(const TriplePage()),
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: TarotColors.dawn.withValues(alpha: 0.3),
            foregroundColor: TarotColors.earth,
            child: Icon(icon),
          ),
          title: Text(title),
          subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Icon(Icons.chevron_right, color: TarotColors.textSub),
          onTap: onTap,
        ),
      );
}
