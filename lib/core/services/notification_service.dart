import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🔑 مفتاح التنقل العام
/// ═══════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// ═══════════════════════════════════════════════════════════
/// 🔔 خدمة الإشعارات — الأذان + الإقامة + Chronometer
/// ✅ إشعار الأذان عند وقت الصلاة
/// ✅ إشعار الإقامة بعد X دقيقة تلقائياً
/// ✅ إشعار دائم بالعد التنازلي
/// ═══════════════════════════════════════════════════════════
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const int _persistentId = 9999;

  static const String _muezzinKey = 'selected_muezzin';
  static const String _defaultMuezzin = 'adhan_sudais';

  /// ═══════════════════════════════════════════════════════════
  /// 🎵 قائمة المؤذنين (14)
  /// ═══════════════════════════════════════════════════════════
  static const List<Map<String, String>> muezzins = [
    {'name': 'الشيخ عبد الرحمن السديس', 'file': 'adhan_sudais'},
    {'name': 'الشيخ ماهر المعيقلي', 'file': 'adhan_almuaiqly'},
    {'name': 'الشيخ ياسر الدوسري', 'file': 'adhan_yasser'},
    {'name': 'الشيخ محمد مروان القصاص', 'file': 'adhan_qatami'},
    {'name': 'الشيخ ناصر القطامي', 'file': 'adhan_qassas'},
    {'name': 'الشيخ عبد الباسط عبد الصمد', 'file': 'adhan_abdalbaset'},
    {'name': 'الشيخ مشاري العفاسي', 'file': 'adhan_alafasy'},
    {'name': 'الشيخ سعد الغامدي', 'file': 'adhan_ghamdi'},
    {'name': 'الشيخ عبد الرحمن الشميري', 'file': 'adhan_shamiree'},
    {'name': 'أذان الحرم المكي', 'file': 'adhan_makkah'},
    {'name': 'أذان المسجد النبوي', 'file': 'adhan_madina'},
    {'name': 'أذان المسجد الأقصى', 'file': 'adhan_alaqsa'},
    {'name': 'أذان مصر', 'file': 'adhan_masr'},
    {'name': 'أذان عمّان', 'file': 'adhan_amman'},
  ];

  static Future<String> getSelectedMuezzin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_muezzinKey);
    if (saved == null || saved.isEmpty) return _defaultMuezzin;
    final valid = muezzins.any((m) => m['file'] == saved);
    return valid ? saved : _defaultMuezzin;
  }

  static Future<void> setSelectedMuezzin(String file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_muezzinKey, file);
    await _createAdhanChannel();
    debugPrint('✅ تم تغيير المؤذن إلى: $file');
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🕌 الأوقات الافتراضية للإقامة لكل صلاة
  /// ═══════════════════════════════════════════════════════════
  static const Map<String, int> defaultIqamaTimes = {
    'الفجر': 20,
    'الظهر': 15,
    'العصر': 15,
    'المغرب': 7,
    'العشاء': 15,
  };

  /// ═══════════════════════════════════════════════════════════
  /// 🔔 التهيئة
  /// ═══════════════════════════════════════════════════════════
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
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔔 تم الضغط على الإشعار: ${response.payload}');
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handleNotificationTap(response.payload!);
          }
        },
      );
    } catch (e) {
      debugPrint('⚠️ فشل تهيئة الإشعارات: $e');
      if (!Platform.isLinux) rethrow;
    }

    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
      await _createAdhanChannel();
    }

    _initialized = true;
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🎯 معالج الضغط على الإشعار
  /// ═══════════════════════════════════════════════════════════
  static void _handleNotificationTap(String payload) {
    try {
      final parts = payload.split('|');
      if (parts.length >= 5) {
        // parts[0] = نوع الإشعار: "صلاة" أو "إقامة"
        final isIqamaOnly = parts[0] == 'إقامة';

        navigatorKey.currentState?.pushNamed(
          '/adhan',
          arguments: {
            'prayerName': parts[1],
            'prayerTime': parts[2],
            'cityName': parts[3],
            'muezzinName': parts[4],
            'isIqamaOnly': isIqamaOnly,
          },
        );
      }
    } catch (e) {
      debugPrint('⚠️ فشل فتح شاشة الأذان: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🎵 إنشاء قنوات الإشعارات
  /// ═══════════════════════════════════════════════════════════
  static Future<void> _createAdhanChannel() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    final selectedFile = await getSelectedMuezzin();

    final AndroidNotificationChannel adhanChannel = AndroidNotificationChannel(
      'adhan_channel',
      'الأذان والإقامة',
      description: 'صوت الأذان والإقامة عند دخول الوقت',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(selectedFile),
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    const AndroidNotificationChannel prayerChannel =
        AndroidNotificationChannel(
      'prayer_channel',
      'أوقات الصلاة',
      description: 'إشعارات أوقات الصلاة',
      importance: Importance.high,
      playSound: false,
    );

    const AndroidNotificationChannel persistentChannel =
        AndroidNotificationChannel(
      'prayer_persistent_channel_v2',
      'الإشعار الدائم',
      description: 'العد التنازلي للصلاة القادمة',
      importance: Importance.low,
      playSound: false,
      showBadge: false,
    );

    try {
      await androidImpl.deleteNotificationChannel('adhan_channel');
      await androidImpl.deleteNotificationChannel('prayer_persistent_channel');
      await androidImpl.createNotificationChannel(adhanChannel);
      await androidImpl.createNotificationChannel(prayerChannel);
      await androidImpl.createNotificationChannel(persistentChannel);
      debugPrint('✅ القنوات جاهزة بالصوت: $selectedFile');
    } catch (e) {
      debugPrint('⚠️ فشل إنشاء القنوات: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🔐 أذونات أندرويد
  /// ═══════════════════════════════════════════════════════════
  static Future<void> _requestAndroidPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    try {
      await androidImpl.requestNotificationsPermission();
      debugPrint('✅ إذن الإشعارات');
    } catch (e) {
      debugPrint('⚠️ requestNotifications: $e');
    }

    try {
      await androidImpl.requestExactAlarmsPermission();
      debugPrint('✅ إذن المنبهات الدقيقة');
    } catch (e) {
      debugPrint('⚠️ requestExactAlarms: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🖥️ طلب صلاحية ملء الشاشة
  /// ═══════════════════════════════════════════════════════════
  static Future<void> requestFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final androidImpl =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return;

      await androidImpl.requestFullScreenIntentPermission();
      debugPrint('✅ طلب صلاحية ملء الشاشة');
    } catch (e) {
      debugPrint('⚠️ فشل طلب صلاحية ملء الشاشة: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// ⏱️ الإشعار الدائم مع Chronometer
  /// ═══════════════════════════════════════════════════════════
  static Future<void> showPersistentNotification({
    required String nextPrayer,
    required DateTime targetTime,
    required String hijriDate,
    required String city,
  }) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'prayer_persistent_channel_v2',
      'الإشعار الدائم',
      channelDescription: 'العد التنازلي للصلاة القادمة',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: targetTime.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      category: AndroidNotificationCategory.stopwatch,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
      color: const Color(0xFFD4AF37),
      colorized: true,
      showProgress: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentAlert: false),
    );

    try {
      await _notifications.show(
        _persistentId,
        '🕌 $nextPrayer',
        '$hijriDate • $city',
        details,
      );
      debugPrint('✅ الإشعار الدائم — Chronometer نحو $targetTime');
    } catch (e) {
      debugPrint('⚠️ فشل الإشعار الدائم: $e');
    }
  }

  static Future<void> cancelPersistent() async {
    try {
      await _notifications.cancel(_persistentId);
    } catch (e) {}
  }

  /// ═══════════════════════════════════════════════════════════
  /// 📅 جدولة إشعارات الأذان + الإقامة
  /// ═══════════════════════════════════════════════════════════
  static Future<void> schedulePrayerNotifications(
    Map<String, String> prayerTimes,
    String cityName,
    String muezzinName,
  ) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    try {
      // إلغاء الإشعارات القديمة
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

        final timeStr =
            '${finalTime.hour.toString().padLeft(2, '0')}:${finalTime.minute.toString().padLeft(2, '0')}';

        // ═══════════════════════════════════════════════════
        // 1️⃣ إشعار الأذان
        // ═══════════════════════════════════════════════════
        final adhanPayload =
            'صلاة|$prayerNameAr|$timeStr|$cityName|$muezzinName';

        try {
          await _notifications.zonedSchedule(
            prayerName.hashCode,
            '🔔 حان وقت صلاة $prayerNameAr',
            'صلاة $prayerNameAr في $cityName — أذان $muezzinName',
            tz.TZDateTime.from(finalTime, tz.local),
            await _adhanNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: adhanPayload,
          );
          debugPrint('✅ جدولة أذان $prayerNameAr في: $finalTime');
        } catch (e) {
          debugPrint('⚠️ فشل جدولة أذان $prayerName: $e');
        }

        // ═══════════════════════════════════════════════════
        // 2️⃣ إشعار الإقامة (بعد X دقيقة)
        // ═══════════════════════════════════════════════════
        final iqamaMinutes = await _getIqamaMinutesForPrayer(prayerNameAr);
        final iqamaTime = finalTime.add(Duration(minutes: iqamaMinutes));

        if (iqamaTime.isAfter(now)) {
          final iqamaTimeStr =
              '${iqamaTime.hour.toString().padLeft(2, '0')}:${iqamaTime.minute.toString().padLeft(2, '0')}';
          final iqamaPayload =
              'إقامة|$prayerNameAr|$iqamaTimeStr|$cityName|$muezzinName';

          try {
            await _notifications.zonedSchedule(
              'iqama_$prayerName'.hashCode,
              '🕌 إقامة صلاة $prayerNameAr',
              'حان وقت الإقامة — قد قامت الصلاة',
              tz.TZDateTime.from(iqamaTime, tz.local),
              await _iqamaNotificationDetails(),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: iqamaPayload,
            );
            debugPrint(
                '✅ جدولة إقامة $prayerNameAr في: $iqamaTime (بعد $iqamaMinutes دقيقة)');
          } catch (e) {
            debugPrint('⚠️ فشل جدولة إقامة $prayerName: $e');
          }
        }

        // ═══════════════════════════════════════════════════
        // 3️⃣ تذكير قبل 15 دقيقة
        // ═══════════════════════════════════════════════════
        final reminderTime = finalTime.subtract(const Duration(minutes: 15));
        if (reminderTime.isAfter(now)) {
          try {
            await _notifications.zonedSchedule(
              'pre_${prayerName}'.hashCode,
              '⏰ قبل صلاة $prayerNameAr بـ 15 دقيقة',
              'استعد لصلاة $prayerNameAr في $cityName',
              tz.TZDateTime.from(reminderTime, tz.local),
              _silentNotificationDetails(),
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

  /// ═══════════════════════════════════════════════════════════
  /// 🕌 جلب وقت الإقامة لكل صلاة
  /// ═══════════════════════════════════════════════════════════
  static Future<int> _getIqamaMinutesForPrayer(String prayerNameAr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prayerKey = 'iqama_$prayerNameAr';

      int? saved = prefs.getInt(prayerKey);
      if (saved != null) return saved;

      return defaultIqamaTimes[prayerNameAr] ?? 15;
    } catch (e) {
      return 15;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// 🧪 اختبار
  /// ═══════════════════════════════════════════════════════════
  static Future<void> showTestNotification() async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    await _notifications.show(
      8888,
      '🔔 اختبار الأذان',
      'يجب أن تسمع صوت الأذان الآن',
      await _adhanNotificationDetails(),
      payload:
          'صلاة|الاختبار|${DateTime.now().hour}:${DateTime.now().minute}|مدينتك|المؤذن',
    );
  }

  static Future<void> showTestIqamaNotification() async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    await _notifications.show(
      8889,
      '🕌 اختبار الإقامة',
      'حان وقت الإقامة — قد قامت الصلاة',
      await _iqamaNotificationDetails(),
      payload:
          'إقامة|الاختبار|${DateTime.now().hour}:${DateTime.now().minute}|مدينتك|المؤذن',
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ مساعدات داخلية
  // ═══════════════════════════════════════════════════════════

  static Future<NotificationDetails> _adhanNotificationDetails() async {
    final selectedFile = await getSelectedMuezzin();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_channel',
        'الأذان',
        channelDescription: 'صوت الأذان عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(selectedFile),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        timeoutAfter: 180000,
        autoCancel: true,
        ongoing: false,
        color: const Color(0xFFD4AF37),
        colorized: true,
        visibility: NotificationVisibility.public,
        ticker: 'حان وقت الصلاة',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

  static Future<NotificationDetails> _iqamaNotificationDetails() async {
    final selectedFile = await getSelectedMuezzin();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_channel',
        'الإقامة',
        channelDescription: 'صوت الإقامة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(selectedFile),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        timeoutAfter: 180000,
        autoCancel: true,
        ongoing: false,
        color: const Color(0xFFFFB74D),
        colorized: true,
        visibility: NotificationVisibility.public,
        ticker: 'حان وقت الإقامة',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

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
