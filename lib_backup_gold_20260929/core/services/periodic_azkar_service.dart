import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🕌 خدمة الأذكار الدورية
/// ✅ إشعارات صامتة + اهتزاز
/// ✅ 20 ذكر يومي + 5 أذكار الجمعة
/// ✅ تتبع الساعات (من 6 صباحاً إلى 10 مساءً)
/// ═══════════════════════════════════════════════════════════
class PeriodicAzkarService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Timer? _timer;
  static int _currentIndex = 0;
  static int _fridayIndex = 0;

  // 📋 الأذكار اليومية (20)
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

  // 📋 أذكار الجمعة (5)
  static const List<String> _fridayAzkar = [
    'اللهم صل وسلم على نبينا محمد ﷺ',
    'اللهم صل على محمد وعلى آل محمد',
    'صلى الله عليه وسلم',
    'اللهم صل على محمد كما صليت على إبراهيم',
    'أكثر من الصلاة على النبي اليوم (يوم الجمعة)',
  ];

  /// 🚀 بدء الخدمة
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
        '🕌 بدء الأذكار كل $intervalMinutes دقيقة ($startHour-$endHour)');

    // أول ذكر فوري
    _showZikrIfInTimeRange(startHour, endHour);

    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _showZikrIfInTimeRange(startHour, endHour),
    );
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 إيقاف الأذكار الدورية');
  }

  static Future<void> restart() async => await start();

  static Future<void> _showZikrIfInTimeRange(
      int startHour, int endHour) async {
    final now = DateTime.now();
    final currentHour = now.hour;
    if (currentHour < startHour || currentHour >= endHour) return;

    final isFriday = now.weekday == DateTime.friday;
    String zikr;
    String title;

    if (isFriday) {
      zikr = _fridayAzkar[_fridayIndex % _fridayAzkar.length];
      _fridayIndex++;
      title = '🕌 الصلاة على النبي ﷺ';
    } else {
      zikr = _azkar[_currentIndex % _azkar.length];
      _currentIndex++;
      title = '📿 ذكر';
    }

    try {
      // ✅ إشعار صامت + اهتزاز (بدون صوت الأذان)
      final androidDetails = AndroidNotificationDetails(
        'periodic_azkar_channel_v3', // ✅ قناة جديدة
        'الأذكار الدورية',
        channelDescription: 'تذكير بالأذكار كل فترة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false, // ✅ صامت
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
        category: AndroidNotificationCategory.reminder,
        color: const Color(0xFFE53935),
        colorized: true,
        ongoing: false,
        autoCancel: true,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: false,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.active,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        zikr,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );

      debugPrint('📿 $title: $zikr');
    } catch (e) {
      debugPrint('⚠️ فشل إشعار الذكر: $e');
    }
  }

  /// 🧪 اختبار فوري
  static Future<void> showTestZikr() async {
    await _showZikrIfInTimeRange(0, 24);
  }
}
