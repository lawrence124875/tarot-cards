import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_bed.dart';
import 'bed_source.dart';
import 'dsp.dart';
import 'breath_timeline.dart';
import 'synth_bed_source.dart';

/// 一次呼吸練習要產生的音檔規格。只含基本型別，可送進背景 isolate。
class SessionSpec {
  const SessionSpec({
    required this.upper,
    required this.lower,
    required this.minutes,
    required this.bells,
    this.binaural = false,
    this.carrier = BinauralCarrier.c128,
  });

  final SoundBed upper;
  final SoundBed lower;
  final int minutes;
  final bool bells;

  /// 雙耳節拍：左耳 [carrier]、右耳高 7.83Hz，兩耳差 7.83Hz（需戴耳機）。開啟時輸出立體聲。
  final bool binaural;

  /// 雙耳節拍左耳的頻率（使用者可選 128Hz 或 216Hz）。
  final BinauralCarrier carrier;

  SessionTimeline get timeline => SessionTimeline(minutes: minutes);

  /// 快取檔名用。改了合成方式請把版本往上加，舊快取自然失效
  /// （v2：0.1.0+10 柔和版＋432Hz；v3：432Hz 長音墊、精準頻率、雙耳節拍可選 128／216Hz；
  /// v4：0.2.0+48 分段播放、音景循環 40／50 秒、鳥鳴與水泡改用 432Hz 系統的音）。
  String get key => 'v4_${_soundKey}_${minutes}m';

  /// 不含時長的部分：開頭段與循環段只跟音景、鈴聲、雙耳節拍有關，換時長可以沿用。
  String get _soundKey =>
      '${upper.name}_${lower.name}_${bells ? 'b' : 'q'}${binaural ? '_bi${carrier.left.round()}' : ''}';

  /// 播放清單（依序播放，循環段重複 n−1 次）。整段 [0, totalSeconds) 被切成：
  /// 開頭 [0, leadIn+P)、循環 [leadIn+P, leadIn+2P) × (n−1)、結尾 [leadIn+nP, totalSeconds)，
  /// P＝[SessionRenderer.loopSeconds]、n＝呼吸秒數 ÷ P（取整數）。呼吸期間的聲音以 P 為週期完全重複，
  /// 所以循環段接上任何一段都沒有接縫；60 分鐘也只要三個檔（約 10 分鐘的音訊）。不滿 P 秒時整段一個檔。
  List<SessionPart> get parts {
    const p = SessionRenderer.loopSeconds;
    final tl = timeline;
    final n = (tl.breathSeconds / p).floor();
    if (n == 0) return [SessionPart('v4_${_soundKey}_${minutes}m', 0, tl.totalSeconds)];
    final head = SessionPart('v4_${_soundKey}_head', 0, tl.leadIn + p);
    final loop = SessionPart('v4_${_soundKey}_loop', tl.leadIn + p, tl.leadIn + 2 * p);
    final tail = SessionPart('v4_${_soundKey}_${minutes}m_end', tl.leadIn + n * p, tl.totalSeconds);
    return [head, for (var i = 1; i < n; i++) loop, tail];
  }
}

/// 練習音檔的一段：時間軸上的 [start, end) 秒，[key] 相同的段內容相同（共用一個檔）。
class SessionPart {
  const SessionPart(this.key, this.start, this.end);

  final String key;
  final double start;
  final double end;

  double get seconds => end - start;
}

/// 雙耳節拍兩組頻率：左耳 [left]、右耳 [right]，相差正好 7.83Hz。
/// 128Hz 是 432Hz 調音（畢氏音律）裡的 C（C4＝256Hz）；216Hz 是 432Hz 的低八度。
enum BinauralCarrier {
  c128(128.0),
  a216(216.0);

  const BinauralCarrier(this.left);

  final double left;
  double get right => left + SessionRenderer.binauralBeat;
}

/// 合成整段練習音檔（16-bit WAV，單聲道；開雙耳節拍時立體聲）：上卦、下卦兩種音景疊加，
/// 柔化高頻後加上 432Hz 調音的長音墊（[TonalPad]），依呼吸時間軸起伏音量，再加上換氣鈴聲（432Hz 調音）。
/// 所有有音高的聲音都是精準頻率的正弦波，可用調音器或頻譜 App 量測。純計算，可在背景 isolate 或單元測試中執行。
class SessionRenderer {
  const SessionRenderer({this.source = const SynthBedSource(), this.sampleRate = 22050});

  final BedSource source;
  final int sampleRate;

  /// 上、下卦循環長度不同，疊在一起時不容易聽出重複；兩者都整除 [loopSeconds]（0.2.0+48 起，原為 31／37 秒）。
  static const upperSeconds = 40.0;
  static const lowerSeconds = 50.0;

