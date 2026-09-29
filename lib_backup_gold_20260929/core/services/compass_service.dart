import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

// إعادة تصدير CompassEvent
export 'package:flutter_compass/flutter_compass.dart' show CompassEvent;

/// ═══════════════════════════════════════════════════════════
/// خدمة البوصلة 3D — Yaw + Pitch + Roll
/// ═══════════════════════════════════════════════════════════
class CompassService {
  static const double makkahLat = 21.4224779;
  static const double makkahLng = 39.8251832;

  /// حساب زاوية القبلة
  static double calculateQiblaDirection(double userLat, double userLng) {
    final lat1 = userLat * pi / 180.0;
    final lng1 = userLng * pi / 180.0;
    final lat2 = makkahLat * pi / 180.0;
    final lng2 = makkahLng * pi / 180.0;

    final dLng = lng2 - lng1;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    var bearing = atan2(y, x) * 180.0 / pi;
    return (bearing + 360.0) % 360.0;
  }

  /// حساب المسافة إلى مكة
  static double calculateDistanceToMakkah(double userLat, double userLng) {
    const earthRadius = 6371.0;
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

  /// تدفق البوصلة (Yaw)
  static Stream<CompassEvent>? get compassStream => FlutterCompass.events;

  /// هل البوصلة متوفرة؟
  static bool get isAvailable => FlutterCompass.events != null;

  /// تدفق مستشعر التسارع (Pitch + Roll)
  static Stream<AccelerometerEvent> get accelerometerStream =>
      accelerometerEventStream();

  /// حساب Pitch (الميل الأمامي/الخلفي)
  static double calculatePitch(double x, double y, double z) {
    return atan2(-x, sqrt(y * y + z * z)) * 180.0 / pi;
  }

  /// حساب Roll (الميل الجانبي)
  static double calculateRoll(double x, double y, double z) {
    return atan2(y, z) * 180.0 / pi;
  }

  /// زاوية دوران السهم
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

  /// هل تحتاج معايرة؟
  static bool needsCalibration(int? accuracy) {
    return accuracy == null || accuracy <= 1;
  }

  /// نصيحة اتجاه (N, NE, E, ...)
  static String getDirectionLabel(double heading) {
    if (heading < 22.5 || heading >= 337.5) return 'شمال';
    if (heading < 67.5) return 'شمال شرق';
    if (heading < 112.5) return 'شرق';
    if (heading < 157.5) return 'جنوب شرق';
    if (heading < 202.5) return 'جنوب';
    if (heading < 247.5) return 'جنوب غرب';
    if (heading < 292.5) return 'غرب';
    return 'شمال غرب';
  }
}
