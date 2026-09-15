import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة المصادقة — Google + Firebase
/// ═══════════════════════════════════════════════════════════
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// ✅ serverClientId من google-services.json
  /// موجود في Firebase Console → Project Settings → Your apps
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '264723055815-h4f5e0p3rrl15vvnr9gp2er9f3r1h4tq.apps.googleusercontent.com',
  );

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  /// ═══════════════════════════════════════════════════════════
  /// دالة موحّدة: Google أو زائر
  /// ═══════════════════════════════════════════════════════════
  Future<Map<String, String>?> signIn() async {
    try {
      final result = await signInWithGoogle();
      if (result != null) return result;
    } catch (e) {
      debugPrint('⚠️ Google فشل: $e');
    }
    return await _signInAsGuest();
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل Google
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, String>?> signInWithGoogle() async {
    try {
      // 1. تسجيل الخروج أولاً لضمان اختيار الحساب
      await _googleSignIn.signOut();

      // 2. فتح نافذة الحساب
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ المستخدم ألغى');
        return null;
      }

      debugPrint('✅ Google user: ${googleUser.email}');

      // 3. الحصول على Tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('🔑 idToken: ${googleAuth.idToken != null}');
      debugPrint('🔑 accessToken: ${googleAuth.accessToken != null}');

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('لم يتم الحصول على tokens');
      }

      // 4. Firebase Credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. تسجيل الدخول في Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _saveUser(user);
        return {
          'displayName': user.displayName ?? 'مستخدم',
          'email': user.email ?? '',
          'uid': user.uid,
          'photoURL': user.photoURL ?? '',
        };
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuth: ${e.code} — ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Google: $e');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل زائر (محلي)
  /// ═══════════════════════════════════════════════════════════
  Future<Map<String, String>?> _signInAsGuest() async {
    try {
      User? firebaseUser;
      try {
        if (_auth.currentUser == null) {
          final cred = await _auth.signInAnonymously();
          firebaseUser = cred.user;
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
      debugPrint('❌ Guest فشل: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// حفظ بيانات المستخدم
  /// ═══════════════════════════════════════════════════════════
  static Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.displayName ?? 'مستخدم');
    await prefs.setString('user_email', user.email ?? '');
    await prefs.setString('user_uid', user.uid);
    await prefs.setString('user_photo', user.photoURL ?? '');
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    debugPrint('✅ محفوظ: ${user.displayName}');
  }

  /// ═══════════════════════════════════════════════════════════
  /// تسجيل الخروج
  /// ═══════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
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