  /// 呼吸期間整體聲音的週期（秒）：音景 40／50 秒、呼吸 10 秒、和弦 40 秒、長音墊起伏與所有頻率
  /// （含 7.83Hz 差頻：7.83×200＝1566）在 200 秒後都回到原點，分段播放因此無縫（[SessionSpec.parts]）。
  static const loopSeconds = 200.0;

  /// 雙耳節拍：右耳比左耳高 7.83Hz（舒曼共振頻率）；左耳頻率見 [BinauralCarrier]。
  static const binauralBeat = 7.83;
  static const binauralLevel = 0.045;

  /// 全部音景最後再過一道低通，聲音更溫暖不刺耳。
  static const softenCutoff = 5000.0;

  /// 整段練習（測試與短練習用）。
  Uint8List renderWav(SessionSpec spec) => renderPart(spec, 0, spec.timeline.totalSeconds);

  /// 時間軸上 [start, end) 秒的音檔。前面先多算一小段（不輸出），讓濾波器與還在響的鈴聲接得上前一段。
  Uint8List renderPart(SessionSpec spec, double start, double end) {
    final sr = sampleRate;
    final tl = spec.timeline;
    final from = (start * sr).round();
    final n = (end * sr).round() - from;
    final pre = math.min(from, (15 * sr).round());

    final same = spec.upper == spec.lower;
    final lower = source.bed(spec.lower, sampleRate: sr, seconds: lowerSeconds);
    final upper = same ? null : source.bed(spec.upper, sampleRate: sr, seconds: upperSeconds);
    // 兩段不相關的音景相加，均方根約放大 √2，各乘 0.75 讓總音量與單一音景相近
    final g = same ? 1.0 : 0.75;

    final bells = spec.bells ? tl.bells() : const <({double time, BellKind kind})>[];
    // 早在前段就響完的鈴聲略過（鈴聲最長 14 秒）
    var nextBell = 0;
    while (nextBell < bells.length && bells[nextBell].time < (from - pre) / sr - 15) {
      nextBell++;
    }
    final active = <_Bell>[];

    final ch = spec.binaural ? 2 : 1;
    final soften = Biquad.lowpass(sr, softenCutoff, 0.6);
    final pad = TonalPad(tl);
    final left = spec.carrier.left, right = spec.carrier.right;
    final data = ByteData(44 + n * 2 * ch);
    _writeHeader(data, n, sr, ch);
    for (var k = -pre; k < n; k++) {
      final i = from + k;
      final t = i / sr;
      var v = lower[i % lower.length] * g;
      if (upper != null) v += upper[i % upper.length] * g;
      // 長音墊加在低通之後：純正弦波不受濾波影響，頻率保持精準
      v = (soften.process(v) + pad.valueAt(t)) * tl.bedGain(t);

      while (nextBell < bells.length && bells[nextBell].time <= t) {
        active.add(_Bell(bells[nextBell].kind, bells[nextBell].time));
        nextBell++;
      }
      if (active.isNotEmpty) {
        for (final b in active) {
          v += b.valueAt(t);
        }
        active.removeWhere((b) => t - b.start > b.length);
      }

      if (k < 0) continue;
      if (ch == 1) {
        // 柔性限幅：一般音量幾乎不受影響，避免雷聲或劈啪聲爆音
        data.setInt16(44 + k * 2, _pcm(v), Endian.little);
      } else {
        // 雙耳節拍只隨準備淡入、結束淡出，不跟呼吸起伏（保持穩定的差頻）
        final e = binauralLevel * tl.bedGain(t) / (1 - tl.depth).clamp(0.01, 1.0);
        final env = math.min(e, binauralLevel);
        final l = v + env * math.sin(2 * math.pi * left * t);
        final r = v + env * math.sin(2 * math.pi * right * t);
        data.setInt16(44 + k * 4, _pcm(l), Endian.little);
        data.setInt16(46 + k * 4, _pcm(r), Endian.little);
      }
    }
    return data.buffer.asUint8List();
  }

  static int _pcm(double v) => (_softClip(v) * 32767).round().clamp(-32768, 32767).toInt();

  static double _softClip(double x) {
    const knee = 0.6;
    final a = x.abs();
    if (a <= knee) return x;
    final over = (a - knee) / (1 - knee);
    final y = knee + (1 - knee) * (1 - math.exp(-over));
    return x.isNegative ? -y : y;
  }

