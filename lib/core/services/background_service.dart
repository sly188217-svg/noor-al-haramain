import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة الخلفيات — 6 خلفيات إسلامية
/// ═══════════════════════════════════════════════════════════
class BackgroundService {
  static const String _key = 'background_index';

  static const List<Map<String, dynamic>> backgrounds = [
    {
      'name': 'الحرم المكي',
      'image': 'assets/images/backgrounds/kaaba.jpg',
      'gradient': [Color(0xFF0B132B), Color(0xFF1C2541)],
    },
    {
      'name': 'المسجد النبوي',
      'image': 'assets/images/backgrounds/madinah.jpg',
      'gradient': [Color(0xFF0F1A2E), Color(0xFF165D31)],
    },
    {
      'name': 'المسجد الأقصى',
      'image': 'assets/images/backgrounds/aqsa.jpg',
      'gradient': [Color(0xFF2D1B00), Color(0xFF4A3000)],
    },
    {
      'name': 'زخرفة إسلامية 1',
      'image': 'assets/images/backgrounds/pattern1.jpg',
      'gradient': [Color(0xFF1A2B3C), Color(0xFF2C3E50)],
    },
    {
      'name': 'زخرفة إسلامية 2',
      'image': 'assets/images/backgrounds/pattern2.jpg',
      'gradient': [Color(0xFF1C2541), Color(0xFF3D2E0A)],
    },
    {
      'name': 'ليل هادئ',
      'image': 'assets/images/backgrounds/night.jpg',
      'gradient': [Color(0xFF0B132B), Color(0xFF000000)],
    },
  ];

  static Future<Map<String, dynamic>> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index < 0 || index >= backgrounds.length) {
      return backgrounds[0];
    }
    return backgrounds[index];
  }

  static Future<int> getCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<void> setBackground(int index) async {
    if (index < 0 || index >= backgrounds.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }

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
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.88),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
