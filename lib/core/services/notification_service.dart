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
  static const String _adhanChannelId = 'adhan_channel_v8';
  static const String _iqamaChannelId = 'iqama_channel_v8';
  static const String _persistentChannelId = 'persistent_channel_v8';
  static const String _muezzinKey = 'selected_muezzin';
  static const String _defaultMuezzin = 'adhan_sudais';
  static const String _notifIcon = '@mipmap/launcher_icon';
  static const String _largeIconAsset = '@drawable/ic_app_colored';

  static const List<Map<String, String>> muezzins = [
    {'name': 'الشيخ عبد الرحمن السديس', 'file': 'adhan_sudais'},
    {'name': 'الشيخ ماهر المعيقلي', 'file': 'adhan_almuaiqly'},
    {'name': 'الشيخ ياسر الدوسري', 'file': 'adhan_yasser'},
    {'name': 'الشيخ محمد مروان القصاص', 'file': 'adhan_qatami'},
    {'name': 'الشيخ ناصر القطامي', 'file': 'adhan_qassas'},
  ];

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(_notifIcon);
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings, onDidReceiveNotificationResponse: _onTap);
    await _createChannels();
    _initialized = true;
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _adhanChannelId, 'الأذان', importance: Importance.max, playSound: true, enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _iqamaChannelId, 'الإقامة', importance: Importance.max, playSound: true, enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _persistentChannelId, 'الصلاة القادمة', importance: Importance.low, playSound: false,
    ));
  }

  static Future<void> requestFullScreenIntentPermission() async {}
  static Future<bool> canUseFullScreenIntent() async => true;
  static Future<void> openFullScreenSettings() async {}

  static void _onTap(NotificationResponse response) {}

  static Future<String> getSelectedMuezzin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_muezzinKey) ?? _defaultMuezzin;
  }

  static Future<void> setSelectedMuezzin(String file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_muezzinKey, file);
  }

  static Future<void> schedulePrayerNotifications(Map<String, String> prayerTimes, String cityName, String muezzinName) async {
    if (!_initialized) await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? true)) return;

    await _notifications.cancelAll();
    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      if (entry.key == 'Sunrise') continue;
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      var scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

      try {
        await _notifications.zonedSchedule(
          entry.key.hashCode, '🔔 حان وقت صلاة ${entry.key}',
          'صلاة ${entry.key} في $cityName',
          tz.TZDateTime.from(scheduledTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _adhanChannelId, 'الأذان', importance: Importance.max, priority: Priority.max,
              fullScreenIntent: true, category: AndroidNotificationCategory.alarm,
              playSound: true, sound: const RawResourceAndroidNotificationSound('adhan_sudais'),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // ✅ إصلاح الخطأ
        );
      } catch (e) {}
    }
  }

  static Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    await _notifications.show(1001, '🔔 اختبار الأذان', 'هذا اختبار', NotificationDetails(
      android: AndroidNotificationDetails(
        _adhanChannelId, 'الأذان', importance: Importance.max, priority: Priority.max,
        fullScreenIntent: true, playSound: true, sound: const RawResourceAndroidNotificationSound('adhan_sudais'),
      ),
    ));
  }

  static Future<void> showTestIqamaNotification() async {
    if (!_initialized) await initialize();
    await _notifications.show(1002, '🕌 اختبار الإقامة', 'حان وقت الإقامة', NotificationDetails(
      android: AndroidNotificationDetails(
        _iqamaChannelId, 'الإقامة', importance: Importance.max, priority: Priority.max,
        fullScreenIntent: true, playSound: true,
      ),
    ));
  }

  static Future<void> showPersistentNotification({
    String? title, String? body, String? nextPrayer, DateTime? targetTime,
    Duration? remaining, String? hijriDate, String? city, int? minutesLeft, // ✅ إرجاع hijriDate
  }) async {
    if (!_initialized) return;
    await _notifications.show(_persistentId, '🕌 الصلاة القادمة: $nextPrayer', '📍 $city', NotificationDetails(
      android: AndroidNotificationDetails(
        _persistentChannelId, 'الصلاة القادمة', importance: Importance.low, priority: Priority.low,
        ongoing: true, autoCancel: false, showWhen: true,
      ),
    ));
  }
}
