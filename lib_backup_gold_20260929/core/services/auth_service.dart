import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🔐 خدمة المصادقة — Firebase Anonymous فقط
/// ✅ لا نحتاج Google Sign-In
/// ✅ Google Play سيتكفل بالاشتراكات
/// ✅ Anonymous يكفي لـ Firestore
/// ═══════════════════════════════════════════════════════════
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل الدخول التلقائي (Anonymous)
  /// ═══════════════════════════════════════════════════════════
  Future<Map<String, String>?> signIn() async {
    try {
      User? firebaseUser;
      try {
        if (_auth.currentUser == null) {
          final cred = await _auth.signInAnonymously();
          firebaseUser = cred.user;
          debugPrint('✅ Firebase Anonymous: ${firebaseUser?.uid}');
        } else {
          firebaseUser = _auth.currentUser;
        }
      } catch (e) {
        debugPrint('⚠️ Anonymous فشل: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      const guestName = 'مستخدم';
      final guestUid = firebaseUser?.uid ?? 'guest_local';

      await prefs.setString('user_name', guestName);
      await prefs.setString('user_email', '');
      await prefs.setString('user_uid', guestUid);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', true);

      return {
        'displayName': guestName,
        'email': '',
        'uid': guestUid,
        'photoURL': '',
      };
    } catch (e) {
      debugPrint('❌ فشل signIn: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل الخروج
  /// ═══════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('⚠️ SignOut: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_uid');
    await prefs.remove('user_photo');
    await prefs.setBool('is_logged_in', false);
    await prefs.setBool('is_guest', false);
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'مستخدم';
  }
}
