import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/background_service.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/saudi_flag.dart';
import '../location/location_permission_screen.dart';
import 'tabs/prayer_tab.dart';
import 'tabs/quran_tab.dart';
import 'tabs/library_tab.dart';
import 'tabs/azkar_tab.dart';
import 'tabs/ai_tab.dart';
import 'tabs/settings_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _userName = 'مستخدم';
  String? _userPhoto;
  String _userCity = 'مكة المكرمة';
  bool _isLocationReady = false;
  int _currentBackground = 0;
  bool _isGoogleSignedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBackground();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final isGoogle = !(prefs.getBool('is_guest') ?? true);
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userPhoto = prefs.getString('user_photo');
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
      _isLocationReady = prefs.getBool('location_enabled') ?? false;
      _isGoogleSignedIn = isGoogle;
    });
  }

  Future<void> _loadBackground() async {
    final index = await BackgroundService.getCurrentIndex();
    if (mounted) setState(() => _currentBackground = index);
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
    );
  }

  void _onTabSelected(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _loadBackground();
    _loadUserData(); // ✅ إعادة تحميل بيانات المستخدم بعد أي تغيير
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return const PrayerTab();
      case 1:
        return const QuranTab();
      case 2:
        return const LibraryTab();
      case 3:
        return const AzkarTab();
      case 4:
        return const AiTab();
      case 5:
        return const SettingsTab();
      default:
        return const PrayerTab();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 تسجيل الدخول بحساب Google
  // ═══════════════════════════════════════════════════════════
  Future<void> _signInWithGoogle() async {
    try {
      final result = await AuthService.signInWithGoogle();
      if (result != null && mounted) {
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ مرحباً ${result['displayName']}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ فشل تسجيل الدخول: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 تسجيل الخروج
  // ═══════════════════════════════════════════════════════════
  Future<void> _signOut() async {
    await AuthService.signOut();
    await _loadUserData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('👋 تم تسجيل الخروج')),
      );
    }
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // صورة وأسم
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              backgroundImage: _userPhoto != null && _userPhoto!.isNotEmpty
                  ? NetworkImage(_userPhoto!)
                  : null,
              child: _userPhoto == null || _userPhoto!.isEmpty
                  ? const Icon(Icons.person,
                      color: Color(0xFFD4AF37), size: 40)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              _userName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _isGoogleSignedIn ? '✅ مسجّل بحساب Google' : '👤 مستخدم زائر',
              style: TextStyle(
                color: _isGoogleSignedIn ? Colors.green : Colors.orange,
                fontSize: 13,
              ),
            ),
            const Divider(color: Colors.grey, height: 30),

            if (!_isGoogleSignedIn)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _signInWithGoogle();
                },
                icon: const Icon(Icons.login),
                label: const Text('تسجيل الدخول بحساب Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: PreferredSize(
        // ✅ إصلاح: ارتفاع الشريط + ارتفاع شريط الحالة
        preferredSize: Size.fromHeight(70 + topPadding),
        child: _buildCustomAppBar(),
      ),
      body: BackgroundService.buildBackground(
        index: _currentBackground,
        child: _buildCurrentTab(),
      ),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الشريط العلوي (مُصلَّح)
  // ═══════════════════════════════════════════════════════════
  Widget _buildCustomAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2541), Color(0xFF0F1A2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          // ✅ ارتفاع ثابت للمحتوى بعد خصم status bar
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // شعار التطبيق
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF0B132B)],
                    ),
                    border:
                        Border.all(color: const Color(0xFFD4AF37), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.mosque,
                        color: Color(0xFFD4AF37), size: 24),
                  ),
                ),
                const SizedBox(width: 8),

                // اسم التطبيق
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'نور الحرمين',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    SizedBox(height: 1),
                    Row(
                      children: [
                        SizedBox(
                          width: 10,
                          height: 1,
                          child: ColoredBox(color: Color(0xFFD4AF37)),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'NOOR AL-HARAMAIN',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 7,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // زر المستخدم (يفتح القائمة)
                InkWell(
                  onTap: _showUserMenu,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isGoogleSignedIn
                          ? Colors.green.withValues(alpha: 0.15)
                          : const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isGoogleSignedIn
                            ? Colors.green.withValues(alpha: 0.5)
                            : const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // صورة المستخدم
                        ClipOval(
                          child: _userPhoto != null && _userPhoto!.isNotEmpty
                              ? Image.network(
                                  _userPhoto!,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Color(0xFFD4AF37),
                                    size: 18,
                                  ),
                                )
                              : Icon(
                                  _isGoogleSignedIn
                                      ? Icons.verified_user
                                      : Icons.person,
                                  color: _isGoogleSignedIn
                                      ? Colors.green
                                      : const Color(0xFFD4AF37),
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isGoogleSignedIn ? _userName : 'تسجيل',
                          style: TextStyle(
                            color: _isGoogleSignedIn
                                ? Colors.green
                                : const Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // علم السعودية
                const SaudiFlag(
                  height: 22,
                  width: 32,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(width: 6),

                // شعار ApexSec
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: Color(0xFFD4AF37), size: 9),
                      SizedBox(width: 2),
                      Text(
                        'ApexSec',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📱 الشريط السفلي
  // ═══════════════════════════════════════════════════════════
  Widget _buildBottomNav(String lang) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2541), Color(0xFF0F1A2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.access_time_rounded),
            label: TranslationService.getText(lang, 'nav_prayer'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_rounded),
            label: TranslationService.getText(lang, 'nav_quran'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.library_books_rounded),
            label: TranslationService.getText(lang, 'nav_library'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.live_tv_rounded),
            label: TranslationService.getText(lang, 'nav_azkar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bolt_rounded),
            label: TranslationService.getText(lang, 'nav_ai'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            label: TranslationService.getText(lang, 'nav_settings'),
          ),
        ],
      ),
    );
  }
}
