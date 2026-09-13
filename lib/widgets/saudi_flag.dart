import 'package:flutter/material.dart';

/// العلم السعودي الرسمي — النسبة 2:3
class SaudiFlag extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;
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
    final effectiveWidth = width ?? height * 1.5;
    final radius = borderRadius ?? BorderRadius.circular(3);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: effectiveWidth,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 0.5,
          ),
          borderRadius: radius,
        ),
        child: Image.asset(
          'assets/images/flags/sa.png',
          width: effectiveWidth,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: effectiveWidth,
              height: height,
              color: const Color(0xFF165D31),
              child: Icon(Icons.flag, color: Colors.white, size: height * 0.6),
            );
          },
        ),
      ),
    );
  }
}
