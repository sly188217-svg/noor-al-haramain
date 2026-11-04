import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _persistentId = 999999;
  static const String _adhanChannelId = 'adhan_channel_v16';
  static const String _iqamaChannelId = 'iqama_channel_v16';
  static const String _persistentChannelId = 'persistent_channel_v16';
  static const String _notifIcon = '@mipmap/launcher_icon';
  static const String _muezzinKey = 'selected_muezzin';

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
    tz_data.initializeTimeZones(); // ✅ بعد فصل الاستيراد
    const androidSettings = AndroidInitializationSettings(_notifIcon);
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );
    await _createChannels();
    await _requestPermissions();
    _initialized = true;
  }

  static Future<String?> getLaunchPayload() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        return details!.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('⚠️ getLaunchPayload: $e');
    }
    return null;
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
        _adhanChannelId, 'الأذان',
        importance: Importance.max, playSound: true, enableVibration: true));
    await android.createNotificationChannel(const AndroidNotificationChannel(
        _iqamaChannelId, 'الإقامة',
        importance: Importance.max, playSound: true, enableVibration: true));
    await android.createNotificationChannel(const AndroidNotificationChannel(
        _persistentChannelId, 'الصلاة القادمة',
        importance: Importance.low, playSound: false));
  }

  static Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static void _onTap(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      _handlePayload(response.payload!);
    }
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    // لا شيء — التعامل يتم في المقدمة
  }

  static void _handlePayload(String payload) {
    try {
      final parts = payload.split('|');
      if (parts.length < 5) return;
      navigatorKey.currentState?.pushNamed('/adhan', arguments: {
        'prayerName': parts[1],
        'prayerTime': parts[2],
        'cityName': parts[3],
        'muezzinName': parts[4],
        'isIqamaOnly': parts[0] == 'إقامة',
      });
    } catch (e) {
      debugPrint('⚠️ _handlePayload: $e');
    }
  }

  static Future<String> getSelectedMuezzin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_muezzinKey) ?? 'adhan_sudais';
  }

  static Future<void> setSelectedMuezzin(String file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_muezzinKey, file);
  }

  // ============================================================
  // ✅ 1) جدولة إشعارات الصلوات
  // ============================================================
  static Future<void> schedulePrayerNotifications({
    required Map<String, DateTime> prayerTimes,
  }) async {
    if (!_initialized) await initialize();
    try {
      final muezzin = await getSelectedMuezzin();

      for (final entry in prayerTimes.entries) {
        final prayerName = entry.key;
        final time = entry.value;
        if (time.isBefore(DateTime.now())) continue;

        final id = prayerName.hashCode & 0x7fffffff;
        final timeStr =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        await _notifications.zonedSchedule(
          id,
          'حان وقت $prayerName',
          'الله أكبر — حي على الصلاة',
          tz.TZDateTime.from(time, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _adhanChannelId,
              'الأذان',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(muezzin),
              enableVibration: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'صلاة|$prayerName|$timeStr||$muezzin',
        );
      }
    } catch (e) {
      debugPrint('⚠️ schedulePrayerNotifications: $e');
    }
  }

  // ============================================================
  // ✅ 2) إشعار دائم (يستخدم _persistentId لإزالة تحذير الحقل)
  // ============================================================
  static Future<void> showPersistentNotification({
    String title = 'الصلاة القادمة',
    String body = '',
    int id = _persistentId,
  }) async {
    if (!_initialized) await initialize();
    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _persistentChannelId,
            'الصلاة القادمة',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            showWhen: false,
          ),
        ),
        payload: body,
      );
    } catch (e) {
      debugPrint('⚠️ showPersistentNotification: $e');
    }
  }

  static Future<void> cancelPersistentNotification() async {
    try {
      await _notifications.cancel(_persistentId);
    } catch (e) {
      debugPrint('⚠️ cancelPersistentNotification: $e');
    }
  }

  // ============================================================
  // ✅ 3) التحقق من صلاحية Full Screen Intent (Android 14+)
  // ============================================================
  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return false;
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.canUseFullScreenIntent();
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ canUseFullScreenIntent: $e');
      return false;
    }
  }

  // ============================================================
  // ✅ 4) فتح إعدادات Full Screen Intent
  // ============================================================
  static Future<void> openFullScreenSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('⚠️ openFullScreenSettings: $e');
    }
  }

  // ============================================================
  // اختبارات (موجودة أصلاً)
  // ============================================================
  static Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    final muezzin = await getSelectedMuezzin();
    await _notifications.show(
      1001,
      '🔔 اختبار الأذان',
      'اضغط لفتح شاشة الأذان فوراً',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _adhanChannelId,
          'الأذان',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(muezzin),
          enableVibration: true,
        ),
      ),
      payload: 'صلاة|العصر|15:30|مكة المكرمة|$muezzin',
    );
  }

  static Future<void> showTestIqamaNotification() async {
    if (!_initialized) await initialize();
    final muezzin = await getSelectedMuezzin();
    await _notifications.show(
      1002,
      '🕌 اختبار الإقامة',
      'اضغط لفتح شاشة الإقامة فوراً',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _iqamaChannelId,
          'الإقامة',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(muezzin),
          enableVibration: true,
        ),
      ),
      payload: 'إقامة|العصر|15:45|مكة المكرمة|$muezzin',
    );
  }
}
