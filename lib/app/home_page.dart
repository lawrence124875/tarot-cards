import 'package:flutter/material.dart';

import '../features/journal/journal_feature.dart';
import '../features/learn/learn_feature.dart';
import '../l10n/l10n.dart';
import '../shared/widgets/adaptive_layout.dart';
import 'feature_registry.dart';
import 'home_tabs.dart';
import 'services.dart';

/// 首頁外框（0.4.0）：底部導覽「今日／占卜／學習／日記」；手機橫放（矮而寬）改側邊導覽，
/// 不佔掉本來就不高的畫面。學習、日記被遠端開關關掉時，對應的分頁一起拿掉。
///
/// 只建目前分頁（不用 IndexedStack 保留其他分頁）：每個分頁自帶橫幅廣告，
/// 看不見的分頁不載入廣告（§4 H）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _Tab {
  const _Tab(this.icon, this.selectedIcon, this.label, this.build);

  final IconData icon;
  final IconData selectedIcon;
  final LocalizedText label;
  final WidgetBuilder build;
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  List<_Tab> _tabs(BuildContext context) {
    final ids = activeFeatures(AppServices.of(context).flags).map((f) => f.id).toSet();
    return [
      _Tab(Icons.wb_sunny_outlined, Icons.wb_sunny, (l) => l.navToday, (_) => const TodayTab()),
      _Tab(Icons.style_outlined, Icons.style, (l) => l.navDivination, (_) => const DivinationTab()),
      if (ids.contains(learnFeature.id))
        _Tab(Icons.school_outlined, Icons.school, (l) => l.featureLearn, learnFeature.builder!),
      if (ids.contains(journalFeature.id))
        _Tab(Icons.book_outlined, Icons.book, (l) => l.navJournal, journalFeature.builder!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = _tabs(context);
    final index = _index.clamp(0, tabs.length - 1);
    void select(int i) => setState(() => _index = i);
    final body = KeyedSubtree(key: ValueKey(index), child: Builder(builder: tabs[index].build));

    if (isShortWide(MediaQuery.sizeOf(context))) {
      return Scaffold(
        body: Row(children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0,
              destinations: [
                for (final t in tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(t.label(l)),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label(l)),
        ],
      ),
    );
  }
}

/// 隱私權政策（本 repo GitHub Pages，§20）。
const privacyPolicyUrl = 'https://lawrence124875.github.io/tarot-cards/privacy.html';

/// 服務條款（同一個 GitHub Pages，訂閱、試用、退款與免責聲明）。
const termsOfServiceUrl = 'https://lawrence124875.github.io/tarot-cards/terms.html';
