import 'dart:math' as math;
import 'dart:typed_data';

/// 音景合成用的基本訊號處理（純 Dart、無平台相依，可在背景 isolate 執行，也可單元測試）。

/// 可重現的亂數（xorshift32）：同一種子產生同一段音景，方便測試與重現問題。
class Rng {
  Rng(int seed) : _s = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _s;

  int _nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x;
    return x;
  }

  /// [0, 1)
  double next() => _nextU32() / 4294967296.0;

  /// [-1, 1)
  double white() => next() * 2 - 1;

  double range(double a, double b) => a + (b - a) * next();

  int nextInt(int max) => (next() * max).floor();
}

/// 粉紅雜訊（Paul Kellet 簡化版）：比白雜訊柔和，適合風、雨。
class PinkNoise {
  PinkNoise(this._rng);

  final Rng _rng;
  double _b0 = 0, _b1 = 0, _b2 = 0;

  double next() {
    final w = _rng.white();
    _b0 = 0.99765 * _b0 + w * 0.0990460;
    _b1 = 0.96300 * _b1 + w * 0.2965164;
    _b2 = 0.57000 * _b2 + w * 1.0526913;
    return (_b0 + _b1 + _b2 + w * 0.1848) * 0.25;
  }
}

/// 布朗雜訊（積分後洩漏）：低沉，適合大地、雷、營火底聲。
class BrownNoise {
  BrownNoise(this._rng);

  final Rng _rng;
  double _b = 0;

  double next() {
    _b = (_b + 0.02 * _rng.white()) / 1.02;
    return _b * 3.5;
  }
}

/// RBJ 雙二階濾波器。
class Biquad {
  Biquad._(this.sampleRate);

  factory Biquad.lowpass(int sampleRate, double fc, [double q = 0.707]) =>
      Biquad._(sampleRate)..setLowpass(fc, q);

  factory Biquad.highpass(int sampleRate, double fc, [double q = 0.707]) =>
      Biquad._(sampleRate)..setHighpass(fc, q);

  factory Biquad.bandpass(int sampleRate, double fc, [double q = 0.707]) =>
      Biquad._(sampleRate)..setBandpass(fc, q);

  final int sampleRate;
  double _b0 = 1, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  double _w0(double fc) => 2 * math.pi * fc.clamp(10.0, sampleRate * 0.45) / sampleRate;

  void setLowpass(double fc, [double q = 0.707]) {
    final w0 = _w0(fc), cw = math.cos(w0), alpha = math.sin(w0) / (2 * q), a0 = 1 + alpha;
    _b0 = (1 - cw) / 2 / a0;
    _b1 = (1 - cw) / a0;
    _b2 = _b0;
    _a1 = -2 * cw / a0;
    _a2 = (1 - alpha) / a0;
  }

  void setHighpass(double fc, [double q = 0.707]) {
    final w0 = _w0(fc), cw = math.cos(w0), alpha = math.sin(w0) / (2 * q), a0 = 1 + alpha;
    _b0 = (1 + cw) / 2 / a0;
    _b1 = -(1 + cw) / a0;
    _b2 = _b0;
    _a1 = -2 * cw / a0;
    _a2 = (1 - alpha) / a0;
  }

  /// 帶通（峰值 0 dB）。
  void setBandpass(double fc, [double q = 0.707]) {
    final w0 = _w0(fc), cw = math.cos(w0), alpha = math.sin(w0) / (2 * q), a0 = 1 + alpha;
    _b0 = alpha / a0;
    _b1 = 0;
    _b2 = -alpha / a0;
    _a1 = -2 * cw / a0;
    _a2 = (1 - alpha) / a0;
  }

  double process(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

/// 平滑隨機 LFO：每 1/rateHz 秒換一個目標值，以餘弦插值，輸出 0–1。
class SmoothRandom {
  SmoothRandom(this._rng, double rateHz, int sampleRate) : _step = rateHz / sampleRate {
    _a = _rng.next();
    _b = _rng.next();
  }

  final Rng _rng;
  final double _step;
  double _t = 0, _a = 0, _b = 0;

  double next() {
    _t += _step;
    if (_t >= 1) {
      _t -= 1;
      _a = _b;
      _b = _rng.next();
    }
    final s = (1 - math.cos(math.pi * _t)) / 2;
    return _a + (_b - _a) * s;
  }
}

/// 以每樣本產生器填滿一段緩衝區。
Float32List renderSamples(int n, double Function() gen) {
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = gen();
  }
  return out;
}

double rmsOf(Float32List b) {
  if (b.isEmpty) return 0;
  var s = 0.0;
  for (final v in b) {
    s += v * v;
  }
  return math.sqrt(s / b.length);
}

double peakOf(Float32List b) {
  var p = 0.0;
  for (final v in b) {
    final a = v.abs();
    if (a > p) p = a;
  }
  return p;
}

/// 連續音層：把均方根調到 [target]。
Float32List normalizeRms(Float32List b, double target) {
  final r = rmsOf(b);
  if (r <= 1e-9) return b;
  final g = target / r;
  for (var i = 0; i < b.length; i++) {
    b[i] *= g;
  }
  return b;
}

/// 稀疏事件音層（雷、鳥鳴、劈啪聲）：把峰值調到 [target]。
Float32List normalizePeak(Float32List b, double target) {
  final p = peakOf(b);
  if (p <= 1e-9) return b;
  final g = target / p;
  for (var i = 0; i < b.length; i++) {
    b[i] *= g;
  }
  return b;
}

double smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// math.pow 回傳 num；音訊運算一律用 double。
double powd(num x, num y) => math.pow(x, y).toDouble();
