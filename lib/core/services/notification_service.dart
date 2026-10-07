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
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const int _persistentId = 999999;

  // ✅ v6 — لإجبار Android على إنشاء قنوات جديدة بأيقونة جديدة
  static const String _adhanChannelId = 'adhan_channel_v6';
  static const String _iqamaChannelId = 'iqama_channel_v6';
  static const String _persistentChannelId = 'persistent_channel_v6';

  static const String _muezzinKey = 'selected_muezzin';
  static const String _defaultMuezzin = 'adhan_sudais';

  // ✅ الأيقونة البيضاء للإشعار (شكل المسجد)
  static const String _notifIcon = '@drawable/ic_notification';
  static const String _largeIconAsset = '@drawable/ic_app_colored';

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

  // ═══════════════════════════════════════════════════════════
  // 🚀 التهيئة
  // ═══════════════════════════════════════════════════════════
  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(_notifIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    await _createChannels();
    await _requestPermissions();

    _initialized = true;
    debugPrint('✅ تم تهيئة الإشعارات (v6)');
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // حذف القنوات القديمة (v5) إن وُجدت
    try {
      await android.deleteNotificationChannel('adhan_channel_v5');
      await android.deleteNotificationChannel('iqama_channel_v5');
      await android.deleteNotificationChannel('persistent_channel_v5');
      debugPrint('🗑️ تم حذف القنوات القديمة (v5)');
    } catch (e) {
      debugPrint('ℹ️ لا توجد قنوات قديمة');
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _adhanChannelId,
        'الأذان',
        description: 'إشعارات الأذان - ملء الشاشة',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _iqamaChannelId,
        'الإقامة',
        description: 'إشعارات الإقامة',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _persistentChannelId,
        'الصلاة القادمة',
        description: 'إشعار الصلاة القادمة مع العد التنازلي',
        importance: Importance.low,
        playSound: false,
      ),
    );

    debugPrint('✅ تم إنشاء قنوات الإشعارات (v6)');
  }

  static Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> requestFullScreenIntentPermission() async {
    debugPrint('ℹ️ استخدم زر الإعدادات لتفعيل ملء الشاشة يدوياً');
  }

  static Future<bool> canUseFullScreenIntent() async => true;

  static Future<void> openFullScreenSettings() async {
    if (!Platform.isAndroid) return;
    debugPrint('ℹ️ افتح الإعدادات يدوياً: Apps → Noor → Full Screen');
  }

  // ═══════════════════════════════════════════════════════════
  // 👆 معالجة الضغط على الإشعار
  // ═══════════════════════════════════════════════════════════
  static void _onTap(NotificationResponse response) {
    debugPrint('👆 تم الضغط على الإشعار: ${response.payload}');
    _handlePayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    debugPrint('👆 ضغط في الخلفية: ${response.payload}');
  }

  static void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (payload == 'RESCHEDULE_AZKAR') return;
    try {
      final parts = payload.split('|');
      if (parts.length < 5) return;
      navigatorKey.currentState?.pushNamed(
        '/adhan',
        arguments: {
          'prayerName': parts[1],
          'prayerTime': parts[2],
          'cityName': parts[3],
          'muezzinName': parts[4],
          'isIqamaOnly': parts[0] == 'إقامة',
        },
      );
    } catch (e) {
      debugPrint('⚠️ فشل معالجة الإشعار: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎙️ المؤذن
  // ═══════════════════════════════════════════════════════════
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
    debugPrint('✅ تم حفظ المؤذن: $file');
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 جدولة الأذان والإقامة
  // ═══════════════════════════════════════════════════════════
  static Future<void> schedulePrayerNotifications(
    Map<String, String> prayerTimes,
    String cityName,
    String muezzinName,
  ) async {
    if (Platform.isLinux) return;
    if (!_initialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) return;

    final pending = await _notifications.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id != _persistentId) await _notifications.cancel(p.id);
    }

    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      if (entry.key == 'Sunrise') continue;

      final prayerNameAr = _translatePrayerName(entry.key);
      final scheduledTime = _parseTime(entry.value, now);
      if (scheduledTime == null) continue;

      final finalTime = scheduledTime.isAfter(now)
          ? scheduledTime
          : scheduledTime.add(const Duration(days: 1));

      final timeStr =
          '${finalTime.hour.toString().padLeft(2, '0')}:${finalTime.minute.toString().padLeft(2, '0')}';

      try {
        await _notifications.zonedSchedule(
          entry.key.hashCode,
          '🔔 حان وقت صلاة $prayerNameAr',
          'صلاة $prayerNameAr في $cityName — أذان $muezzinName',
          tz.TZDateTime.from(finalTime, tz.local),
          await _adhanNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'صلاة|$prayerNameAr|$timeStr|$cityName|$muezzinName',
        );
        debugPrint('✅ جدولة أذان $prayerNameAr: $finalTime');
      } catch (e) {
        debugPrint('⚠️ فشل أذان $entry.key: $e');
      }

      final iqamaMinutes = await _getIqamaMinutesForPrayer(prayerNameAr);
      final iqamaTime = finalTime.add(Duration(minutes: iqamaMinutes));

      if (iqamaTime.isAfter(now)) {
        final iqamaTimeStr =
            '${iqamaTime.hour.toString().padLeft(2, '0')}:${iqamaTime.minute.toString().padLeft(2, '0')}';
        try {
          await _notifications.zonedSchedule(
            'iqama_${entry.key}'.hashCode,
            '🕌 إقامة صلاة $prayerNameAr',
            'حان وقت الإقامة — قد قامت الصلاة',
            tz.TZDateTime.from(iqamaTime, tz.local),
            await _iqamaNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload:
                'إقامة|$prayerNameAr|$iqamaTimeStr|$cityName|$muezzinName',
          );
          debugPrint('✅ جدولة إقامة $prayerNameAr: $iqamaTime');
        } catch (e) {
          debugPrint('⚠️ فشل إقامة $entry.key: $e');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧪 اختبارات
  // ═══════════════════════════════════════════════════════════
  static Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    await _notifications.show(
      1001,
      '🔔 اختبار الأذان',
      'هذا اختبار — سيظهر ملء الشاشة',
      await _adhanNotificationDetails(),
      payload: 'صلاة|العصر|15:30|مكة المكرمة|اختبار',
    );
  }

  static Future<void> showTestIqamaNotification() async {
    if (!_initialized) await initialize();
    debugPrint('🕌 إشعار إقامة اختباري بعد 3 ثوانٍ...');
    await Future.delayed(const Duration(seconds: 3));
    await _notifications.show(
      1002,
      '🕌 اختبار الإقامة',
      'حان وقت الإقامة — قد قامت الصلاة',
      await _iqamaNotificationDetails(),
      payload: 'إقامة|العصر|15:45|مكة المكرمة|اختبار',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 تفاصيل الأذان
  // ═══════════════════════════════════════════════════════════
  static Future<NotificationDetails> _adhanNotificationDetails() async {
    final selectedFile = await getSelectedMuezzin();
    debugPrint('🎵 الأذان بالمؤذن: $selectedFile');

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _adhanChannelId,
        'الأذان',
        channelDescription: 'إشعارات الأذان - ملء الشاشة',
        icon: _notifIcon,
        largeIcon: DrawableResourceAndroidBitmap(_largeIconAsset),
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(selectedFile),
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        timeoutAfter: 300000,
        autoCancel: true,
        ongoing: false,
        color: const Color(0xFFE53935),
        colorized: false, // ✅ false لضمان ظهور شكل الأيقونة
        visibility: NotificationVisibility.public,
        ticker: 'حان وقت الصلاة',
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 تفاصيل الإقامة
  // ═══════════════════════════════════════════════════════════
  static Future<NotificationDetails> _iqamaNotificationDetails() async {
    final selectedFile = await getSelectedMuezzin();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _iqamaChannelId,
        'الإقامة',
        channelDescription: 'إشعارات الإقامة',
        icon: _notifIcon,
        largeIcon: DrawableResourceAndroidBitmap(_largeIconAsset),
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(selectedFile),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        timeoutAfter: 300000,
        autoCancel: true,
        ongoing: false,
        color: const Color(0xFFE53935),
        colorized: false,
        visibility: NotificationVisibility.public,
        ticker: 'حان وقت الإقامة',
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📌 إشعار الصلاة القادمة (مع أيقونة المسجد + العد التنازلي)
  // ═══════════════════════════════════════════════════════════
  static Future<void> showPersistentNotification({
    String? title,
    String? body,
    String? nextPrayer,
    DateTime? targetTime,
    Duration? remaining,
    String? hijriDate,
    String? city,
    int? minutesLeft,
  }) async {
    if (Platform.isLinux || !_initialized) return;

    // ─── العنوان ───
    String t;
    if (title != null && title.isNotEmpty) {
      t = title;
    } else if (nextPrayer != null && nextPrayer.isNotEmpty) {
      t = '🕌 الصلاة القادمة: $nextPrayer';
    } else {
      t = '🕌 الصلاة القادمة';
    }

    // ─── النص ───
    final buffer = StringBuffer();

    if (remaining != null && !remaining.isNegative) {
      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      final s = remaining.inSeconds.remainder(60);
      if (h > 0) {
        buffer.write(
            '⏳ ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
      } else {
        buffer.write(
            '⏳ ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
      }
    }

    if (targetTime != null) {
      final hh = targetTime.hour.toString().padLeft(2, '0');
      final mm = targetTime.minute.toString().padLeft(2, '0');
      if (buffer.isNotEmpty) buffer.write('  •  ');
      buffer.write('🕐 $hh:$mm');
    }

    if (city != null && city.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('📍 $city');
    }

    if (hijriDate != null && hijriDate.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('📅 $hijriDate');
    }

    final b = buffer.toString().trim().isEmpty
        ? 'اقترب وقت الصلاة'
        : buffer.toString();

    final whenMillis = targetTime?.millisecondsSinceEpoch;

    await _notifications.show(
      _persistentId,
      t,
      b,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _persistentChannelId,
          'الصلاة القادمة',
          channelDescription: 'إشعار الصلاة القادمة مع العد التنازلي',
          // ✅ أيقونة المسجد (كانت مفقودة هنا!)
          icon: _notifIcon,
          largeIcon: DrawableResourceAndroidBitmap(_largeIconAsset),
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          when: whenMillis,
          usesChronometer: whenMillis != null,
          chronometerCountDown: true,
          showWhen: whenMillis != null,
          onlyAlertOnce: true,
          color: const Color(0xFF4A90E2),
          colorized: false,
        ),
      ),
    );
  }

  static Future<void> cancelPersistent() async {
    try {
      await _notifications.cancel(_persistentId);
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ مساعدات
  // ═══════════════════════════════════════════════════════════
  static String _translatePrayerName(String key) {
    const map = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
      'Sunrise': 'الشروق',
    };
    return map[key] ?? key;
  }

  static DateTime? _parseTime(String time, DateTime ref) {
    try {
      final parts = time.split(':');
      if (parts.length < 2) return null;
      return DateTime(ref.year, ref.month, ref.day, int.parse(parts[0]),
          int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  static Future<int> _getIqamaMinutesForPrayer(String prayerNameAr) async {
    final prefs = await SharedPreferences.getInstance();
    switch (prayerNameAr) {
      case 'الفجر':
        return prefs.getInt('iqama_fajr') ?? 20;
      case 'الظهر':
        return prefs.getInt('iqama_dhuhr') ?? 15;
      case 'العصر':
        return prefs.getInt('iqama_asr') ?? 15;
      case 'المغرب':
        return prefs.getInt('iqama_maghrib') ?? 5;
      case 'العشاء':
        return prefs.getInt('iqama_isha') ?? 15;
      default:
        return 15;
    }
  }
}
