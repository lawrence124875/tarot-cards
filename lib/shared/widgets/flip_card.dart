import 'dart:math';

import 'package:flutter/material.dart';

/// 翻牌：flipped 由 false 變 true 時，從牌背翻到牌面。
class FlipCard extends StatefulWidget {
  const FlipCard({super.key, required this.flipped, required this.back, required this.front});

  final bool flipped;
  final Widget back;
  final Widget front;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.flipped ? 1 : 0,
  );

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped == old.flipped) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = widget.flipped ? 1 : 0;
    } else if (widget.flipped) {
      _c.forward();
    } else {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final angle = Curves.easeInOutCubic.transform(_c.value) * pi;
        final showFront = angle > pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(pi),
                  child: widget.front,
                )
              : widget.back,
        );
      },
    );
  }
}
