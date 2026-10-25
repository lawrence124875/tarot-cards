import 'dart:math' as math;
import 'dart:typed_data';

/// IMA ADPCM（WAV 格式代碼 0x11，單聲道）解碼：真實錄音音景存成這種 4 bit 格式，
/// App 自己解碼成 PCM 再和長音墊、鈴聲混音，不依賴平台解碼器（Android／iOS 結果一樣）。
/// 檔案由 tarot-content 的 tools/make_loops.py 以 ffmpeg（adpcm_ima_wav）產生。
({Float32List samples, int sampleRate}) decodeImaAdpcmWav(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  String id(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (bytes.length < 12 || id(0) != 'RIFF' || id(8) != 'WAVE') {
    throw const FormatException('不是 WAV 檔');
  }
  int? sampleRate, blockAlign, total;
  int? dataStart, dataLength;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final chunk = id(at);
    final size = d.getUint32(at + 4, Endian.little);
    final body = at + 8;
    switch (chunk) {
      case 'fmt ':
        if (d.getUint16(body, Endian.little) != 0x11) throw const FormatException('不是 IMA ADPCM');
        if (d.getUint16(body + 2, Endian.little) != 1) throw const FormatException('只支援單聲道');
        sampleRate = d.getUint32(body + 4, Endian.little);
        blockAlign = d.getUint16(body + 12, Endian.little);
      case 'fact':
        total = d.getUint32(body, Endian.little);
      case 'data':
        dataStart = body;
        dataLength = math.min(size, bytes.length - body);
    }
    at = body + size + (size & 1);
  }
  if (sampleRate == null || blockAlign == null || dataStart == null || dataLength == null) {
    throw const FormatException('WAV 缺少 fmt 或 data');
  }
  final perBlock = (blockAlign - 4) * 2 + 1;
  final blocks = (dataLength + blockAlign - 1) ~/ blockAlign;
  final out = Float32List(total ?? blocks * perBlock);
  var n = 0;
  for (var b = 0; b < blocks && n < out.length; b++) {
    final start = dataStart + b * blockAlign;
    final end = math.min(start + blockAlign, dataStart + dataLength);
    if (end - start < 4) break;
    var predictor = d.getInt16(start, Endian.little);
    var index = math.min(bytes[start + 2], 88);
    out[n++] = predictor / 32768;
    for (var i = start + 4; i < end && n < out.length; i++) {
      // 每個位元組兩個樣本：低 4 bit 在前
      for (var half = 0; half < 2 && n < out.length; half++) {
        final nibble = half == 0 ? bytes[i] & 0x0f : bytes[i] >> 4;
        final step = _steps[index];
        // 與 ffmpeg 的編解碼器相同的算法（逐位相加的寫法會有少許差異）
        final diff = ((2 * (nibble & 7) + 1) * step) >> 3;
        predictor = (nibble & 8 != 0 ? predictor - diff : predictor + diff).clamp(-32768, 32767).toInt();
        index = (index + _indexTable[nibble]).clamp(0, 88).toInt();
        out[n++] = predictor / 32768;
      }
    }
  }
  return (samples: n == out.length ? out : Float32List.sublistView(out, 0, n), sampleRate: sampleRate);
}

const _indexTable = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8];

const _steps = [
  7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, //
  50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
  337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
  2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487,
  12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
];
