import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class PeriodicAzkarService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'periodic_azkar_channel_v5';
  static const int _baseId = 50000;

  static const List<String> _azkar = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'لا حول ولا قوة إلا بالله',
    'أستغفر الله العظيم',
    'سبحان الله وبحمده',
    'سبحان الله العظيم',
    'لا إله إلا الله وحده لا شريك له',
    'الله أكبر كبيراً والحمد لله كثيراً',
    'سبحان الله والحمد لله ولا إله إلا الله والله أكبر',
    'اللهم اغفر لي ولوالدي',
    'اللهم أصلح قلبي',
    'حسبي الله ونعم الوكيل',
    'اللهم إني أسألك الجنة',
    'اللهم أجرني من النار',
    'لا إله إلا أنت سبحانك إني كنت من الظالمين',
    'اللهم صل على محمد',
    'أستغفر الله وأتوب إليه',
    'سبحان الله وبحمده سبحان الله العظيم',
  ];

  static const List<String> _fridayAzkar = [
    'اللهم صل وسلم على نبينا محمد ﷺ',
    'اللهم صل على محمد وعلى آل محمد',
    'صلى الله عليه وسلم',
    'اللهم صل على محمد كما صليت على إبراهيم',
    'أكثر من الصلاة على النبي اليوم (يوم الجمعة)',
  ];

  static final Int64List _azkarVibration =
      Int64List.fromList([0, 300, 200, 300]);

  static Future<void> start() async {
    await stop();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('periodic_azkar_enabled') ?? false;
    if (!enabled) {
      debugPrint('⚠️ الأذكار الدورية غير مفعّلة');
      return;
    }

    final intervalMinutes = prefs.getInt('periodic_azkar_interval') ?? 15;
    final startHour = prefs.getInt('periodic_azkar_start_hour') ?? 6;
    final endHour = prefs.getInt('periodic_azkar_end_hour') ?? 22;

    debugPrint(
        '🕌 جدولة الأذكار كل $intervalMinutes دقيقة ($startHour-$endHour)');

    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'الأذكار الدورية (v5)',
          description: 'تذكير بالأذكار كل فترة',
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        ),
      );
    }

    await _scheduleAllAzkarForToday(
      intervalMinutes: intervalMinutes,
      startHour: startHour,
      endHour: endHour,
    );

    debugPrint('✅ تم جدولة الأذكار');
  }

  static Future<void> _scheduleAllAzkarForToday({
    required int intervalMinutes,
    required int startHour,
    required int endHour,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, startHour, 0);

    int index = 0;
    int notificationId = _baseId;
    int scheduledCount = 0;

    DateTime slot = todayStart;
    while (slot.isBefore(now)) {
      slot = slot.add(Duration(minutes: intervalMinutes));
    }

    final endDate = DateTime(now.year, now.month, now.day + 2, 0, 0);

    while (slot.isBefore(endDate)) {
      if (slot.hour >= startHour && slot.hour < endHour) {
        final isFriday = slot.weekday == DateTime.friday;
        final zikr = isFriday
            ? _fridayAzkar[index % _fridayAzkar.length]
            : _azkar[index % _azkar.length];
        final title = isFriday ? '🕌 الصلاة على النبي ﷺ' : '📿 ذكر';

        try {
          await _notifications.zonedSchedule(
            notificationId++,
            title,
            zikr,
            tz.TZDateTime.from(slot, tz.local),
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'الأذكار الدورية (v5)',
                channelDescription: 'تذكير بالأذكار',
                importance: Importance.high,
                priority: Priority.high,
                playSound: false,
                enableVibration: true,
                vibrationPattern: _azkarVibration,
                category: AndroidNotificationCategory.reminder,
                color: const Color(0xFFE53935),
                colorized: true,
                styleInformation: const BigTextStyleInformation(''),
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: false,
                presentBadge: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          index++;
          scheduledCount++;

          if (scheduledCount >= 100) break;
        } catch (e) {
          debugPrint('⚠️ فشل جدولة ذكر في $slot: $e');
        }
      }

      slot = slot.add(Duration(minutes: intervalMinutes));
    }

    debugPrint('✅ تم جدولة $scheduledCount ذكر');
  }

  static Future<void> stop() async {
    debugPrint('🛑 إيقاف الأذكار الدورية');
    try {
      final pending = await _notifications.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _baseId && p.id < _baseId + 200) {
          await _notifications.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل إلغاء الأذكار: $e');
    }
  }

  static Future<void> restart() async => await start();

  static Future<void> showTestZikr() async {
    final now = DateTime.now();
    final isFriday = now.weekday == DateTime.friday;
    final zikr = isFriday
        ? _fridayAzkar[now.second % _fridayAzkar.length]
        : _azkar[now.second % _azkar.length];
    final title = isFriday ? '🕌 الصلاة على النبي ﷺ' : '📿 ذكر';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      zikr,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'الأذكار الدورية (v5)',
          channelDescription: 'تذكير بالأذكار',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          vibrationPattern: _azkarVibration,
          category: AndroidNotificationCategory.reminder,
          color: const Color(0xFFE53935),
          colorized: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
          presentBadge: true,
        ),
      ),
    );
    debugPrint('🧪 $title: $zikr');
  }
}
