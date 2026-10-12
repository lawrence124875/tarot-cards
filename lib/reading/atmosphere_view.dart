import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/content/card_content.dart';
import '../core/tarot/atmosphere.dart';
import '../core/tarot/draw.dart';
import '../l10n/l10n.dart';
import 'section.dart';

/// 規則產生的觀察 → 一句句文字（文字在內容檔 atmosphere.json，依語言）。
/// 佔位：{card}、{cards}、{count}、{a}、{b}、{position}。
List<String> atmosphereLines({
  required List<Observation> observations,
  required AtmosphereTexts texts,
  required SpreadDraw draw,
  required SpreadText? spreadText,
  required AppLocalizations l,
}) {
  String name(int pos) => l.drawnName(draw.cards[pos]);
  String names(List<int> ps) => ps.map(name).join(l.listSeparator);
  String posName(int pos) {
    final key = draw.spread.positions[pos].key;
    return spreadText?.positions[key]?.name ?? '${pos + 1}';
  }

  final out = <String>[];
  for (final o in observations) {
    final sub = switch (o.code) {
      'elementSingle' || 'elementDominant' || 'elementMissing' => o.element?.name,
      'dignity' => o.dignity?.name,
      'numberRepeat' => '${o.number}',
      'numberStage' => o.stage?.name,
      'numberFlow' => o.trend?.name,
      _ => null,
    };
    var s = texts.text(o.code, sub);
    if (s.isEmpty) continue;
    s = s
        .replaceAll('{count}', '${o.count}')
        .replaceAll('{cards}', names(o.positions))
        .replaceAll('{card}', o.positions.isEmpty ? '' : name(o.positions.first))
        .replaceAll('{a}', o.positions.isNotEmpty ? name(o.positions[0]) : '')
        .replaceAll('{b}', o.positions.length > 1 ? name(o.positions[1]) : '')
        .replaceAll('{position}', o.positions.length > 1 ? posName(o.positions[1]) : '');
    out.add(s);
  }
  return out;
}

/// 解讀頁的「整體氛圍」段落：先一句說明這是常見解讀慣例，再列出各則觀察。
class AtmosphereSection extends StatelessWidget {
  const AtmosphereSection({super.key, required this.lines, required this.texts});

  final List<String> lines;
  final AtmosphereTexts texts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    if (lines.isEmpty) return const SizedBox.shrink();
    return Section(
      title: l.sectionAtmosphere,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (texts.intro.isNotEmpty) Text(texts.intro, style: t.bodySmall),
          for (final s in lines)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.brightness_7_outlined, size: 14, color: TarotColors.rice),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s)),
              ]),
            ),
          if (texts.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(texts.note, style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}
