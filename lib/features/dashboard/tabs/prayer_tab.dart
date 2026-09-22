import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/hijri_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/adhan_download_service.dart';
import '../../qibla/qibla_screen.dart';
import '../../kids/kids_stories_screen.dart';

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  bool _isDetectingLocation = false;
  String _errorMessage = '';
  String _userName = 'مستخدم';
  List<Map<String, dynamic>> _prayerList = [];

  double _userLat = 21.4225;
  double _userLng = 39.8262;

  String _selectedMuezzinId = 'adhan_sudais';
  String _selectedMuezzinName = 'الشيخ عبد الرحمن السديس';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Map<String, int> _prayerOffsets = {};

  bool _showWeeklyTable = false;
  bool _showDua = false;

  Timer? _timer;
  String? _lastAdhanTriggeredPrayer;
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

    // ✅ Chronometer: نضبط الإشعار الدائم مرة واحدة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePersistentNotification();
    });
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
      _updatePersistentNotification();
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
    String id = prefs.getString('selected_muezzin') ?? 'adhan_sudais';

    final valid = NotificationService.muezzins.any((m) => m['file'] == id);
    if (!valid) {
      id = 'adhan_sudais';
      await prefs.setString('selected_muezzin', id);
    }

    final matching = NotificationService.muezzins.firstWhere(
      (m) => m['file'] == id,
      orElse: () => NotificationService.muezzins.first,
    );

    if (mounted) {
      setState(() {
        _selectedMuezzinId = id;
        _selectedMuezzinName = matching['name'] ?? 'مؤذن';
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
          decoded.map((key, value) =>
              MapEntry(key, int.tryParse(value.toString()) ?? 0)),
        );
      } catch (e) {
        _prayerOffsets = {};
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 تحديد الموقع التلقائي
  // ═══════════════════════════════════════════════════════════
  Future<void> _detectLocationAutomatically() async {
    if (_isDetectingLocation) return;

    setState(() => _isDetectingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showSnack('📍 خدمة الموقع مغلقة. جاري فتح الإعدادات...');
        await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(seconds: 3));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showSnack('⚠️ لم يتم تفعيل خدمة الموقع. حاول مرة أخرى.');
          if (mounted) setState(() => _isDetectingLocation = false);
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack('⚠️ الإذن مرفوض نهائياً. جاري فتح الإعدادات...');
        await Geolocator.openAppSettings();
        if (mounted) setState(() => _isDetectingLocation = false);
        return;
      }

      if (permission == LocationPermission.denied) {
        _showSnack('⚠️ لم يتم منح إذن الموقع.');
        if (mounted) setState(() => _isDetectingLocation = false);
        return;
      }

      _showSnack('📍 جاري تحديد موقعك...');

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      debugPrint('✅ الموقع: ${position.latitude}, ${position.longitude}');

      String city = 'موقعك';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.locality ??
              p.subAdministrativeArea ??
              p.administrativeArea ??
              p.country ??
              'موقعك';
        }
      } catch (e) {
        debugPrint('⚠️ فشل geocoding: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('user_lat', position.latitude);
      await prefs.setDouble('user_lng', position.longitude);
      await prefs.setString('user_city', city);
      await prefs.setBool('location_enabled', true);

      if (!mounted) return;

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _cityName = city;
        _lastFetchTime = DateTime.now().subtract(const Duration(hours: 2));
      });

      await _loadLocationAndFetchTimes();

      _showSnack('✅ تم تحديد الموقع: $city');
    } on TimeoutException {
      _showSnack('⚠️ انتهت مهلة تحديد الموقع. حاول مرة أخرى.');
    } catch (e) {
      debugPrint('❌ فشل تحديد الموقع: $e');
      _showSnack('⚠️ فشل تحديد الموقع. تأكد من تفعيل GPS.');
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 جلب أوقات الصلاة
  // ═══════════════════════════════════════════════════════════
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

        await prefs.setString('cached_prayer_times', jsonEncode(_prayerTimes));
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
            'Sunrise': _applyOffset(
                'Sunrise', timings['Sunrise']?.toString() ?? '00:00'),
            'Dhuhr':
                _applyOffset('Dhuhr', timings['Dhuhr']?.toString() ?? '00:00'),
            'Asr': _applyOffset('Asr', timings['Asr']?.toString() ?? '00:00'),
            'Maghrib': _applyOffset(
                'Maghrib', timings['Maghrib']?.toString() ?? '00:00'),
            'Isha': _applyOffset('Isha', timings['Isha']?.toString() ?? '00:00'),
          };
          _buildPrayerListFromTimes();

          await NotificationService.schedulePrayerNotifications(
            _prayerTimes.map((k, v) => MapEntry(k, v.toString())),
            _cityName,
            _selectedMuezzinName,
          );

          // ✅ تحديث الإشعار الدائم بعد جلب الأوقات الجديدة
          await _updatePersistentNotification();
        }
      }
    } catch (e) {}
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
              'Fajr':
                  _applyOffset('Fajr', timings['Fajr']?.toString() ?? '00:00'),
              'Dhuhr': _applyOffset(
                  'Dhuhr', timings['Dhuhr']?.toString() ?? '00:00'),
              'Asr':
                  _applyOffset('Asr', timings['Asr']?.toString() ?? '00:00'),
              'Maghrib': _applyOffset(
                  'Maghrib', timings['Maghrib']?.toString() ?? '00:00'),
              'Isha':
                  _applyOffset('Isha', timings['Isha']?.toString() ?? '00:00'),
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
      _checkAdhanTime();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // ⏱️ الإشعار الدائم — Chronometer (بدون Timer)
  // ═══════════════════════════════════════════════════════════
  Future<void> _updatePersistentNotification() async {
    try {
      if (!mounted) return;
      if (_prayerList.isEmpty) return;

      final hijri = HijriService.getHijriDate(DateTime.now());

      // 🎯 حساب وقت الصلاة القادمة الفعلي
      final nextPrayerTime = _calculateNextPrayerTime();
      if (nextPrayerTime == null) {
        debugPrint('⚠️ لم نتمكن من حساب وقت الصلاة القادمة');
        return;
      }

      await NotificationService.showPersistentNotification(
        nextPrayer: _nextPrayer,
        targetTime: nextPrayerTime,
        hijriDate: hijri,
        city: _cityName,
      );
    } catch (e) {
      debugPrint('⚠️ تحديث الإشعار الدائم فشل: $e');
    }
  }

  /// 🎯 حساب وقت الصلاة القادمة (DateTime)
  DateTime? _calculateNextPrayerTime() {
    try {
      final now = DateTime.now();

      for (var prayer in _prayerList) {
        final timeStr = (prayer['time'] ?? '').toString();
        final cleanTime = timeStr
            .replaceAll(RegExp(r'\(.*\)'), '')
            .replaceAll(RegExp(r'AM|PM', caseSensitive: false), '')
            .trim();
        if (cleanTime.isEmpty) continue;

        final parts = cleanTime.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final prayerTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        if (prayerTime.isAfter(now)) {
          return prayerTime;
        }
      }

      // لم توجد — نرجع وقت الفجر غداً
      if (_prayerList.isNotEmpty) {
        final fajrStr = (_prayerList.first['time'] ?? '').toString();
        final cleanFajr = fajrStr
            .replaceAll(RegExp(r'\(.*\)'), '')
            .replaceAll(RegExp(r'AM|PM', caseSensitive: false), '')
            .trim();
        final parts = cleanFajr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 5;
          final minute = int.tryParse(parts[1]) ?? 0;
          return DateTime(
            now.year,
            now.month,
            now.day + 1,
            hour,
            minute,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ _calculateNextPrayerTime: $e');
      return null;
    }
  }

  void _checkAdhanTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);

    for (var prayer in _prayerList) {
      final name = prayer['name'] as String;
      final time = (prayer['time'] ?? '').toString();
      final cleanTime = time
          .replaceAll(RegExp(r'\(.*\)'), '')
          .replaceAll(RegExp(r'AM|PM', caseSensitive: false), '')
          .trim();

      if (cleanTime == currentTime &&
          _lastAdhanTriggeredPrayer != '$name-$currentTime') {
        if (name.contains('الشروق')) continue;
        _lastAdhanTriggeredPrayer = '$name-$currentTime';
        _triggerAdhanAutomatically(name);
        break;
      }
    }
  }

  Future<bool> _playAdhanFromAssets(String muezzinId) async {
    final assetSourcePath =
        await AdhanDownloadService.getAssetSourcePath(muezzinId);
    if (assetSourcePath == null) {
      debugPrint('⚠️ الأذان غير متاح: $muezzinId');
      return false;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetSourcePath));
      return true;
    } catch (e) {
      debugPrint('❌ فشل تشغيل الأذان: $e');
      return false;
    }
  }

  Future<void> _triggerAdhanAutomatically(String prayerName) async {
    try {
      final started = await _playAdhanFromAssets(_selectedMuezzinId);
      if (!started) return;

      if (mounted) setState(() => _isPlaying = true);

      await _audioPlayer.onPlayerComplete.first;
      if (mounted) setState(() => _isPlaying = false);

      await Future.delayed(const Duration(milliseconds: 500));
      await _playDuaAfterAdhan();
    } catch (e) {
      debugPrint('❌ خطأ في تشغيل الأذان: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _playDuaAfterAdhan() async {
    try {
      final duaPlayer = AudioPlayer();
      await duaPlayer.play(
        AssetSource('adhan/dua/dua_after_adhan.mp3'),
      );
      await duaPlayer.onPlayerComplete.first;
      await duaPlayer.dispose();
    } catch (e) {
      await _speakDuaWithTts();
    }
  }

  Future<void> _speakDuaWithTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('ar');
      await tts.setSpeechRate(0.4);
      await tts.speak(
        'اللهم رب هذه الدعوة التامة، والصلاة القائمة، '
        'آت محمداً الوسيلة والفضيلة، وابعثه مقاماً محموداً الذي وعدته',
      );
    } catch (e) {
      debugPrint('⚠️ فشل TTS: $e');
    }
  }

  Future<void> _playAdhan(String prayerName) async {
    try {
      final started = await _playAdhanFromAssets(_selectedMuezzinId);
      if (!started) {
        _showSnack('⚠️ الأذان غير متاح');
        return;
      }

      if (mounted) setState(() => _isPlaying = true);

      _showSnack('🔊 تشغيل الأذان لصلاة $prayerName');

      await _audioPlayer.onPlayerComplete.first;
      if (mounted) setState(() => _isPlaying = false);

      if (mounted) setState(() => _showDua = true);
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => _showDua = false);
    } catch (e) {
      debugPrint('❌ خطأ في تشغيل الأذان: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _openDonation() async {
    const url = 'https://ehsan.sa/';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('⚠️ تعذر فتح منصة إحسان');
      }
    } catch (e) {
      _showSnack('⚠️ خطأ: $e');
    }
  }

  void _openKidsStories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KidsStoriesScreen(),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
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
              final validValue = NotificationService.muezzins
                      .any((m) => m['file'] == tempMuezzinId)
                  ? tempMuezzinId
                  : 'adhan_sudais';

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
                          color:
                              const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: validValue,
                      dropdownColor: const Color(0xFF1C2541),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox(),
                      isExpanded: true,
                      items: NotificationService.muezzins.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['file']!,
                          child: Text(m['name']!),
                        );
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
                await NotificationService.setSelectedMuezzin(tempMuezzinId);
                if (tempOffset != 0) {
                  _prayerOffsets[prayerName] = tempOffset;
                } else {
                  _prayerOffsets.remove(prayerName);
                }
                await prefs.setString(
                    'prayer_offsets', jsonEncode(_prayerOffsets));
                final matching = NotificationService.muezzins.firstWhere(
                  (m) => m['file'] == tempMuezzinId,
                  orElse: () => NotificationService.muezzins.first,
                );
                if (mounted) {
                  setState(() {
                    _selectedMuezzinId = tempMuezzinId;
                    _selectedMuezzinName = matching['name'] ?? 'مؤذن';
                  });
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadLocationAndFetchTimes();
              },
              child: const Text('تطبيق'),
            ),
          ],
        );
      },
    );
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Color(0xFFD4AF37), size: 16),
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
                              crossAxisAlignment: CrossAxisAlignment.end,
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                              icon: Icons.child_care,
                              label: 'أطفال',
                              onTap: _openKidsStories,
                            ),
                            _buildControlButton(
                              icon: Icons.volunteer_activism,
                              label: 'تبرع',
                              onTap: _openDonation,
                            ),
                            _buildControlButton(
                              icon: Icons.my_location,
                              label: _isDetectingLocation
                                  ? 'جاري...'
                                  : 'موقعي',
                              onTap: _detectLocationAutomatically,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.15),
                                const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.05)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3)),
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
                                    onTap: _isPlaying
                                        ? _stopAudio
                                        : () => _playAdhan(_nextPrayer),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: const BoxDecoration(
                                          color: Color(0xFFD4AF37),
                                          shape: BoxShape.circle),
                                      child: Icon(
                                        _isPlaying
                                            ? Icons.stop
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
