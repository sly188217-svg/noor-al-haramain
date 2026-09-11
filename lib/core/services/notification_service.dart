import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ✅ إعدادات لينكس مع defaultActionName المطلوب
    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'فتح', // أو 'Open'
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    try {
      await _notifications.initialize(settings);
    } catch (e) {
      // على لينكس نتجاوز الأخطاء
      if (!Platform.isLinux) {
        rethrow;
      }
    }
  }

  static Future<void> showPrayerNotification({
    required String prayerName,
    required String prayerTime,
    required String cityName,
    required String muezzinName,
  }) async {
    // ✅ على لينكس لا نرسل إشعارات
    if (Platform.isLinux) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_lang') ?? 'ar';
      final isArabic = lang == 'ar';

      final title = isArabic
          ? '🔔 وقت صلاة $prayerName'
          : '🔔 $prayerName Prayer Time';
      final body = isArabic
          ? 'حان الآن وقت صلاة $prayerName في $cityName. أذان $muezzinName'
          : 'It\'s time for $prayerName prayer in $cityName. Adhan by $muezzinName';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'prayer_channel',
        'أوقات الصلاة',
        channelDescription: 'إشعارات أوقات الصلاة والأذان',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('adhan'),
      );

      const DarwinNotificationDetails iosDetails =
          DarwinNotificationDetails(
        sound: 'adhan.wav',
        presentAlert: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        prayerName.hashCode,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('⚠️ فشل إرسال الإشعار: $e');
    }
  }

  static Future<void> schedulePrayerNotifications(
    Map<String, String> prayerTimes,
    String cityName,
    String muezzinName,
  ) async {
    // ✅ على لينكس لا نجدد الإشعارات
    if (Platform.isLinux) {
      return;
    }

    try {
      await _notifications.cancelAll();

      final now = DateTime.now();
      for (var entry in prayerTimes.entries) {
        final prayerName = entry.key;
        final timeStr = entry.value;
        try {
          final timeParts = timeStr.split(':');
          if (timeParts.length == 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1].split(' ')[0]);
            final scheduledTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );
            final finalTime = scheduledTime.isAfter(now)
                ? scheduledTime
                : scheduledTime.add(const Duration(days: 1));

            await _notifications.zonedSchedule(
              prayerName.hashCode,
              '🔔 صلاة $prayerName',
              'حان وقت صلاة $prayerName في $cityName',
              tz.TZDateTime.from(finalTime, tz.local),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'prayer_channel',
                  'أوقات الصلاة',
                  channelDescription: 'إشعارات أوقات الصلاة والأذان',
                  importance: Importance.high,
                  priority: Priority.high,
                  sound: RawResourceAndroidNotificationSound('adhan'),
                ),
                iOS: DarwinNotificationDetails(
                  sound: 'adhan.wav',
                  presentAlert: true,
                  presentSound: true,
                ),
              ),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
              androidScheduleMode: AndroidScheduleMode.exact,
            );
          }
        } catch (e) {
          debugPrint('⚠️ فشل جدولة إشعار $prayerName: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل جدولة الإشعارات: $e');
    }
  }
}
