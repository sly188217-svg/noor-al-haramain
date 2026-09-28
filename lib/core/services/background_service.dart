import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎨 خدمة الخلفيات — 4 صور + 2 تدرجات (6 خلفيات)
/// ═══════════════════════════════════════════════════════════
class BackgroundService {
  static const String _key = 'background_index';

  static const List<Map<String, dynamic>> backgrounds = [
    // 1. الكعبة المشرفة 🕋
    {
      'name': 'الكعبة المشرفة',
      'type': 'image',
      'imagePath': 'assets/images/backgrounds/makkah.jpg',
      'icon': Icons.mosque,
    },
    // 2. المسجد النبوي 🕌
    {
      'name': 'المسجد النبوي',
      'type': 'image',
      'imagePath': 'assets/images/backgrounds/madinah.jpg',
      'icon': Icons.mosque,
    },
    // 3. المدينة المنورة 🕌
    {
      'name': 'المدينة المنورة',
      'type': 'image',
      'imagePath': 'assets/images/backgrounds/madinah2.jpg',
      'icon': Icons.mosque,
    },
    // 4. الحرم المكي 🕋 (الصورة الجديدة)
    {
      'name': 'الحرم المكي',
      'type': 'image',
      'imagePath': 'assets/images/backgrounds/makkah2.jpg',
      'icon': Icons.mosque,
    },
    // 5. ذهبي فاخر ⭐
    {
      'name': 'ذهبي فاخر',
      'type': 'gradient',
      'colors': [
        Color(0xFF1A1A00),
        Color(0xFFD4AF37),
        Color(0xFF1A1A00),
      ],
      'icon': Icons.temple_buddhist,
    },
    // 6. ليل هادئ 🌙
    {
      'name': 'ليل هادئ',
      'type': 'gradient',
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

  static Widget buildBackground({
    required int index,
    required Widget child,
  }) {
    if (index < 0 || index >= backgrounds.length) {
      index = 0;
    }
    final bg = backgrounds[index];
    final type = bg['type'] as String;

    return Stack(
      children: [
        Positioned.fill(
          child: type == 'image'
              ? _buildImageBackground(bg['imagePath'] as String)
              : _buildGradientBackground(bg['colors'] as List<Color>),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _IslamicPatternPainter(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  static Widget _buildImageBackground(String path) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A1929),
                Color(0xFF132F4C),
                Color(0xFF0A1929),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.mosque,
              color: Colors.white12,
              size: 200,
            ),
          ),
        );
      },
    );
  }

  static Widget _buildGradientBackground(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

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

    for (int i = 0; i < 8; i++) {
      final angle = i * (3.14159 / 4);
      final dx = radius * _cos(angle);
      final dy = radius * _sin(angle);
      final point = Offset(center.dx + dx, center.dy + dy);
      canvas.drawLine(center, point, paint);
      canvas.drawCircle(point, 4, paint);
    }

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, paint);
    }
  }

  double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
