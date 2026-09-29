import 'package:flutter/material.dart';

class AnimatedIslamicBackground extends StatefulWidget {
  final Widget child;
  const AnimatedIslamicBackground({super.key, required this.child});

  @override
  State<AnimatedIslamicBackground> createState() => _AnimatedIslamicBackgroundState();
}

class _AnimatedIslamicBackgroundState extends State<AnimatedIslamicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // الخلفية الأساسية
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                Color(0xFF1C2541), // أزرق فاخر
                Color(0xFF0B132B), // أسود ملكي
              ],
              stops: [0.3, 1.0],
            ),
          ),
        ),

        // وهج ذهبي متحرك (الدائرة الذهبية الخافتة)
        Positioned(
          top: -100,
          left: -100,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  50 * _controller.value,
                  50 * _controller.value,
                ),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4AF37).withOpacity(0.04),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // وهج ذهبي ثانٍ (جهة اليمين السفلى)
        Positioned(
          bottom: -100,
          right: -100,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -30 * _controller.value,
                  -30 * _controller.value,
                ),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4AF37).withOpacity(0.03),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        blurRadius: 80,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // نقش إسلامي شفاف (نص مكرر بشكل خافت)
        Positioned(
          bottom: 20,
          right: 20,
          child: Opacity(
            opacity: 0.03,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Text(
                'الله 🌙 نور',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
              ),
            ),
          ),
        ),

        // المحتوى الذي سيظهر فوق الخلفية
        widget.child,
      ],
    );
  }
}
