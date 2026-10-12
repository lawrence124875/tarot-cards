import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../monetization/premium_service.dart';

/// RevenueCat 實作（HANDOFF §23）。**唯一 import purchases_flutter 的檔案**。
///
/// - 金鑰：CI 以 --dart-define=REVENUECAT_API_KEY 注入（GitHub Secret `REVENUECAT_ANDROID_API_KEY`，
///   RevenueCat 專案「謙卦」的 Google Play 公開 SDK 金鑰，goog_ 開頭）。沒注入＝[FreePremium]。
/// - 權限 `premium`；Offering 預設（current）內放 Monthly、Annual 兩個 Package。
/// - FORCE_PREMIUM=true（只給個人測試建置）時一律視為訂閱戶。
class RevenueCatPremium implements PremiumService {
  RevenueCatPremium._();

  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const _forcePremium = bool.fromEnvironment('FORCE_PREMIUM');
  static const entitlementId = 'premium';

  static bool get configured => _apiKey.isNotEmpty;

  @override
  final ValueNotifier<bool> isPremium = ValueNotifier(_forcePremium);

  /// 金鑰沒設定或初始化失敗時回傳 [FreePremium]（App 照常可用，只是不能訂閱）。
  static Future<PremiumService> init() async {
    if (_forcePremium) return FreePremium(premium: true);
    if (_apiKey.isEmpty) return FreePremium();
    try {
      await Purchases.setLogLevel(kReleaseMode ? LogLevel.warn : LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      final p = RevenueCatPremium._();
      Purchases.addCustomerInfoUpdateListener(p._apply);
      // 啟動時查一次（有快取，離線也很快）；查不到就先當免費版，之後 listener 會更新
      try {
        p._apply(await Purchases.getCustomerInfo().timeout(const Duration(seconds: 8)));
      } catch (_) {}
      return p;
    } catch (e) {
      debugPrint('RevenueCat 初始化失敗：$e');
      return FreePremium();
    }
  }

  void _apply(CustomerInfo info) => isPremium.value = info.entitlements.active.containsKey(entitlementId);

  @override
  bool get canPurchase => true;

  @override
  Future<List<SubscriptionPlan>> plans() async {
    try {
      final current = (await Purchases.getOfferings()).current;
      if (current == null) return const [];
      return [
        if (current.monthly case final m?) SubscriptionPlan(period: PlanPeriod.monthly, price: m.storeProduct.priceString, handle: m),
        if (current.annual case final a?) SubscriptionPlan(period: PlanPeriod.yearly, price: a.storeProduct.priceString, handle: a),
      ];
    } catch (e) {
      debugPrint('讀取訂閱方案失敗：$e');
      return const [];
    }
  }

  @override
  Future<PurchaseOutcome> purchase(SubscriptionPlan plan) async {
    final pkg = plan.handle;
    if (pkg is! Package) return PurchaseOutcome.failed;
    try {
      final result = await Purchases.purchasePackage(pkg);
      _apply(result.customerInfo);
      return isPremium.value ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelled
          : PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<bool> restore() async {
    try {
      _apply(await Purchases.restorePurchases());
    } catch (_) {}
    return isPremium.value;
  }
}
