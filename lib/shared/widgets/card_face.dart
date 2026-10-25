import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/deck/deck.dart';
import '../../core/tarot/tarot_card.dart';
import '../../l10n/l10n.dart';
import 'card_art_viewer.dart';

/// 牌面寬高比（1909 原版掃描約 0.58）。
const double kCardAspect = 0.58;

/// 一張牌的牌面：目前牌面組的圖（逆位時旋轉 180 度）；沒有圖時畫出牌號、牌名與元素。
/// [zoomable] 為 true 時點一下開啟滿版看圖（可點牌面上的象徵物）。
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.cardId, this.reversed = false, this.zoomable = false, this.deck, this.nameless = false});

  final int cardId;
  final bool reversed;
  final bool zoomable;

  /// 認牌練習用：遮住牌面下緣印的牌名（1909 原版大阿爾克那下方有英文牌名）。
  final bool nameless;

  /// 指定牌面組（例如日記回看時用當時的牌面組）；省略時用目前設定的。
  final Deck? deck;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return ValueListenableBuilder<Deck?>(
      valueListenable: services.deck,
      builder: (context, current, _) {
        final d = deck ?? current;
        final art = _Art(cardId: cardId, deck: d, nameless: nameless);
        final face = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TarotColors.inkCard,
              border: Border.all(color: TarotColors.mountain, width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RotatedBox(quarterTurns: reversed ? 2 : 0, child: art),
          ),
        );
        if (!zoomable) return face;
        final l = context.l10n;
        return Semantics(
          button: true,
          label: l.cardZoomLabel(l.cardName(cardId)),
          child: GestureDetector(
            onTap: () => showCardArt(context, cardId: cardId, reversed: reversed, deck: d),
            child: Stack(fit: StackFit.expand, children: [
              face,
              const PositionedDirectional(
                end: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x88000000), shape: BoxShape.circle),
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.open_in_full, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Art extends StatefulWidget {
  const _Art({required this.cardId, required this.deck, this.nameless = false});

  final int cardId;
  final Deck? deck;
  final bool nameless;

  @override
  State<_Art> createState() => _ArtState();
}

class _ArtState extends State<_Art> {
  Future<ImageProvider?>? _art;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _art ??= AppServices.of(context).decks.cardArt(widget.deck, widget.cardId);
  }

  @override
  void didUpdateWidget(_Art old) {
    super.didUpdateWidget(old);
    if (old.cardId != widget.cardId || old.deck?.id != widget.deck?.id) {
      _art = AppServices.of(context).decks.cardArt(widget.deck, widget.cardId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: _art,
      builder: (context, snap) {
        final img = snap.data;
        if (img == null) {
          return snap.connectionState == ConnectionState.done
              ? PaintedCardFace(cardId: widget.cardId, showName: !widget.nameless)
              : const SizedBox.expand();
        }
        final image = Image(
          image: img,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => PaintedCardFace(cardId: widget.cardId, showName: !widget.nameless),
        );
        if (!widget.nameless) return image;
        return Stack(fit: StackFit.expand, children: [
          image,
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 0.12,
              child: ColoredBox(color: TarotPalette.light.inkCard),
            ),
          ),
        ]);
      },
    );
  }
}

/// 沒有牌面圖時的牌面：上方牌號（大阿爾克那羅馬數字／小阿爾克那元素），中央元素圖示，下方牌名。
class PaintedCardFace extends StatelessWidget {
  const PaintedCardFace({super.key, required this.cardId, this.showName = true});

  final int cardId;
  final bool showName;

  static IconData elementIcon(TarotElement e) => switch (e) {
        TarotElement.fire => Icons.local_fire_department_outlined,
        TarotElement.water => Icons.water_drop_outlined,
        TarotElement.air => Icons.air,
        TarotElement.earth => Icons.spa_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final card = TarotCard.byId(cardId);
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6E3), Color(0xFFF7E1C4)],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: FittedBox(
        child: SizedBox(
          width: 160,
          height: 160 / kCardAspect,
          child: Column(
            children: [
              Text(l.cardCorner(card), style: t.titleMedium?.copyWith(color: TarotPalette.light.earth)),
              const Spacer(),
              Icon(elementIcon(card.element), size: 64, color: TarotPalette.light.earth),
              const Spacer(),
              Text(showName ? l.cardName(cardId) : '?', textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: TarotPalette.light.text)),
            ],
          ),
        ),
      ),
    );
  }
}
