import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/runes/rune_glyphs.dart';
import '../../core/runes/runes.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 符文石寬高比（3:4）。
const double kRuneAspect = 3 / 4;

const _stoneLight = TarotColors.stoneLight;
const _stoneDark = TarotColors.stoneDark;
const _carve = TarotColors.stoneCarve;
const _carveShadow = TarotColors.stoneCarveShadow;

/// 符文石正面：石面漸層＋刻痕線條（程式繪製，不佔 App 空間）。逆位時符文旋轉 180°。
class RuneStoneFace extends StatelessWidget {
  const RuneStoneFace({super.key, required this.runeId, this.reversed = false, this.name});

  final int runeId;
  final bool reversed;
  final String? name;

  @override
  Widget build(BuildContext context) => Semantics(
        label: name,
        child: CustomPaint(painter: _StonePainter(key: RuneStone.byId(runeId).key, reversed: reversed)),
      );
}

/// 符文石背面：沒有刻字的石頭。
class RuneStoneBack extends StatelessWidget {
  const RuneStoneBack({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _StonePainter());
}

class _StonePainter extends CustomPainter {
  const _StonePainter({this.key, this.reversed = false});

  final String? key;
  final bool reversed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * 0.32));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [_stoneLight, _stoneDark],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = TarotColors.shadow.withValues(alpha: 0.25),
    );
    final strokes = key == null ? null : runeStrokes[key];
    if (strokes == null) return;
    final box = Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 0.42, height: size.height * 0.58);
    canvas.save();
    if (reversed) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(math.pi);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final w = size.shortestSide * 0.075;
    Path path() {
      final p = Path();
      for (final line in strokes) {
        Offset at(Offset o) => Offset(box.left + o.dx * box.width, box.top + o.dy * box.height);
        p.moveTo(at(line.first).dx, at(line.first).dy);
        for (final o in line.skip(1)) {
          p.lineTo(at(o).dx, at(o).dy);
        }
      }
      return p;
    }

    final p = path();
    Paint line(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(p.shift(Offset(w * 0.18, w * 0.22)), line(_carveShadow.withValues(alpha: 0.6), w));
    canvas.drawPath(p, line(_carve, w));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StonePainter old) => old.key != key || old.reversed != reversed;
}

/// 一顆符文的文字段落（解讀頁與符文頁共用）。[reversed] 時先顯示「向內整理」的讀法。
class RuneTextView extends StatelessWidget {
  const RuneTextView({super.key, required this.text, this.reversed = false});

  final RuneText text;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final showReversed = reversed && text.reversedMeaning.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (text.keywords.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [for (final k in text.keywords) Chip(label: Text(k))]),
      if (text.poem.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('「${text.poem}」',
              style: t.bodyMedium?.copyWith(color: TarotColors.textSub, fontStyle: FontStyle.italic)),
        ),
      if (showReversed) ...[
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.runeReversedLabel, style: t.labelLarge)),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(text.reversedMeaning, style: t.bodyLarge)),
        Section(title: l.runeUprightLabel, child: Text(text.meaning)),
      ] else
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(text.meaning, style: t.bodyLarge)),
      if (text.love.isNotEmpty) Section(title: l.lenormandLove, child: Text(text.love)),
      if (text.work.isNotEmpty) Section(title: l.lenormandWork, child: Text(text.work)),
      if (text.advice.isNotEmpty) Section(title: l.runeCoreReminder, child: Text(text.advice)),
      if (!showReversed && text.reversedMeaning.isNotEmpty)
        Section(title: l.runeReversedLabel, child: Text(text.reversedMeaning, style: t.bodyMedium)),
    ]);
  }
}

/// 單顆符文頁（符文庫、課程、日記中點開）。
class RuneStonePage extends StatelessWidget {
  const RuneStonePage({super.key, required this.runeId, this.reversed = false});

  final int runeId;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final s = AppServices.of(context);
    return FutureBuilder<Map<int, RuneText>>(
      future: s.runes.runes(),
      builder: (context, snap) {
        final text = snap.data?[runeId];
        return Scaffold(
          appBar: AppBar(title: Text(text?.name ?? RuneStone.byId(runeId).key)),
          body: ListView(
            padding: readablePadding(context, top: 8, bottom: 40),
            children: [
              Center(
                child: SizedBox(
                  width: 150,
                  child: AspectRatio(
                    aspectRatio: kRuneAspect,
                    child: RuneStoneFace(runeId: runeId, reversed: reversed, name: text?.name),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (text != null)
                RuneTextView(text: text, reversed: reversed)
              else if (snap.connectionState == ConnectionState.done)
                Text(context.l10n.runeContentMissing),
            ],
          ),
        );
      },
    );
  }
}

/// 課程中提到的符文小圖。
Widget runeLessonTile(BuildContext context, int id) {
  if (!RuneStone.isValid(id)) return const SizedBox.shrink();
  return InkWell(
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RuneStonePage(runeId: id))),
    child: SizedBox(width: 56, child: AspectRatio(aspectRatio: kRuneAspect, child: RuneStoneFace(runeId: id))),
  );
}

/// 「名稱」或「名稱（逆位）」。
String runeDisplayName(AppLocalizations l, Map<int, RuneText> texts, DrawnRune r) {
  final name = texts[r.id]?.name ?? RuneStone.byId(r.id).key;
  return r.reversed ? l.runeNameReversed(name) : name;
}
