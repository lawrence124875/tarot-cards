import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/tarot/draw.dart';
import '../../core/tarot/spread.dart';
import 'card_back.dart';
import 'card_face.dart';
import 'flip_card.dart';

/// 依牌陣的版面擺放牌：未抽到的位置顯示虛線框，已抽未翻的顯示牌背，翻開的顯示牌面。
/// 版面座標以牌寬＝1、牌高＝1.6 為單位（[SpreadPosition]），整個牌陣等比縮放到可用空間。
class SpreadLayout extends StatelessWidget {
  const SpreadLayout({
    super.key,
    required this.spread,
    required this.cards,
    required this.revealed,
    this.onTap,
    this.selected,
    this.maxCardWidth = 220,
  });

  final Spread spread;

  /// 依位置；尚未抽到的為 null。
  final List<DrawnCard?> cards;
  final Set<int> revealed;
  final void Function(int position)? onTap;

  /// 標示目前選中的位置（解讀頁捲到該張時）。
  final int? selected;
  final double maxCardWidth;

  static const _slotH = 1.6;

  @override
  Widget build(BuildContext context) {
    final ps = spread.positions;
    double minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in ps) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x + 1);
      maxY = math.max(maxY, p.y + _slotH);
    }
    final w = maxX - minX, h = maxY - minY;
    return LayoutBuilder(builder: (context, box) {
      final unit = math.min(maxCardWidth, math.min(box.maxWidth / w, box.maxHeight.isFinite ? box.maxHeight / h : double.infinity));
      final cardW = unit * 0.92, cardH = cardW / kCardAspect;
      return Center(
        child: SizedBox(
          width: unit * w,
          height: unit * h,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < ps.length; i++)
              Positioned(
                left: (ps[i].x - minX) * unit + (unit - cardW) / 2,
                top: (ps[i].y - minY) * unit + (unit * _slotH - cardH) / 2,
                width: cardW,
                height: cardH,
                child: Transform.rotate(
                  angle: ps[i].crossed ? math.pi / 2 : 0,
                  child: _Slot(
                    index: i,
                    card: i < cards.length ? cards[i] : null,
                    revealed: revealed.contains(i),
                    selected: selected == i,
                    onTap: onTap == null ? null : () => onTap!(i),
                    small: cardW < 70,
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.card, required this.revealed, required this.selected, this.onTap, required this.small});

  final int index;
  final DrawnCard? card;
  final bool revealed;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = card;
    Widget child;
    if (c == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TarotColors.mountain, width: 1.2),
          color: TarotColors.inkCard.withValues(alpha: 0.6),
        ),
        child: Center(
          child: Text('${index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: TarotColors.textSub)),
        ),
      );
    } else {
      child = FlipCard(
        flipped: revealed,
        back: const CardBack(),
        front: CardFace(cardId: c.cardId, reversed: c.reversed),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            if (selected) BoxShadow(color: TarotColors.rice.withValues(alpha: 0.7), blurRadius: 10, spreadRadius: 1),
            if (!selected && c != null) BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
          child,
          if (c != null && !small)
            PositionedDirectional(
              top: -8,
              start: -8,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: TarotColors.earth,
                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white, height: 1)),
              ),
            ),
        ]),
      ),
    );
  }
}
