import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة الموقع — GPS دقيق + Geocoding عربي
/// ═══════════════════════════════════════════════════════════
/// 
/// ✅ يستخدم GPS الحقيقي فقط (لا IP)
/// ✅ يحصل على إحداثيات دقيقة (best accuracy)
/// ✅ يستخدم timeout واضح (20 ثانية)
/// ✅ يعرض أخطاء صريحة بدل الفشل الصامت
/// ✅ Reverse Geocoding عربي لاسم المدينة
class LocationService {
  /// ═══════════════════════════════════════════════════════════
  /// الحصول على الموقع الحالي بدقة GPS
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // 1. التحقق من خدمة الموقع
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'خدمة الموقع معطّلة. يرجى تشغيل GPS من إعدادات الهاتف.';
      }

      // 2. طلب الأذونات
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw 'تم رفض إذن الموقع. لا يمكن تحديد موقعك.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'إذن الموقع مرفوض بشكل دائم. يرجى تفعيله من إعدادات التطبيق.';
      }

      // 3. الحصول على الموقع بدقة عالية جداً
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // 4. الحصول على اسم المدينة (Reverse Geocoding)
      final cityName = await _getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final result = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': cityName,
        'source': 'GPS',
        'accuracy': position.accuracy,
      };

      // 5. حفظ الموقع تلقائياً
      await saveLocation(result);

      return result;
    } on TimeoutException {
      throw 'انتهت مهلة تحديد الموقع. تأكد من وجود إشارة GPS جيدة.';
    } catch (e) {
      debugPrint('❌ فشل تحديد الموقع: $e');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// Reverse Geocoding: الإحداثيات → اسم المدينة
  /// ═══════════════════════════════════════════════════════════
  static Future<String> _getCityFromCoordinates(
      double lat, double lng) async {
    // المحاولة 1: BigDataCloud (يدعم العربية)
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client'
              '?latitude=$lat&longitude=$lng&localityLanguage=ar',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // أولوية: city → locality → principalSubdivision
        final city = data['city'] ??
            data['locality'] ??
            data['principalSubdivision'] ??
            '';
        if (city.isNotEmpty) return city;
      }
    } catch (e) {
      debugPrint('⚠️ BigDataCloud فشل: $e');
    }

    // المحاولة 2: Nominatim (OpenStreetMap)
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?lat=$lat&lon=$lng&format=json&accept-language=ar',
            ),
            headers: {'User-Agent': 'NoorAlHaramain/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};
        final city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['state'] ??
            '';
        if (city.isNotEmpty) return city;
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim فشل: $e');
    }

    // Fallback: إحداثيات كاسم
    return 'موقعك الحالي (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
  }

  /// ═══════════════════════════════════════════════════════════
  /// البحث عن موقع يدوياً باسم المدينة (للاستخدام في الإعدادات)
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> getLocationFromCityName(
      String cityName) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/search'
              '?q=$cityName&format=json&limit=1&accept-language=ar',
            ),
            headers: {'User-Agent': 'NoorAlHaramain/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final location = data[0];
          return {
            'latitude': double.parse(location['lat']),
            'longitude': double.parse(location['lon']),
            'city': location['display_name']?.split(',').first ?? cityName,
            'source': 'Manual',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ فشل البحث: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// حفظ الموقع في SharedPreferences
  /// ═══════════════════════════════════════════════════════════
  static Future<void> saveLocation(Map<String, dynamic> locationData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_lat', locationData['latitude']);
    await prefs.setDouble('user_lng', locationData['longitude']);
    await prefs.setString('user_city', locationData['city']);
    await prefs.setBool('location_enabled', true);
  }

  /// ═══════════════════════════════════════════════════════════
  /// فتح إعدادات الموقع في الهاتف
  /// ═══════════════════════════════════════════════════════════
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// ═══════════════════════════════════════════════════════════
  /// فتح إعدادات التطبيق (للأذونات)
  /// ═══════════════════════════════════════════════════════════
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
