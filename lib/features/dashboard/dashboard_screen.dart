import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/background_service.dart';
import '../../core/services/translation_service.dart';
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
  String _userCity = 'مكة المكرمة';
  int _currentBackground = 0;

  static const Color _primary = Color(0xFF4A90E2);
  static const Color _primaryDark = Color(0xFF2E5C8A);
  static const Color _primaryLight = Color(0xFF64B5F6);
  static const Color _bg = Color(0xFF0A1929);
  static const Color _surface = Color(0xFF132F4C);
  static const Color _surfaceDark = Color(0xFF0F2236);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBackground();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
    });
  }

  Future<void> _loadBackground() async {
    final index = await BackgroundService.getCurrentIndex();
    if (mounted) setState(() => _currentBackground = index);
  }

  void _onTabSelected(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _loadBackground();
    _loadUserData();
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(78 + topPadding),
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
  // 🎨 الشريط العلوي
  // ═══════════════════════════════════════════════════════════
  Widget _buildCustomAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_surface, _surfaceDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(
          bottom: BorderSide(color: _primary, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _primary.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 78,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _buildAppLogo(),
                const SizedBox(width: 10),
                _buildAppName(),
                const Spacer(),
                _buildApexSecLogo(),
                const SizedBox(width: 8),
                const SaudiFlag(
                  height: 42,
                  width: 60,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [_surface, _bg],
          stops: [0.3, 1.0],
        ),
        border: Border.all(color: _primary, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.6),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.mosque, color: _primaryLight, size: 32),
      ),
    );
  }

  Widget _buildAppName() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'نور الحرمين',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            shadows: [
              Shadow(color: Color(0xFF4A90E2), blurRadius: 12),
            ],
          ),
        ),
        SizedBox(height: 3),
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 1.5,
              child: ColoredBox(color: _primaryLight),
            ),
            SizedBox(width: 5),
            Text(
              'NOOR AL-HARAMAIN',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 7.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🛡️ شعار ApexSec المكبّر
  Widget _buildApexSecLogo() {
    return Container(
      width: 90,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Image.asset(
            'assets/icon/apexsec_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.shield, color: _primaryLight, size: 28),
              );
            },
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
          colors: [_surface, _surfaceDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(
          top: BorderSide(color: _primary, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
          BoxShadow(
            color: _primary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: _primaryLight,
        unselectedItemColor: Colors.white38,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.access_time_rounded, 0),
            activeIcon: _build3DIcon(Icons.access_time_rounded, 0, active: true),
            label: TranslationService.getText(lang, 'nav_prayer'),
          ),
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.menu_book_rounded, 1),
            activeIcon: _build3DIcon(Icons.menu_book_rounded, 1, active: true),
            label: TranslationService.getText(lang, 'nav_quran'),
          ),
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.library_books_rounded, 2),
            activeIcon:
                _build3DIcon(Icons.library_books_rounded, 2, active: true),
            label: TranslationService.getText(lang, 'nav_library'),
          ),
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.live_tv_rounded, 3),
            activeIcon: _build3DIcon(Icons.live_tv_rounded, 3, active: true),
            label: TranslationService.getText(lang, 'nav_azkar'),
          ),
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.bolt_rounded, 4),
            activeIcon: _build3DIcon(Icons.bolt_rounded, 4, active: true),
            label: TranslationService.getText(lang, 'nav_ai'),
          ),
          BottomNavigationBarItem(
            icon: _build3DIcon(Icons.settings_rounded, 5),
            activeIcon: _build3DIcon(Icons.settings_rounded, 5, active: true),
            label: TranslationService.getText(lang, 'nav_settings'),
          ),
        ],
      ),
    );
  }

  Widget _build3DIcon(IconData icon, int index, {bool active = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [_primaryLight, _primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: active ? 24 : 22,
        color: active ? Colors.white : Colors.white38,
      ),
    );
  }
}
