import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_bed.dart';
import 'bed_source.dart';
import 'dsp.dart';

/// 程式合成的八種自然音景（沿用謙卦音景引擎）。不用任何錄音檔，因此沒有授權問題。
///
/// 各音層以均方根（連續聲）或峰值（稀疏事件）校準到絕對音量，
/// 刻意保留各卦的相對大小：例如山（寂靜）本來就比雷（雷雨）安靜。
///
/// 0.1.0+10 調得更柔和：整體削弱高頻、突發聲（雷、劈啪、拍岸、雨滴）壓低並放緩起音、
/// 起伏放慢；泛音長鳴改以 432Hz 為基準（108Hz＝432÷4，泛音含 216、324、432Hz）。
/// 0.2.x：泛音長鳴與蟲鳴都是精準的 432Hz 系統頻率，可用調音器量測。
/// 0.2.0+48：艮卦鳥鳴改在 432Hz 系統的音之間滑音（滑音只在兩個音之間）、坎卦水泡的起始音取自 432Hz 系統（[birdNotes]、[bubbleNotes]）。
/// 風、雨、水流、火、雷等雜訊沒有音高，不需調音。
class SynthBedSource extends BedSource {
  const SynthBedSource({this.seed = 1});

  final int seed;

  /// 艮卦鳥鳴用的音（Hz）：和長音墊同一組 A 大調五聲音階（A＝432Hz）的高八度：B 1944、C# 2160、E 2592、F# 2880、A 3456。
  static const birdNotes = [1944.0, 2160.0, 2592.0, 2880.0, 3456.0];

  /// 坎卦水泡的起始音（Hz）：同一組五聲音階的 C# 270、E 324、F# 360、A 432、B 486、C# 540、E 648。
  static const bubbleNotes = [270.0, 324.0, 360.0, 432.0, 486.0, 540.0, 648.0];

  /// 循環接縫的交叉淡化長度（秒）。
  static const crossfadeSeconds = 3.0;

  @override
  Float32List bed(SoundBed trigram, {required int sampleRate, required double seconds}) {
    final n = (seconds * sampleRate).round();
    final m = math.min((crossfadeSeconds * sampleRate).round(), n ~/ 2);
    final total = n + m;
    final rng = Rng(seed * 7919 + trigram.index * 104729 + 17);
    final layers = _recipe(trigram)(rng, sampleRate, total);

    final raw = Float32List(total);
    for (final l in layers) {
      for (var i = 0; i < total; i++) {
        raw[i] += l[i];
      }
    }
    return makeLoop(raw, n, m);
  }

  /// 把多生成的尾端 [m] 個樣本以等功率交叉淡化疊回開頭，得到長度 [n] 的無縫循環。
  static Float32List makeLoop(Float32List raw, int n, int m) {
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = raw[i];
    }
    for (var i = 0; i < m; i++) {
      final x = i / m * math.pi / 2;
      out[i] = raw[i] * math.sin(x) + raw[n + i] * math.cos(x);
    }
    return out;
  }

  static _Recipe _recipe(SoundBed t) => switch (t) {
        SoundBed.sky => _sky,
        SoundBed.earth => _earth,
        SoundBed.thunder => _thunderRain,
        SoundBed.wind => _wind,
        SoundBed.water => _water,
        SoundBed.fire => _fire,
        SoundBed.mountain => _mountain,
        SoundBed.lake => _lake,
      };
}

typedef _Recipe = List<Float32List> Function(Rng r, int sr, int n);

/// 坎・水：山澗流水——快速變化的帶通雜訊（水流）＋細小氣泡音。
List<Float32List> _water(Rng r, int sr, int n) {
  final rushBp = Biquad.bandpass(sr, 1200, 0.9);
  final body = Biquad.bandpass(sr, 420, 0.7);
  final fast = SmoothRandom(r, 3, sr);
  final slow = SmoothRandom(r, 0.15, sr);
  var k = 0;
  final rush = renderSamples(n, () {
    final f = fast.next(), s = slow.next();
    if ((k++ & 31) == 0) rushBp.setBandpass(500 + 900 * f, 0.9);
    return rushBp.process(r.white()) * (0.6 + 0.4 * s) + body.process(r.white()) * 0.5;
  });

  final bubbles = Float32List(n);
  var t = 0;
  while (t < n) {
    t += (r.range(0.02, 0.2) * sr).round(); // 平均約每秒 9 個
    final f0 = SynthBedSource.bubbleNotes[r.nextInt(SynthBedSource.bubbleNotes.length)], tau = r.range(0.01, 0.025), amp = r.range(0.2, 1.0);
    final len = (tau * 6 * sr).round();
    var phase = 0.0, f = f0;
    for (var j = 0; j < len && t + j < n; j++) {
      phase += 2 * math.pi * f / sr;
      f *= 1 + 6.0 / sr; // 氣泡上升時音高略升
      bubbles[t + j] += amp * math.exp(-j / (tau * sr)) * math.sin(phase);
    }
  }
  return [normalizeRms(rush, 0.075), normalizeRms(bubbles, 0.01)];
}

