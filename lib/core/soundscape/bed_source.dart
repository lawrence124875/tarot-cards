import 'dart:typed_data';

import 'sound_bed.dart';

/// 音景來源（策略，HANDOFF §9 第 2 點）：給一種音景，回傳一段可無縫循環的單聲道音景。
/// 目前實作為程式合成（SynthBedSource）；日後若改用錄音檔，只需新增一個實作。
abstract class BedSource {
  const BedSource();

  /// 長度＝round(seconds × sampleRate)，最後一個樣本接回第一個樣本時不會有接縫。
  Float32List bed(SoundBed trigram, {required int sampleRate, required double seconds});
}
