import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// 訂閱（HANDOFF §23）。畫面只認這個介面；RevenueCat 只出現在
/// `lib/core/revenuecat/revenuecat_premium.dart`（依 §9 依賴反轉）。
///
/// 權限（entitlement）一律叫 `premium`：月訂、年訂都掛在它底下。
/// 不在本機存「已訂閱」標記：每次啟動向 RevenueCat 查（同智慧聽覺巡航）。
abstract class PremiumService {
  /// 目前是否為訂閱戶；購買、恢復、啟動查詢後會更新。
  ValueListenable<bool> get isPremium;

  /// 能不能購買（RevenueCat 金鑰已設定且初始化成功）。false 時訂閱頁顯示「尚未開放」。
  bool get canPurchase;

  /// 目前可購買的方案（月訂、年訂）；查不到回傳空清單。
  Future<List<SubscriptionPlan>> plans();

  Future<PurchaseOutcome> purchase(SubscriptionPlan plan);

  /// 恢復購買（換手機、重裝）；回傳恢復後是否為訂閱戶。
  Future<bool> restore();
}

enum PlanPeriod { monthly, yearly }

enum PurchaseOutcome { success, cancelled, failed }

/// 一個可購買的方案。價格一律用商店（RevenueCat）回傳、已在地化的字串，不寫死幣別。
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.period,
    required this.price,
    this.amount,
    this.currencyCode,
    this.trialDays,
    this.handle,
  });

  final PlanPeriod period;

  /// 商店的當地價格字串（RevenueCat priceString，例：NT$590、US$24.99）。
  final String price;

  /// 數字價格與幣別（換算年繳每月約多少用）；商店沒給就是 null。
  final double? amount;
  final String? currencyCode;

  /// 免費試用天數（Play 的免費試用優惠；使用者不符資格時商店不會給）；沒有試用為 null。
  final int? trialDays;

  /// 實作端自己的物件（RevenueCat 的 Package），畫面不使用。
  final Object? handle;

  bool get hasTrial => (trialDays ?? 0) > 0;

  /// 年繳換算每月約多少（當地幣別符號沿用 [price] 的寫法）；算不出來回傳 null。
  /// RevenueCat Flutter SDK 沒有 pricePerMonthString，所以由 price／12 換算。
  String? perMonth(String locale) {
    final a = amount, code = currencyCode;
    if (period != PlanPeriod.yearly || a == null || a <= 0 || code == null || code.isEmpty) return null;
    final symbol = price.replaceAll(RegExp(r'[\p{N}.,\s\u066b\u066c]', unicode: true), '');
    final digitsFirst = RegExp(r'^[\p{N}]', unicode: true).hasMatch(price.trim());
    String fmt(String loc) {
      final f = NumberFormat.currency(locale: loc, name: code, symbol: '');
      final n = f.format(a / 12).trim();
      if (symbol.isEmpty) return '$n $code';
      return digitsFirst ? '$n $symbol' : '$symbol$n';
    }

    try {
      return fmt(locale);
    } catch (_) {
      try {
        return fmt('en');
      } catch (_) {
        return null;
      }
    }
  }
}

/// 沒有 RevenueCat（金鑰未設定、初始化失敗、測試）：永遠是免費版，不能購買。
class FreePremium implements PremiumService {
  FreePremium({bool premium = false}) : isPremium = ValueNotifier(premium);

  @override
  final ValueNotifier<bool> isPremium;

  @override
  bool get canPurchase => false;

  @override
  Future<List<SubscriptionPlan>> plans() async => const [];

  @override
  Future<PurchaseOutcome> purchase(SubscriptionPlan plan) async => PurchaseOutcome.failed;

  @override
  Future<bool> restore() async => isPremium.value;
}
