import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة الخلفيات — تُدار مركزياً
/// ═══════════════════════════════════════════════════════════
class BackgroundService {
  static const String _key = 'background_index';

  /// قائمة الخلفيات
  static const List<Map<String, dynamic>> backgrounds = [
    {
      'name': 'الحرم المكي',
      'image': 'assets/images/backgrounds/kaaba.jpg',
      'gradient': [Color(0xFF0B132B), Color(0xFF1C2541)],
    },
    {
      'name': 'المدينة المنورة',
      'image': 'assets/images/backgrounds/madinah.jpg',
      'gradient': [Color(0xFF0F1A2E), Color(0xFF165D31)],
    },
    {
      'name': 'مسجد',
      'image': 'assets/images/backgrounds/mosque1.jpg',
      'gradient': [Color(0xFF2D1B00), Color(0xFF4A3000)],
    },
    {
      'name': 'قبة',
      'image': 'assets/images/backgrounds/mosque2.jpg',
      'gradient': [Color(0xFF1A2B3C), Color(0xFF2C3E50)],
    },
    {
      'name': 'زخرفة 1',
      'image': 'assets/images/backgrounds/pattern1.jpg',
      'gradient': [Color(0xFF1C2541), Color(0xFF3D2E0A)],
    },
    {
      'name': 'زخرفة 2',
      'image': 'assets/images/backgrounds/pattern2.jpg',
      'gradient': [Color(0xFF0B132B), Color(0xFF000000)],
    },
  ];

  /// الحصول على الخلفية الحالية
  static Future<Map<String, dynamic>> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index < 0 || index >= backgrounds.length) {
      return backgrounds[0];
    }
    return backgrounds[index];
  }

  /// الحصول على فهرس الخلفية الحالية
  static Future<int> getCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  /// حفظ الخلفية المختارة
  static Future<void> setBackground(int index) async {
    if (index < 0 || index >= backgrounds.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }

  /// بناء ويدجت الخلفية (صورة أو gradient)
  static Widget buildBackground({
    required int index,
    required Widget child,
  }) {
    if (index < 0 || index >= backgrounds.length) {
      index = 0;
    }
    final bg = backgrounds[index];

    return Stack(
      children: [
        // الطبقة 1: الخلفية (صورة أو gradient)
        Positioned.fill(
          child: Image.asset(
            bg['image'] as String,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bg['gradient'] as List<Color>,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
        ),
        // الطبقة 2: تعتيم داكن (لتحسين قراءة النصوص)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // الطبقة 3: المحتوى
        Positioned.fill(child: child),
      ],
    );
  }
}