/// 震・雷：遠雷春雨——粉紅雜訊雨聲＋雨滴＋每隔 9–16 秒一次低沉遠雷。
List<Float32List> _thunderRain(Rng r, int sr, int n) {
  final pink = PinkNoise(r);
  final rainHp = Biquad.highpass(sr, 400), rainLp = Biquad.lowpass(sr, 2500);
  final rain = renderSamples(n, () => rainLp.process(rainHp.process(pink.next())));

  final dropHp = Biquad.bandpass(sr, 1500, 0.8);
  final dropDecay = math.exp(-1 / (0.004 * sr));
  var env = 0.0;
  final drops = renderSamples(n, () {
    if (r.next() < 25 / sr) env += powd(r.next(), 2);
    env *= dropDecay;
    return dropHp.process(r.white() * env);
  });

  final brown = BrownNoise(r);
  final lp1 = Biquad.lowpass(sr, 140), lp2 = Biquad.lowpass(sr, 140);
  final rumble = SmoothRandom(r, 2.5, sr);
  final thunder = Float32List(n);
  var start = (r.range(3, 8) * sr).round();
  var att = 0.5, dec = 3.0, height = 1.0;
  var next = start;
  for (var i = 0; i < n; i++) {
    if (i == next) {
      start = i;
      att = r.range(1.0, 2.0);
      dec = r.range(3.0, 5.0);
      height = r.range(0.5, 1.0);
      next = i + (r.range(12, 20) * sr).round();
    }
    final x = lp2.process(lp1.process(brown.next()));
    final ts = (i - start) / sr;
    final e = i < start ? 0.0 : (ts < att ? powd(ts / att, 2) : math.exp(-(ts - att) / dec));
    thunder[i] = x * e * height * (0.5 + 0.5 * rumble.next());
  }
  return [normalizeRms(rain, 0.06), normalizeRms(drops, 0.01), normalizePeak(thunder, 0.25)];
}

/// 巽・風：林間風——中心頻率緩慢游移的帶通粉紅雜訊（陣風）＋高頻樹葉沙沙聲。
List<Float32List> _wind(Rng r, int sr, int n) {
  final pink = PinkNoise(r);
  final bp = Biquad.bandpass(sr, 500, 0.8);
  final centre = SmoothRandom(r, 0.05, sr);
  final gustLfo = SmoothRandom(r, 0.06, sr);
  final rustle = SmoothRandom(r, 4, sr);
  final leafHp1 = Biquad.highpass(sr, 1200), leafHp2 = Biquad.lowpass(sr, 3000);
  final gusts = Float32List(n);
  var k = 0;
  final wind = renderSamples(n, () {
    final c = centre.next();
    final g = 0.45 + 0.55 * powd(gustLfo.next(), 1.5);
    gusts[k] = g;
    if ((k++ & 31) == 0) bp.setBandpass(200 + 500 * c, 0.8);
    return bp.process(pink.next()) * g;
  });
  var i = 0;
  final leaves = renderSamples(n, () {
    final g = gusts[i++];
    return leafHp2.process(leafHp1.process(r.white())) * g * g * (0.5 + 0.5 * rustle.next());
  });
  return [normalizeRms(wind, 0.08), normalizeRms(leaves, 0.012)];
}

