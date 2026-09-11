import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';

class CompassService {
  static double _currentHeading = 0.0;
  static double _currentPitch = 0.0;
  static double _currentRoll = 0.0;

  static Stream<Map<String, double>> get compassStream {
    return _getCompassStream();
  }

  static Stream<Map<String, double>> _getCompassStream() async* {
    // استخدام مستشعرات الجيروسكوب والمغناطيسية لحساب الاتجاه بدقة 3D
    await for (var event in accelerometerEvents) {
      // محاكاة: في التطبيق الحقيقي ندمج البيانات من المستشعرات
      // نستخدم هنا محاكاة بسيطة للعرض
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final heading = (now * 0.1) % 360; // دوران مستمر للتجربة
      yield {
        'heading': heading,
        'pitch': sin(now * 0.05) * 10,
        'roll': cos(now * 0.07) * 10,
      };
    }
  }

  static double calculateQiblaDirection(double userLat, double userLng) {
    const double MAKKAH_LAT = 21.4225;
    const double MAKKAH_LNG = 39.8262;

    double lat1 = userLat * pi / 180;
    double lng1 = userLng * pi / 180;
    double lat2 = MAKKAH_LAT * pi / 180;
    double lng2 = MAKKAH_LNG * pi / 180;

    double dLng = lng2 - lng1;

    double y = sin(dLng) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }
}
