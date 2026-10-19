import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_cards/core/soundscape/sound_bed.dart';
import 'package:tarot_cards/core/tarot/tarot_card.dart';
import 'package:tarot_cards/core/soundscape/breath_timeline.dart';
import 'package:tarot_cards/core/soundscape/dsp.dart';
import 'package:tarot_cards/core/soundscape/session_renderer.dart';
import 'package:tarot_cards/core/soundscape/synth_bed_source.dart';

void main() {
  group('呼吸節奏（吸 4、吐 6）', () {
    const p = BreathPattern();

    test('每分鐘 6 次', () => expect(60 / p.cycle, 6));

    test('階段與進度', () {
      expect(p.at(0).phase, BreathPhase.inhale);
      expect(p.at(2).progress, closeTo(0.5, 1e-9));
      expect(p.at(4).phase, BreathPhase.exhale);
      expect(p.at(7).progress, closeTo(0.5, 1e-9));
      expect(p.at(10).phase, BreathPhase.inhale);
      expect(p.at(10).cycle, 1);
      expect(p.at(9).secondsLeftInPhase, closeTo(1, 1e-9));
    });

    test('呼吸圓大小：吸到頂為 1、吐完為 0，連續', () {
      expect(p.at(0).fullness, closeTo(0, 1e-9));
      expect(p.at(3.999).fullness, closeTo(1, 1e-3));
      expect(p.at(4).fullness, closeTo(1, 1e-9));
      expect(p.at(9.999).fullness, closeTo(0, 1e-3));
    });
  });

  group('練習時間軸', () {
    const tl = SessionTimeline(minutes: 2);

    test('準備 → 呼吸 → 完成', () {
      expect(tl.at(1).phase, BreathPhase.prepare);
      expect(tl.at(tl.leadIn).phase, BreathPhase.inhale);
      expect(tl.at(tl.breathEnd - 0.01).phase, BreathPhase.exhale);
      expect(tl.at(tl.breathEnd).phase, BreathPhase.done);
      expect(tl.totalSeconds, tl.leadIn + 120 + tl.tail);
    });

    test('音量曲線在各段交界處連續，頭尾為 0', () {
      expect(tl.bedGain(0), closeTo(0, 1e-9));
      expect(tl.bedGain(tl.leadIn - 1e-6), closeTo(tl.bedGain(tl.leadIn), 1e-4));
      expect(tl.bedGain(tl.breathEnd - 1e-6), closeTo(tl.bedGain(tl.breathEnd), 1e-4));
      expect(tl.bedGain(tl.totalSeconds), closeTo(0, 1e-9));
      for (var t = 0.0; t < tl.totalSeconds; t += 0.25) {
        expect(tl.bedGain(t), inInclusiveRange(0, 1));
      }
    });

    test('鈴聲：每次吸、吐各一聲，加上結束鈴', () {
      final b = tl.bells();
      expect(b.length, 2 * 12 + 1);
      expect(b.first.time, tl.leadIn);
      expect(b[1].kind, BellKind.exhale);
      expect(b[1].time, tl.leadIn + 4);
      expect(b.last.kind, BellKind.end);
      expect(b.last.time, tl.breathEnd);
    });
  });

  group('八種音景（程式合成）', () {
    const source = SynthBedSource();
    const sr = 11025;

    for (final t in SoundBed.values) {
      test('${t.name}：長度正確、數值正常、音量合理', () {
        final b = source.bed(t, sampleRate: sr, seconds: 12);
        expect(b.length, 12 * sr);
        expect(b.every((v) => v.isFinite), isTrue);
        final r = rmsOf(b);
        expect(r, greaterThan(0.01));
        expect(r, lessThan(0.25));
        expect(peakOf(b), lessThan(1.5));
      });
    }

    test('同一設定產生同樣的聲音（可重現）', () {
      final a = source.bed(SoundBed.water, sampleRate: sr, seconds: 7);
      final b = source.bed(SoundBed.water, sampleRate: sr, seconds: 7);
      expect(a, b);
    });

    test('循環接縫：交叉淡化後開頭接得上原本的尾端', () {
      final raw = Float32List.fromList(List.generate(30, (i) => i.toDouble()));
      final loop = SynthBedSource.makeLoop(raw, 20, 10);
      expect(loop.length, 20);
      expect(loop[0], closeTo(raw[20], 1e-6)); // 第 0 個樣本＝原本第 n 個，接縫連續
      expect(loop[15], raw[15]);
    });
  });

  test('元素 → 兩層音景：每個元素都不同，且都用得到八種音景中的音景', () {
    final pairs = {for (final e in TarotElement.values) e: bedsFor(e)};
    expect(pairs[TarotElement.fire], (upper: SoundBed.sky, lower: SoundBed.fire));
    expect(pairs[TarotElement.water], (upper: SoundBed.lake, lower: SoundBed.water));
    expect(pairs[TarotElement.air], (upper: SoundBed.sky, lower: SoundBed.wind));
    expect(pairs[TarotElement.earth], (upper: SoundBed.mountain, lower: SoundBed.earth));
    expect(pairs.values.toSet(), hasLength(4));
    // 每張牌都有音景（大阿爾克那依黃金黎明元素）
    for (final c in TarotCard.all) {
      final b = bedsFor(c.element);
      expect(b.upper, isNot(b.lower), reason: c.key);
    }
  });

  test('整段練習音檔：WAV 格式與長度', () {
    const spec = SessionSpec(upper: SoundBed.earth, lower: SoundBed.mountain, minutes: 1, bells: true);
    final bytes = const SessionRenderer(sampleRate: 8000).renderWav(spec);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');
    expect(tag(36), 'data');
    final samples = (spec.timeline.totalSeconds * 8000).round();
    expect(bytes.length, 44 + samples * 2);
    final d = ByteData.sublistView(bytes);
    expect(d.getUint32(24, Endian.little), 8000);
    expect(d.getInt16(44, Endian.little).abs(), lessThan(10)); // 從無聲淡入
    expect(spec.key, 'v5_earth_mountain_b_1m');
    expect(d.getUint16(22, Endian.little), 1);
  });

  test('雙耳節拍：立體聲、左右聲道不同', () {
    const spec = SessionSpec(upper: SoundBed.sky, lower: SoundBed.sky, minutes: 1, bells: false, binaural: true);
    final bytes = const SessionRenderer(sampleRate: 8000).renderWav(spec);
    final d = ByteData.sublistView(bytes);
    final samples = (spec.timeline.totalSeconds * 8000).round();
    expect(bytes.length, 44 + samples * 4);
    expect(d.getUint16(22, Endian.little), 2);
    expect(spec.key, 'v5_sky_sky_q_bi128_1m');
    var diff = 0;
    for (var i = 8000 * 10; i < 8000 * 11; i++) {
      diff += (d.getInt16(44 + i * 4, Endian.little) - d.getInt16(46 + i * 4, Endian.little)).abs();
    }
    expect(diff, greaterThan(0));
  });

  group('432Hz 與 7.83Hz 可量測', () {
    // 某個頻率在訊號中的振幅（單一頻率的離散傅立葉轉換）。
    double amp(List<double> x, int sr, double f) {
      var re = 0.0, im = 0.0;
      for (var i = 0; i < x.length; i++) {
        final w = 2 * math.pi * f * i / sr;
        re += x[i] * math.cos(w);
        im += x[i] * math.sin(w);
      }
      return 2 * math.sqrt(re * re + im * im) / x.length;
    }

    List<double> channel(Uint8List bytes, int ch, int from, int to, {required int channels}) {
      final d = ByteData.sublistView(bytes);
      return [for (var i = from; i < to; i++) d.getInt16(44 + (i * channels + ch) * 2, Endian.little) / 32768];
    }

    for (final c in BinauralCarrier.values) {
      test('雙耳節拍 ${c.left}Hz：左耳 ${c.left}、右耳 ${c.right}，相差 7.83Hz', () {
        expect(c.right - c.left, closeTo(7.83, 1e-9));
        final spec =
            SessionSpec(upper: SoundBed.water, lower: SoundBed.earth, minutes: 1, bells: false, binaural: true, carrier: c);
        const sr = 8000;
        final bytes = const SessionRenderer(sampleRate: sr).renderWav(spec);
        // 20 秒（解析度 0.05Hz）：音景與長音墊兩耳相同，相減後只剩兩個雙耳音
        final l = channel(bytes, 0, 20 * sr, 40 * sr, channels: 2);
        final r = channel(bytes, 1, 20 * sr, 40 * sr, channels: 2);
        final diff = [for (var i = 0; i < l.length; i++) l[i] - r[i]];
        final atLeft = amp(diff, sr, c.left), atRight = amp(diff, sr, c.right);
        expect(atLeft, greaterThan(0.02));
        expect(atRight, greaterThan(0.02));
        // 偏 0.1Hz 就明顯變小：頻率是精準的
        expect(amp(diff, sr, c.left + 0.1), lessThan(atLeft * 0.2));
        expect(amp(diff, sr, c.right - 0.1), lessThan(atRight * 0.2));
      });
    }

    test('長音墊只用 432Hz 系統的整數頻率', () {
      for (final f in TonalPad.frequencies) {
        expect(f, f.roundToDouble());
        // 皆為 A＝432 純律 A 大調五聲音階（A、B、C#、E、F#）的八度
        const pitchClasses = [432.0, 486.0, 540.0, 648.0, 720.0];
        var x = f;
        while (x < 432) {
          x *= 2;
        }
        while (x >= 864) {
          x /= 2;
        }
        expect(pitchClasses.any((p) => (p - x).abs() < 1e-9), isTrue, reason: '$f Hz');
      }
    });

    test('鳥鳴與水泡的音也是同一組五聲音階', () {
      const pitchClasses = [432.0, 486.0, 540.0, 648.0, 720.0];
      for (final f in [...SynthBedSource.birdNotes, ...SynthBedSource.bubbleNotes]) {
        var x = f;
        while (x < 432) {
          x *= 2;
        }
        while (x >= 864) {
          x /= 2;
        }
        expect(pitchClasses.any((p) => (p - x).abs() < 1e-9), isTrue, reason: '$f Hz');
      }
    });

    test('鈴聲：吸氣 432Hz', () {
      const spec = SessionSpec(upper: SoundBed.mountain, lower: SoundBed.mountain, minutes: 1, bells: true);
      const sr = 8000;
      final bytes = const SessionRenderer(sampleRate: sr).renderWav(spec);
      final tl = spec.timeline;
      final start = ((tl.leadIn + 10) * sr).round(); // 第二次吸氣鈴
      final x = channel(bytes, 0, start, start + 2 * sr, channels: 1);
      final at432 = amp(x, sr, 432);
      expect(at432, greaterThan(amp(x, sr, 428) * 3));
      expect(at432, greaterThan(amp(x, sr, 436) * 3));
    });
  });

  group('分段播放（自訂時長，0.2.0+48）', () {
    test('短練習一個檔；60 分鐘＝開頭＋循環 17 次＋結尾，總長不變', () {
      const short = SessionSpec(upper: SoundBed.water, lower: SoundBed.fire, minutes: 3, bells: true);
      expect(short.parts, hasLength(1));
      expect(short.parts.single.seconds, short.timeline.totalSeconds);

      const long = SessionSpec(upper: SoundBed.water, lower: SoundBed.fire, minutes: 60, bells: true);
      final parts = long.parts;
      expect(parts, hasLength(19)); // 3600 ÷ 200 ＝ 18：開頭 1＋循環 17＋結尾 1
      expect(parts.skip(1).take(17).map((p) => p.key).toSet(), hasLength(1));
      expect(parts.map((p) => p.key).toSet(), hasLength(3)); // 只要三個檔
      expect(parts.fold<double>(0, (a, p) => a + p.seconds), closeTo(long.timeline.totalSeconds, 1e-9));
      for (var i = 1; i < parts.length; i++) {
        if (i < parts.length - 1) expect(parts[i].seconds, SessionRenderer.loopSeconds);
      }
      // 換時長時開頭段、循環段可沿用
      const other = SessionSpec(upper: SoundBed.water, lower: SoundBed.fire, minutes: 30, bells: true);
      expect(other.parts.first.key, parts.first.key);
      expect(other.parts[1].key, parts[1].key);
      expect(other.parts.last.key, isNot(parts.last.key));
    });

    test('循環段首尾無縫：播完循環段接回開頭，聲音和連續播放一模一樣', () {
      const spec = SessionSpec(
          upper: SoundBed.mountain, lower: SoundBed.water, minutes: 10, bells: true, binaural: true, carrier: BinauralCarrier.a216);
      const sr = 4000;
      const r = SessionRenderer(sampleRate: sr);
      final loop = spec.parts[1];
      // 循環段之後接著的 1 秒（連續播放時的樣子）與循環段開頭的 1 秒
      final after = r.renderPart(spec, loop.end, loop.end + 1);
      final head = r.renderPart(spec, loop.start, loop.start + 1);
      final a = ByteData.sublistView(after), b = ByteData.sublistView(head);
      var maxDiff = 0;
      for (var i = 0; i < sr * 2; i++) {
        maxDiff = math.max(maxDiff, (a.getInt16(44 + i * 2, Endian.little) - b.getInt16(44 + i * 2, Endian.little)).abs());
      }
      expect(maxDiff, lessThanOrEqualTo(2)); // 只差浮點誤差
    });

    test('各段接起來＝整段一次算完', () {
      const spec = SessionSpec(upper: SoundBed.thunder, lower: SoundBed.lake, minutes: 7, bells: true);
      const sr = 2000;
      const r = SessionRenderer(sampleRate: sr);
      final whole = ByteData.sublistView(r.renderWav(spec));
      var at = 0;
      for (final p in spec.parts) {
        final part = ByteData.sublistView(r.renderPart(spec, p.start, p.end));
        final n = (part.lengthInBytes - 44) ~/ 2;
        for (var i = 0; i < n; i += 97) {
          expect((part.getInt16(44 + i * 2, Endian.little) - whole.getInt16(44 + (at + i) * 2, Endian.little)).abs(),
              lessThanOrEqualTo(2));
        }
        at += n;
      }
      expect(at, (whole.lengthInBytes - 44) ~/ 2);
    });
  });
}
