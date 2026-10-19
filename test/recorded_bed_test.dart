import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/soundscape/dsp.dart';
import 'package:tarot_cards/core/soundscape/ima_adpcm.dart';
import 'package:tarot_cards/core/soundscape/recorded_bed_source.dart';
import 'package:tarot_cards/core/soundscape/session_renderer.dart';
import 'package:tarot_cards/core/soundscape/sound_bed.dart';
import 'package:tarot_cards/core/soundscape/synth_bed_source.dart';

Map<SoundBed, Uint8List> _files() =>
    {for (final b in RecordedBedSource.recorded) b: File(RecordedBedSource.assetPath(b)).readAsBytesSync()};

double _rms(Float32List x, int from, int n) {
  var s = 0.0;
  for (var i = 0; i < n; i++) {
    final v = x[(from + i) % x.length];
    s += v * v;
  }
  return math.sqrt(s / n);
}

void main() {
  final files = _files();

  test('每種有錄音的音景都有檔案，總大小低於 10MB，來源都列在 CREDITS.md', () {
    var total = 0;
    final credits = File('assets/audio/CREDITS.md').readAsStringSync();
    for (final b in RecordedBedSource.recorded) {
      total += files[b]!.length;
      expect(credits, contains('${b.name}.wav'));
    }
    expect(total, lessThan(10 * 1024 * 1024));
  });

  group('IMA ADPCM 解碼', () {
    test('格式正確、長度能整除 200 秒、不是靜音', () {
      for (final b in RecordedBedSource.recorded) {
        final d = decodeImaAdpcmWav(files[b]!);
        expect(d.sampleRate, 22050, reason: b.name);
        final period = (SessionRenderer.loopSeconds * d.sampleRate).round();
        expect(period % d.samples.length, 0, reason: '${b.name}：${d.samples.length} 個樣本');
        expect(rmsOf(d.samples), greaterThan(0.005), reason: b.name);
        expect(peakOf(d.samples), lessThanOrEqualTo(1.0), reason: b.name);
      }
    });

    test('循環無縫：頭尾接起來沒有跳動、音量相近', () {
      for (final b in RecordedBedSource.recorded) {
        final x = decodeImaAdpcmWav(files[b]!).samples;
        final level = rmsOf(x);
        // 接縫處相鄰兩個樣本的差距不比一般相鄰樣本大太多
        var typical = 0.0;
        for (var i = 1; i < x.length; i++) {
          typical += (x[i] - x[i - 1]).abs();
        }
        typical /= x.length - 1;
        expect((x.first - x.last).abs(), lessThan(typical * 8 + level * 0.5), reason: b.name);
        // 接縫前後 0.5 秒的音量差在 6 dB 內（鳥鳴本來就有起伏，太短的窗會誤判）
        const k = 11025;
        final before = _rms(x, x.length - k, k), after = _rms(x, 0, k);
        expect((20 * math.log(before / after) / math.ln10).abs(), lessThan(6), reason: b.name);
      }
    });

    test('不是 IMA ADPCM 的檔案會被拒絕', () {
      expect(() => decodeImaAdpcmWav(Uint8List.fromList(List.filled(64, 0))), throwsFormatException);
    });
  });

  group('錄音音景', () {
    final source = RecordedBedSource(files);

    test('有錄音的用錄音（長度＝錄音長度、音量對齊），其他退回合成', () {
      for (final b in SoundBed.values) {
        final x = source.bed(b, sampleRate: 22050, seconds: 40);
        if (RecordedBedSource.recorded.contains(b)) {
          expect(x.length, decodeImaAdpcmWav(files[b]!).samples.length, reason: b.name);
          expect(rmsOf(x), closeTo(RecordedBedSource.levels[b]!, 1e-3), reason: b.name);
        } else {
          expect(x.length, 40 * 22050, reason: b.name);
        }
      }
    });

    test('沒有錄音檔時整個退回合成', () {
      const empty = RecordedBedSource({});
      const synth = SynthBedSource();
      final a = empty.bed(SoundBed.water, sampleRate: 4000, seconds: 5);
      final b = synth.bed(SoundBed.water, sampleRate: 4000, seconds: 5);
      expect(a, b);
    });

    test('換取樣率後長度照比例、仍能整除 200 秒', () {
      final x = source.bed(SoundBed.lake, sampleRate: 4000, seconds: 40);
      expect((SessionRenderer.loopSeconds * 4000).round() % x.length, 0);
    });

    test('用錄音的練習音檔：循環段接回開頭仍然無縫', () {
      const spec = SessionSpec(upper: SoundBed.lake, lower: SoundBed.water, minutes: 10, bells: true);
      const sr = 4000;
      final r = SessionRenderer(sampleRate: sr, source: source);
      final loop = spec.parts[1];
      final after = ByteData.sublistView(r.renderPart(spec, loop.end, loop.end + 1));
      final head = ByteData.sublistView(r.renderPart(spec, loop.start, loop.start + 1));
      var maxDiff = 0;
      for (var i = 0; i < sr; i++) {
        maxDiff = math.max(maxDiff, (after.getInt16(44 + i * 2, Endian.little) - head.getInt16(44 + i * 2, Endian.little)).abs());
      }
      expect(maxDiff, lessThanOrEqualTo(2));
    });
  });
}
