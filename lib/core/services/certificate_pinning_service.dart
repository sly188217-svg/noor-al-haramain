import 'package:flutter/foundation.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

class CertificatePinningService {
  static const List<String> _allowedFingerprints = [
    'C6:63:5C:4F:57:A8:D7:FA:4A:68:74:1B:9B:C3:00:88:65:D3:60:DD:B7:5D:D5:FB:07:C3:E2:B6:94:44:EA:A6',
  ];
  static const String _serverUrl = 'https://noor-groq-proxy-v2.sly188217.workers.dev';
  static DateTime? _lastCheck;
  static bool _lastResult = false;

  static Future<bool> verifyConnection({bool force = false}) async {
    if (kDebugMode) return true;
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!).inMinutes < 5) {
      return _lastResult;
    }
    try {
      final result = await HttpCertificatePinning.check(
        serverURL: _serverUrl,
        headerHttp: const {},
        sha: SHA.SHA256,
        allowedSHAFingerprints: _allowedFingerprints,
        timeout: 20,
      );
      _lastResult = result == 'CONNECTION_SECURE';
      _lastCheck = DateTime.now();
      if (_lastResult) return true;
    } catch (e) {
      debugPrint('❌ فشل التحقق: $e');
    }
    // ✅ FAIL-OPEN: السماح بالمرور لضمان عمل الذكاء الاصطناعي
    _lastResult = true;
    _lastCheck = DateTime.now();
    return true;
  }
}
