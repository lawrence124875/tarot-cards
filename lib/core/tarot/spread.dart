/// 牌陣中的一個位置。[x]、[y] 是版面上的格點（牌寬＝1、牌高＝1.6 的座標），[crossed] 為橫放（凱爾特十字第 2 張）。
/// 位置名稱與意義依語言放在內容檔（spreads.json），這裡只有代號與版面。
class SpreadPosition {
  const SpreadPosition(this.key, this.x, this.y, {this.crossed = false});

  final String key;
  final double x;
  final double y;
  final bool crossed;
}

/// 牌陣（策略：新增牌陣＝在 [Spreads.all] 加一個，並在內容檔 spreads.json 寫名稱與位置意義）。
class Spread {
  const Spread({
    required this.id,
    required this.positions,
    required this.keyPosition,
    this.premium = false,
    this.source = SpreadSource.convention,
  });

  final String id;
  final List<SpreadPosition> positions;

  /// 代表整個牌陣的位置（音景元素、分享卡、日記列表縮圖取這張牌）。
  final int keyPosition;

  /// 會員牌陣（免費版看得到但點了開訂閱頁）。
  final bool premium;

  /// 來源：經典文獻（凱爾特十字見 Waite 1910 第三部）或現代常見做法。
  final SpreadSource source;

  int get size => positions.length;
}

enum SpreadSource { waite, convention }

class Spreads {
  Spreads._();

  static const one = Spread(
    id: 'one',
    positions: [SpreadPosition('focus', 0, 0)],
    keyPosition: 0,
  );

  static const three = Spread(
    id: 'three',
    positions: [
      SpreadPosition('past', 0, 0),
      SpreadPosition('present', 1.2, 0),
      SpreadPosition('future', 2.4, 0),
    ],
    keyPosition: 1,
  );

  /// 二選一：下方是現在，左右兩條路各兩張（做法→可能的走向）。
  static const choice = Spread(
    id: 'choice',
    positions: [
      SpreadPosition('now', 1.2, 3.6),
      SpreadPosition('pathA', 0, 1.8),
      SpreadPosition('outcomeA', 0, 0),
      SpreadPosition('pathB', 2.4, 1.8),
      SpreadPosition('outcomeB', 2.4, 0),
    ],
    keyPosition: 0,
    premium: true,
  );

  /// 關係：你、對方、你們之間，下方是課題，上方是可以一起走的方向。
  static const relationship = Spread(
    id: 'relationship',
    positions: [
      SpreadPosition('you', 0, 1.8),
      SpreadPosition('other', 2.4, 1.8),
      SpreadPosition('between', 1.2, 1.8),
      SpreadPosition('challenge', 1.2, 3.6),
      SpreadPosition('direction', 1.2, 0),
    ],
    keyPosition: 2,
    premium: true,
  );

  /// 凱爾特十字（Waite《The Pictorial Key to the Tarot》1910 第三部〈An Ancient Celtic Method of Divination〉）：
  /// 1 覆蓋、2 橫越、3 頭頂、4 腳下、5 身後、6 面前，7–10 在右側由下而上：自己、環境、希望與恐懼、結果。
  static const celtic = Spread(
    id: 'celtic',
    positions: [
      SpreadPosition('cover', 1.4, 2.7),
      SpreadPosition('cross', 1.4, 2.7, crossed: true),
      SpreadPosition('crown', 1.4, 0.9),
      SpreadPosition('beneath', 1.4, 4.5),
      SpreadPosition('behind', 0, 2.7),
      SpreadPosition('before', 2.8, 2.7),
      SpreadPosition('self', 4.4, 5.4),
      SpreadPosition('house', 4.4, 3.6),
      SpreadPosition('hopes', 4.4, 1.8),
      SpreadPosition('outcome', 4.4, 0),
    ],
    keyPosition: 0,
    premium: true,
    source: SpreadSource.waite,
  );

  static const all = [one, three, choice, relationship, celtic];

  static Spread byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => one);
}
