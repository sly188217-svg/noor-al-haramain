import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/hijri_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/adhan_download_service.dart';
import '../../../core/data/muezzins.dart';
import '../../qibla/qibla_screen.dart';

// ==============================================
// خلفية إسلامية
// ==============================================
class IslamicBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;

    for (int i = 0; i < 8; i++) {
      final angle = i * (pi / 4);
      final dx = radius * cos(angle);
      final dy = radius * sin(angle);
      final point = Offset(center.dx + dx, center.dy + dy);
      canvas.drawLine(center, point, paint);
      canvas.drawCircle(point, 4, paint);
    }

    for (int i = 0; i < 8; i++) {
      final angle1 = i * (pi / 4);
      final angle2 = (i + 1) * (pi / 4);
      final dx1 = radius * cos(angle1);
      final dy1 = radius * sin(angle1);
      final dx2 = radius * cos(angle2);
      final dy2 = radius * sin(angle2);
      final p1 = Offset(center.dx + dx1, center.dy + dy1);
      final p2 = Offset(center.dx + dx2, center.dy + dy2);
      final midAngle = (angle1 + angle2) / 2;
      final midRadius = radius * 1.2;
      final midDx = midRadius * cos(midAngle);
      final midDy = midRadius * sin(midAngle);
      final midPoint = Offset(center.dx + midDx, center.dy + midDy);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(midPoint.dx, midPoint.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==============================================
// PrayerTab
// ==============================================
class PrayerTab extends StatefulWidget {
  const PrayerTab({super.key});

  @override
  State<PrayerTab> createState() => _PrayerTabState();
}

class _PrayerTabState extends State<PrayerTab> with WidgetsBindingObserver {
  final ValueNotifier<Duration> _timeRemainingNotifier =
      ValueNotifier(Duration.zero);

  Map<String, dynamic> _prayerTimes = {};
  Map<String, dynamic> _weeklyPrayers = {};
  String _cityName = 'جاري التحميل...';
  String _nextPrayer = '--';
  bool _isLoading = true;
  String _errorMessage = '';
  String _userName = 'مستخدم';
  List<Map<String, dynamic>> _prayerList = [];

  double _userLat = 21.4225;
  double _userLng = 39.8262;

  String _selectedMuezzinId = 'marwan';
  String _selectedMuezzinName = 'محمد مروان القصاص';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Map<String, int> _prayerOffsets = {};

  bool _showWeeklyTable = false;
  bool _showDua = false;

  Timer? _timer;
  DateTime _lastFetchTime =
      DateTime.now().subtract(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadMuezzinPreference();
    _loadPrayerOffsets();
    _loadLocationAndFetchTimes();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    _timeRemainingNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastFetchTime).inHours >= 1) {
        _loadLocationAndFetchTimes();
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _userName = prefs.getString('user_name') ?? 'مستخدم');
    }
  }

  Future<void> _loadMuezzinPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('selected_muezzin') ?? 'marwan';
    final name = MuezzinData.getMuezzinName(id);
    if (mounted) {
      setState(() {
        _selectedMuezzinId = id;
        _selectedMuezzinName = name;
      });
    }
  }

  Future<void> _loadPrayerOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOffsets = prefs.getString('prayer_offsets');
    if (savedOffsets != null) {
      try {
        final decoded = jsonDecode(savedOffsets);
        _prayerOffsets = Map<String, int>.from(
          decoded.map(
              (key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0)),
        );
      } catch (e) {
        _prayerOffsets = {};
      }
    }
  }

  Future<void> _loadLocationAndFetchTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTimes = prefs.getString('cached_prayer_times');
    final cachedCity = prefs.getString('cached_city');

    if (cachedTimes != null && cachedCity != null) {
      try {
        _prayerTimes = Map<String, dynamic>.from(jsonDecode(cachedTimes));
        _cityName = cachedCity;
        _buildPrayerListFromTimes();
        if (mounted) setState(() => _isLoading = false);
      } catch (e) {}
    }

    if (DateTime.now().difference(_lastFetchTime).inHours >= 1) {
      if (mounted) setState(() => _isLoading = true);
      try {
        _userLat = prefs.getDouble('user_lat') ?? 21.4225;
        _userLng = prefs.getDouble('user_lng') ?? 39.8262;
        _cityName = prefs.getString('user_city') ?? 'مكة المكرمة';

        await _fetchPrayerTimesFromAPI();
        await _fetchWeeklyPrayers();

        await prefs.setString(
            'cached_prayer_times', jsonEncode(_prayerTimes));
        await prefs.setString('cached_city', _cityName);
        _lastFetchTime = DateTime.now();
      } catch (e) {
        if (mounted) {
          setState(() =>
              _errorMessage = 'تعذر تحديث الأوقات، استخدم البيانات المخزنة');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPrayerTimesFromAPI() async {
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    final url =
        'https://api.aladhan.com/v1/timings/$dateStr?latitude=$_userLat&longitude=$_userLng&method=4';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          final timings = data['data']['timings'];
          _prayerTimes = {
            'Fajr': _applyOffset('Fajr', timings['Fajr']?.toString() ?? '00:00'),
            'Sunrise':
                _applyOffset('Sunrise', timings['Sunrise']?.toString() ?? '00:00'),
            'Dhuhr':
                _applyOffset('Dhuhr', timings['Dhuhr']?.toString() ?? '00:00'),
            'Asr': _applyOffset('Asr', timings['Asr']?.toString() ?? '00:00'),
            'Maghrib':
                _applyOffset('Maghrib', timings['Maghrib']?.toString() ?? '00:00'),
            'Isha': _applyOffset('Isha', timings['Isha']?.toString() ?? '00:00'),
          };
          _buildPrayerListFromTimes();

          // ✅ جدولة إشعارات الأذان لكل صلاة
          await NotificationService.schedulePrayerNotifications(
            _prayerTimes.map((k, v) => MapEntry(k, v.toString())),
            _cityName,
            _selectedMuezzinName,
          );
        }
      }
    } catch (e) {
      // تجاهل — سنستخدم البيانات المخزنة
    }
  }

  String _applyOffset(String prayerName, String timeStr) {
    final offset = _prayerOffsets[prayerName] ?? 0;
    if (offset == 0) return timeStr;
    try {
      String clean = timeStr.replaceAll(RegExp(r'\(.*\)'), '').trim();
      clean =
          clean.replaceAll(RegExp(r'AM|PM', caseSensitive: false), '').trim();
      final parts = clean.split(':');
      if (parts.length != 2) return timeStr;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      minute += offset;
      while (minute >= 60) {
        minute -= 60;
        hour++;
      }
      while (minute < 0) {
        minute += 60;
        hour--;
      }
      hour = hour.clamp(0, 23);
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _fetchWeeklyPrayers() async {
    if (_weeklyPrayers.isNotEmpty) return;
    final now = DateTime.now();
    Map<String, dynamic> weekly = {};
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final dateStr = DateFormat('dd-MM-yyyy').format(date);
      final url =
          'https://api.aladhan.com/v1/timings/$dateStr?latitude=$_userLat&longitude=$_userLng&method=4';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['code'] == 200) {
            final timings = data['data']['timings'];
            weekly[DateFormat('EEEE', 'ar').format(date)] = {
              'Fajr': _applyOffset('Fajr', timings['Fajr']?.toString() ?? '00:00'),
              'Dhuhr':
                  _applyOffset('Dhuhr', timings['Dhuhr']?.toString() ?? '00:00'),
              'Asr': _applyOffset('Asr', timings['Asr']?.toString() ?? '00:00'),
              'Maghrib': _applyOffset(
                  'Maghrib', timings['Maghrib']?.toString() ?? '00:00'),
              'Isha': _applyOffset('Isha', timings['Isha']?.toString() ?? '00:00'),
            };
          }
        }
      } catch (e) {}
    }
    if (mounted) setState(() => _weeklyPrayers = weekly);
  }

  void _buildPrayerListFromTimes() {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final nowStr = timeFormat.format(now);

    List<Map<String, dynamic>> prayers = [
      {
        'name': 'الفجر',
        'icon': Icons.wb_twilight,
        'time': _prayerTimes['Fajr']?.toString() ?? '00:00',
      },
      {
        'name': 'الشروق',
        'icon': Icons.wb_sunny,
        'time': _prayerTimes['Sunrise']?.toString() ?? '00:00',
      },
      {
        'name': 'الظهر',
        'icon': Icons.light_mode,
        'time': _prayerTimes['Dhuhr']?.toString() ?? '00:00',
      },
      {
        'name': 'العصر',
        'icon': Icons.wb_sunny_outlined,
        'time': _prayerTimes['Asr']?.toString() ?? '00:00',
      },
      {
        'name': 'المغرب',
        'icon': Icons.nights_stay,
        'time': _prayerTimes['Maghrib']?.toString() ?? '00:00',
      },
      {
        'name': 'العشاء',
        'icon': Icons.nightlight_round,
        'time': _prayerTimes['Isha']?.toString() ?? '00:00',
      },
    ];

    String nextName = 'العشاء';
    Duration remaining = Duration.zero;
    bool foundNext = false;

    for (var prayer in prayers) {
      final prayerTimeStr = (prayer['time'] ?? '00:00').toString();
      String cleanTime =
          prayerTimeStr.replaceAll(RegExp(r'\(.*\)'), '').trim();
      cleanTime =
          cleanTime.replaceAll(RegExp(r'AM|PM', caseSensitive: false), '').trim();
      try {
        final prayerTime = DateFormat('HH:mm').parse(cleanTime);
        final nowTime = DateFormat('HH:mm').parse(nowStr);
        if (prayerTime.isAfter(nowTime) && !foundNext) {
          nextName = prayer['name']!;
          remaining = prayerTime.difference(nowTime);
          foundNext = true;
          prayer['isNext'] = true;
        } else {
          prayer['isNext'] = false;
        }
      } catch (e) {
        prayer['isNext'] = false;
      }
    }

    if (!foundNext) {
      nextName = 'الفجر (غداً)';
      try {
        final fajrRaw = (_prayerTimes['Fajr'] ?? '00:00').toString();
        final fajrStr = fajrRaw.replaceAll(RegExp(r'\(.*\)'), '').trim();
        final cleanFajr =
            fajrStr.replaceAll(RegExp(r'AM|PM', caseSensitive: false), '').trim();
        final fajrTime = DateFormat('HH:mm').parse(cleanFajr);
        final nowTime = DateFormat('HH:mm').parse(nowStr);
        final secondsToMidnight =
            (24 * 3600) - (nowTime.hour * 3600 + nowTime.minute * 60);
        final fajrSeconds = fajrTime.hour * 3600 + fajrTime.minute * 60;
        remaining = Duration(seconds: secondsToMidnight + fajrSeconds);
      } catch (e) {
        remaining = const Duration(hours: 8);
      }
      prayers.first['isNext'] = true;
    }

    if (mounted) {
      setState(() {
        _prayerList = prayers;
        _nextPrayer = nextName;
        _timeRemainingNotifier.value = remaining;
      });
    }
  }

  void _startCountdownTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemainingNotifier.value > Duration.zero) {
        _timeRemainingNotifier.value -= const Duration(seconds: 1);
      } else {
        _loadLocationAndFetchTimes();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _showPrayerSettings(String prayerName) {
    if (prayerName.isEmpty) return;
    final currentOffset = _prayerOffsets[prayerName] ?? 0;
    int tempOffset = currentOffset;
    String tempMuezzinId = _selectedMuezzinId;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          title: Text(
            '⚙️ إعدادات صلاة $prayerName',
            style: const TextStyle(color: Color(0xFFD4AF37)),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎙️ تغيير صوت الأذان:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B132B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: tempMuezzinId,
                      dropdownColor: const Color(0xFF1C2541),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox(),
                      items: MuezzinData.muezzins.map((m) {
                        return DropdownMenuItem(
                            value: m['id'], child: Text(m['name']!));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => tempMuezzinId = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('⏱️ تعديل الوقت يدوياً:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove,
                            color: Color(0xFFD4AF37)),
                        onPressed: () =>
                            setDialogState(() => tempOffset -= 1),
                      ),
                      Text('$tempOffset دقيقة',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18)),
                      IconButton(
                        icon:
                            const Icon(Icons.add, color: Color(0xFFD4AF37)),
                        onPressed: () =>
                            setDialogState(() => tempOffset += 1),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_muezzin', tempMuezzinId);
                if (tempOffset != 0) {
                  _prayerOffsets[prayerName] = tempOffset;
                } else {
                  _prayerOffsets.remove(prayerName);
                }
                await prefs.setString(
                    'prayer_offsets', jsonEncode(_prayerOffsets));
                if (mounted) {
                  setState(() {
                    _selectedMuezzinId = tempMuezzinId;
                    _selectedMuezzinName =
                        MuezzinData.getMuezzinName(tempMuezzinId);
                  });
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadLocationAndFetchTimes();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('✅ تم تحديث الإعدادات لصلاة $prayerName')),
                  );
                }
              },
              child: const Text('تطبيق'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  //  تشغيل الأذان
  // ============================================================
  Future<void> _playAdhan(String prayerName) async {
    try {
      final localPath =
          await AdhanDownloadService.getLocalPath(_selectedMuezzinId);
      final localFile = File(localPath);

      if (await localFile.exists() && await localFile.length() > 100000) {
        await _audioPlayer.play(DeviceFileSource(localPath));
        if (mounted) setState(() => _isPlaying = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('🔊 تشغيل الأذان (محلي) لصلاة $prayerName')),
          );
        }

        await Future.delayed(const Duration(seconds: 30));
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);

        if (mounted) setState(() => _showDua = true);
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) setState(() => _showDua = false);

        // فتح شاشة القبلة بعد الأذان
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QiblaScreen()),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ الأذان المحلي غير محمّل. اذهب إلى: الإعدادات ← تحميل الأذان'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تعذر تشغيل الأذان')),
        );
      }
    }
  }

  Widget _buildDuaScreen() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF0B132B)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 60),
              const SizedBox(height: 16),
              const Text('دعاء الأذان',
                  style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Amiri',
                    height: 1.8),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                  color: Color(0xFFD4AF37), strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// فتح شاشة القبلة
  void _openQiblaScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QiblaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    if (_showDua) return _buildDuaScreen();

    final now = DateTime.now();
    String gregorianDate;
    try {
      gregorianDate = DateFormat('dd MMMM yyyy', lang).format(now);
    } catch (e) {
      gregorianDate = DateFormat('dd MMMM yyyy', 'ar').format(now);
    }

    String hijriDate = '';
    try {
      hijriDate = HijriService.getHijriDate(now);
    } catch (e) {
      hijriDate = '';
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: IslamicBackgroundPainter(),
            size: MediaQuery.of(context).size,
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37)))
                : Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Color(0xFFD4AF37),
                                        size: 16),
                                    const SizedBox(width: 6),
                                    Text(_cityName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('👤 $_userName',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(gregorianDate,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12)),
                                if (hijriDate.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(hijriDate,
                                      style: const TextStyle(
                                          color: Color(0xFFD4AF37),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2541)
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up,
                                  color: Color(0xFFD4AF37), size: 16),
                              const SizedBox(width: 8),
                              Text('المؤذن: $_selectedMuezzinName',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: Icons.calendar_view_week,
                              label: '7 أيام',
                              onTap: () {
                                setState(() => _showWeeklyTable =
                                    !_showWeeklyTable);
                                if (_showWeeklyTable) _fetchWeeklyPrayers();
                              },
                            ),
                            _buildControlButton(
                              icon: Icons.explore,
                              label: 'القبلة',
                              onTap: _openQiblaScreen,
                            ),
                            _buildControlButton(
                              icon: Icons.refresh,
                              label: 'تحديث',
                              onTap: _loadLocationAndFetchTimes,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_showWeeklyTable && _weeklyPrayers.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C2541)
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('📅 الأيام السبعة القادمة',
                                    style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ..._weeklyPrayers.entries.map((entry) {
                                  final day = entry.key;
                                  final times =
                                      entry.value as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(day,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                        Row(
                                          children: [
                                            _buildMiniTime('فجر',
                                                times['Fajr']?.toString() ?? '--'),
                                            _buildMiniTime('ظهر',
                                                times['Dhuhr']?.toString() ?? '--'),
                                            _buildMiniTime('عصر',
                                                times['Asr']?.toString() ?? '--'),
                                            _buildMiniTime('مغرب',
                                                times['Maghrib']?.toString() ?? '--'),
                                            _buildMiniTime('عشاء',
                                                times['Isha']?.toString() ?? '--'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                const Color(0xFFD4AF37).withValues(alpha: 0.05)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('الصلاة القادمة',
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                      const SizedBox(height: 6),
                                      Text(_nextPrayer,
                                          style: const TextStyle(
                                              color: Color(0xFFD4AF37),
                                              fontSize: 24,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => _playAdhan(_nextPrayer),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: const BoxDecoration(
                                          color: Color(0xFFD4AF37),
                                          shape: BoxShape.circle),
                                      child: Icon(
                                        _isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: const Color(0xFF0B132B),
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('الوقت المتبقي',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14)),
                                  ValueListenableBuilder(
                                    valueListenable:
                                        _timeRemainingNotifier,
                                    builder: (context, value, child) {
                                      return Text(
                                        _formatDuration(value),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: 1 -
                                    (_timeRemainingNotifier.value.inSeconds /
                                            86400)
                                        .clamp(0.0, 1.0),
                                backgroundColor: Colors.white12,
                                color: const Color(0xFFD4AF37),
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _prayerList.length,
                            itemBuilder: (context, index) {
                              final prayer = _prayerList[index];
                              final isNext = prayer['isNext'] ?? false;
                              final prayerName =
                                  prayer['name']?.toString() ?? '';

                              return Material(
                                color: Colors.transparent,
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isNext
                                        ? const Color(0xFFD4AF37)
                                            .withValues(alpha: 0.15)
                                        : const Color(0xFF1C2541)
                                            .withValues(alpha: 0.5),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isNext
                                            ? const Color(0xFFD4AF37)
                                            : Colors.white12,
                                        width: isNext ? 1.5 : 0.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                              prayer['icon'] as IconData? ??
                                                  Icons.access_time,
                                              color: isNext
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.grey,
                                              size: 22),
                                          const SizedBox(width: 14),
                                          Text(
                                            prayerName,
                                            style: TextStyle(
                                                color: isNext
                                                    ? const Color(
                                                        0xFFD4AF37)
                                                    : Colors.white,
                                                fontSize: 15,
                                                fontWeight: isNext
                                                    ? FontWeight.bold
                                                    : FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.settings,
                                                color: Color(0xFFD4AF37),
                                                size: 16),
                                            onPressed: () =>
                                                _showPrayerSettings(
                                                    prayerName),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.volume_up,
                                                color: Color(0xFFD4AF37),
                                                size: 16),
                                            onPressed: () =>
                                                _playAdhan(prayerName),
                                          ),
                                          Text(
                                            prayer['time']?.toString() ??
                                                '--:--',
                                            style: TextStyle(
                                                color: isNext
                                                    ? const Color(
                                                        0xFFD4AF37)
                                                    : Colors.white70,
                                                fontSize: 15,
                                                fontWeight: isNext
                                                    ? FontWeight.bold
                                                    : FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_errorMessage,
                                style: const TextStyle(
                                    color: Colors.orange, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541).withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
            ),
            child:
                Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMiniTime(String name, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFF0B132B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4)),
      child: Text('$name: $time',
          style: const TextStyle(color: Colors.white54, fontSize: 9)),
    );
  }
}
