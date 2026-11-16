import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';

/// LC Lab 其他 App（設定頁最下方）。圖示在 assets/other_apps/（建置時由私人 repo 匯入，不連網抓）；
/// 點擊以外部應用程式開啟 Play 商店頁，不加追蹤參數。
class OtherApp {
  const OtherApp({required this.id, required this.name, required this.desc});

  /// Play 套件名稱（也是圖示檔名）。
  final String id;
  final String Function(AppLocalizations l) name;
  final String Function(AppLocalizations l) desc;

  String get url => 'https://play.google.com/store/apps/details?id=$id';
  String get icon => 'assets/other_apps/$id.png';
}

final otherApps = [
  OtherApp(id: 'com.lclab.qiangua', name: (l) => l.otherAppQianguaName, desc: (l) => l.otherAppQianguaDesc),
  OtherApp(id: 'tw.bcc.englishapp', name: (l) => l.otherAppEnglishName, desc: (l) => l.otherAppEnglishDesc),
];

class OtherAppsSection extends StatelessWidget {
  const OtherAppsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.otherAppsTitle, style: t.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          for (final a in otherApps)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  a.icon,
                  width: 44,
                  height: 44,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44, child: Icon(Icons.apps)),
                ),
              ),
              title: Text(a.name(l)),
              subtitle: Text(a.desc(l)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication),
            ),
        ]),
      ),
    ]);
  }
}
