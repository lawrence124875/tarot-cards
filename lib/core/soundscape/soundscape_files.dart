import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/audio_playback.dart';
import 'recorded_bed_source.dart';
import 'session_renderer.dart';
import 'sound_bed.dart';

/// 準備練習音檔：在背景 isolate 合成（不卡畫面；有真實錄音的音景先從 assets 讀出錄音），存到暫存資料夾，回傳依序播放的清單（[SessionSpec.parts]）。
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
    Map<SoundBed, Uint8List>? recordings;
    for (final p in parts) {
      final path = pathOf(p);
      if (!done.add(path)) continue;
      final file = File(path);
      if (await file.exists() && await file.length() > 44) continue;
      recordings ??= await _loadRecordings(spec);
      await _renderInBackground(spec, p, path, recordings);
    }
    return [
      for (final p in parts) AudioPart(pathOf(p), Duration(microseconds: (p.seconds * 1e6).round())),
    ];
  }
}

/// 這次用到、而且有真實錄音的音景（assets/audio/*.wav）。讀不到就略過，該音景改用合成。
Future<Map<SoundBed, Uint8List>> _loadRecordings(SessionSpec spec) async {
  final out = <SoundBed, Uint8List>{};
  for (final bed in {spec.upper, spec.lower}) {
    if (!RecordedBedSource.recorded.contains(bed)) continue;
    try {
      final data = await rootBundle.load(RecordedBedSource.assetPath(bed));
      out[bed] = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {}
  }
  return out;
}

// 頂層函式：送進 isolate 的閉包只帶 spec、段落、path 與錄音內容，不夾帶其他物件。
Future<void> _renderInBackground(SessionSpec spec, SessionPart part, String path, Map<SoundBed, Uint8List> recordings) =>
    Isolate.run(() => renderSessionToFile(spec, part, path, recordings: recordings));
