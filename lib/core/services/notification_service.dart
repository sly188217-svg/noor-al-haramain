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
  static const int _persistentId = 9999;

  /// 🎵 اسم ملف الأذان (بدون الامتداد) في android/app/src/main/res/raw/
  /// ⚠️ تأكد من وجود الملف: adhan_marwan.mp3 في المجلد المذكور
  static const String _adhanSoundName = 'adhan_marwan';

  /// تهيئة الإشعارات
  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('⚠️ فشل ضبط المنطقة الزمنية: $e');
    }

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

    try {
      await _notifications.initialize(settings);
    } catch (e) {
      debugPrint('⚠️ فشل تهيئة الإشعارات: $e');
      if (!Platform.isLinux) rethrow;
    }

    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
      await _createAdhanChannel(); // ✅ إنشاء قناة الأذان
    }

    _initialized = true;
  }

  /// ═══════════════════════════════════════════════════════════
  /// ✅ إنشاء قناة الأذان بصوت مخصص
  /// ═══════════════════════════════════════════════════════════
  static Future<void> _createAdhanChannel() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // قناة الأذان (صوت كامل)
    const AndroidNotificationChannel adhanChannel = AndroidNotificationChannel(
      'adhan_channel',
      'الأذان',
      description: 'صوت الأذان عند دخول وقت الصلاة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_adhanSoundName),
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    // قناة الإشعار العادي (بدون صوت، للإشعار الدائم)
    const AndroidNotificationChannel prayerChannel =
        AndroidNotificationChannel(
      'prayer_channel',
      'أوقات الصلاة',
      description: 'إشعارات أوقات الصلاة',
      importance: Importance.high,
      playSound: false,
    );

    await androidImpl.createNotificationChannel(adhanChannel);
    await androidImpl.createNotificationChannel(prayerChannel);
  }

  static Future<void> _requestAndroidPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    try {
      await androidImpl.requestNotificationsPermission();
    } catch (e) {
      debugPrint('⚠️ requestNotificationsPermission: $e');
    }

    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ requestExactAlarmsPermission: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🔔 إشعار ثابت دائم — العد التنازلي + التاريخ الهجري
  /// ═══════════════════════════════════════════════════════════
  static Future<void> showPersistentNotification({
    required String nextPrayer,
    required String timeRemaining,
    required String hijriDate,
    required String city,
  }) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'prayer_persistent_channel',
      'الإشعار الدائم',
      channelDescription: 'يعرض العد التنازلي للصلاة القادمة',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.service,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: false),
    );

    try {
      await _notifications.show(
        _persistentId,
        '🕌 $nextPrayer — $timeRemaining',
        '$hijriDate • $city',
        details,
      );
    } catch (e) {
      debugPrint('⚠️ فشل الإشعار الدائم: $e');
    }
  }

  /// إلغاء الإشعار الدائم
  static Future<void> cancelPersistent() async {
    try {
      await _notifications.cancel(_persistentId);
    } catch (e) {}
  }

  /// ═══════════════════════════════════════════════════════════
  /// جدولة إشعارات الأذان لكل صلاة
  /// ═══════════════════════════════════════════════════════════
  static Future<void> schedulePrayerNotifications(
    Map<String, String> prayerTimes,
    String cityName,
    String muezzinName,
  ) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    try {
      // ✅ إلغاء الإشعارات المجدولة فقط (بدون الإشعار الدائم)
      final pending = await _notifications.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id != _persistentId) {
          await _notifications.cancel(p.id);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) return;

      final now = DateTime.now();

      for (final entry in prayerTimes.entries) {
        final prayerName = entry.key;
        if (prayerName == 'Sunrise') continue;

        final prayerNameAr = _translatePrayerName(prayerName);
        final scheduledTime = _parseTime(entry.value, now);
        if (scheduledTime == null) continue;

        final finalTime = scheduledTime.isAfter(now)
            ? scheduledTime
            : scheduledTime.add(const Duration(days: 1));

        try {
          await _notifications.zonedSchedule(
            prayerName.hashCode,
            '🔔 حان وقت صلاة $prayerNameAr',
            'صلاة $prayerNameAr في $cityName — أذان $muezzinName',
            tz.TZDateTime.from(finalTime, tz.local),
            _adhanNotificationDetails(), // ✅ يستخدم قناة الأذان
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('⚠️ فشل جدولة $prayerName: $e');
        }

        // إشعار تذكيري قبل 15 دقيقة (بدون صوت)
        final reminderTime = finalTime.subtract(const Duration(minutes: 15));
        if (reminderTime.isAfter(now)) {
          try {
            await _notifications.zonedSchedule(
              'pre_${prayerName}'.hashCode,
              '⏰ قبل صلاة $prayerNameAr بـ 15 دقيقة',
              'استعد لصلاة $prayerNameAr في $cityName',
              tz.TZDateTime.from(reminderTime, tz.local),
              _silentNotificationDetails(), // ✅ بدون صوت
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (e) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل جدولة الإشعارات: $e');
    }
  }

  /// إشعار فوري (للاختبار)
  static Future<void> showTestNotification() async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    await _notifications.show(
      8888,
      '🔔 اختبار الأذان',
      'هذا إشعار تجريبي — يجب أن تسمع صوت الأذان',
      _adhanNotificationDetails(),
    );
  }

  /// إلغاء جميع الإشعارات (بما فيها الدائم)
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════
  // مساعدات داخلية
  // ═══════════════════════════════════════════════════════════

  /// ✅ تفاصيل إشعار الأذان (بصوت)
  static NotificationDetails _adhanNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_channel',
        'الأذان',
        channelDescription: 'صوت الأذان عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_adhanSoundName),
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        timeoutAfter: 120000, // 2 دقيقة
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        sound: '$_adhanSoundName.aiff',
      ),
    );
  }

  /// ✅ تفاصيل إشعار صامت (للإشعار الدائم والتذكير)
  static NotificationDetails _silentNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_channel',
        'أوقات الصلاة',
        channelDescription: 'إشعارات أوقات الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: false,
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
