import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/data/muezzins.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== بيانات المستخدم والموقع =====
  String _userName = 'مستخدم';
  String _userCity = 'مكة المكرمة';
  String _userCountry = 'السعودية';
  String _userRegion = 'منطقة مكة المكرمة';
  String _userDistrict = 'مكة المكرمة';
  double _userLat = 21.4225;
  double _userLng = 39.8262;
  bool _isLocationReady = false;

  // ===== إعدادات أخرى =====
  int _selectedBackground = 0;
  String _selectedTimeFormat = '24h';
  String _selectedMuezzin = 'marwan';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  double _soundVolume = 0.8;
  String _appVersion = '1.0.0';

  // ===== قائمة الخلفيات =====
  final List<Map<String, dynamic>> _backgrounds = [
    {'name': 'الحرم المكي', 'nameEn': 'Makkah Haram', 'asset': 'assets/images/makkah.jpg', 'color': 0xFF0B132B},
    {'name': 'المدينة المنورة', 'nameEn': 'Madinah Haram', 'asset': 'assets/images/madinah.jpg', 'color': 0xFF1C2541},
    {'name': 'قبة الصخرة', 'nameEn': 'Dome of the Rock', 'asset': 'assets/images/qubbah.jpg', 'color': 0xFF2D1B00},
    {'name': 'مسجد الأقصى', 'nameEn': 'Al-Aqsa Mosque', 'asset': 'assets/images/aqsa.jpg', 'color': 0xFF1A2B3C},
    {'name': 'زخرفة إسلامية 1', 'nameEn': 'Islamic Pattern 1', 'asset': 'assets/images/pattern1.jpg', 'color': 0xFF1C2541},
    {'name': 'زخرفة إسلامية 2', 'nameEn': 'Islamic Pattern 2', 'asset': 'assets/images/pattern2.jpg', 'color': 0xFF2C1810},
  ];

  // ===== بيانات البحث عن الموقع =====
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  //  تحميل وحفظ الإعدادات
  // ============================================================
  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
      _userCountry = prefs.getString('user_country') ?? 'السعودية';
      _userRegion = prefs.getString('user_region') ?? 'منطقة مكة المكرمة';
      _userDistrict = prefs.getString('user_district') ?? 'مكة المكرمة';
      _userLat = prefs.getDouble('user_lat') ?? 21.4225;
      _userLng = prefs.getDouble('user_lng') ?? 39.8262;
      _isLocationReady = prefs.getBool('location_enabled') ?? false;
      _selectedBackground = prefs.getInt('background_index') ?? 0;
      _selectedTimeFormat = prefs.getString('time_format') ?? '24h';
      _selectedMuezzin = prefs.getString('selected_muezzin') ?? 'marwan';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _soundVolume = prefs.getDouble('sound_volume') ?? 0.8;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_city', _userCity);
    await prefs.setString('user_country', _userCountry);
    await prefs.setString('user_region', _userRegion);
    await prefs.setString('user_district', _userDistrict);
    await prefs.setDouble('user_lat', _userLat);
    await prefs.setDouble('user_lng', _userLng);
    await prefs.setBool('location_enabled', _isLocationReady);
    await prefs.setInt('background_index', _selectedBackground);
    await prefs.setString('time_format', _selectedTimeFormat);
    await prefs.setString('selected_muezzin', _selectedMuezzin);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setDouble('sound_volume', _soundVolume);
  }

  Future<void> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final lines = pubspec.split('\n');
      for (var line in lines) {
        if (line.trim().startsWith('version:')) {
          final version = line.trim().replaceAll('version:', '').trim();
          setState(() => _appVersion = version);
          break;
        }
      }
    } catch (e) {
      setState(() => _appVersion = '1.0.0');
    }
  }

  // ============================================================
  //  البحث عن الموقع (جميع بلدان العالم، مدن، قرى، مناطق)
  //  باستخدام Nominatim API (يوفر نتائج دقيقة جداً)
  // ============================================================
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty || query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // استخدام Nominatim API للبحث عن المواقع
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=20&accept-language=ar';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'NoorAlHaramain/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = data.map((item) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          return {
            'name': item['display_name']?.toString() ?? 'بدون اسم',
            'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
            'lon': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
            'type': item['type']?.toString() ?? '',
            'category': item['category']?.toString() ?? '',
            'city': address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? address['municipality'] ?? '',
            'state': address['state'] ?? address['region'] ?? '',
            'country': address['country'] ?? '',
            'country_code': address['country_code']?.toString()?.toUpperCase() ?? '',
            'suburb': address['suburb'] ?? '',
            'neighbourhood': address['neighbourhood'] ?? '',
          };
        }).toList();

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تعذر البحث عن الموقع. حاول مرة أخرى.')),
        );
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ فشل الاتصال: $e')),
      );
    }
  }

  // ============================================================
  //  اختيار الموقع من نتائج البحث
  // ============================================================
  void _selectLocation(Map<String, dynamic> location) {
    setState(() {
      final city = location['city']?.toString() ?? '';
      final country = location['country']?.toString() ?? '';
      final state = location['state']?.toString() ?? '';
      final suburb = location['suburb']?.toString() ?? '';
      final name = location['name']?.toString() ?? '';

      _userLat = location['lat'] ?? 0.0;
      _userLng = location['lon'] ?? 0.0;
      _userCity = city.isNotEmpty ? city : name;
      _userCountry = country.isNotEmpty ? country : 'غير معروف';
      _userRegion = state.isNotEmpty ? state : '';
      _userDistrict = suburb.isNotEmpty ? suburb : city;
      _isLocationReady = true;
    });

    _saveSettings();
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchQuery = '';
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم تحديث الموقع إلى: ${_userCity}, ${_userCountry}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  //  عرض شاشة اختيار الموقع (نافذة منبثقة)
  // ============================================================
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  // ===== شريط العنوان =====
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C2541),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
                        const SizedBox(width: 8),
                        const Text(
                          '🔍 اختر موقعك (جميع بلدان العالم)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // ===== حقل البحث =====
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setModalState(() {
                          _searchQuery = value;
                          if (value.isNotEmpty) {
                            _searchLocation(value);
                          } else {
                            _searchResults = [];
                          }
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '🔍 ابحث عن مدينة، قرية، منطقة، دولة...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  setModalState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF0B132B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // ===== إحصائيات البحث =====
                  if (_searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🌍 ${_searchResults.length} نتيجة',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '📍 ${_searchResults.where((r) => r['type'] == 'city').length} مدينة • ${_searchResults.where((r) => r['type'] == 'village').length} قرية',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // ===== قائمة النتائج =====
                  Expanded(
                    child: _isSearching
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Color(0xFFD4AF37)),
                                SizedBox(height: 16),
                                Text(
                                  'جاري البحث...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty
                                          ? Icons.location_on
                                          : Icons.location_off,
                                      color: Colors.grey,
                                      size: 60,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'ابحث عن مدينة، قرية، منطقة، أو دولة'
                                          : 'لا توجد نتائج لـ "$_searchQuery"',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      const SizedBox(height: 8),
                                    if (_searchQuery.isNotEmpty)
                                      const Text(
                                        'تأكد من صحة الإملاء أو ابحث بشكل أوسع',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final location = _searchResults[index];
                                  final typeIcon = _getLocationIcon(location['type'] ?? '');
                                  final typeColor = _getLocationColor(location['type'] ?? '');

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C2541).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: typeColor, width: 0.5),
                                        ),
                                        child: Center(
                                          child: Text(
                                            typeIcon,
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        location['name'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            _buildLocationDetails(location),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '📍 ${location['lat']?.toStringAsFixed(4)}, ${location['lon']?.toStringAsFixed(4)}',
                                            style: const TextStyle(
                                              color: Color(0xFFD4AF37),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white24,
                                        size: 14,
                                      ),
                                      onTap: () => _selectLocation(location),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  //  دوال مساعدة لتنسيق النتائج
  // ============================================================
  String _getLocationIcon(String type) {
    switch (type) {
      case 'city':
        return '🏙️';
      case 'town':
        return '🏘️';
      case 'village':
        return '🌾';
      case 'hamlet':
        return '🏡';
      case 'state':
      case 'region':
        return '🗺️';
      case 'country':
        return '🌍';
      case 'suburb':
        return '🏠';
      default:
        return '📍';
    }
  }

  Color _getLocationColor(String type) {
    switch (type) {
      case 'city':
        return Colors.blue;
      case 'town':
        return Colors.teal;
      case 'village':
        return Colors.green;
      case 'hamlet':
        return Colors.orange;
      case 'state':
      case 'region':
        return Colors.purple;
      case 'country':
        return Colors.red;
      case 'suburb':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _buildLocationDetails(Map<String, dynamic> location) {
    final parts = <String>[];
    final city = location['city']?.toString() ?? '';
    final state = location['state']?.toString() ?? '';
    final country = location['country']?.toString() ?? '';
    final suburb = location['suburb']?.toString() ?? '';

    if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (country.isNotEmpty) parts.add(country);

    return parts.isNotEmpty ? parts.join(' • ') : 'موقع غير معروف';
  }

  // ============================================================
  //  عرض اختيار الخلفية
  // ============================================================
  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: Column(
          children: [
            const Text(
              'اختر خلفية التطبيق',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemCount: _backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = _backgrounds[index];
                  final isSelected = _selectedBackground == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBackground = index;
                      });
                      _saveSettings();
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(bg['color']),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bg['name'] ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  حوار إعادة التعيين
  // ============================================================
  void _showResetDialog(bool isArabic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text(
          '⚠️ تحذير',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'هل أنت متأكد من إعادة تعيين جميع الإعدادات إلى الوضع الافتراضي؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(context);
              setState(() {
                _userName = 'مستخدم';
                _userCity = 'مكة المكرمة';
                _userCountry = 'السعودية';
                _userRegion = 'منطقة مكة المكرمة';
                _userDistrict = 'مكة المكرمة';
                _userLat = 21.4225;
                _userLng = 39.8262;
                _isLocationReady = false;
                _selectedBackground = 0;
                _selectedTimeFormat = '24h';
                _selectedMuezzin = 'marwan';
                _notificationsEnabled = true;
                _soundEnabled = true;
                _soundVolume = 0.8;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ تم إعادة تعيين الإعدادات')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  بناء البطاقات
  // ============================================================
  Widget _buildSettingsCard(Widget child) {
    return Card(
      color: const Color(0xFF1C2541),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  // ============================================================
  //  بناء الواجهة الرئيسية
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text(
              '⚙️ الإعدادات',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '🕌 دينية'),
            Tab(text: '🌐 عامة'),
            Tab(text: '🎵 صوت'),
            Tab(text: 'ℹ️ معلومات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReligiousSettings(),
          _buildGeneralSettings(),
          _buildSoundSettings(),
          _buildInfoTab(),
        ],
      ),
    );
  }

  // ============================================================
  //  1. الإعدادات الدينية
  // ============================================================
  Widget _buildReligiousSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '📍 الموقع الحالي',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏙️ $_userCity',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🗺️ $_userRegion',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🌍 $_userCountry',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)}',
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isLocationReady ? Icons.gps_fixed : Icons.gps_off,
                    color: _isLocationReady ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isLocationReady ? '✅ الموقع مفعل' : '❌ الموقع غير مفعل',
                    style: TextStyle(
                      color: _isLocationReady ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showLocationPicker,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تغيير الموقع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '🎙️ المؤذن',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMuezzin,
                dropdownColor: const Color(0xFF1C2541),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0B132B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: MuezzinData.muezzins.map((m) {
                  return DropdownMenuItem(
                    value: m['id'],
                    child: Text(m['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMuezzin = value);
                    _saveSettings();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔔 الإشعارات',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text(
                  'تفعيل الإشعارات',
                  style: TextStyle(color: Colors.white70),
                ),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSettings();
                },
                activeColor: const Color(0xFFD4AF37),
                tileColor: const Color(0xFF0B132B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  2. الإعدادات العامة
  // ============================================================
  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.image, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '🖼️ خلفية التطبيق',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _backgrounds[_selectedBackground]['name'] ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showBackgroundPicker,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('تغيير'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(_backgrounds[_selectedBackground]['color']),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    _backgrounds[_selectedBackground]['name'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '⏰ تنسيق الوقت',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedTimeFormat == '24h' ? '24 ساعة' : '12 ساعة (صباح/مساء)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '24h', label: Text('24')),
                      ButtonSegment(value: '12h', label: Text('12')),
                    ],
                    selected: {_selectedTimeFormat},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _selectedTimeFormat = selection.first);
                      _saveSettings();
                    },
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: Colors.black,
                      selectedBackgroundColor: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restore, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '🔄 إعادة تعيين الإعدادات',
                    style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'إعادة تعيين جميع الإعدادات إلى الوضع الافتراضي',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  _showResetDialog(true);
                },
                icon: const Icon(Icons.warning, size: 16),
                label: const Text('إعادة التعيين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  3. إعدادات الصوت
  // ============================================================
  Widget _buildSoundSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '🔊 الصوت',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text(
                  'تفعيل الصوت',
                  style: TextStyle(color: Colors.white70),
                ),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  _saveSettings();
                },
                activeColor: const Color(0xFFD4AF37),
                tileColor: const Color(0xFF0B132B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔊 مستوى الصوت',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.volume_down, color: Color(0xFFD4AF37), size: 20),
                  Expanded(
                    child: Slider(
                      value: _soundVolume,
                      min: 0,
                      max: 1,
                      activeColor: const Color(0xFFD4AF37),
                      inactiveColor: Colors.grey,
                      onChanged: (value) {
                        setState(() => _soundVolume = value);
                        _saveSettings();
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Color(0xFFD4AF37), size: 20),
                  Text(
                    '${(_soundVolume * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    '🎵 تلاوة القرآن',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر القارئ المفضل للاستماع إلى التلاوة',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMuezzin,
                dropdownColor: const Color(0xFF1C2541),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0B132B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: MuezzinData.muezzins.map((m) {
                  return DropdownMenuItem(
                    value: m['id'],
                    child: Text(m['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMuezzin = value);
                    _saveSettings();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  4. معلومات التطبيق
  // ============================================================
  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            children: [
              const Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 80),
              const SizedBox(height: 16),
              const Text(
                'نور الحرمين',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تطبيق إسلامي عالمي',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const Divider(color: Colors.grey, height: 32),
              _buildInfoRow('الإصدار', _appVersion),
              _buildInfoRow('الحزمة', 'com.apexsec.noor_al_haramain_global'),
              _buildInfoRow('المنصة', 'Android / iOS / Linux'),
              _buildInfoRow('الوضع', 'Debug'),
              _buildInfoRow('اللغة', 'العربية'),
              const Divider(color: Colors.grey, height: 32),
              const SizedBox(height: 8),
              const Text(
                'تطبيق نور الحرمين العالمي هو تطبيق إسلامي شامل يقدم أوقات الصلاة الدقيقة، المصحف الشريف، الأذكار، الأدعية، الرقية الشرعية، البث المباشر للحرمين، والعديد من الميزات الإسلامية. مصمم للمسلمين في جميع أنحاء العالم.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.star, color: Color(0xFFD4AF37), size: 30),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFFD4AF37), size: 30),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.feedback, color: Color(0xFFD4AF37), size: 30),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                '© 2024 نور الحرمين. جميع الحقوق محفوظة.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'صُنع بحب للمسلمين في كل مكان ❤️',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
