import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة الخلفيات — 6 خلفيات Gradient إسلامية
/// ═══════════════════════════════════════════════════════════
/// 
/// ✅ لا تحتاج صور خارجية
/// ✅ تعمل 100% بدون إنترنت
/// ✅ خفيفة جداً (0 KB)
/// 
class BackgroundService {
  static const String _key = 'background_index';

  static const List<Map<String, dynamic>> backgrounds = [
    // 1. أخضر إسلامي (الحرم المكي)
    {
      'name': 'الحرم المكي',
      'colors': [
        Color(0xFF0B132B),
        Color(0xFF165D31),
        Color(0xFF0B132B),
      ],
      'icon': Icons.mosque,
    },
    // 2. أخضر زمردي (المدينة المنورة)
    {
      'name': 'المدينة المنورة',
      'colors': [
        Color(0xFF0F1A2E),
        Color(0xFF1B5E20),
        Color(0xFF0F1A2E),
      ],
      'icon': Icons.mosque,
    },
    // 3. ذهبي فاخر (قبة الصخرة)
    {
      'name': 'قبة الصخرة',
      'colors': [
        Color(0xFF1A1A00),
        Color(0xFFD4AF37),
        Color(0xFF1A1A00),
      ],
      'icon': Icons.temple_buddhist,
    },
    // 4. أزرق ليلي (المسجد الأقصى)
    {
      'name': 'المسجد الأقصى',
      'colors': [
        Color(0xFF0B132B),
        Color(0xFF1A237E),
        Color(0xFF0B132B),
      ],
      'icon': Icons.mosque,
    },
    // 5. بنفسجي إسلامي (زخرفة)
    {
      'name': 'زخرفة إسلامية',
      'colors': [
        Color(0xFF1C2541),
        Color(0xFF4A148C),
        Color(0xFF1C2541),
      ],
      'icon': Icons.auto_awesome,
    },
    // 6. أسود هادئ (ليل)
    {
      'name': 'ليل هادئ',
      'colors': [
        Color(0xFF000000),
        Color(0xFF0B132B),
        Color(0xFF000000),
      ],
      'icon': Icons.nightlight,
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

  /// بناء الخلفية كـ Gradient + زخرفة إسلامية
  static Widget buildBackground({
    required int index,
    required Widget child,
  }) {
    if (index < 0 || index >= backgrounds.length) {
      index = 0;
    }
    final bg = backgrounds[index];
    final colors = bg['colors'] as List<Color>;

    return Stack(
      children: [
        // 1. الخلفية المتدرجة
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 2. زخرفة إسلامية شفافة
        Positioned.fill(
          child: CustomPaint(
            painter: _IslamicPatternPainter(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            ),
          ),
        ),

        // 3. الأيقونة الكبيرة الشفافة
        Positioned(
          top: 80,
          right: 20,
          child: Icon(
            bg['icon'] as IconData,
            size: 120,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.06),
          ),
        ),

        // 4. المحتوى
        Positioned.fill(child: child),
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// رسم زخرفة إسلامية (نجمة 8 رؤوس + دوائر)
/// ═══════════════════════════════════════════════════════════
class _IslamicPatternPainter extends CustomPainter {
  final Color color;

  _IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // نجمة 8 رؤوس
    for (int i = 0; i < 8; i++) {
      final angle = i * (3.14159 / 4);
      final dx = radius * _cos(angle);
      final dy = radius * _sin(angle);
      final point = Offset(center.dx + dx, center.dy + dy);
      canvas.drawLine(center, point, paint);
      canvas.drawCircle(point, 4, paint);
    }

    // دوائر متحدة المركز
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, paint);
    }
  }

  double _cos(double x) {
    // Taylor approximation
    return (1 - x * x / 2 + x * x * x * x / 24);
  }

  double _sin(double x) {
    return (x - x * x * x / 6 + x * x * x * x * x / 120);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
