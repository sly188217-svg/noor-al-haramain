import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/location_service.dart';
import '../dashboard/dashboard_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _locationData;

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);

    // جلب الموقع الحقيقي (GPS أو IP)
    final location = await LocationService.getCurrentLocation();
    setState(() {
      _locationData = location;
      _isLoading = false;
    });

    // حفظ الموقع في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_lat', location['latitude']);
    await prefs.setDouble('user_lng', location['longitude']);
    await prefs.setString('user_city', location['city']);
    await prefs.setBool('location_enabled', true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تحديد موقعك: ${location['city']} (${location['source']})'),
          backgroundColor: Colors.green,
        ),
      );
      // ننتقل للوحة التحكم
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  void _skipLocation() async {
    final prefs = await SharedPreferences.getInstance();
    // استخدام مكة كقيمة افتراضية
    await prefs.setDouble('user_lat', 21.4225);
    await prefs.setDouble('user_lng', 39.8262);
    await prefs.setString('user_city', 'مكة المكرمة (افتراضي)');
    await prefs.setBool('location_enabled', false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الشعار
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  color: Color(0xFFD4AF37),
                  size: 60,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '📍 تحديد الموقع الجغرافي',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'سنقوم بتحديد موقعك بدقة لحساب أوقات الصلاة واتجاه القبلة الصحيح.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // عرض الموقع إذا تم جلبها
              if (_locationData != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '📍 ${_locationData!['city']}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'الإحداثيات: ${_locationData!['latitude'].toStringAsFixed(4)}, ${_locationData!['longitude'].toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'المصدر: ${_locationData!['source']}',
                        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFD4AF37))
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _requestLocationPermission,
                        child: const Text(
                          '✅ تحديد موقعي الآن',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _skipLocation,
                child: const Text(
                  'تخطي واستخدام مكة المكرمة (افتراضي)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
