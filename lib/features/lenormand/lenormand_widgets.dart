import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/lenormand/lenormand.dart';
import '../../l10n/l10n.dart';
import '../../reading/section.dart';
import '../../shared/widgets/adaptive_layout.dart';

/// 雷諾曼牌面寬高比（2:3，BnF 公有領域掃描裁切後的比例）。
const double kLenormandAspect = 2 / 3;

/// 雷諾曼牌面：assets/lenormand/deck/NN.webp；沒有圖時畫出牌號與牌名。
class LenormandFace extends StatelessWidget {
  const LenormandFace({super.key, required this.cardId, this.name});

  final int cardId;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final card = LenormandCard.byId(cardId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TarotColors.inkCard,
          border: Border.all(color: TarotColors.mountain, width: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(
          card.artAsset,
          fit: BoxFit.cover,
          semanticLabel: name,
          errorBuilder: (_, __, ___) => _Painted(number: '$cardId', name: name ?? ''),
        ),
      ),
    );
  }
}

/// 雷諾曼牌背。
class LenormandBack extends StatelessWidget {
  const LenormandBack({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          LenormandCard.backAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFF2E2646),
            child: Center(child: Icon(Icons.auto_awesome, color: Color(0xFFBF9648))),
          ),
        ),
      );
}

class _Painted extends StatelessWidget {
  const _Painted({required this.number, required this.name});

  final String number, name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(number, style: t.headlineSmall?.copyWith(color: TarotColors.earth)),
        const SizedBox(height: 4),
        Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
      ]),
    );
  }
}

/// 節奏的介面名稱。
String lenormandSpeedName(AppLocalizations l, LenormandSpeed s) => switch (s) {
      LenormandSpeed.fast => l.lenormandSpeedFast,
      LenormandSpeed.medium => l.lenormandSpeedMedium,
      LenormandSpeed.slow => l.lenormandSpeedSlow,
    };

/// 一張雷諾曼牌的文字段落（解讀頁與單張牌頁共用）。
class LenormandTextView extends StatelessWidget {
  const LenormandTextView({super.key, required this.text});

  final LenormandText text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (text.keywords.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [for (final k in text.keywords) Chip(label: Text(k))]),
      Padding(padding: const EdgeInsets.only(top: 12), child: Text(text.meaning, style: t.bodyLarge)),
      if (text.love.isNotEmpty) Section(title: l.lenormandLove, child: Text(text.love)),
      if (text.work.isNotEmpty) Section(title: l.lenormandWork, child: Text(text.work)),
      if (text.advice.isNotEmpty) Section(title: l.lenormandAdvice, child: Text(text.advice)),
      Section(
        title: l.lenormandTiming,
        child: Text('${lenormandSpeedName(l, text.speed)}${text.playing.isEmpty ? '' : '　·　${text.playing}'}',
            style: t.bodyMedium?.copyWith(color: TarotColors.textSub)),
      ),
    ]);
  }
}

/// 單張雷諾曼牌頁（牌庫、課程中點開）。
class LenormandCardPage extends StatelessWidget {
  const LenormandCardPage({super.key, required this.cardId});

  final int cardId;

  @override
  Widget build(BuildContext context) {
    final s = AppServices.of(context);
    return FutureBuilder<Map<int, LenormandText>>(
      future: s.lenormand.cards(),
      builder: (context, snap) {
        final text = snap.data?[cardId];
        return Scaffold(
          appBar: AppBar(title: Text(text?.name ?? '$cardId')),
          body: ListView(
            padding: readablePadding(context, top: 8, bottom: 40),
            children: [
              Center(
                child: SizedBox(
                  width: 180,
                  child: AspectRatio(aspectRatio: kLenormandAspect, child: LenormandFace(cardId: cardId, name: text?.name)),
                ),
              ),
              const SizedBox(height: 16),
              if (text != null)
                LenormandTextView(text: text)
              else if (snap.connectionState == ConnectionState.done)
                Text(context.l10n.lenormandContentMissing),
            ],
          ),
        );
      },
    );
  }
}

/// 課程中提到的雷諾曼牌小圖。
Widget lenormandLessonTile(BuildContext context, int id) {
  if (!LenormandCard.isValid(id)) return const SizedBox.shrink();
  return InkWell(
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LenormandCardPage(cardId: id))),
    child: SizedBox(
      width: 70,
      child: AspectRatio(aspectRatio: kLenormandAspect, child: LenormandFace(cardId: id)),
    ),
  );
}
