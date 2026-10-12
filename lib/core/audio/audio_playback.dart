/// 播放清單中的一個音檔與它的長度（長度用來把各段的播放位置換算成整段的位置）。
class AudioPart {
  const AudioPart(this.path, this.length);

  final String path;
  final Duration length;
}

/// 依序無縫播放幾個音檔（HANDOFF §9.1：平台相關的部分包在介面後面）。
/// 整個 App 只有一個播放器（背景播放與通知控制的套件只支援單一播放器）。
abstract class AudioPlayback {
  /// 載入播放清單並設定通知／鎖定畫面顯示的資訊，回傳總長度；失敗時拋出例外。
  Future<Duration?> load(
    List<AudioPart> parts, {
    required String id,
    required String title,
    String subtitle = '',
    String? artFilePath,
  });

  /// 開始或繼續播放（不等播完）。
  Future<void> play();
  Future<void> pause();

  /// 停止並移除通知。
  Future<void> stop();

  /// 目前在整個清單中的播放位置（播放中會依時間推算，適合每個畫格讀取）。
  Duration get position;

  /// 播放／暫停狀態改變（包含使用者在通知或鎖定畫面按的）。
  Stream<bool> get playingChanges;

  /// 播放到清單結尾。
  Stream<void> get completed;

  /// 使用者在通知列或鎖定畫面按了「停止」（或從最近使用列表滑掉 App）。
  Stream<void> get stoppedExternally;
}