/// 離・火：營火——低沉的火焰呼呼聲＋成串的劈啪聲與偶爾的木柴爆裂。
List<Float32List> _fire(Rng r, int sr, int n) {
  final brown = BrownNoise(r);
  final roarLp = Biquad.lowpass(sr, 350);
  final roarLfo = SmoothRandom(r, 0.6, sr);
  final roar = renderSamples(n, () => roarLp.process(brown.next()) * (0.75 + 0.25 * roarLfo.next()));

  final pink = PinkNoise(r);
  final hissBp = Biquad.bandpass(sr, 2000, 0.7);
  final hiss = renderSamples(n, () => hissBp.process(pink.next()));

  final density = SmoothRandom(r, 0.4, sr);
  final crackHp = Biquad.bandpass(sr, 1800, 0.7);
  final popBp = Biquad.bandpass(sr, 800, 1.0);
  final crackDecay = math.exp(-1 / (0.004 * sr));
  final popDecay = math.exp(-1 / (0.02 * sr));
  var ce = 0.0, pe = 0.0;
  final crackles = renderSamples(n, () {
    final rate = 1 + 6 * powd(density.next(), 2);
    if (r.next() < rate / sr) ce += 0.15 + 0.85 * powd(r.next(), 3);
    if (r.next() < 0.25 / sr) pe += r.range(0.4, 0.8);
    ce *= crackDecay;
    pe *= popDecay;
    return crackHp.process(r.white() * ce) + popBp.process(r.white() * pe) * 0.6;
  });
  return [normalizeRms(roar, 0.055), normalizeRms(hiss, 0.005), normalizePeak(crackles, 0.2)];
}

/// 艮・山：山林寂靜——很輕的山間空氣聲，偶爾遠處幾聲鳥鳴。刻意比其他音景安靜。
List<Float32List> _mountain(Rng r, int sr, int n) {
  final brown = BrownNoise(r);
  final airLp = Biquad.lowpass(sr, 400);
  final air = renderSamples(n, () => airLp.process(brown.next()));

  final pink = PinkNoise(r);
  final bp = Biquad.bandpass(sr, 600, 0.8);
  final c = SmoothRandom(r, 0.05, sr), a = SmoothRandom(r, 0.08, sr);
  var k = 0;
  final breeze = renderSamples(n, () {
    final cv = c.next();
    if ((k++ & 31) == 0) bp.setBandpass(500 + 300 * cv, 0.8);
    return bp.process(pink.next()) * (0.4 + 0.6 * a.next());
  });

  // 兩種鳥，各有固定的音高、滑音方向與節奏；起音與終音都是 432Hz 系統的音
  const notes = SynthBedSource.birdNotes;
  ({double f, double ratio}) pick() {
    final from = r.nextInt(notes.length);
    final to = (from + r.nextInt(5) - 2).clamp(0, notes.length - 1); // 最多滑兩個音
    return (f: notes[from], ratio: notes[to] / notes[from]);
  }

  final species = [
    for (var s = 0; s < 2; s++)
      (
        note: pick(),
        dur: r.range(0.06, 0.14),
        gap: r.range(0.06, 0.16),
        count: 2 + r.nextInt(4),
      ),
  ];
  final birds = Float32List(n);
  var t = r.range(1, 4);
  while (t * sr < n) {
    final sp = species[r.nextInt(species.length)];
    final amp = r.range(0.3, 1.0); // 遠近
    var s = (t * sr).round();
    for (var c2 = 0; c2 < sp.count; c2++) {
      final d = (sp.dur * sr).round();
      var phase = 0.0;
      for (var j = 0; j < d && s + j < n; j++) {
        final tau = j / d;
        final f = sp.note.f * powd(sp.note.ratio, tau) * (1 + 0.01 * math.sin(2 * math.pi * 25 * j / sr));
        phase += 2 * math.pi * f / sr;
        final e = powd(math.sin(math.pi * tau), 2);
        birds[s + j] += amp * e * (math.sin(phase) + 0.2 * math.sin(2 * phase));
      }
      s += d + (sp.gap * sr).round();
    }
    t += r.range(6, 14);
  }
  return [normalizeRms(air, 0.035), normalizeRms(breeze, 0.012), normalizePeak(birds, 0.08)];
}

/// 兌・澤：湖畔水波——一波波緩慢起伏的低頻水聲，每波推到最高時輕拍岸邊。
List<Float32List> _lake(Rng r, int sr, int n) {
  final swell = Float32List(n);
  final lapEnv = Float32List(n);
  var t = 0.0;
  while (t * sr < n) {
    final rise = r.range(2.0, 3.0), fall = r.range(4.0, 5.5), h = r.range(0.6, 1.0);
    final s = (t * sr).round();
    final len = ((rise + fall) * sr).round();
    for (var j = 0; j < len && s + j < n; j++) {
      final ts = j / sr;
      final e = ts < rise
          ? powd(math.sin(math.pi / 2 * ts / rise), 2)
          : powd(math.cos(math.pi / 2 * (ts - rise) / fall), 2);
      swell[s + j] += h * e;
    }
    final lapStart = s + (rise * sr).round();
    final lapLen = (1.2 * sr).round();
    for (var j = 0; j < lapLen && lapStart + j < n; j++) {
      final ts = j / sr;
      lapEnv[lapStart + j] += h * smoothstep(ts / 0.12) * math.exp(-ts / 0.3);
    }
    t += r.range(6.0, 9.0);
  }

  final pink = PinkNoise(r);
  final lp1 = Biquad.lowpass(sr, 500), lp2 = Biquad.lowpass(sr, 500);
  var i = 0;
  final water = renderSamples(n, () => lp2.process(lp1.process(pink.next())) * (0.15 + 0.85 * swell[i++]));
  final lapBp = Biquad.bandpass(sr, 700, 1.0);
  i = 0;
  final laps = renderSamples(n, () => lapBp.process(r.white() * lapEnv[i++]));
  final shimmerHp = Biquad.highpass(sr, 4000);
  i = 0;
  final shimmer = renderSamples(n, () => shimmerHp.process(r.white()) * swell[i++]);
  return [normalizeRms(water, 0.075), normalizePeak(laps, 0.12), normalizeRms(shimmer, 0.003)];
}

