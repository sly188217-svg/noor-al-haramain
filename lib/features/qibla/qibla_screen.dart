import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/services/compass_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription? _compassSub;
  StreamSubscription? _accelSub;

  double _deviceHeading = 0.0;
  double _qiblaBearing = 0.0;
  double _distanceKm = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;

  int? _accuracy;
  bool _hasLocation = false;
  bool _hasCompass = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!CompassService.isAvailable) {
      if (!mounted) return;
      setState(() => _errorMessage = 'جهازك لا يحتوي على بوصلة مغناطيسية');
      return;
    }
    if (!mounted) return;
    setState(() => _hasCompass = true);

    // ─── الموقع ───
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _errorMessage = 'لم يتم منح إذن الموقع');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _hasLocation = true;
        _qiblaBearing = CompassService.calculateQiblaDirection(
          position.latitude,
          position.longitude,
        );
        _distanceKm = CompassService.calculateDistanceToMakkah(
          position.latitude,
          position.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذّر تحديد الموقع: $e');
    }

    // ─── البوصلة (Yaw) ───
    _compassSub = CompassService.compassStream?.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          final heading = event.heading;
          if (heading != null) _deviceHeading = heading;
          _accuracy = event.accuracy?.toInt() ?? _accuracy;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _errorMessage = 'خطأ في البوصلة: $e');
      },
    );

    // ─── مستشعر التسارع (Pitch + Roll) ───
    _accelSub = CompassService.accelerometerStream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _pitch = CompassService.calculatePitch(event.x, event.y, event.z);
          _roll = CompassService.calculateRoll(event.x, event.y, event.z);
        });
      },
      onError: (e) {
        // تجاهل
      },
    );
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        foregroundColor: const Color(0xFFD4AF37),
        title: const Text('🧭 اتجاه القبلة'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_errorMessage.isNotEmpty) _buildError(),

                if (!_hasCompass || !_hasLocation)
                  const CircularProgressIndicator(
                      color: Color(0xFFD4AF37)),

                if (_hasCompass && _hasLocation) ...[
                  _build3DCompass(),
                  const SizedBox(height: 24),
                  _buildInfo(),
                  const SizedBox(height: 16),
                  if (CompassService.needsCalibration(_accuracy))
                    _buildCalibrationWarning(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 البوصلة 3D
  // ═══════════════════════════════════════════════════════════
  Widget _build3DCompass() {
    final arrowAngle = CompassService.getArrowAngle(
      deviceHeading: _deviceHeading,
      qiblaBearing: _qiblaBearing,
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateX(_pitch * pi / 180.0 * 0.5)
        ..rotateY(_roll * pi / 180.0 * 0.5),
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // الحلقة الخارجية (Compass Rose)
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F1A35),
                    const Color(0xFF0B132B),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // الشمال (N) — أحمر
                  Positioned(top: 10, child: _cardinalLabel('ش', Colors.red, 20)),
                  // الشرق (E)
                  Positioned(right: 10, child: _cardinalLabel('ق', Colors.white70, 16)),
                  // الجنوب (S)
                  Positioned(bottom: 10, child: _cardinalLabel('ج', Colors.white70, 16)),
                  // الغرب (W)
                  Positioned(left: 10, child: _cardinalLabel('غ', Colors.white70, 16)),

                  // علامات دقيقة (Ticks)
                  ..._buildTicks(),
                ],
              ),
            ),

            // السهم الدوّار (يشير إلى القبلة)
            Transform.rotate(
              angle: arrowAngle * pi / 180.0,
              child: CustomPaint(
                size: const Size(220, 220),
                painter: _Arrow3DPainter(),
              ),
            ),

            // الرقم في المركز
            Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B132B),
                border: Border.all(color: const Color(0xFFD4AF37), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_qiblaBearing.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CompassService.getDirectionLabel(_qiblaBearing),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTicks() {
    return List.generate(72, (i) {
      final angle = i * 5.0;
      final isMajor = i % 9 == 0; // كل 45°
      return Transform.rotate(
        angle: angle * pi / 180.0,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.only(top: isMajor ? 22 : 18),
            width: 1.5,
            height: isMajor ? 12 : 6,
            color: isMajor
                ? const Color(0xFFD4AF37)
                : const Color(0xFFD4AF37).withValues(alpha: 0.4),
          ),
        ),
      );
    });
  }

  Widget _cardinalLabel(String text, Color color, double size) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 معلومات البوصلة
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _infoRow('🧭 اتجاه الهاتف',
              '${_deviceHeading.toStringAsFixed(1)}° — ${CompassService.getDirectionLabel(_deviceHeading)}'),
          const Divider(color: Colors.white12, height: 16),
          _infoRow('🕋 اتجاه القبلة',
              '${_qiblaBearing.toStringAsFixed(1)}° — ${CompassService.getDirectionLabel(_qiblaBearing)}'),
          const Divider(color: Colors.white12, height: 16),
          _infoRow('📏 المسافة إلى مكة',
              '${_distanceKm.toStringAsFixed(0)} كم'),
          const Divider(color: Colors.white12, height: 16),
          _infoRow('📐 ميل الهاتف', '${_pitch.toStringAsFixed(1)}°'),
          const Divider(color: Colors.white12, height: 16),
          _infoRow('🔄 دوران الهاتف', '${_roll.toStringAsFixed(1)}°'),
          const Divider(color: Colors.white12, height: 16),
          _infoRow('🎯 دقة البوصلة',
              CompassService.getAccuracyLabel(_accuracy)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'البوصلة غير دقيقة. حرّك الهاتف على شكل ∞ (رقم 8) لمعايرتها.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 رسم السهم 3D
// ═══════════════════════════════════════════════════════════
class _Arrow3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    // سهم ذهبي مع ظل
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFFB8860B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final borderPaint = Paint()
      ..color = const Color(0xFFFFF8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    path.moveTo(center.dx, center.dy - size.height * 0.42);
    path.lineTo(center.dx - size.width * 0.09, center.dy - size.height * 0.22);
    path.lineTo(center.dx - size.width * 0.035, center.dy - size.height * 0.22);
    path.lineTo(center.dx - size.width * 0.035, center.dy + size.height * 0.35);
    path.lineTo(center.dx + size.width * 0.035, center.dy + size.height * 0.35);
    path.lineTo(center.dx + size.width * 0.035, center.dy - size.height * 0.22);
    path.lineTo(center.dx + size.width * 0.09, center.dy - size.height * 0.22);
    path.close();

    // ظل
    canvas.drawPath(path.shift(const Offset(2, 4)), shadowPaint);
    // السهم
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // رمز الكعبة 🕋
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🕋',
        style: TextStyle(fontSize: 30),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - 15, center.dy - size.height * 0.42 - 35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
