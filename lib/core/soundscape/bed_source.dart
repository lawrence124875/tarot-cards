import 'dart:typed_data';

import 'sound_bed.dart';

/// 音景來源（策略，HANDOFF §9 第 2 點）：給一種音景，回傳一段可無縫循環的單聲道音景。
/// 實作：程式合成（SynthBedSource）、真實錄音（RecordedBedSource，沒有錄音的音景退回合成）。
abstract class BedSource {
  const BedSource();

  /// 最後一個樣本接回第一個樣本時不會有接縫。合成版長度＝round(seconds × sampleRate)；
  /// 錄音版回傳錄音本身的長度（能整除 200 秒，見 RecordedBedSource）。
  Float32List bed(SoundBed trigram, {required int sampleRate, required double seconds});
}
