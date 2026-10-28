import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'free_limits.dart';

/// 今天還能不能起卦。
enum CastAllowance {
  /// 免費次數還有（或是訂閱戶）。
  free,

  /// 免費次數用完，但還能看獎勵廣告換一次。
  needsReward,

  /// 免費與獎勵次數都用完，明天再來或訂閱。
  exhausted,
}

/// 允許的這一次抽牌是怎麼來的（決定要不要播插頁，HANDOFF H 第 5 點）。
class CastGrant {
  const CastGrant({required this.premium, required this.rewarded, required this.dailyIndex, this.firstEver = false});

  /// 訂閱戶（不計次、沒有廣告）。
  final bool premium;

  /// 這次是看獎勵廣告換來的（不再播插頁）。
  final bool rewarded;

  /// 今天第幾次抽牌（從 1 起算；訂閱戶為 0）。
  final int dailyIndex;

  /// 這台裝置第一次抽牌（統計 first_draw）。
  final bool firstEver;

  /// 每日第 1 次免費抽牌：解讀前播一則插頁。
  bool get wantsInterstitial => !premium && !rewarded && dailyIndex == 1;
}

/// 每日起卦次數（本機計數，跨日自動歸零；以手機當地日期為準）。
/// 計數只存在本機檔案，不上傳；重裝 App 會歸零，這是可接受的寬鬆。
class CastQuota {
  CastQuota({required this.limits, QuotaStorage? storage, DateTime Function()? clock})
      : _storage = storage ?? FileQuotaStorage(),
        _clock = clock ?? DateTime.now;

  FreeLimits limits;
  final QuotaStorage _storage;
  final DateTime Function() _clock;

  String _day = '';
  int _used = 0; // 今天已起卦次數（含用獎勵換來的）
  int _rewarded = 0; // 今天看獎勵廣告換到的次數
  bool _everDrawn = false; // 這台裝置抽過牌沒（不跨日歸零）
  bool _loaded = false;

  String _today() {
    final n = _clock();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensure() async {
    if (!_loaded) {
      final m = await _storage.read();
      _day = m['day'] as String? ?? '';
      _used = (m['used'] as num?)?.toInt() ?? 0;
      _rewarded = (m['rewarded'] as num?)?.toInt() ?? 0;
      _everDrawn = m['ever'] == true;
      _loaded = true;
    }
    final today = _today();
    if (_day != today) {
      _day = today;
      _used = 0;
      _rewarded = 0;
    }
  }

  Future<void> _persist() => _storage.write({'day': _day, 'used': _used, 'rewarded': _rewarded, 'ever': _everDrawn});

  /// 可用次數＝免費次數＋今天看廣告換到的次數。
  Future<CastAllowance> check() async {
    await _ensure();
    if (_used < limits.castsPerDay + _rewarded) return CastAllowance.free;
    return _rewarded < limits.rewardedPerDay ? CastAllowance.needsReward : CastAllowance.exhausted;
  }

  /// 今天剩幾次免費（不含獎勵）；顯示用。
  Future<int> freeLeft() async {
    await _ensure();
    final left = limits.castsPerDay + _rewarded - _used;
    return left < 0 ? 0 : left;
  }

  /// 抽牌成功時呼叫一次。免費版計次；訂閱戶（[premium]）不計次，只記「抽過牌」。
  /// [rewarded]：這次是看獎勵廣告換來的。
  Future<CastGrant> recordCast({bool premium = false, bool rewarded = false}) async {
    await _ensure();
    final first = !_everDrawn;
    _everDrawn = true;
    if (!premium) _used++;
    if (!premium || first) await _persist();
    return CastGrant(premium: premium, rewarded: rewarded, dailyIndex: premium ? 0 : _used, firstEver: first);
  }

  /// 看完獎勵廣告（或廣告載入失敗、無填充時照樣給予）：多一次抽牌，計入每日獎勵上限。
  Future<void> grantReward() async {
    await _ensure();
    _rewarded++;
    await _persist();
  }
}

abstract class QuotaStorage {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> data);
}

class MemoryQuotaStorage implements QuotaStorage {
  Map<String, Object?> data = {};

  @override
  Future<Map<String, Object?>> read() async => {...data};

  @override
  Future<void> write(Map<String, Object?> d) async => data = {...d};
}

/// 存在 App 文件資料夾的 `quota.json`（與卦記同一個資料夾，不需權限）。
class FileQuotaStorage implements QuotaStorage {
  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/quota.json');

  @override
  Future<Map<String, Object?>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, Object?> data) async {
    try {
      await (await _file()).writeAsString(jsonEncode(data));
    } catch (_) {
      // 寫不進去只會讓計數寬鬆，不影響使用
    }
  }
}
