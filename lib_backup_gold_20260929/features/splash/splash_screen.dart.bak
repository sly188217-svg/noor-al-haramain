import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/translation_service.dart';
import 'language_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();

    Future.delayed(const Duration(milliseconds: 3500), () {
      _navigateToLanguage();
    });
  }

  void _navigateToLanguage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LanguageSelectionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Stack(
        children: [
          // خلفية متدرجة
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          // وهج ذهبي
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
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
          ),
          // المحتوى
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇸🇦', style: TextStyle(fontSize: 80, shadows: [
                      Shadow(color: Color(0xFFD4AF37), blurRadius: 30)
                    ])),
                    const SizedBox(height: 20),
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2A3A5C), Color(0xFF1C2541)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                              color: const Color(0xFFD4AF37), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield,
                                color: Color(0xFFD4AF37), size: 28),
                            const SizedBox(width: 12),
                            const Text('ApexSec',
                                style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                          color: Color(0xFFD4AF37),
                                          blurRadius: 15)
                                    ])),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('GLOBAL',
                                  style: TextStyle(
                                      color: Color(0xFF0B132B),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('نــور الـحــرمــيــن',
                        style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                  color: Color(0xFFD4AF37),
                                  blurRadius: 25,
                                  offset: Offset(0, 2))
                            ])),
                    const SizedBox(height: 8),
                    const Text('Noor Al-Haramain',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 6)),
                    const SizedBox(height: 12),
                    Container(
                      width: 100,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFFD4AF37),
                            Colors.transparent
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(
                        color: Color(0xFFD4AF37), strokeWidth: 2.5),
                    const SizedBox(height: 20),
                    Text(
                      TranslationService.getText(lang, 'preparing'),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        children: [
                          Text(
                            TranslationService.getText(lang, 'for_muslims'),
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'For Muslims Everywhere 🌍',
                            style: TextStyle(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                fontSize: 9,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 8),
                          Text('v1.0.0',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.1),
                                  fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
