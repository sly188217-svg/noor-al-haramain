import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/translation_service.dart';
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
  bool _isLocationReady = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
      _isLocationReady = prefs.getBool('location_enabled') ?? false;
    });
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
  }

  // ✅ بناء تبويب واحد فقط حسب الاختيار (Lazy Loading)
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

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildCustomAppBar(),
      ),
      // ✅ بدلاً من IndexedStack (يبني الجميع) → نبني الحالي فقط
      body: _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  // ============================================================
  // 🎨 الشريط العلوي
  // ============================================================
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
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // شعار التطبيق
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF0B132B)],
                  ),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 26),
                ),
              ),
              const SizedBox(width: 10),

              // اسم التطبيق
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'نور الحرمين',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 1,
                        color: const Color(0xFFD4AF37).withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      const Text(
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

              // معلومات المستخدم
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Color(0xFFD4AF37), size: 11),
                      const SizedBox(width: 3),
                      Text(
                        _userName,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLocationReady ? Icons.gps_fixed : Icons.gps_off,
                        color: _isLocationReady ? Colors.green : Colors.redAccent,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _userCity,
                        style: TextStyle(
                          color: _isLocationReady ? Colors.green : Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // علم السعودية
              Container(
                width: 34,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF165D31),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.6),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 3,
                      child: Text(
                        'لا إله إلا الله',
                        style: TextStyle(color: Colors.white, fontSize: 4, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      child: Container(width: 22, height: 1.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // شعار ApexSec
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.7),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Color(0xFFD4AF37), size: 10),
                    SizedBox(width: 3),
                    Text(
                      'ApexSec',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
                onPressed: _refreshLocation,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 📱 الشريط السفلي
  // ============================================================
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
            color: const Color(0xFFD4AF37).withOpacity(0.3),
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
