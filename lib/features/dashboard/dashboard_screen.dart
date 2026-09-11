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
    // التحقق من mounted قبل تحديث الحالة
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
      _isLocationReady = prefs.getBool('location_enabled') ?? false;
    });
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    // التنقل إلى شاشة الموقع دون تراكم في المكدس
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
    );
  }

  // قائمة الأقسام الستة (نهائية)
  final List<Widget> _tabs = const [
    PrayerTab(),
    QuranTab(),
    LibraryTab(),
    AzkarTab(),
    AiTab(),
    SettingsTab(),
  ];

  // دالة للتعامل مع تغيير التبويب مع التحقق من mounted
  void _onTabSelected(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.mosque, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            // الاسم بالعربية والإنجليزية معاً
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نور الحرمين',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Noor Al-Haramain',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // معلومات المستخدم والمدينة (يمين)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '👤 $_userName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: _refreshLocation,
                  child: Row(
                    children: [
                      Icon(
                        _isLocationReady ? Icons.gps_fixed : Icons.gps_off,
                        color: _isLocationReady
                            ? const Color(0xFFD4AF37)
                            : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _userCity,
                        style: TextStyle(
                          color: _isLocationReady ? Colors.green : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
            onPressed: _refreshLocation,
            tooltip: 'تحديث الموقع',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFD4AF37).withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected, // استخدام الدالة الآمنة
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 11,
          unselectedFontSize: 10,
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
      ),
    );
  }
}
