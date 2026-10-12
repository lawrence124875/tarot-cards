import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// 背景播放與通知列／鎖定畫面的媒體控制（audio_service，與智慧聽覺巡航同一套）。
/// 0.1.0+13 起取代 just_audio_background：它在 MIUI 鎖定畫面不顯示暫停鍵，
/// 這裡明確指定按鈕「暫停／播放、停止」並列為精簡按鈕。
class BreathAudioHandler extends BaseAudioHandler {
  BreathAudioHandler() {
    player.playbackEventStream.listen((_) => _broadcast(), onError: (Object _, StackTrace __) {});
    player.playingStream.listen((_) => _broadcast());
  }

  final AudioPlayer player = AudioPlayer();

  /// 整段練習中的播放位置（分段播放時由 JustAudioPlayback 換算），通知列進度條用。
  Duration Function()? positionOf;
  final _externalStops = StreamController<void>.broadcast();

  /// 使用者在通知列、鎖定畫面或耳機按了「停止」，或把 App 從最近使用列表滑掉。
  Stream<void> get externalStops => _externalStops.stream;

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [playing ? MediaControl.pause : MediaControl.play, MediaControl.stop],
      systemActions: const {MediaAction.play, MediaAction.pause, MediaAction.playPause, MediaAction.stop},
      androidCompactActionIndices: const [0, 1],
      processingState: switch (player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: positionOf?.call() ?? player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  @override
  Future<void> play() async => unawaited(player.play());

  @override
  Future<void> pause() => player.pause();

  /// 系統或通知按「停止」：通知 App 結束練習，再停止播放。
  @override
  Future<void> stop() async {
    _externalStops.add(null);
    await stopFromApp();
  }

  /// App 自己停止（練習結束或離開頁面），不發 externalStops。
  Future<void> stopFromApp() async {
    await player.stop();
    playbackState.add(playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.idle));
  }

  /// 從最近使用列表滑掉 App：停止播放，收掉通知與鎖定畫面卡片（智慧聽覺巡航的教訓）。
  @override
  Future<void> onTaskRemoved() => stop();
}
