import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import '../audio/audio_playback.dart';
import 'session_renderer.dart';

/// 準備練習音檔：在背景 isolate 合成（不卡畫面），存到暫存資料夾，回傳依序播放的清單（[SessionSpec.parts]）。
/// 已有的段直接沿用（開頭段、循環段換時長也能用）；這次用不到的舊檔刪掉。
/// 檔案大小與時長無關：最多三個檔、約 10 分鐘音訊（單聲道約 26 MB，雙耳節拍立體聲加倍）。
abstract class SoundscapeFiles {
  Future<List<AudioPart>> prepare(SessionSpec spec);
}

class CachedSoundscapeFiles implements SoundscapeFiles {
  static const _prefix = 'breath_';

  @override
  Future<List<AudioPart>> prepare(SessionSpec spec) async {
    final dir = (await getTemporaryDirectory()).path;
    final parts = spec.parts;
    String pathOf(SessionPart p) => '$dir/$_prefix${p.key}.wav';
    final keep = {for (final p in parts) pathOf(p)};

    await for (final e in Directory(dir).list()) {
      final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
      if (e is File && name.startsWith(_prefix) && !keep.contains(e.path)) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
    final done = <String>{};
    for (final p in parts) {
      final path = pathOf(p);
      if (!done.add(path)) continue;
      final file = File(path);
      if (await file.exists() && await file.length() > 44) continue;
      await _renderInBackground(spec, p, path);
    }
    return [
      for (final p in parts) AudioPart(pathOf(p), Duration(microseconds: (p.seconds * 1e6).round())),
    ];
  }
}

// 頂層函式：送進 isolate 的閉包只帶 spec、段落與 path，不夾帶其他物件。
Future<void> _renderInBackground(SessionSpec spec, SessionPart part, String path) =>
    Isolate.run(() => renderSessionToFile(spec, part, path));
