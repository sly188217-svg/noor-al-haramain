import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';

// نصدّر CompassEvent من المكتبة لاستخدامه في qibla_screen
export 'package:flutter_compass/flutter_compass.dart' show CompassEvent;

/// خدمة البوصلة والقبلة
class CompassService {
  /// إحداثيات الكعبة المشرفة
  static const double makkahLat = 21.4224779;
  static const double makkahLng = 39.8251832;

  /// حساب زاوية القبلة من موقع المستخدم إلى الكعبة
  static double calculateQiblaDirection(double userLat, double userLng) {
    final lat1 = userLat * pi / 180.0;
    final lng1 = userLng * pi / 180.0;
    final lat2 = makkahLat * pi / 180.0;
    final lng2 = makkahLng * pi / 180.0;

    final dLng = lng2 - lng1;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    var bearing = atan2(y, x) * 180.0 / pi;
    bearing = (bearing + 360.0) % 360.0;
    return bearing;
  }

  /// حساب المسافة من المستخدم إلى الكعبة بالكيلومترات
  static double calculateDistanceToMakkah(double userLat, double userLng) {
    const double earthRadius = 6371.0;

    final dLat = (makkahLat - userLat) * pi / 180.0;
    final dLng = (makkahLng - userLng) * pi / 180.0;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180.0) *
            cos(makkahLat * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// تدفق أحداث البوصلة (يُرجع null إذا لم يكن المستشعر متوفراً)
  static Stream<CompassEvent>? get compassStream => FlutterCompass.events;

  /// هل البوصلة متوفرة؟
  static bool get isAvailable => FlutterCompass.events != null;

  /// حساب زاوية دوران السهم
  static double getArrowAngle({
    required double deviceHeading,
    required double qiblaBearing,
  }) {
    return (qiblaBearing - deviceHeading + 360.0) % 360.0;
  }

  /// تقييم دقة البوصلة
  static String getAccuracyLabel(int? accuracy) {
    if (accuracy == null) return 'غير معروفة';
    switch (accuracy) {
      case 3:
        return 'عالية ✅';
      case 2:
        return 'متوسطة 🟡';
      case 1:
        return 'منخفضة 🟠';
      case 0:
        return 'غير دقيقة — حرّك الهاتف ∞';
      default:
        return 'غير معروفة';
    }
  }

  /// هل تحتاج البوصلة إلى معايرة؟
  static bool needsCalibration(int? accuracy) =>
      accuracy == null || accuracy <= 1;
}
