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
      backgroundColor: const Color(0xFF0B132B),
      appBar: PreferredSize(
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
  // 🎨 الشريط العلوي — بدون زر "حسابي"
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
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // 🕌 شعار التطبيق
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

                // 📛 اسم التطبيق
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

                // 🇸🇦 علم السعودية
                const SaudiFlag(
                  height: 22,
                  width: 32,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(width: 6),

                // 🛡️ شعار ApexSec
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
