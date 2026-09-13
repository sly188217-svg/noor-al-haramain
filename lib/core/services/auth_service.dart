import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  /// ✅ دالة موحّدة: تحاول Google، فإن فشلت تستخدم زائر
  /// هي نفسها signInWithGoogle لكن مع fallback
  Future<Map<String, String>?> signIn() async {
    try {
      final result = await signInWithGoogle();
      if (result != null) return result;
    } catch (e) {
      // فشل Google، ننتقل للوضع التجريبي
    }

    // ✅ Fallback: حساب زائر محلي
    return await _signInAsGuest();
  }

  /// تسجيل الدخول بحساب Google
  static Future<Map<String, String>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', user.displayName ?? 'مستخدم');
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_uid', user.uid);
        await prefs.setBool('is_logged_in', true);

        return {
          'displayName': user.displayName ?? 'مستخدم',
          'email': user.email ?? '',
          'uid': user.uid,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// ✅ تسجيل دخول كزائر (محلياً، بدون Firebase)
  Future<Map<String, String>?> _signInAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const guestName = 'زائر';
      const guestUid = 'guest_local';

      await prefs.setString('user_name', guestName);
      await prefs.setString('user_email', '');
      await prefs.setString('user_uid', guestUid);
      await prefs.setBool('is_logged_in', true);

      return {
        'displayName': guestName,
        'email': '',
        'uid': guestUid,
      };
    } catch (e) {
      return null;
    }
  }

  /// تسجيل الخروج
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      // تجاهل
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_uid');
    await prefs.setBool('is_logged_in', false);
  }

  /// الحصول على اسم المستخدم
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'مستخدم';
  }
}
