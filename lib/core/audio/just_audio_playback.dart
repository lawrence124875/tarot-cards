import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_playback.dart';
import 'breath_audio_handler.dart';

/// 以 just_audio 播放；背景播放與通知／鎖定畫面控制由 BreathAudioHandler（audio_service）處理。
/// 背景服務初始化失敗時退回一般播放器：仍可在前景播放，只是沒有通知控制。
class JustAudioPlayback implements AudioPlayback {
  static BreathAudioHandler? _handler;
  static String _album = '';

  /// [channelName]：通知類別名稱；[album]：鎖定畫面卡片上的 App 名稱（皆由 l10n 提供）。
  static Future<void> initBackground({required String channelName, required String album}) async {
    _album = album;
    try {
      _handler = await AudioService.init(
        builder: BreathAudioHandler.new,
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.lclab.tarot.breath',
          androidNotificationChannelName: channelName,
          androidNotificationIcon: 'drawable/ic_stat_tarot', // 單色牌與太陽（branding/draw_icon.py）
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      _handler = null; // 例如上次的背景服務還沒釋放；不影響 App 啟動
    }
  }

  late final AudioPlayer _player = _handler?.player ?? AudioPlayer();

  /// 每一段開始時，在整個清單中的位置。
  var _offsets = <Duration>[Duration.zero];

  @override
  Future<Duration?> load(
    List<AudioPart> parts, {
    required String id,
    required String title,
    String subtitle = '',
    String? artFilePath,
  }) async {
    var at = Duration.zero;
    _offsets = [];
    for (final p in parts) {
      _offsets.add(at);
      at += p.length;
    }
    final sources = {for (final p in parts) p.path: AudioSource.file(p.path)};
    await _player.setAudioSources([for (final p in parts) sources[p.path]!]);
    final d = at;
    _handler?.positionOf = () => position;
    _handler?.mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: subtitle,
      album: _album,
      duration: d,
      artUri: artFilePath == null ? null : Uri.file(artFilePath),
    ));
    return d;
  }

  @override
  Future<void> play() async {
    // just_audio 的 play() 要到停止播放才會完成，不能 await
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    final h = _handler;
    if (h != null) {
      await h.stopFromApp();
    } else {
      await _player.stop();
    }
  }

  @override
  Duration get position {
    final i = _player.currentIndex ?? 0;
    return (i < _offsets.length ? _offsets[i] : Duration.zero) + _player.position;
  }

  @override
  Stream<bool> get playingChanges => _player.playingStream;

  @override
  Stream<void> get completed =>
      _player.processingStateStream.where((s) => s == ProcessingState.completed).map((_) {});

  @override
  Stream<void> get stoppedExternally => _handler?.externalStops ?? const Stream.empty();
}
