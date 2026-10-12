import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/content/card_content.dart';
import '../../core/deck/deck.dart';

/// 牌面上可點的象徵物：在牌面圖上畫出小圓點，點了顯示名稱與意義。
/// 座標來自牌面組（deck.json），名稱與意義來自解讀內容（依 id 對應）；兩邊都有的才顯示。
/// 逆位時座標跟著牌面旋轉 180 度。
class SymbolOverlay extends StatelessWidget {
  const SymbolOverlay({
    super.key,
    required this.spots,
    required this.content,
    required this.reversed,
    required this.size,
    this.visible = true,
  });

  final List<SymbolSpot> spots;
  final CardContent? content;
  final bool reversed;

  /// 牌面圖實際顯示的大小（點的位置依此換算）。
  final Size size;
  final bool visible;

  List<(SymbolSpot, SymbolContent)> get items => [
        for (final s in spots)
          if (content?.symbol(s.id) != null) (s, content!.symbol(s.id)!),
      ];

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final list = items;
    return Stack(children: [
      for (final (spot, sym) in list)
        Positioned(
          left: (reversed ? 1 - spot.x : spot.x) * size.width - 22,
          top: (reversed ? 1 - spot.y : spot.y) * size.height - 22,
          child: Semantics(
            button: true,
            label: sym.name,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSymbol(context, sym),
              child: const SizedBox(width: 44, height: 44, child: Center(child: _Dot())),
            ),
          ),
        ),
    ]);
  }
}

Future<void> showSymbol(BuildContext context, SymbolContent sym) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sym.name, style: t.headlineSmall),
                const SizedBox(height: 10),
                Text(sym.meaning, style: t.bodyMedium),
              ],
            ),
          ),
        );
      },
    );

/// 一個會輕輕呼吸的光點。
class _Dot extends StatefulWidget {
  const _Dot();

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = still ? 0.5 : _c.value;
        return Container(
          width: 16 + 6 * v,
          height: 16 + 6 * v,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TarotColors.dawn.withValues(alpha: 0.55 + 0.25 * v),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6)],
          ),
        );
      },
    );
  }
}
