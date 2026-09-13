import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// تهيئة الإشعارات + طلب الأذونات
  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. تهيئة قاعدة بيانات المناطق الزمنية
    tz.initializeTimeZones();

    // 2. ضبط المنطقة الزمنية من الجهاز
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('🌍 Timezone set to: $tzName');
    } catch (e) {
      debugPrint('⚠️ فشل ضبط المنطقة الزمنية: $e');
    }

    // 3. إعدادات المنصات
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'فتح');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    // 4. تهيئة
    try {
      await _notifications.initialize(settings);
    } catch (e) {
      debugPrint('⚠️ فشل تهيئة الإشعارات: $e');
      if (!Platform.isLinux) rethrow;
    }

    // 5. طلب الأذونات على Android
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }

    _initialized = true;
  }

  static Future<void> _requestAndroidPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // إذن الإشعارات (Android 13+)
    try {
      await androidImpl.requestNotificationsPermission();
    } catch (e) {
      debugPrint('⚠️ requestNotificationsPermission: $e');
    }

    // إذن الإشعارات المجدولة بدقة (Android 12+)
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ requestExactAlarmsPermission: $e');
    }
  }

  /// جدولة إشعارات الأذان لكل صلاة
  static Future<void> schedulePrayerNotifications(
    Map<String, String> prayerTimes,
    String cityName,
    String muezzinName,
  ) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    try {
      await _notifications.cancelAll();

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) {
        debugPrint('⏸️ الإشعارات معطلة من الإعدادات');
        return;
      }

      final now = DateTime.now();

      for (final entry in prayerTimes.entries) {
        final prayerName = entry.key;

        // تجاهل الشروق (ليس صلاة)
        if (prayerName == 'Sunrise') continue;

        final prayerNameAr = _translatePrayerName(prayerName);
        final scheduledTime = _parseTime(entry.value, now);
        if (scheduledTime == null) continue;

        final finalTime = scheduledTime.isAfter(now)
            ? scheduledTime
            : scheduledTime.add(const Duration(days: 1));

        // الإشعار الرئيسي عند وقت الأذان
        try {
          await _notifications.zonedSchedule(
            prayerName.hashCode,
            '🔔 حان وقت صلاة $prayerNameAr',
            'صلاة $prayerNameAr في $cityName — أذان $muezzinName',
            tz.TZDateTime.from(finalTime, tz.local),
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('⚠️ فشل جدولة إشعار $prayerName: $e');
        }

        // إشعار تذكيري قبل 15 دقيقة (اختياري)
        final reminderTime = finalTime.subtract(const Duration(minutes: 15));
        if (reminderTime.isAfter(now)) {
          try {
            await _notifications.zonedSchedule(
              'pre_${prayerName}'.hashCode,
              '⏰ قبل صلاة $prayerNameAr بـ 15 دقيقة',
              'استعد لصلاة $prayerNameAr في $cityName',
              tz.TZDateTime.from(reminderTime, tz.local),
              _notificationDetails(),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (e) {
            debugPrint('⚠️ فشل جدولة تذكير $prayerName: $e');
          }
        }
      }

      debugPrint('✅ تم جدولة إشعارات الصلاة');
    } catch (e) {
      debugPrint('⚠️ فشل جدولة الإشعارات: $e');
    }
  }

  /// إشعار فوري (للاختبار من الإعدادات)
  static Future<void> showTestNotification() async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    await _notifications.show(
      9999,
      '🔔 اختبار الإشعارات',
      'إذا وصلتك هذه الرسالة، فالإشعارات تعمل بنجاح!',
      _notificationDetails(),
    );
  }

  /// إلغاء جميع الإشعارات
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // ============================================================
  // مساعدات داخلية
  // ============================================================

  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_channel',
        'أوقات الصلاة',
        channelDescription: 'إشعارات أوقات الصلاة والأذان',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  static String _translatePrayerName(String name) {
    switch (name) {
      case 'Fajr':
        return 'الفجر';
      case 'Dhuhr':
        return 'الظهر';
      case 'Asr':
        return 'العصر';
      case 'Maghrib':
        return 'المغرب';
      case 'Isha':
        return 'العشاء';
      case 'Sunrise':
        return 'الشروق';
      default:
        return name;
    }
  }

  static DateTime? _parseTime(String timeStr, DateTime reference) {
    try {
      String clean = timeStr.replaceAll(RegExp(r'\(.*\)'), '').trim();
      clean =
          clean.replaceAll(RegExp(r'AM|PM', caseSensitive: false), '').trim();

      final parts = clean.split(':');
      if (parts.length < 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1].trim());

      return DateTime(
        reference.year,
        reference.month,
        reference.day,
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }
}
