import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/background_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/periodic_azkar_service.dart';
import '../../../core/data/muezzins.dart';
import '../../../widgets/saudi_flag.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🎨 الألوان
  static const Color _primary = Color(0xFFE53935);
  static const Color _primaryDark = Color(0xFFB71C1C);
  static const Color _primaryLight = Color(0xFFFF5252);
  static const Color _bg = Color(0xFF0A1929);
  static const Color _surface = Color(0xFF132F4C);
  static const Color _surfaceDark = Color(0xFF0F2236);

  String _userName = 'مستخدم';
  String _userCity = 'مكة المكرمة';
  double _userLat = 21.4225;
  double _userLng = 39.8262;
  bool _isLocationReady = false;
  int _selectedBackground = 0;
  String _selectedTimeFormat = '24h';
  String _selectedMuezzin = 'adhan_sudais';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  double _soundVolume = 0.8;
  String _appVersion = '1.0.0';

  // 📿 إعدادات الأذكار الدورية
  bool _periodicAzkarEnabled = false;
  int _periodicAzkarInterval = 15;
  int _periodicAzkarStartHour = 6;
  int _periodicAzkarEndHour = 22;

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

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String muezzin = prefs.getString('selected_muezzin') ?? 'adhan_sudais';
    final valid =
        NotificationService.muezzins.any((m) => m['file'] == muezzin);
    if (!valid) {
      muezzin = 'adhan_sudais';
      await prefs.setString('selected_muezzin', muezzin);
    }
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
      _userLat = prefs.getDouble('user_lat') ?? 21.4225;
      _userLng = prefs.getDouble('user_lng') ?? 39.8262;
      _isLocationReady = prefs.getBool('location_enabled') ?? false;
      _selectedBackground = prefs.getInt('background_index') ?? 0;
      _selectedTimeFormat = prefs.getString('time_format') ?? '24h';
      _selectedMuezzin = muezzin;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _soundVolume = prefs.getDouble('sound_volume') ?? 0.8;
      _periodicAzkarEnabled =
          prefs.getBool('periodic_azkar_enabled') ?? false;
      _periodicAzkarInterval = prefs.getInt('periodic_azkar_interval') ?? 15;
      _periodicAzkarStartHour =
          prefs.getInt('periodic_azkar_start_hour') ?? 6;
      _periodicAzkarEndHour = prefs.getInt('periodic_azkar_end_hour') ?? 22;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_city', _userCity);
    await prefs.setDouble('user_lat', _userLat);
    await prefs.setDouble('user_lng', _userLng);
    await prefs.setBool('location_enabled', _isLocationReady);
    await prefs.setInt('background_index', _selectedBackground);
    await prefs.setString('time_format', _selectedTimeFormat);
    await prefs.setString('selected_muezzin', _selectedMuezzin);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setDouble('sound_volume', _soundVolume);
    await prefs.setBool('periodic_azkar_enabled', _periodicAzkarEnabled);
    await prefs.setInt('periodic_azkar_interval', _periodicAzkarInterval);
    await prefs.setInt('periodic_azkar_start_hour', _periodicAzkarStartHour);
    await prefs.setInt('periodic_azkar_end_hour', _periodicAzkarEndHour);
  }

  Future<void> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final lines = pubspec.split('\n');
      for (var line in lines) {
        if (line.trim().startsWith('version:')) {
          final version = line.trim().replaceAll('version:', '').trim();
          if (mounted) setState(() => _appVersion = version);
          break;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

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
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=20&accept-language=ar';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NoorAlHaramain/1.0'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = data.map((item) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          return {
            'name': item['display_name']?.toString() ?? '',
            'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
            'lon': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
            'city': address['city'] ??
                address['town'] ??
                address['village'] ??
                '',
            'state': address['state'] ?? '',
            'country': address['country'] ?? '',
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
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    setState(() {
      _userLat = location['lat'] ?? 0.0;
      _userLng = location['lon'] ?? 0.0;
      _userCity = location['city'] ?? location['name'] ?? '';
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
      SnackBar(content: Text('✅ تم تحديث الموقع إلى: $_userCity')),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryDark, _surface],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '🔍 اختر موقعك',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setModalState(() {
                          _searchQuery = value;
                          if (value.isNotEmpty) _searchLocation(value);
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '🔍 ابحث عن مدينة، قرية، دولة...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon:
                            const Icon(Icons.search, color: _primary),
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isSearching
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: _primary))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final location = _searchResults[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.location_city,
                                      color: _primary),
                                  title: Text(location['name'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${location['city']} ${location['country']}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11)),
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

  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          children: [
            const Text('اختر خلفية التطبيق',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: BackgroundService.backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = BackgroundService.backgrounds[index];
                  final isSelected = _selectedBackground == index;
                  final type = bg['type'] as String? ?? 'gradient';

                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedBackground = index);
                      await BackgroundService.setBackground(index);
                      _saveSettings();
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('✅ تم تطبيق: ${bg['name']}')),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _primary : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (type == 'image')
                              Image.asset(
                                bg['imagePath'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _surface,
                                  child: const Icon(Icons.image,
                                      color: Colors.white24, size: 40),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: bg['colors'] as List<Color>,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Icon(
                                bg['icon'] as IconData,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 24,
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              right: 6,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  bg['name'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: _primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
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

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1.5),
        ),
        title: const Text('⚠️ تحذير', style: TextStyle(color: Colors.red)),
        content: const Text('هل أنت متأكد من إعادة تعيين جميع الإعدادات؟',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _userName = 'مستخدم';
                  _userCity = 'مكة المكرمة';
                  _userLat = 21.4225;
                  _userLng = 39.8262;
                  _isLocationReady = false;
                  _selectedBackground = 0;
                  _selectedTimeFormat = '24h';
                  _selectedMuezzin = 'adhan_sudais';
                  _notificationsEnabled = true;
                  _soundEnabled = true;
                  _soundVolume = 0.8;
                  _periodicAzkarEnabled = false;
                });
              }
              await PeriodicAzkarService.stop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم إعادة التعيين')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 4),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surface, _surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 4,
        shadowColor: Colors.black45,
        title: const Row(
          children: [
            Icon(Icons.settings, color: _primary),
            SizedBox(width: 8),
            Text('⚙️ الإعدادات',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelColor: _primary,
          unselectedLabelColor: Colors.white54,
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

  // ═══════════════════════════════════════════════════════════
  // 1. الدينية
  // ═══════════════════════════════════════════════════════════
  Widget _buildReligiousSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: _primary, size: 24),
                  SizedBox(width: 8),
                  Text('📍 الموقع الحالي',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🏙️ $_userCity',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '📍 ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: _primaryLight, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                      _isLocationReady ? Icons.gps_fixed : Icons.gps_off,
                      color: _isLocationReady ? Colors.green : Colors.red,
                      size: 16),
                  const SizedBox(width: 4),
                  Text(
                      _isLocationReady ? '✅ الموقع مفعل' : '❌ الموقع غير مفعل',
                      style: TextStyle(
                          color: _isLocationReady
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showLocationPicker,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تغيير'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: _primary.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.volume_up, color: _primary, size: 24),
                  SizedBox(width: 8),
                  Text('🎙️ المؤذن',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedMuezzin,
                dropdownColor: _surface,
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bg.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: _primary.withValues(alpha: 0.3))),
                ),
                items: NotificationService.muezzins
                    .map((m) => DropdownMenuItem<String>(
                          value: m['file']!,
                          child: Text(m['name']!),
                        ))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() => _selectedMuezzin = value);
                    await _saveSettings();
                    await NotificationService.setSelectedMuezzin(value);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم تغيير المؤذن')),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              // 🧪 اختبار الأذان
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await NotificationService.showTestNotification();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('🔔 تم إرسال اختبار الأذان')),
                    );
                  },
                  icon: const Icon(Icons.play_circle),
                  label: const Text('🔔 اختبار الأذان'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                    shadowColor: _primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 🕌 اختبار إشعار الإقامة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await NotificationService.showTestIqamaNotification();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('🕌 إشعار الإقامة سيرن بعد 10 ثوانٍ')),
                    );
                  },
                  icon: const Icon(Icons.timer),
                  label: const Text('🕌 اختبار إشعار الإقامة (10 ثوانٍ)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 📿 قسم الأذكار الدورية
        _buildPeriodicAzkarCard(),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔔 الإشعارات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('تفعيل الإشعارات',
                    style: TextStyle(color: Colors.white70)),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSettings();
                },
                activeThumbColor: _primary,
                tileColor: _bg.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📿 بطاقة الأذكار الدورية
  // ═══════════════════════════════════════════════════════════
  Widget _buildPeriodicAzkarCard() {
    return _buildSettingsCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: _primary, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('📿 الأذكار الدورية',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('تذكير تلقائي بالأذكار كل فترة',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('تفعيل الأذكار الدورية',
                style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _periodicAzkarEnabled ? '✅ تعمل حالياً' : 'معطّلة',
              style: TextStyle(
                  color:
                      _periodicAzkarEnabled ? Colors.green : Colors.white54,
                  fontSize: 12),
            ),
            value: _periodicAzkarEnabled,
            activeThumbColor: _primary,
            onChanged: (value) async {
              setState(() => _periodicAzkarEnabled = value);
              await _saveSettings();
              if (value) {
                await PeriodicAzkarService.start();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ تم تفعيل الأذكار الدورية')),
                );
              } else {
                await PeriodicAzkarService.stop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('🛑 تم إيقاف الأذكار الدورية')),
                );
              }
            },
          ),
          if (_periodicAzkarEnabled) ...[
            const Divider(color: Colors.white12),
            ListTile(
              title: const Text('⏱️ كل كم دقيقة؟',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('$_periodicAzkarInterval دقيقة',
                  style: const TextStyle(
                      color: _primaryLight, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
              onTap: _showIntervalPicker,
            ),
            ListTile(
              title: const Text('🌅 وقت البدء',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                  '${_periodicAzkarStartHour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                      color: _primaryLight, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
              onTap: () => _showHourPicker('periodic_azkar_start_hour', 0, 12),
            ),
            ListTile(
              title: const Text('🌙 وقت الانتهاء',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                  '${_periodicAzkarEndHour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                      color: _primaryLight, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
              onTap: () => _showHourPicker('periodic_azkar_end_hour', 12, 24),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await PeriodicAzkarService.showTestZikr();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('🧪 تم إرسال إشعار ذكر تجريبي')),
                  );
                },
                icon: const Icon(Icons.notifications_active),
                label: const Text('🧪 اختبار إشعار ذكر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 4,
                  shadowColor: _primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showIntervalPicker() {
    const options = [5, 10, 15, 30, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_primaryDark, _surface]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer, color: Colors.white),
                SizedBox(width: 8),
                Text('⏱️ كل كم دقيقة؟',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...options.map((m) {
            return ListTile(
              title: Text('$m دقيقة',
                  style: const TextStyle(color: Colors.white)),
              trailing: _periodicAzkarInterval == m
                  ? const Icon(Icons.check, color: _primary)
                  : null,
              onTap: () async {
                setState(() => _periodicAzkarInterval = m);
                await _saveSettings();
                await PeriodicAzkarService.restart();
                if (mounted) Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  void _showHourPicker(String key, int min, int max) {
    final current = key == 'periodic_azkar_start_hour'
        ? _periodicAzkarStartHour
        : _periodicAzkarEndHour;
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _surface]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      key == 'periodic_azkar_start_hour'
                          ? '🌅 وقت البدء'
                          : '🌙 وقت الانتهاء',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: max - min,
                itemBuilder: (context, index) {
                  final hour = min + index;
                  return ListTile(
                    title: Text('${hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(color: Colors.white)),
                    trailing: current == hour
                        ? const Icon(Icons.check, color: _primary)
                        : null,
                    onTap: () async {
                      setState(() {
                        if (key == 'periodic_azkar_start_hour') {
                          _periodicAzkarStartHour = hour;
                        } else {
                          _periodicAzkarEndHour = hour;
                        }
                      });
                      await _saveSettings();
                      await PeriodicAzkarService.restart();
                      if (mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. العامة
  // ═══════════════════════════════════════════════════════════
  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.image, color: _primary, size: 24),
                  SizedBox(width: 8),
                  Text('🖼️ خلفية التطبيق',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _primary.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if ((BackgroundService.backgrounds[
                                        _selectedBackground]['type']
                                    as String?) ==
                                'image')
                              Image.asset(
                                BackgroundService.backgrounds[
                                    _selectedBackground]['imagePath'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _surface,
                                  child: const Icon(Icons.image,
                                      color: Colors.white24, size: 40),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (BackgroundService.backgrounds[
                                                _selectedBackground]
                                            ['colors']
                                        as List<Color>),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            Center(
                              child: Text(
                                BackgroundService.backgrounds[
                                        _selectedBackground]['name']
                                    as String,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showBackgroundPicker,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('تغيير'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 4),
                  ),
                ],
              ),
            ],
          ),
        ),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⏰ تنسيق الوقت',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          _selectedTimeFormat == '24h' ? '24 ساعة' : '12 ساعة',
                          style: const TextStyle(color: Colors.white70))),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '24h', label: Text('24')),
                      ButtonSegment(value: '12h', label: Text('12')),
                    ],
                    selected: {_selectedTimeFormat},
                    onSelectionChanged: (s) {
                      setState(() => _selectedTimeFormat = s.first);
                      _saveSettings();
                    },
                    style: SegmentedButton.styleFrom(
                        selectedForegroundColor: Colors.white,
                        selectedBackgroundColor: _primary),
                  ),
                ],
              ),
            ],
          ),
        ),

        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.restore, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('🔄 إعادة التعيين',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _showResetDialog,
                icon: const Icon(Icons.warning, size: 16),
                label: const Text('إعادة التعيين'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3. الصوت
  // ═══════════════════════════════════════════════════════════
  Widget _buildSoundSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔊 الصوت',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('تفعيل الصوت',
                    style: TextStyle(color: Colors.white70)),
                value: _soundEnabled,
                onChanged: (v) {
                  setState(() => _soundEnabled = v);
                  _saveSettings();
                },
                activeThumbColor: _primary,
              ),
              Row(
                children: [
                  const Icon(Icons.volume_down, color: _primary, size: 20),
                  Expanded(
                    child: Slider(
                      value: _soundVolume,
                      activeColor: _primary,
                      onChanged: (v) {
                        setState(() => _soundVolume = v);
                        _saveSettings();
                      },
                    ),
                  ),
                  Text('${(_soundVolume * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4. المعلومات
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(_buildAccountSection()),
        _buildSettingsCard(
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryLight, _primary, _primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.mosque, color: Colors.white, size: 90),
              ),
              const SizedBox(height: 20),
              const Text('نور الحرمين',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('تطبيق إسلامي عالمي',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              const SaudiFlag(
                height: 80,
                width: 120,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 32),
              _buildInfoRow('الإصدار', _appVersion),
              _buildInfoRow('الحزمة', 'com.apexsec.noor_al_haramain_global'),
              _buildInfoRow('المنصة', 'Android'),
              _buildInfoRow('اللغة', 'العربية'),
            ],
          ),
        ),
        _buildDeveloperSection(),
      ],
    );
  }

  Widget _buildDeveloperSection() {
    return _buildSettingsCard(
      Column(
        children: [
          Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _primary.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.asset(
                'assets/icon/apexsec_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.shield, color: _primaryLight, size: 50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ApexSec',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          const Text('Developed by ApexSec Technologies',
              style: TextStyle(
                  color: Colors.white54, fontSize: 12, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.person, color: _primary, size: 24),
            SizedBox(width: 8),
            Text('🔐 الحساب',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('مستخدم نشط',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('مرحباً $_userName',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'الحساب يعمل تلقائياً عبر Google Play.\n'
                'الاشتراك والمزامنة يتمّان بواسطة Google عند الحاجة.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.6),
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
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
