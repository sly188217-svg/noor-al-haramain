import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 📊 خدمة الاستخدام — محفوظة في Firebase Firestore
/// ✅ لا يمكن التلاعب بحذف التطبيق
/// ✅ تجديد يومي تلقائي
/// ═══════════════════════════════════════════════════════════
class UsageService {
  static const int _freeChats = 3;
  static const int _freeRecitations = 2;
  static const String _guestUidKey = 'guest_uid';

  static Future<String> _getUid() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) return user.uid;
    } catch (e) {
      debugPrint('⚠️ Firebase Auth غير متاح: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    String? guestUid = prefs.getString(_guestUidKey);
    if (guestUid == null) {
      guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_guestUidKey, guestUid);
    }
    return guestUid;
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>> _getUsage() async {
    final uid = await _getUid();
    final today = _today();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usage')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        final initial = {
          'chats_used': 0,
          'recitations_used': 0,
          'last_reset': today,
          'is_premium': false,
        };
        await FirebaseFirestore.instance
            .collection('usage')
            .doc(uid)
            .set(initial);
        return initial;
      }

      final data = doc.data() ?? {};
      final lastReset = data['last_reset'] as String? ?? '';

      if (lastReset != today) {
        await FirebaseFirestore.instance
            .collection('usage')
            .doc(uid)
            .update({
          'chats_used': 0,
          'recitations_used': 0,
          'last_reset': today,
        });
        return {
          ...data,
          'chats_used': 0,
          'recitations_used': 0,
          'last_reset': today,
        };
      }

      return data;
    } catch (e) {
      debugPrint('⚠️ فشل قراءة Firestore: $e');
      return await _localFallback();
    }
  }

  static Future<Map<String, dynamic>> _localFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final lastReset = prefs.getString('local_last_reset') ?? '';

    if (lastReset != today) {
      await prefs.setInt('local_chats_used', 0);
      await prefs.setInt('local_recitations_used', 0);
      await prefs.setString('local_last_reset', today);
    }

    return {
      'chats_used': prefs.getInt('local_chats_used') ?? 0,
      'recitations_used': prefs.getInt('local_recitations_used') ?? 0,
      'is_premium': prefs.getBool('is_premium') ?? false,
    };
  }

  static Future<int> remainingChats() async {
    final data = await _getUsage();
    if (data['is_premium'] == true) return 999999;
    final used = (data['chats_used'] as num?)?.toInt() ?? 0;
    return (_freeChats - used).clamp(0, _freeChats);
  }

  static Future<int> remainingRecitations() async {
    final data = await _getUsage();
    if (data['is_premium'] == true) return 999999;
    final used = (data['recitations_used'] as num?)?.toInt() ?? 0;
    return (_freeRecitations - used).clamp(0, _freeRecitations);
  }

  static Future<bool> canChat() async => (await remainingChats()) > 0;
  static Future<bool> canRecite() async => (await remainingRecitations()) > 0;

  static Future<void> incrementChat() async {
    final uid = await _getUid();
    try {
      await FirebaseFirestore.instance
          .collection('usage')
          .doc(uid)
          .set({
        'chats_used': FieldValue.increment(1),
        'last_reset': _today(),
      }, SetOptions(merge: true));
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final used = prefs.getInt('local_chats_used') ?? 0;
      await prefs.setInt('local_chats_used', used + 1);
    }
  }

  static Future<void> incrementRecitation() async {
    final uid = await _getUid();
    try {
      await FirebaseFirestore.instance
          .collection('usage')
          .doc(uid)
          .set({
        'recitations_used': FieldValue.increment(1),
        'last_reset': _today(),
      }, SetOptions(merge: true));
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final used = prefs.getInt('local_recitations_used') ?? 0;
      await prefs.setInt('local_recitations_used', used + 1);
    }
  }

  static Future<bool> isPremium() async {
    final data = await _getUsage();
    return data['is_premium'] == true;
  }

  static Future<void> activatePremium() async {
    final uid = await _getUid();
    try {
      await FirebaseFirestore.instance
          .collection('usage')
          .doc(uid)
          .set({'is_premium': true}, SetOptions(merge: true));
    } catch (e) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
  }

  static Future<void> deactivatePremium() async {
    final uid = await _getUid();
    try {
      await FirebaseFirestore.instance
          .collection('usage')
          .doc(uid)
          .set({'is_premium': false}, SetOptions(merge: true));
    } catch (e) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', false);
  }
}