  static void _writeHeader(ByteData d, int samples, int sr, int ch) {
    void ascii(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        d.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    d.setUint32(4, 36 + samples * 2 * ch, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    d.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    d.setUint16(20, 1, Endian.little); // PCM
    d.setUint16(22, ch, Endian.little); // 1＝單聲道、2＝立體聲
    d.setUint32(24, sr, Endian.little);
    d.setUint32(28, sr * 2 * ch, Endian.little); // byte rate
    d.setUint16(32, 2 * ch, Endian.little); // block align
    d.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    d.setUint32(40, samples * 2 * ch, Endian.little);
  }
}

/// 432Hz 調音的柔和長音墊：A 大調五聲音階（純律，以 A＝432Hz 為準），每個音都是整數赫茲，
/// 調音器量得到。和弦每次呼吸（吸氣開始時）換一次，3 秒交叉淡入，聽起來明亮、緩慢、不搶耳。
///
/// 用到的音：E 81／162／324、F# 90／180／360、A 108／216／432、B 243、C# 270（Hz）。
class TonalPad {
  TonalPad(this.timeline);

  final SessionTimeline timeline;

  /// 整體音量：和各卦音景差不多大小（均方根約 0.03）。
  static const level = 0.06;

  /// 換和弦的交叉淡入秒數。
  static const fade = 3.0;

  /// 和弦進行：A → F#m7 → Esus → A6，每個和弦由低到高。
  static const chords = <List<double>>[
    [108, 216, 270, 324, 432],
    [90, 180, 216, 270, 360],
    [81, 162, 243, 324, 432],
    [108, 216, 270, 360, 432],
  ];

  /// 低音較大、高音較輕。
  static const _amps = [0.5, 0.4, 0.3, 0.25, 0.15];

  /// 每個聲部各自緩慢起伏（秒週期不同，避免同時漲落）。
  /// 0.2.0+48 起都是 1/200 的整數倍，200 秒後回到原點（[SessionRenderer.loopSeconds]）。
  static const _lfo = [0.050, 0.065, 0.085, 0.060, 0.075];

  /// 所有用得到的頻率（測試與說明用）。
  static Set<double> get frequencies => {for (final c in chords) ...c};

  double _chord(int index, double t) {
    final c = chords[index];
    var v = 0.0;
    for (var k = 0; k < c.length; k++) {
      final w = 2 * math.pi * c[k] * t;
      final swell = 0.75 + 0.25 * math.sin(2 * math.pi * _lfo[k] * t + k);
      v += _amps[k] * swell * (math.sin(w) + 0.12 * math.sin(2 * w));
    }
    return v;
  }

  double valueAt(double t) {
    // 第幾次呼吸（準備期算第 0 次）與這次呼吸已過的秒數
    final cycle = timeline.pattern.cycle;
    final n = math.max(0, ((t - timeline.leadIn) / cycle).floor());
    final idx = n % chords.length;
    final x = n == 0 ? 1.0 : smoothstep((t - timeline.leadIn - n * cycle) / fade);
    var v = _chord(idx, t) * x;
    if (x < 1) v += _chord((idx + chords.length - 1) % chords.length, t) * (1 - x);
    return v * level;
  }
}

/// 頌缽般的柔和鈴聲：三個泛音（整數倍）、各自指數衰減。432Hz 調音：吸氣 432Hz（A4）、吐氣與結束 324Hz（其下純四度）。
class _Bell {
  _Bell(this.kind, this.start);

  final BellKind kind;
  final double start;

  static const _ratios = [1.0, 2.0, 3.0];
  static const _amps = [1.0, 0.35, 0.15];
  static const _decays = [2.4, 1.2, 0.7];

  double get _freq => switch (kind) {
        BellKind.inhale => 432.0,
        BellKind.exhale => 324.0,
        BellKind.end => 324.0,
      };

  double get _level => switch (kind) {
        BellKind.inhale => 0.07,
        BellKind.exhale => 0.06,
        BellKind.end => 0.09,
      };

  double get _decayScale => kind == BellKind.end ? 2.0 : 1.0;

  double get length => 7.0 * _decayScale;

  double valueAt(double t) {
    final dt = t - start;
    if (dt < 0) return 0;
    final attack = smoothstep(dt / 0.03); // 起音放緩，像輕輕觸碰
    var v = 0.0;
    for (var p = 0; p < _ratios.length; p++) {
      v += _amps[p] * math.exp(-dt / (_decays[p] * _decayScale)) * math.sin(2 * math.pi * _freq * _ratios[p] * dt);
    }
    return v * attack * _level;
  }
}

/// 在背景 isolate 執行：產生一段音檔並寫入 [path]（先寫暫存檔再改名，避免留下半個檔案）。
Future<void> renderSessionToFile(SessionSpec spec, SessionPart part, String path) async {
  final bytes = const SessionRenderer().renderPart(spec, part.start, part.end);
  final tmp = File('$path.part');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(path);
}
