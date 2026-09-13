import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/adhan_download_service.dart';
import '../../../core/data/muezzins.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _userName = 'مستخدم';
  String _userCity = 'مكة المكرمة';
  double _userLat = 21.4225;
  double _userLng = 39.8262;
  bool _isLocationReady = false;
  int _selectedBackground = 0;
  String _selectedTimeFormat = '24h';
  String _selectedMuezzin = 'marwan';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  double _soundVolume = 0.8;
  String _appVersion = '1.0.0';

  final List<Map<String, dynamic>> _backgrounds = [
    {'name': 'الحرم المكي', 'color': 0xFF0B132B},
    {'name': 'المدينة المنورة', 'color': 0xFF1C2541},
    {'name': 'قبة الصخرة', 'color': 0xFF2D1B00},
    {'name': 'المسجد الأقصى', 'color': 0xFF1A2B3C},
    {'name': 'زخرفة إسلامية 1', 'color': 0xFF1C2541},
    {'name': 'زخرفة إسلامية 2', 'color': 0xFF2C1810},
  ];

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
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم';
      _userCity = prefs.getString('user_city') ?? 'مكة المكرمة';
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
          if (mounted) setState(() => _appVersion = version);
          break;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  // ===== البحث عن الموقع =====
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
      final url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=20&accept-language=ar';
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
            'city': address['city'] ?? address['town'] ?? address['village'] ?? '',
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
      backgroundColor: const Color(0xFF0B132B),
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
                      color: Color(0xFF1C2541),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '🔍 اختر موقعك',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                        filled: true,
                        fillColor: const Color(0xFF0B132B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final location = _searchResults[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C2541).withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.location_city, color: Color(0xFFD4AF37)),
                                  title: Text(location['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${location['city']} ${location['country']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 350,
        child: Column(
          children: [
            const Text('اختر خلفية التطبيق', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: _backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = _backgrounds[index];
                  final isSelected = _selectedBackground == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedBackground = index);
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
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, color: isSelected ? const Color(0xFFD4AF37) : Colors.grey, size: 28),
                            const SizedBox(height: 6),
                            Text(bg['name'] ?? '', textAlign: TextAlign.center, style: TextStyle(color: isSelected ? const Color(0xFFD4AF37) : Colors.white70, fontSize: 10)),
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
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('⚠️ تحذير', style: TextStyle(color: Colors.red)),
        content: const Text('هل أنت متأكد من إعادة تعيين جميع الإعدادات؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
                  _selectedMuezzin = 'marwan';
                  _notificationsEnabled = true;
                  _soundEnabled = true;
                  _soundVolume = 0.8;
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إعادة التعيين')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ===== تحميل الأذان =====
  Future<void> _startDownload() async {
    double totalProgress = 0;
    String currentMuezzin = 'جاري التحضير...';
    int completed = 0;
    final total = AdhanDownloadService.muezzinUrls.length;

    // عرض حوار التقدم
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2541),
              title: const Text('📥 جاري تحميل الأذان', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: totalProgress,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFD4AF37),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Text('$completed / $total', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(currentMuezzin, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final ids = AdhanDownloadService.muezzinUrls.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        final id = ids[i];
        currentMuezzin = MuezzinData.getMuezzinName(id);
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await _startDownload();
          return;
        }
        await AdhanDownloadService.downloadMuezzin(id, (p) {
          totalProgress = (i + p) / total;
        });
        completed = i + 1;
      }
    } catch (e) {}

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحميل جميع الأذان بنجاح!'), duration: Duration(seconds: 3)),
      );
    }
  }

  Widget _buildSettingsCard(Widget child) {
    return Card(
      color: const Color(0xFF1C2541),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

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
            Text('⚙️ الإعدادات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  // ===== 1. الدينية =====
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
                  Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 24),
                  SizedBox(width: 8),
                  Text('📍 الموقع الحالي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    Text('🏙️ $_userCity', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('📍 ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)}', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(_isLocationReady ? Icons.gps_fixed : Icons.gps_off, color: _isLocationReady ? Colors.green : Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(_isLocationReady ? '✅ الموقع مفعل' : '❌ الموقع غير مفعل', style: TextStyle(color: _isLocationReady ? Colors.green : Colors.red, fontSize: 12)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showLocationPicker,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تغيير'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
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
              const Row(
                children: [
                  Icon(Icons.volume_up, color: Color(0xFFD4AF37), size: 24),
                  SizedBox(width: 8),
                  Text('🎙️ المؤذن', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                items: MuezzinData.muezzins.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['name']!))).toList(),
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

        // ===== تحميل الأذان =====
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download, color: Color(0xFFD4AF37), size: 24),
                  SizedBox(width: 8),
                  Text('📥 تحميل الأذان', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('حمّل الأذان مرة واحدة ليعمل بدون إنترنت', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              FutureBuilder<int>(
                future: AdhanDownloadService.downloadedCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  final isComplete = count >= AdhanDownloadService.muezzinUrls.length;
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: count / AdhanDownloadService.muezzinUrls.length,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFD4AF37),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Text('$count / ${AdhanDownloadService.muezzinUrls.length} مؤذن محمّل', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isComplete ? null : _startDownload,
                              icon: const Icon(Icons.download, size: 16),
                              label: Text(isComplete ? 'محمّل ✅' : 'تحميل الآن'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (count > 0)
                            ElevatedButton.icon(
                              onPressed: () async {
                                await AdhanDownloadService.clearAll();
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ تم الحذف')));
                              },
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('حذف'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                            ),
                        ],
                      ),
                    ],
                  );
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
              const Text('🔔 الإشعارات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('تفعيل الإشعارات', style: TextStyle(color: Colors.white70)),
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

  // ===== 2. العامة =====
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
                  Icon(Icons.image, color: Color(0xFFD4AF37), size: 24),
                  SizedBox(width: 8),
                  Text('🖼️ خلفية التطبيق', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(_backgrounds[_selectedBackground]['name'] ?? '', style: const TextStyle(color: Colors.white70))),
                  ElevatedButton.icon(
                    onPressed: _showBackgroundPicker,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('تغيير'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
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
              const Text('⏰ تنسيق الوقت', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(_selectedTimeFormat == '24h' ? '24 ساعة' : '12 ساعة', style: const TextStyle(color: Colors.white70))),
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
                    style: SegmentedButton.styleFrom(selectedForegroundColor: Colors.black, selectedBackgroundColor: const Color(0xFFD4AF37)),
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
              const Row(
                children: [
                  Icon(Icons.restore, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('🔄 إعادة التعيين', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _showResetDialog,
                icon: const Icon(Icons.warning, size: 16),
                label: const Text('إعادة التعيين'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== 3. الصوت =====
  Widget _buildSoundSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔊 الصوت', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('تفعيل الصوت', style: TextStyle(color: Colors.white70)),
                value: _soundEnabled,
                onChanged: (v) {
                  setState(() => _soundEnabled = v);
                  _saveSettings();
                },
                activeColor: const Color(0xFFD4AF37),
              ),
              Row(
                children: [
                  const Icon(Icons.volume_down, color: Color(0xFFD4AF37), size: 20),
                  Expanded(
                    child: Slider(
                      value: _soundVolume,
                      activeColor: const Color(0xFFD4AF37),
                      onChanged: (v) {
                        setState(() => _soundVolume = v);
                        _saveSettings();
                      },
                    ),
                  ),
                  Text('${(_soundVolume * 100).toInt()}%', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== 4. المعلومات =====
  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          Column(
            children: [
              const Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 80),
              const SizedBox(height: 16),
              const Text('نور الحرمين', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('تطبيق إسلامي عالمي', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const Divider(color: Colors.grey, height: 32),
              _buildInfoRow('الإصدار', _appVersion),
              _buildInfoRow('الحزمة', 'com.apexsec.noor_al_haramain_global'),
              _buildInfoRow('المنصة', 'Android'),
              _buildInfoRow('اللغة', 'العربية'),
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
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
