import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/services.dart';
import '../../core/content/card_content.dart';
import '../../core/deck/deck.dart';
import '../../l10n/l10n.dart';
import 'symbol_overlay.dart';

/// 開啟滿版牌面圖，讓使用者專心看象；牌面上的象徵物可以點。
/// [overlay] 會疊在畫面下方（例如呼吸練習的小呼吸圓），不攔截點擊。
Future<void> showCardArt(BuildContext context,
    {required int cardId, bool reversed = false, Deck? deck, Widget? overlay}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) =>
        CardArtViewer(cardId: cardId, reversed: reversed, deck: deck, overlay: overlay),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  ));
}

/// 滿版看圖：完整顯示牌面（contain），兩指可縮放；點牌面以外的地方或右上角返回。
/// 牌面上的光點是可點的象徵物（右下角可隱藏）。進入時隱藏系統列，離開時恢復。
class CardArtViewer extends StatefulWidget {
  const CardArtViewer({super.key, required this.cardId, this.reversed = false, this.deck, this.overlay});

  final int cardId;
  final bool reversed;
  final Deck? deck;
  final Widget? overlay;

  @override
  State<CardArtViewer> createState() => _CardArtViewerState();
}

class _CardArtViewerState extends State<CardArtViewer> {
  late final Services _s = AppServices.of(context);
  late final Deck? _deck = widget.deck ?? _s.deck.value;
  late final Future<ImageProvider?> _art = _s.decks.cardArt(_deck, widget.cardId);
  late final Future<CardContent?> _content = _s.content.card(widget.cardId);
  final _zoom = TransformationController();
  bool _symbols = true;
  bool _hint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _hintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _zoom.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final spots = _deck?.annotation(widget.cardId).symbols ?? const [];
    final white = t.bodySmall?.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 6, color: Colors.black)]);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: l.artViewerLabel(l.cardName(widget.cardId)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<List<Object?>>(
                future: Future.wait([_art, _content]),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final img = snap.data![0] as ImageProvider?;
                  final content = snap.data![1] as CardContent?;
                  if (img == null) {
                    return Center(child: Text(l.cardName(widget.cardId), style: t.headlineSmall?.copyWith(color: Colors.white)));
                  }
                  final aspect = _deck?.aspect ?? 0.58;
                  return InteractiveViewer(
                    transformationController: _zoom,
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: LayoutBuilder(
                          builder: (context, box) => GestureDetector(
                            onTap: () {}, // 點牌面本身不返回（方便點象徵物、縮放）
                            child: Stack(children: [
                              Positioned.fill(
                                child: RotatedBox(
                                  quarterTurns: widget.reversed ? 2 : 0,
                                  child: Image(image: img, fit: BoxFit.fill),
                                ),
                              ),
                              Positioned.fill(
                                child: SymbolOverlay(
                                  spots: spots,
                                  content: content,
                                  reversed: widget.reversed,
                                  size: box.biggest,
                                  visible: _symbols,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.overlay != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 88,
                  child: IgnorePointer(child: Center(child: widget.overlay)),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _hint ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Text(spots.isEmpty ? l.tapToReturn : l.tapSymbolsHint,
                        textAlign: TextAlign.center, style: white),
                  ),
                ),
              ),
              if (spots.isNotEmpty)
                PositionedDirectional(
                  end: 8,
                  bottom: 8,
                  child: IconButton(
                    tooltip: _symbols ? l.hideSymbols : l.showSymbols,
                    onPressed: () => setState(() => _symbols = !_symbols),
                    icon: Icon(_symbols ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70),
                  ),
                ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: SafeArea(
                  child: IconButton(
                    tooltip: l.back,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
