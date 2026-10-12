import 'package:flutter/foundation.dart';

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

/// 一個可購買的方案。[price] 是商店回傳、已在地化的價格字串（例：NT$90）。
class SubscriptionPlan {
  const SubscriptionPlan({required this.period, required this.price, this.monthlyEquivalent, this.handle});

  final PlanPeriod period;
  final String price;

  /// 年訂換算每月（例：NT$50），商店有提供才顯示。
  final String? monthlyEquivalent;

  /// 實作端自己的物件（RevenueCat 的 Package），畫面不使用。
  final Object? handle;
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
