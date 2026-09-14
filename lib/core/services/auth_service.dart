import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة المصادقة — Google + Firebase
/// ═══════════════════════════════════════════════════════════
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ GoogleSignIn مع serverClientId
  /// ⚠️ serverClientId من google-services.json (oauth_client مع client_type: 3)
  /// إذا لم يوجد، سيستخدم Google Sign-In الإعدادات الافتراضية
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  /// ═══════════════════════════════════════════════════════════
  /// دالة موحّدة: تحاول Google، فإن فشلت تستخدم زائر
  /// ═══════════════════════════════════════════════════════════
  Future<Map<String, String>?> signIn() async {
    try {
      final result = await signInWithGoogle();
      if (result != null) return result;
    } catch (e) {
      debugPrint('⚠️ Google Sign-In فشل: $e');
    }
    // Fallback: حساب زائر محلي
    return await _signInAsGuest();
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل الدخول بحساب Google
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, String>?> signInWithGoogle() async {
    try {
      // 1. تسجيل الخروج أولاً (لضمان اختيار الحساب)
      await _googleSignIn.signOut();

      // 2. فتح نافذة اختيار الحساب
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ المستخدم ألغى تسجيل الدخول');
        return null;
      }

      // 3. الحصول على tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        debugPrint('❌ لم يتم الحصول على tokens');
        return null;
      }

      // 4. إنشاء credential لـ Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. تسجيل الدخول في Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // 6. حفظ بيانات المستخدم محلياً
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', user.displayName ?? 'مستخدم');
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_uid', user.uid);
        await prefs.setString('user_photo', user.photoURL ?? '');
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('is_guest', false);

        debugPrint('✅ تم تسجيل الدخول: ${user.email}');
        return {
          'displayName': user.displayName ?? 'مستخدم',
          'email': user.email ?? '',
          'uid': user.uid,
          'photoURL': user.photoURL ?? '',
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل دخول كزائر (محلياً، بدون Firebase)
  /// ═══════════════════════════════════════════════════════════
  Future<Map<String, String>?> _signInAsGuest() async {
    try {
      // ✅ محاولة تسجيل دخول مجهول في Firebase أولاً
      UserCredential? credential;
      try {
        if (_auth.currentUser == null) {
          credential = await _auth.signInAnonymously();
        }
      } catch (e) {
        debugPrint('⚠️ Anonymous Auth فشل: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      const guestName = 'زائر';
      final guestUid = credential?.user?.uid ?? 'guest_local';

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
      debugPrint('❌ فشل تسجيل الزائر: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل الخروج
  /// ═══════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('⚠️ خطأ في تسجيل الخروج: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_uid');
    await prefs.remove('user_photo');
    await prefs.setBool('is_logged_in', false);
    await prefs.setBool('is_guest', false);
  }

  /// ═══════════════════════════════════════════════════════════
  /// الحصول على اسم المستخدم
  /// ═══════════════════════════════════════════════════════════
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'مستخدم';
  }

  /// ═══════════════════════════════════════════════════════════
  /// هل المستخدم زائر؟
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_guest') ?? false;
  }
}
