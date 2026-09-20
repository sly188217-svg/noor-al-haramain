import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/adhan_download_service.dart';
import '../../core/services/hijri_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🕌 شاشة الأذان ملء الشاشة
/// ✅ تظهر تلقائياً عند دخول وقت الصلاة
/// ✅ تعرض اسم الصلاة + الوقت + التاريخ
/// ✅ تشغل الأذان
/// ═══════════════════════════════════════════════════════════
class AdhanScreen extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final String cityName;
  final String muezzinName;

  const AdhanScreen({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.cityName,
    required this.muezzinName,
  });

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isPlaying = false;
  String _hijriDate = '';

  @override
  void initState() {
    super.initState();

    // تهيئة التاريخ الهجري
    try {
      _hijriDate = HijriService.getHijriDate(DateTime.now());
    } catch (e) {
      _hijriDate = '';
    }

    // تهيئة الأنيميشن
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // تشغيل الأذان تلقائياً
    _playAdhan();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAdhan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muezzinId = prefs.getString('selected_muezzin') ?? 'adhan_sudais';

      final path = await AdhanDownloadService.getAssetSourcePath(muezzinId);
      if (path == null) {
        debugPrint('⚠️ الأذان غير متاح');
        return;
      }

      await _audioPlayer.play(AssetSource(path));
      if (mounted) setState(() => _isPlaying = true);

      _audioPlayer.onPlayerComplete.listen((_) async {
        if (mounted) setState(() => _isPlaying = false);
        // إغلاق الشاشة بعد انتهاء الأذان
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      debugPrint('❌ فشل تشغيل الأذان: $e');
    }
  }

  Future<void> _stopAdhan() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() => _isPlaying = false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('⚠️ فشل إيقاف الأذان: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1C2541),
              Color(0xFF0B132B),
            ],
            stops: [0.2, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ═══════════════════════════════════════════════════
              // الجزء العلوي: التاريخ + المدينة
              // ═══════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // المدينة
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFFD4AF37), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          widget.cityName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // التاريخ الهجري
                    if (_hijriDate.isNotEmpty)
                      Text(
                        _hijriDate,
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════════════
              // الجزء الأوسط: الشعار + الصلاة + الوقت
              // ═══════════════════════════════════════════════════
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الشعار النابض
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF1C2541),
                              Color(0xFF0B132B),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.mosque,
                            color: Color(0xFFD4AF37),
                            size: 70,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // نص: حان وقت صلاة
                    const Text(
                      '🕌 حان وقت صلاة',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // اسم الصلاة
                    Text(
                      widget.prayerName,
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // خط فاصل ذهبي
                    Container(
                      width: 120,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFD4AF37),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // الوقت
                    Text(
                      widget.prayerTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // اسم المؤذن
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.volume_up,
                              color: Color(0xFFD4AF37), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'أذان: ${widget.muezzinName}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════════════
              // الجزء السفلي: زر الإيقاف
              // ═══════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // نص الحالة
                    Text(
                      _isPlaying ? '🎧 الأذان يُشغَّل الآن...' : '✅ انتهى الأذان',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // زر الإيقاف
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _stopAdhan,
                        icon: const Icon(Icons.stop_circle, size: 26),
                        label: Text(
                          _isPlaying ? 'إيقاف الأذان' : 'إغلاق',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
