import 'dart:async';

/// 事件只給「旁觀者」（紀錄、統計、評分提醒…）。主流程（抽牌→解讀）直接呼叫，不走事件。
abstract class AppEvent {
  const AppEvent();
}

/// 使用者看到一次解讀。
class ReadingShown extends AppEvent {
  const ReadingShown({required this.methodId, required this.spreadId, required this.keyCard, required this.reversed});

  final String methodId;
  final String spreadId;

  /// 牌陣關鍵位置的那張牌（00–77）。
  final int keyCard;

  /// 逆位張數。
  final int reversed;
}

/// 存了一筆日記（不帶任何文字內容）。
class JournalSaved extends AppEvent {
  const JournalSaved({required this.hasReminder});

  final bool hasReminder;
}

/// 開始一次呼吸練習。
class BreathStarted extends AppEvent {
  const BreathStarted({required this.cardId, required this.minutes, required this.silent, required this.binaural});

  final int cardId;
  final int minutes;
  final bool silent;
  final bool binaural;
}

/// 呼吸練習完整做完（從通知列提早停止的不算）。
class BreathCompleted extends AppEvent {
  const BreathCompleted({required this.cardId, required this.minutes});

  final int cardId;
  final int minutes;
}

/// 打開訂閱頁（source：cast_limit、journal_limit、breath、menu）。
class PaywallShown extends AppEvent {
  const PaywallShown({required this.source});

  final String source;
}

/// 看完一支獎勵廣告並拿到獎勵（source：cast、journal）。
class RewardedEarned extends AppEvent {
  const RewardedEarned({required this.source});

  final String source;
}

/// 購買或恢復訂閱成功（period：monthly、yearly、restore）。
class Subscribed extends AppEvent {
  const Subscribed({required this.period});

  final String period;
}

class EventBus {
  final _controller = StreamController<AppEvent>.broadcast();

  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();

  void emit(AppEvent event) => _controller.add(event);
}
