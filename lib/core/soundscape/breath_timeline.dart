import 'dsp.dart';

enum BreathPhase { prepare, inhale, exhale, done }

class BreathState {
  const BreathState(this.phase, this.progress, {this.cycle = 0, this.secondsLeftInPhase = 0});

  final BreathPhase phase;

  /// 此階段已進行的比例 0–1。
  final double progress;
  final int cycle;
  final double secondsLeftInPhase;

  /// 呼吸圓的大小（0＝最小、1＝最大），與音景音量起伏使用同一條曲線。
  double get fullness => switch (phase) {
        BreathPhase.prepare => 0,
        BreathPhase.inhale => smoothstep(progress),
        BreathPhase.exhale => 1 - smoothstep(progress),
        BreathPhase.done => 0,
      };
}

/// 呼吸節奏（2026-10-02 決定：吸 4 秒、吐 6 秒，每分鐘 6 次）。
class BreathPattern {
  const BreathPattern({this.inhale = 4, this.exhale = 6});

  final double inhale;
  final double exhale;

  double get cycle => inhale + exhale;

  BreathState at(double t) {
    final c = (t / cycle).floor();
    final inCycle = t - c * cycle;
    if (inCycle < inhale) {
      return BreathState(BreathPhase.inhale, inCycle / inhale, cycle: c, secondsLeftInPhase: inhale - inCycle);
    }
    final e = inCycle - inhale;
    return BreathState(BreathPhase.exhale, e / exhale, cycle: c, secondsLeftInPhase: exhale - e);
  }
}

/// 一次呼吸練習的時間軸（以音檔時間為準）：
/// 準備 [leadIn] 秒（音景淡入）→ 呼吸 [minutes] 分鐘 → 收尾 [tail] 秒（音景淡出）。
/// 畫面與音檔都由這裡推算，兩者因此永遠同步。
class SessionTimeline {
  const SessionTimeline({
    required this.minutes,
    this.pattern = const BreathPattern(),
    this.leadIn = 3,
    this.tail = 5,
    this.depth = 0.35,
  });

  final int minutes;
  final BreathPattern pattern;
  final double leadIn;
  final double tail;

  /// 音景隨呼吸起伏的深度（吐氣到底時音量為 1 − depth）。
  final double depth;

  double get breathSeconds => minutes * 60.0;
  double get breathEnd => leadIn + breathSeconds;
  double get totalSeconds => breathEnd + tail;

  BreathState at(double audioSeconds) {
    if (audioSeconds < leadIn) {
      return BreathState(BreathPhase.prepare, audioSeconds / leadIn, secondsLeftInPhase: leadIn - audioSeconds);
    }
    if (audioSeconds >= breathEnd) return const BreathState(BreathPhase.done, 1);
    return pattern.at(audioSeconds - leadIn);
  }

  /// 音景音量：準備時淡入，呼吸時隨吸吐起伏，結束後淡出。
  double bedGain(double audioSeconds) {
    final low = 1 - depth;
    if (audioSeconds < leadIn) return low * smoothstep(audioSeconds / leadIn);
    if (audioSeconds >= breathEnd) return low * (1 - smoothstep((audioSeconds - breathEnd) / tail));
    return low + depth * pattern.at(audioSeconds - leadIn).fullness;
  }

  /// 鈴聲時間點：每次吸氣開始（高音）、吐氣開始（低音），以及結束鈴。
  List<({double time, BellKind kind})> bells() {
    final out = <({double time, BellKind kind})>[];
    for (var t = 0.0; t < breathSeconds - 1e-6; t += pattern.cycle) {
      out.add((time: leadIn + t, kind: BellKind.inhale));
      out.add((time: leadIn + t + pattern.inhale, kind: BellKind.exhale));
    }
    out.add((time: breathEnd, kind: BellKind.end));
    return out;
  }
}

enum BellKind { inhale, exhale, end }
