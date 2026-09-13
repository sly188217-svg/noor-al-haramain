import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _ipApiUrl = 'http://ip-api.com/json/';

  // دالة رئيسية للحصول على الموقع (ذكية)
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    // 1. نحاول أولاً الحصول على موقع دقيق من GPS
    try {
      final gpsLocation = await _getLocationFromGPS();
      if (gpsLocation != null) {
        return gpsLocation;
      }
    } catch (e) {
      // إذا فشل GPS، ننتقل للخطوة التالية
    }

    // 2. إذا فشل GPS، نحاول الحصول على موقع تقريبي من IP
    try {
      final ipLocation = await _getLocationFromIP();
      if (ipLocation != null) {
        return ipLocation;
      }
    } catch (e) {
      // إذا فشل كل شيء، نستخدم مكة المكرمة كموقع افتراضي
    }

    // 3. الخيار الأخير: مكة المكرمة (حالة طوارئ)
    return {
      'latitude': 21.4225,
      'longitude': 39.8262,
      'city': 'مكة المكرمة (افتراضي)',
      'source': 'Fallback',
    };
  }

  // دالة مساعدة: جلب الموقع من GPS
  static Future<Map<String, dynamic>?> _getLocationFromGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // الحصول على الموقع بدقة عالية
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // محاولة الحصول على اسم المدينة من الإحداثيات
    String cityName = await _getCityFromCoordinates(position.latitude, position.longitude);

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'city': cityName,
      'source': 'GPS',
    };
  }

  // دالة مساعدة: جلب الموقع من عنوان IP
  static Future<Map<String, dynamic>?> _getLocationFromIP() async {
    try {
      final response = await http.get(Uri.parse(_ipApiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {
            'latitude': data['lat'],
            'longitude': data['lon'],
            'city': data['city'] ?? 'مدينة غير معروفة',
            'source': 'IP-API',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // دالة مساعدة: الحصول على اسم المدينة من الإحداثيات (عكس الجغرافيا)
  static Future<String> _getCityFromCoordinates(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client'
          '?latitude=$lat&longitude=$lng&localityLanguage=ar',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['city'] ?? 'مدينة غير معروفة';
      }
      return 'مدينة غير معروفة';
    } catch (e) {
      return 'مدينة غير معروفة';
    }
  }

  // دالة لتحديد الموقع يدوياً (سيستخدمها المستخدم من الإعدادات)
  static Future<Map<String, dynamic>?> getLocationFromCityName(String cityName) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.bigdatacloud.net/data/geocode?locality=$cityName&localityLanguage=ar',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final location = data[0];
          return {
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'city': location['locality'] ?? cityName,
            'source': 'Manual',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // حفظ الموقع المختار في SharedPreferences
  static Future<void> saveLocation(Map<String, dynamic> locationData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_lat', locationData['latitude']);
    await prefs.setDouble('user_lng', locationData['longitude']);
    await prefs.setString('user_city', locationData['city']);
    await prefs.setBool('location_enabled', true);
  }
}
