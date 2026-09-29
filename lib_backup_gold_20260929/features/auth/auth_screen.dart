import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../location/location_permission_screen.dart';

class AuthScreen extends StatefulWidget {
  final String selectedLang;
  const AuthScreen({super.key, required this.selectedLang});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);

    final userData = await _authService.signIn();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (userData != null) {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'مستخدم';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ مرحباً $userName! تمت المزامنة بنجاح')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const LocationPermissionScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل تسجيل الدخول، حاول مجدداً')),
      );
    }
  }

  Future<void> _skipSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ "مستخدم" بدلاً من "زائر" أو "(Mock)"
    await prefs.setString('user_name', 'مستخدم');
    await prefs.setString('user_email', '');
    await prefs.setString('user_uid', 'local_user');
    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const LocationPermissionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, color: Color(0xFFD4AF37), size: 80),
              const SizedBox(height: 20),
              const Text(
                'مرحباً بك في نور الحرمين',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'سجّل دخولك لمزامنة بياناتك عبر أجهزتك',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleSignIn,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata,
                          color: Colors.blue, size: 30),
                  label: Text(
                    _isLoading
                        ? 'جاري المزامنة...'
                        : '🚀 تسجيل الدخول بحساب Google',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _skipSignIn,
                child: const Text(
                  'تخطي (المتابعة كمستخدم) →',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🔒 بياناتك محفوظة على جهازك ولا تُشارك مع أي طرف ثالث',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
