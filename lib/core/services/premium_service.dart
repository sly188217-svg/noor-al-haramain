import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// ═══════════════════════════════════════════════════════════
/// 💎 خدمة Premium — RevenueCat
/// ✅ Google Play + Huawei AppGallery
/// ✅ تفعيل فوري
/// ═══════════════════════════════════════════════════════════
class PremiumService {
  // ✅ المفاتيح من .env (أكثر أماناً)
  static String get _googleApiKey =>
      dotenv.env['REVENUECAT_GOOGLE_KEY'] ?? '';
  static String get _huaweiApiKey =>
      dotenv.env['REVENUECAT_HUAWEI_KEY'] ?? '';

  static const String _entitlementId = 'Noor Al-Haramain Premium';

  static bool _isInitialized = false;

  /// ✅ هل الخدمة جاهزة؟
  static bool get initialized => _isInitialized;
  static bool _isPremium = false;

  /// 🚀 التهيئة عند بدء التطبيق
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = _detectApiKey();
    if (apiKey.isEmpty) {
      debugPrint('⚠️ RevenueCat API Key مفقود في .env');
      return;
    }

    try {
      await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.error);

      await Purchases.configure(PurchasesConfiguration(apiKey));

      _isInitialized = true;
      debugPrint('✅ RevenueCat initialized');

      await checkPremiumStatus();

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        final isActive = customerInfo
                .entitlements.active[_entitlementId]?.isActive ??
            false;
        if (_isPremium != isActive) {
          _isPremium = isActive;
          debugPrint('💎 Premium status changed: $isActive');
        }
      });
    } catch (e) {
      debugPrint('❌ فشل تهيئة RevenueCat: $e');
    }
  }

  static String _detectApiKey() {
    return _googleApiKey;
  }

  static Future<bool> checkPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium =
          customerInfo.entitlements.active[_entitlementId]?.isActive ?? false;
      debugPrint('💎 Premium: $_isPremium');
      return _isPremium;
    } catch (e) {
      debugPrint('❌ فشل فحص الاشتراك: $e');
      return false;
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('❌ فشل جلب المنتجات: $e');
      return null;
    }
  }

  static Future<PurchaseResult> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      final isActive = result.customerInfo
              .entitlements.active[_entitlementId]?.isActive ??
          false;
      _isPremium = isActive;
      return PurchaseResult(
        success: isActive,
        message: isActive ? '✅ تم تفعيل الاشتراك بنجاح' : '⚠️ لم يتم التفعيل',
        customerInfo: result.customerInfo,
      );
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(success: false, message: 'تم إلغاء الشراء');
      }
      return PurchaseResult(success: false, message: 'خطأ: ${e.message}');
    } catch (e) {
      return PurchaseResult(success: false, message: 'خطأ: $e');
    }
  }

  static Future<PurchaseResult> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isActive =
          customerInfo.entitlements.active[_entitlementId]?.isActive ?? false;
      _isPremium = isActive;
      return PurchaseResult(
        success: isActive,
        message: isActive ? '✅ تم استعادة الاشتراك' : 'لا يوجد اشتراك نشط',
        customerInfo: customerInfo,
      );
    } catch (e) {
      return PurchaseResult(success: false, message: 'خطأ: $e');
    }
  }

  static bool get isPremium => _isPremium;

  static void listenToChanges(void Function(bool) onChanged) {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final isActive =
          customerInfo.entitlements.active[_entitlementId]?.isActive ?? false;
      _isPremium = isActive;
      onChanged(isActive);
    });
  }
}

class PurchaseResult {
  final bool success;
  final String message;
  final CustomerInfo? customerInfo;

  PurchaseResult({
    required this.success,
    required this.message,
    this.customerInfo,
  });
}
