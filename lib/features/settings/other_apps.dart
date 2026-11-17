import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/services.dart';
import '../../core/telemetry/remote_flags.dart';
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
  OtherApp(id: 'com.lclab.qimen', name: (l) => l.otherAppQimenName, desc: (l) => l.otherAppQimenDesc),
];

/// 尚未上架的 App：Remote Config `tr_other_app_<套件名稱以底線取代點>` 設為 1 才顯示（預設不顯示）。
const _hiddenUntilLaunch = {'com.lclab.qimen'};

bool _visible(RemoteFlags flags, OtherApp a) =>
    !_hiddenUntilLaunch.contains(a.id) || flags.intValue('tr_other_app_${a.id.replaceAll('.', '_')}', 0) == 1;

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
          for (final a in otherApps.where((a) => _visible(AppServices.of(context).flags, a)))
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
