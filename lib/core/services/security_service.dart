import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:safe_device/safe_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🛡️ SecurityService — الحماية الأقصى (Native + Dart)
/// ═══════════════════════════════════════════════════════════
class SecurityService {
  static const _nativeChannel = MethodChannel('com.apexsec.noor/security');

  // ✅ flutter_secure_storage 11.x — API جديد
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _encryptionKeyAlias = 'noor_enc_key_v2';
  static const _deviceIdKey = 'noor_device_id_v2';
  static const _rateLimitKey = 'noor_rate_limit_v2';

  static String? _cachedDeviceId;
  static DateTime? _lastSecurityCheck;
  static SecurityReport? _cachedReport;

  // ═══════════════════════════════════════════════════════════
  // 🛡️ الفحص الأمني الشامل (Native + Dart)
  // ═══════════════════════════════════════════════════════════
  static Future<SecurityReport> runFullCheck({bool force = false}) async {
    if (!force &&
        _cachedReport != null &&
        _lastSecurityCheck != null &&
        DateTime.now().difference(_lastSecurityCheck!).inMinutes < 5) {
      return _cachedReport!;
    }

    if (kDebugMode) {
      return SecurityReport.safe();
    }

    final critical = <String>[];
    final warnings = <String>[];

    // ═══════════════════════════════════════════════════════════
    // 🔴 Native Checks (Kotlin — أقوى)
    // ═══════════════════════════════════════════════════════════

    // 1) Signature Verification
    try {
      final isValid = await _nativeChannel.invokeMethod<bool>('verifySignature');
      if (isValid == false) {
        critical.add('🚨 التطبيق مُعدَّل أو موقع بتوقيع مختلف');
      }
    } catch (e) {
      debugPrint('⚠️ Signature check: $e');
    }

    // 2) Debugger Detection
    try {
      final hasDebugger =
          await _nativeChannel.invokeMethod<bool>('isDebuggerAttached');
      if (hasDebugger == true) {
        critical.add('🐛 Debugger متصل بالتطبيق');
      }
    } catch (e) {
      debugPrint('⚠️ Debugger check: $e');
    }

    // 3) Frida / Xposed / Substrate
    try {
      final hasFrida = await _nativeChannel.invokeMethod<bool>('isFridaRunning');
      if (hasFrida == true) {
        critical.add('🐍 أداة حقن (Frida/Xposed) مكتشفة');
      }
    } catch (e) {
      debugPrint('⚠️ Frida check: $e');
    }

    // 4) Emulator Detection (Native)
    try {
      final isEmu = await _nativeChannel.invokeMethod<bool>('isEmulator');
      if (isEmu == true) {
        critical.add('🖥️ التطبيق يعمل على محاكي');
      }
    } catch (e) {
      debugPrint('⚠️ Emulator check: $e');
    }

    // 5) Root Detection (Native)
    try {
      final isRoot = await _nativeChannel.invokeMethod<bool>('isRooted');
      if (isRoot == true) {
        critical.add('🔓 الجهاز مُروَّت (Root)');
      }
    } catch (e) {
      debugPrint('⚠️ Root check: $e');
    }

    // ═══════════════════════════════════════════════════════════
    // 🟡 Dart Checks (طبقة إضافية)
    // ═══════════════════════════════════════════════════════════

    // 6) Mock Location
    try {
      final isMock = await SafeDevice.isMockLocation;
      if (isMock == true) {
        warnings.add('📍 موقع وهمي مُفعَّل');
      }
    } catch (e) {
      debugPrint('⚠️ Mock check: $e');
    }

    // 7) Developer Mode
    try {
      final isDev = await SafeDevice.isDevelopmentModeEnable;
      if (isDev == true) {
        warnings.add('🔧 وضع المطور');
      }
    } catch (e) {
      debugPrint('⚠️ Dev mode check: $e');
    }

    _cachedReport = SecurityReport(
      isSafe: critical.isEmpty,
      issues: critical,
      warnings: warnings,
    );
    _lastSecurityCheck = DateTime.now();

    return _cachedReport!;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 تشفير/فك تشفير AES-256-GCM
  // ═══════════════════════════════════════════════════════════
  static Future<enc.Key> _getOrCreateEncryptionKey() async {
    try {
      final stored = await _storage.read(key: _encryptionKeyAlias);
      if (stored != null && stored.length > 20) {
        return enc.Key.fromBase64(stored);
      }

      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final key = enc.Key(Uint8List.fromList(keyBytes));
      await _storage.write(key: _encryptionKeyAlias, value: key.base64);
      return key;
    } catch (e) {
      debugPrint('❌ فشل المفتاح: $e');
      return enc.Key.fromUtf8('NoorAlHaramainFallbackKey32Byte!');
    }
  }

  static Future<String> encryptText(String plaintext) async {
    try {
      final key = await _getOrCreateEncryptionKey();
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('❌ فشل التشفير: $e');
      return plaintext;
    }
  }

  static Future<String> decryptText(String ciphertext) async {
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return ciphertext;

      final key = await _getOrCreateEncryptionKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      return ciphertext;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🆔 Device ID فريد
  // ═══════════════════════════════════════════════════════════
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      final stored = await _storage.read(key: _deviceIdKey);
      if (stored != null && stored.isNotEmpty) {
        _cachedDeviceId = stored;
        return stored;
      }

      final info = DeviceInfoPlugin();
      String rawId = '';

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        rawId = '${android.id}-${android.model}-${android.brand}';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        rawId = ios.identifierForVendor ?? '';
      }

      if (rawId.isEmpty) {
        final r = Random.secure();
        rawId =
            List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      }

      final hashed = sha256.convert(utf8.encode('noor_v2_$rawId')).toString();
      await _storage.write(key: _deviceIdKey, value: hashed);
      _cachedDeviceId = hashed;
      return hashed;
    } catch (e) {
      return 'unknown';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏱️ Rate Limiting
  // ═══════════════════════════════════════════════════════════
  static Future<bool> checkRateLimit({
    required String action,
    required int maxPerMinute,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final raw = prefs.getString(_rateLimitKey) ?? '{}';
      final Map<String, dynamic> log = jsonDecode(raw);

      final filtered = <String, dynamic>{};
      for (final entry in log.entries) {
        final timestamps = (entry.value as List)
            .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
            .where((t) => now.difference(t).inMinutes < 1)
            .toList();
        if (timestamps.isNotEmpty) {
          filtered[entry.key] =
              timestamps.map((t) => t.millisecondsSinceEpoch).toList();
        }
      }

      final actionLog = (filtered[action] as List?) ?? [];
      if (actionLog.length >= maxPerMinute) return false;

      actionLog.add(now.millisecondsSinceEpoch);
      filtered[action] = actionLog;

      await prefs.setString(_rateLimitKey, jsonEncode(filtered));
      return true;
    } catch (e) {
      return true;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 تخزين آمن
  // ═══════════════════════════════════════════════════════════
  static Future<void> storeSecret(String key, String value) async {
    try {
      final encrypted = await encryptText(value);
      await _storage.write(key: key, value: encrypted);
    } catch (e) {
      debugPrint('❌ فشل تخزين $key: $e');
    }
  }

  static Future<String?> readSecret(String key) async {
    try {
      final encrypted = await _storage.read(key: key);
      if (encrypted == null) return null;
      return await decryptText(encrypted);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteSecret(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  static Future<void> wipeAllSecrets() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 الحصول على هاش التوقيع
  // ═══════════════════════════════════════════════════════════
  static Future<String> getSignatureHash() async {
    try {
      final hash = await _nativeChannel.invokeMethod<String>('getSignatureHash');
      return hash ?? '';
    } catch (e) {
      return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📋 تقرير الأمان
// ═══════════════════════════════════════════════════════════
class SecurityReport {
  final bool isSafe;
  final List<String> issues;
  final List<String> warnings;

  const SecurityReport({
    required this.isSafe,
    this.issues = const [],
    this.warnings = const [],
  });

  factory SecurityReport.safe() => const SecurityReport(isSafe: true);

  int get criticalCount => issues.length;
  int get warningCount => warnings.length;
}
