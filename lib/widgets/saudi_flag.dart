import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// العلم السعودي الرسمي — نسبة 2:3
/// ═══════════════════════════════════════════════════════════
/// 
/// يستخدم صورة PNG رسمية: assets/images/flags/sa.png
/// الأبعاد: 480x320 (نسبة 2:3)
/// 
class SaudiFlag extends StatelessWidget {
  /// الارتفاع (الافتراضي 24)
  final double height;

  /// العرض (اختياري — يُحسب تلقائياً بنسبة 2:3)
  final double? width;

  /// طريقة ملء الصورة
  final BoxFit fit;

  /// زوايا دائرية (اختياري)
  final BorderRadius? borderRadius;

  const SaudiFlag({
    super.key,
    this.height = 24,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // العلم السعودي: نسبة 2:3 (عرض:ارتفاع)
    final effectiveWidth = width ?? height * 1.5;
    final radius = borderRadius ?? BorderRadius.circular(3);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: effectiveWidth,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.5,
          ),
          borderRadius: radius,
          color: const Color(0xFF165D31), // لون احتياطي
        ),
        child: Image.asset(
          'assets/images/flags/sa.png',
          width: effectiveWidth,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('⚠️ فشل تحميل العلم السعودي: $error');
            return Container(
              color: const Color(0xFF165D31),
              child: Center(
                child: Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: height * 0.6,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
