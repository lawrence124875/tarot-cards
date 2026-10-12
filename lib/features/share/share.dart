import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/tarot/draw.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/spread_layout.dart';

/// 分享文字附上的下載連結：Android 為 Google Play；iOS 上架後由 CI 傳入 App Store 網址（IOS_STORE_URL），
/// 未設定時仍用 Google Play 連結。
const _playUrl = 'https://play.google.com/store/apps/details?id=com.lclab.tarot';
const _iosUrl = String.fromEnvironment('IOS_STORE_URL');
String get storeUrl => defaultTargetPlatform == TargetPlatform.iOS && _iosUrl.isNotEmpty ? _iosUrl : _playUrl;

/// 分享面板在 iPad 上要知道從哪裡彈出；手機上不影響。
Rect? _origin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

/// 推薦給朋友：分享一段文字＋商店連結。
Future<void> shareApp(BuildContext context) async {
  final l = context.l10n;
  final origin = _origin(context);
  try {
    await SharePlus.instance.share(ShareParams(text: l.shareAppText(storeUrl), sharePositionOrigin: origin));
  } catch (_) {
    if (context.mounted) _failed(context);
  }
}

/// 分享這次抽牌：預覽卡片，按「分享圖片」後輸出 PNG（1080×1920）並附上文字與商店連結。
/// 卡片只放牌面（單張）或牌陣、牌名與關鍵牌這組解讀的標題與畫面，不放使用者寫的問題（隱私）。
Future<void> showShareReading(
  BuildContext context, {
  required SpreadDraw draw,
  String? title,
  String? image,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ShareDialog(draw: draw, title: title, image: image),
    );

void _failed(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.shareFailed)));

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.draw, this.title, this.image});

  final SpreadDraw draw;
  final String? title;
  final String? image;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _card = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final origin = _origin(context);
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      final file = File('${(await getTemporaryDirectory()).path}/tarot_${widget.draw.keyCard.cardId}.png');
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      final name = l.drawnName(widget.draw.keyCard);
      final text = widget.title == null ? l.shareAppText(storeUrl) : l.shareReadingText(name, widget.title!, storeUrl);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        sharePositionOrigin: origin,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.shareFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      content: SizedBox(
        width: 300,
        child: FittedBox(
          child: RepaintBoundary(
            key: _card,
            child: ShareCard(draw: widget.draw, title: widget.title, image: widget.image),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.ios_share, size: 18),
          label: Text(l.shareImage),
        ),
      ],
    );
  }
}

/// 分享用的卡片（固定 360×640 邏輯像素，輸出時 3 倍＝1080×1920）。
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.draw, this.title, this.image});

  final SpreadDraw draw;
  final String? title;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      width: 360,
      height: 640,
      color: TarotColors.ink,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        children: [
          if (draw.cards.length == 1)
            SizedBox(
              width: 200,
              child: AspectRatio(
                aspectRatio: kCardAspect,
                child: CardFace(cardId: draw.cards.first.cardId, reversed: draw.cards.first.reversed),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: SpreadLayout(
                spread: draw.spread,
                cards: draw.cards,
                revealed: {for (var i = 0; i < draw.cards.length; i++) i},
              ),
            ),
          const SizedBox(height: 12),
          Text([for (final c in draw.cards) l.drawnName(c)].join(l.listSeparator),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          const SizedBox(height: 8),
          if (title != null)
            Text(title!,
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall?.copyWith(fontSize: 22)),
          if (image != null) ...[
            const SizedBox(height: 10),
            // 卦象文字：依剩下的高度決定行數，最後一行以「…」收尾（不在半行處被切掉）
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final style = t.bodyMedium?.copyWith(color: TarotColors.textSub);
                final line = (style?.fontSize ?? 14) * (style?.height ?? 1.4) * MediaQuery.textScalerOf(context).scale(1);
                final lines = (box.maxHeight / line).floor().clamp(1, 6);
                return Text(image!,
                    textAlign: TextAlign.center, maxLines: lines, overflow: TextOverflow.ellipsis, style: style);
              }),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 8),
          // 名稱與副標一行，太長時等比縮小（英文等副標較長的語言原本會折成兩行、靠邊）
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${l.appTitle}${l.separator}${l.appSubtitle}',
                maxLines: 1, style: t.bodySmall?.copyWith(color: TarotColors.earth, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }
}
