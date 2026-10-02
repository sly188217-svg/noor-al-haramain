import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// ═══════════════════════════════════════════════════════════
/// 💎 خدمة Premium — RevenueCat
/// ✅ Google Play + Huawei AppGallery
/// ✅ تفعيل فوري
/// ═══════════════════════════════════════════════════════════
class PremiumService {
  // ⚠️ استبدل هذه المفاتيح من RevenueCat
  static const String _googleApiKey = 'goog_xxxxxxxxxxxxxxxxxx';
  static const String _huaweiApiKey = 'huawei_xxxxxxxxxxxxxxxxxx';

  // ✅ معرف الصلاحية
  static const String _entitlementId = 'premium';

  static bool _isInitialized = false;
  static bool _isPremium = false;

  /// 🚀 التهيئة عند بدء التطبيق
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // ✅ اختيار المفتاح حسب المتجر
      final String apiKey = _detectApiKey();

      await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.error);

      await Purchases.configure(PurchasesConfiguration(apiKey));

      _isInitialized = true;
      debugPrint('✅ RevenueCat initialized');

      // ✅ فحص الحالة
      await checkPremiumStatus();

      // ✅ الاستماع للتغييرات
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

  /// 🔍 تحديد المفتاح حسب المنصة
  static String _detectApiKey() {
    // على Android، يمكن استخدام `Platform` لمعرفة إن كان Huawei
    // لكن لتبسيط الأمر، نستخدم المفتاح العام
    return _googleApiKey;
  }

  /// 💎 فحص حالة الاشتراك
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

  /// 🛒 جلب المنتجات
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('❌ فشل جلب المنتجات: $e');
      return null;
    }
  }

  /// 💳 شراء
  static Future<PurchaseResult> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);

      final isActive = result
              .customerInfo.entitlements.active[_entitlementId]?.isActive ??
          false;

      _isPremium = isActive;

      return PurchaseResult(
        success: isActive,
        message: isActive
            ? '✅ تم تفعيل الاشتراك بنجاح'
            : '⚠️ لم يتم التفعيل',
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

  /// 🔄 استعادة
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

  /// 🔍 هل Premium؟
  static bool get isPremium => _isPremium;

  /// 🎧 للاستماع للتغييرات في الواجهة
  static void listenToChanges(void Function(bool) onChanged) {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final isActive =
          customerInfo.entitlements.active[_entitlementId]?.isActive ?? false;
      _isPremium = isActive;
      onChanged(isActive);
    });
  }
}

/// 📦 نتيجة الشراء
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
