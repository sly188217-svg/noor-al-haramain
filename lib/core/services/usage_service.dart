import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة تتبع الاستخدام اليومي
/// ═══════════════════════════════════════════════════════════
/// 
/// - المجاني: 3 تصحيحات يومياً + 5 أسئلة للمساعد
/// - المدفوع: غير محدود
/// 
class UsageService {
  static const int freeRecitationLimit = 3;
  static const int freeChatLimit = 5;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// ═══════════════════════════════════════════════════════════
  /// الحصول على UID الحالي
  /// ═══════════════════════════════════════════════════════════
  static String? get _uid => _auth.currentUser?.uid;

  /// ═══════════════════════════════════════════════════════════
  /// تاريخ اليوم بصيغة YYYY-MM-DD
  /// ═══════════════════════════════════════════════════════════
  static String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// ═══════════════════════════════════════════════════════════
  /// قراءة بيانات المستخدم
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getUserData() async {
    if (_uid == null) return {};

    try {
      final doc = await _db.collection('users').doc(_uid).get();
      if (!doc.exists) {
        // إنشاء مستند جديد
        final initialData = {
          'createdAt': FieldValue.serverTimestamp(),
          'subscription': 'free',
          'dailyRecitations': 0,
          'dailyChats': 0,
          'lastResetDate': _today,
          'totalRecitations': 0,
          'totalChats': 0,
        };
        await _db.collection('users').doc(_uid).set(initialData);
        return initialData;
      }

      final data = doc.data() ?? {};

      // إعادة التعيين اليومية
      if (data['lastResetDate'] != _today) {
        await _db.collection('users').doc(_uid).update({
          'dailyRecitations': 0,
          'dailyChats': 0,
          'lastResetDate': _today,
        });
        data['dailyRecitations'] = 0;
        data['dailyChats'] = 0;
        data['lastResetDate'] = _today;
      }

      return data;
    } catch (e) {
      debugPrint('❌ خطأ في قراءة بيانات المستخدم: $e');
      return {};
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// هل المستخدم Premium؟
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> isPremium() async {
    final data = await getUserData();
    return data['subscription'] == 'premium';
  }

  /// ═══════════════════════════════════════════════════════════
  /// هل يمكن للمستخدم إجراء تصحيح؟
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> canRecite() async {
    if (_uid == null) return false;
    final data = await getUserData();

    if (data['subscription'] == 'premium') return true;

    final count = data['dailyRecitations'] as int? ?? 0;
    return count < freeRecitationLimit;
  }

  /// ═══════════════════════════════════════════════════════════
  /// هل يمكن للمستخدم إرسال سؤال؟
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> canChat() async {
    if (_uid == null) return false;
    final data = await getUserData();

    if (data['subscription'] == 'premium') return true;

    final count = data['dailyChats'] as int? ?? 0;
    return count < freeChatLimit;
  }

  /// ═══════════════════════════════════════════════════════════
  /// زيادة عداد التصحيحات
  /// ═══════════════════════════════════════════════════════════
  static Future<void> incrementRecitation() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).update({
        'dailyRecitations': FieldValue.increment(1),
        'totalRecitations': FieldValue.increment(1),
        'lastResetDate': _today,
      });
    } catch (e) {
      debugPrint('❌ خطأ في زيادة العداد: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// زيادة عداد الأسئلة
  /// ═══════════════════════════════════════════════════════════
  static Future<void> incrementChat() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).update({
        'dailyChats': FieldValue.increment(1),
        'totalChats': FieldValue.increment(1),
        'lastResetDate': _today,
      });
    } catch (e) {
      debugPrint('❌ خطأ في زيادة العداد: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// المتبقي من التصحيحات المجانية اليوم
  /// ═══════════════════════════════════════════════════════════
  static Future<int> remainingRecitations() async {
    final data = await getUserData();
    if (data['subscription'] == 'premium') return -1; // غير محدود
    final count = data['dailyRecitations'] as int? ?? 0;
    final remaining = freeRecitationLimit - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// ═══════════════════════════════════════════════════════════
  /// المتبقي من الأسئلة المجانية اليوم
  /// ═══════════════════════════════════════════════════════════
  static Future<int> remainingChats() async {
    final data = await getUserData();
    if (data['subscription'] == 'premium') return -1;
    final count = data['dailyChats'] as int? ?? 0;
    final remaining = freeChatLimit - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// ═══════════════════════════════════════════════════════════
  /// ترقية المستخدم إلى Premium (للاستخدام بعد الدفع)
  /// ═══════════════════════════════════════════════════════════
  static Future<void> upgradeToPremium({
    required String productId,
    required DateTime expiry,
  }) async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).update({
        'subscription': 'premium',
        'productId': productId,
        'subscriptionExpiry': Timestamp.fromDate(expiry),
        'upgradedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ تم ترقية المستخدم إلى Premium');
    } catch (e) {
      debugPrint('❌ خطأ في الترقية: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// إلغاء الاشتراك
  /// ═══════════════════════════════════════════════════════════
  static Future<void> cancelPremium() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).update({
        'subscription': 'free',
        'subscriptionExpiry': null,
      });
      debugPrint('✅ تم إلغاء الاشتراك');
    } catch (e) {
      debugPrint('❌ خطأ في الإلغاء: $e');
    }
  }
}
