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

/// 這台裝置第一次抽牌（漏斗起點）。
class FirstDraw extends AppEvent {
  const FirstDraw({required this.spreadId});

  final String spreadId;
}

/// 碰到免費版限制（type：draw、spread、lesson、journal、breath）。
class HitFreeLimit extends AppEvent {
  const HitFreeLimit({required this.type});

  final String type;
}

/// 獎勵廣告播出（source：cast、journal；earned：有沒有看完拿到獎勵）。
class RewardedAdShown extends AppEvent {
  const RewardedAdShown({required this.source, required this.earned});

  final String source;
  final bool earned;
}

/// 獎勵廣告載入失敗、無填充或顯示失敗。
class RewardedAdFailed extends AppEvent {
  const RewardedAdFailed({required this.source});

  final String source;
}

/// 每日第 1 次抽牌的插頁播出。
class InterstitialShown extends AppEvent {
  const InterstitialShown();
}

/// 插頁載入失敗、無填充、逾時 3 秒或顯示失敗（直接顯示解讀）。
class InterstitialFailed extends AppEvent {
  const InterstitialFailed();
}

/// 打開訂閱頁（source：cast_limit、spread_<id>、lesson_<unitId>、lesson_preview_<unitId>、
/// journal_limit、breath、deck_<id>、menu）。
class PaywallShown extends AppEvent {
  const PaywallShown({required this.source});

  final String source;
}

/// 開始免費試用（購買了帶試用優惠的方案）。
class TrialStarted extends AppEvent {
  const TrialStarted({required this.period});

  final String period;
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
