import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/compass_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription? _compassSub;
  double _deviceHeading = 0.0;
  double _qiblaBearing = 0.0;
  double _distanceKm = 0.0;
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
    // 1. تحقق من المستشعر
    if (!CompassService.isAvailable) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'جهازك لا يحتوي على بوصلة مغناطيسية';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _hasCompass = true);

    // 2. اطلب الموقع
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'لم يتم منح إذن الموقع';
        });
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
      setState(() {
        _errorMessage = 'تعذّر تحديد الموقع: $e';
      });
    }

    // 3. ابدأ الاستماع للبوصلة
    _compassSub = CompassService.compassStream?.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          // ✅ heading و accuracy قد تكون null
          final heading = event.heading;
          if (heading != null) {
            _deviceHeading = heading;
          }
          _accuracy = event.accuracy?.toInt() ?? _accuracy;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _errorMessage = 'خطأ في البوصلة: $e');
      },
    );
  }

  @override
  void dispose() {
    _compassSub?.cancel();
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
                  const CircularProgressIndicator(color: Color(0xFFD4AF37)),

                if (_hasCompass && _hasLocation) ...[
                  _buildCompass(),
                  const SizedBox(height: 30),
                  _buildInfo(),
                  const SizedBox(height: 20),
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

  Widget _buildCompass() {
    // زاوية دوران السهم
    final arrowAngle = CompassService.getArrowAngle(
      deviceHeading: _deviceHeading,
      qiblaBearing: _qiblaBearing,
    );

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الحلقة الخارجية (ثابتة - تمثل الشمال)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                width: 3,
              ),
              color: const Color(0xFF0F1A35),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(top: 8, child: _cardinalLabel('ش', Colors.red)),
                Positioned(
                    bottom: 8, child: _cardinalLabel('ج', Colors.white70)),
                Positioned(
                    left: 8, child: _cardinalLabel('غ', Colors.white70)),
                Positioned(
                    right: 8, child: _cardinalLabel('ق', Colors.white70)),
              ],
            ),
          ),

          // السهم الدوّار
          Transform.rotate(
            angle: arrowAngle * pi / 180.0,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _ArrowPainter(),
            ),
          ),

          // الرقم في المركز
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B132B),
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
            ),
            child: Center(
              child: Text(
                '${_qiblaBearing.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardinalLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _infoRow('🧭 اتجاه الهاتف',
              '${_deviceHeading.toStringAsFixed(1)}°'),
          const SizedBox(height: 8),
          _infoRow('🕋 اتجاه القبلة',
              '${_qiblaBearing.toStringAsFixed(1)}°'),
          const SizedBox(height: 8),
          _infoRow('📏 المسافة إلى مكة',
              '${_distanceKm.toStringAsFixed(0)} كم'),
          const SizedBox(height: 8),
          _infoRow(
              '🎯 دقة البوصلة', CompassService.getAccuracyLabel(_accuracy)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orange.withValues(alpha: 0.5)),
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

/// رسم السهم
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    path.moveTo(center.dx, center.dy - size.height * 0.42);
    path.lineTo(
        center.dx - size.width * 0.08, center.dy - size.height * 0.25);
    path.lineTo(
        center.dx - size.width * 0.03, center.dy - size.height * 0.25);
    path.lineTo(
        center.dx - size.width * 0.03, center.dy + size.height * 0.35);
    path.lineTo(
        center.dx + size.width * 0.03, center.dy + size.height * 0.35);
    path.lineTo(
        center.dx + size.width * 0.03, center.dy - size.height * 0.25);
    path.lineTo(
        center.dx + size.width * 0.08, center.dy - size.height * 0.25);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // رمز الكعبة 🕋
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🕋',
        style: TextStyle(fontSize: 28),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - 14, center.dy - size.height * 0.42 - 30),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
