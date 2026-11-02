import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _persistentId = 999999;
  static const String _adhanChannelId = 'adhan_channel_v15';
  static const String _iqamaChannelId = 'iqama_channel_v15';
  static const String _persistentChannelId = 'persistent_channel_v15';
  static const String _notifIcon = '@mipmap/launcher_icon';
  static const String _muezzinKey = 'selected_muezzin';

  // ✅ تم إصلاح الأسماء هنا (القصاص والقطامي)
  static const List<Map<String, String>> muezzins = [
    {'name': 'الشيخ عبد الرحمن السديس', 'file': 'adhan_sudais'},
    {'name': 'الشيخ ماهر المعيقلي', 'file': 'adhan_almuaiqly'},
    {'name': 'الشيخ ياسر الدوسري', 'file': 'adhan_yasser'},
    {'name': 'الشيخ ناصر القطامي', 'file': 'adhan_qassas'},
    {'name': 'الشيخ محمد مروان القصاص', 'file': 'adhan_qatami'},
    {'name': 'الشيخ سعد الغامدي', 'file': 'adhan_ghamdi'},
    {'name': 'الشيخ مشاري العفاسي', 'file': 'adhan_alafasy'},
    {'name': 'الشيخ عبد الباسط عبد الصمد', 'file': 'adhan_abdalbaset'},
    {'name': 'الشيخ محمد صديق المنشاوي', 'file': 'adhan_minshawi'},
    {'name': 'الشيخ محمود خليل الحصري', 'file': 'adhan_husary'},
    {'name': 'الشيخ مصطفى إسماعيل', 'file': 'adhan_ismail'},
    {'name': 'الشيخ عبد العزيز الزهراني', 'file': 'adhan_zahrani'},
    {'name': 'الشيخ فارس عباد', 'file': 'adhan_abbad'},
    {'name': 'الشيخ أحمد بن علي العجمي', 'file': 'adhan_ajmi'},
    {'name': 'الشيخ خالد الجليل', 'file': 'adhan_jalil'},
  ];

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(_notifIcon);
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings, onDidReceiveNotificationResponse: _onTap, onDidReceiveBackgroundNotificationResponse: _onTapBackground);
    await _createChannels();
    await _requestPermissions();
    _initialized = true;
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(_adhanChannelId, 'الأذان', importance: Importance.max, playSound: true, enableVibration: true));
    await android.createNotificationChannel(const AndroidNotificationChannel(_iqamaChannelId, 'الإقامة', importance: Importance.max, playSound: true, enableVibration: true));
    await android.createNotificationChannel(const AndroidNotificationChannel(_persistentChannelId, 'الصلاة القادمة', importance: Importance.low, playSound: false));
  }

  static Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static void _onTap(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) _handlePayload(response.payload!);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {}

  static void _handlePayload(String payload) {
    try {
      final parts = payload.split('|');
      if (parts.length < 5) return;
      navigatorKey.currentState?.pushNamed('/adhan', arguments: {
        'prayerName': parts[1], 'prayerTime': parts[2], 'cityName': parts[3],
        'muezzinName': parts[4], 'isIqamaOnly': parts[0] == 'إقامة',
      });
    } catch (e) { debugPrint('⚠️ $e'); }
  }

  static Future<String> getSelectedMuezzin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_muezzinKey) ?? 'adhan_sudais';
  }

  static Future<void> setSelectedMuezzin(String file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_muezzinKey, file);
  }

  static Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    final muezzin = await getSelectedMuezzin();
    await _notifications.show(1001, '🔔 اختبار الأذان', 'اضغط لفتح شاشة الأذان فوراً', NotificationDetails(
      android: AndroidNotificationDetails(_adhanChannelId, 'الأذان', importance: Importance.max, priority: Priority.max, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, playSound: true, sound: RawResourceAndroidNotificationSound(muezzin), enableVibration: true),
    ), payload: 'صلاة|العصر|15:30|مكة المكرمة|$muezzin');
  }

  static Future<void> showTestIqamaNotification() async {
    if (!_initialized) await initialize();
    final muezzin = await getSelectedMuezzin();
    await _notifications.show(1002, '🕌 اختبار الإقامة', 'اضغط لفتح شاشة الإقامة فوراً', NotificationDetails(
      android: AndroidNotificationDetails(_iqamaChannelId, 'الإقامة', importance: Importance.max, priority: Priority.max, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, playSound: true, sound: RawResourceAndroidNotificationSound(muezzin), enableVibration: true),
    ), payload: 'إقامة|العصر|15:45|مكة المكرمة|$muezzin');
  }

  static Future<void> schedulePrayerNotifications(Map<String, String> prayerTimes, String cityName, String muezzinName) async {
    if (!_initialized) await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? true)) return;
    
    final muezzin = await getSelectedMuezzin();
    final pending = await _notifications.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id != _persistentId) await _notifications.cancel(p.id);
    }
    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      if (entry.key == 'Sunrise') continue;
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      var scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

      final prayerNameAr = _translatePrayerName(entry.key);
      final timeStr = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

      try {
        await _notifications.zonedSchedule(
          entry.key.hashCode, '🔔 حان وقت صلاة $prayerNameAr', 'صلاة $prayerNameAr في $cityName — $muezzinName',
          tz.TZDateTime.from(scheduledTime, tz.local), NotificationDetails(
            android: AndroidNotificationDetails(_adhanChannelId, 'الأذان', importance: Importance.max, priority: Priority.max, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, playSound: true, sound: RawResourceAndroidNotificationSound(muezzin)),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'صلاة|$prayerNameAr|$timeStr|$cityName|$muezzin',
        );
      } catch (e) { debugPrint('⚠️ $e'); }
    }
  }

  static String _translatePrayerName(String key) {
    const map = {'Fajr': 'الفجر', 'Dhuhr': 'الظهر', 'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء', 'Sunrise': 'الشروق'};
    return map[key] ?? key;
  }

  static Future<void> showPersistentNotification({String? title, String? body, String? nextPrayer, DateTime? targetTime, Duration? remaining, String? hijriDate, String? city, int? minutesLeft}) async {
    if (Platform.isLinux || !_initialized) return;
    String t = title ?? (nextPrayer != null ? '🕌 الصلاة القادمة: $nextPrayer' : '🕌 الصلاة القادمة');
    final buffer = StringBuffer();
    if (city != null && city.isNotEmpty) buffer.write('📍 $city');
    final b = buffer.toString().trim().isEmpty ? 'اقترب وقت الصلاة' : buffer.toString();
    final finalTarget = targetTime ?? DateTime.now().add(remaining ?? const Duration(hours: 1));
    final whenMillis = finalTarget.millisecondsSinceEpoch;
    await _notifications.show(_persistentId, t, b, NotificationDetails(
      android: AndroidNotificationDetails(_persistentChannelId, 'الصلاة القادمة', icon: _notifIcon, importance: Importance.low, priority: Priority.low, playSound: false, enableVibration: false, ongoing: true, autoCancel: false, when: whenMillis, usesChronometer: true, chronometerCountDown: true, showWhen: true, onlyAlertOnce: true, color: const Color(0xFF4A90E2)),
    ));
  }
}