/// 乾・天：高空清風——高處輕薄的風聲，加上緩慢起伏的泛音長鳴（以 432Hz 為基準的自然泛音）。
List<Float32List> _sky(Rng r, int sr, int n) {
  final pink = PinkNoise(r);
  final bp = Biquad.bandpass(sr, 1800, 0.6);
  final c = SmoothRandom(r, 0.05, sr), a = SmoothRandom(r, 0.1, sr);
  var k = 0;
  final air = renderSamples(n, () {
    final cv = c.next();
    if ((k++ & 31) == 0) bp.setBandpass(900 + 700 * cv, 0.6);
    return bp.process(pink.next()) * (0.5 + 0.5 * a.next());
  });

  const base = 108.0; // 432 ÷ 4：泛音含 216、324、432Hz
  const ratios = [1.0, 1.5, 2.0, 3.0, 4.0];
  const amps = [1.0, 0.5, 0.45, 0.25, 0.15];
  final partials = [
    for (var p = 0; p < ratios.length; p++)
      (
        f: base * ratios[p], // 精準的 432Hz 系統頻率（不再加隨機偏移）
        a: amps[p],
        lfo: SmoothRandom(r, r.range(0.03, 0.08), sr),
        phase: r.range(0, 2 * math.pi),
      ),
  ];
  final phases = [for (final p in partials) p.phase];
  final drone = renderSamples(n, () {
    var v = 0.0;
    for (var p = 0; p < partials.length; p++) {
      phases[p] += 2 * math.pi * partials[p].f / sr;
      if (phases[p] > 2 * math.pi) phases[p] -= 2 * math.pi;
      v += partials[p].a * (0.4 + 0.6 * partials[p].lfo.next()) * math.sin(phases[p]);
    }
    return v;
  });
  return [normalizeRms(air, 0.035), normalizeRms(drone, 0.04)];
}

/// 坤・地：夜野蟲鳴——大地低沉的嗡鳴，加上三隻遠近不同的蟋蟀。
List<Float32List> _earth(Rng r, int sr, int n) {
  final brown = BrownNoise(r);
  final humLp = Biquad.lowpass(sr, 150);
  final hum = renderSamples(n, () => humLp.process(brown.next()));
  final pink = PinkNoise(r);
  final airLp = Biquad.lowpass(sr, 500);
  final air = renderSamples(n, () => airLp.process(pink.next()));

  final crickets = [
    for (var c = 0; c < 3; c++)
      (
        f: const [3240.0, 3456.0, 3888.0][c], // 432Hz 系統的高音（324×10、432×8、432×9）
        period: r.range(0.5, 0.9),
        pulses: 3 + r.nextInt(2),
        pulseRate: r.range(26, 34),
        amp: r.range(0.5, 1.0),
        offset: r.range(0, 1),
        lfo: SmoothRandom(r, 0.07, sr),
      ),
  ];
  var i = 0;
  final song = renderSamples(n, () {
    final ts = i++ / sr;
    var v = 0.0;
    for (final c in crickets) {
      final dist = c.lfo.next();
      final inPeriod = (ts / c.period + c.offset) % 1.0 * c.period;
      if (inPeriod < c.pulses / c.pulseRate) {
        final e = powd(math.sin(math.pi * ((inPeriod * c.pulseRate) % 1.0)), 2);
        v += math.sin(2 * math.pi * c.f * ts) * e * c.amp * (0.3 + 0.7 * dist);
      }
    }
    return v;
  });
  return [normalizeRms(hum, 0.05), normalizeRms(air, 0.015), normalizeRms(song, 0.012)];
}
