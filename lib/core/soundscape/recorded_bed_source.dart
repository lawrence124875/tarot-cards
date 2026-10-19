import 'dart:typed_data';

import 'bed_source.dart';
import 'dsp.dart';
import 'ima_adpcm.dart';
import 'sound_bed.dart';
import 'synth_bed_source.dart';

/// 真實自然錄音的音景（CC0／公有領域，作者與授權見 assets/audio/CREDITS.md）。
/// 有錄音的音景用錄音，其他（營火、蟲鳴、風聲、高空清風）沿用程式合成（[SynthBedSource]）。
///
/// 錄音檔已剪成無縫循環，長度都能整除 [SessionRenderer.loopSeconds]（200 秒），所以不論當上層（40 秒）
/// 或下層（50 秒）用，整段練習的聲音仍以 200 秒為週期，分段播放一樣無縫。回傳長度是錄音本身的長度，
/// 不是 [seconds]（混音時以 `i % length` 循環取樣）。
class RecordedBedSource extends BedSource {
  /// [files]：音景 → assets/audio/<名稱>.wav 的內容（IMA ADPCM，見 [decodeImaAdpcmWav]）。
  const RecordedBedSource(this.files, {this.fallback = const SynthBedSource()});

  final Map<SoundBed, Uint8List> files;
  final BedSource fallback;

  /// 有錄音的音景。
  static const recorded = {SoundBed.water, SoundBed.thunder, SoundBed.lake, SoundBed.mountain};

  static String assetPath(SoundBed bed) => 'assets/audio/${bed.name}.wav';

  /// 錄音的均方根，對齊合成版各音景的音量（山林刻意比較安靜）。
  static const levels = {
    SoundBed.water: 0.075,
    SoundBed.thunder: 0.065,
    SoundBed.lake: 0.07,
    SoundBed.mountain: 0.04,
  };

  @override
  Float32List bed(SoundBed trigram, {required int sampleRate, required double seconds}) {
    final file = files[trigram];
    if (file == null) return fallback.bed(trigram, sampleRate: sampleRate, seconds: seconds);
    final decoded = decodeImaAdpcmWav(file);
    final x = decoded.sampleRate == sampleRate ? decoded.samples : resampleLoop(decoded.samples, decoded.sampleRate, sampleRate);
    return normalizeRms(x, levels[trigram] ?? 0.06);
  }

  /// 把一段循環線性內插成另一個取樣率，尾端接回開頭內插，仍然無縫。
  static Float32List resampleLoop(Float32List x, int from, int to) {
    final n = (x.length * to / from).round();
    final out = Float32List(n);
    final ratio = x.length / n;
    for (var i = 0; i < n; i++) {
      final p = i * ratio;
      final k = p.floor();
      final f = p - k;
      out[i] = x[k % x.length] * (1 - f) + x[(k + 1) % x.length] * f;
    }
    return out;
  }
}
