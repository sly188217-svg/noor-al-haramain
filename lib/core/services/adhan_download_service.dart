import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة تحميل الأذان
/// ═══════════════════════════════════════════════════════════
/// 
/// 📦 3 مؤذنين مضمّنين في التطبيق (يعملون بدون إنترنت):
///    - محمد مروان القصاص (marwan)
///    - ياسر القطامي (yasser)
///    - صلاح البدير (salah_budair)
/// 
/// 📥 9 مؤذنين يُحمّلون من الإنترنت عند الطلب
/// 
class AdhanDownloadService {
  static const String _downloadedKey = 'adhan_downloaded';
  static const Duration _timeout = Duration(seconds: 60);

  /// ✅ المؤذنون المضمّنون في التطبيق (bundled)
  static const Set<String> bundledMuezzins = {
    'marwan',
    'yasser',
    'salah_budair',
  };

  /// ✅ روابط التحميل للمؤذنين (islamcan.com)
  static final Map<String, String> muezzinUrls = {
    'marwan': 'https://www.islamcan.com/audio/adhan/azan1.mp3',
    'yasser': 'https://www.islamcan.com/audio/adhan/azan2.mp3',
    'afasy': 'https://www.islamcan.com/audio/adhan/azan3.mp3',
    'sudais': 'https://www.islamcan.com/audio/adhan/azan4.mp3',
    'ali_jaber': 'https://www.islamcan.com/audio/adhan/azan5.mp3',
    'ahmad_hajjim': 'https://www.islamcan.com/audio/adhan/azan6.mp3',
    'basir_dosari': 'https://www.islamcan.com/audio/adhan/azan7.mp3',
    'abdullah_juhani': 'https://www.islamcan.com/audio/adhan/azan8.mp3',
    'abdullah_busfar': 'https://www.islamcan.com/audio/adhan/azan9.mp3',
    'khalid_qahdani': 'https://www.islamcan.com/audio/adhan/azan10.mp3',
    'salah_budair': 'https://www.islamcan.com/audio/adhan/azan11.mp3',
    'husary': 'https://www.islamcan.com/audio/adhan/azan12.mp3',
  };

  /// ═══════════════════════════════════════════════════════════
  /// هل المؤذن مضمّن في التطبيق؟
  /// ═══════════════════════════════════════════════════════════
  static bool isBundled(String muezzinId) {
    return bundledMuezzins.contains(muezzinId);
  }

  /// ═══════════════════════════════════════════════════════════
  /// الحصول على مجلد تخزين الأذان المُحمَّل
  /// ═══════════════════════════════════════════════════════════
  static Future<Directory> _getAdhanDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${dir.path}/adhan_files');
    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }
    return adhanDir;
  }

  /// ═══════════════════════════════════════════════════════════
  /// مسار ملف الأذان المحلي (للمُحمَّل)
  /// ═══════════════════════════════════════════════════════════
  static Future<String> getLocalPath(String muezzinId) async {
    final dir = await _getAdhanDir();
    return '${dir.path}/$muezzinId.mp3';
  }

  /// ═══════════════════════════════════════════════════════════
  /// مسار الأذان المضمّن في assets
  /// ═══════════════════════════════════════════════════════════
  static String getBundledAssetPath(String muezzinId) {
    return 'assets/adhan/$muezzinId/adhan.mp3';
  }

  /// ═══════════════════════════════════════════════════════════
  /// الحصول على المسار النهائي للأذان:
  /// 1. إذا مضمّن → asset path
  /// 2. إذا مُحمّل → local file path
  /// 3. إذا لا → null
  /// ═══════════════════════════════════════════════════════════
  static Future<String?> getAdhanPath(String muezzinId) async {
    // 1. مضمّن؟
    if (isBundled(muezzinId)) {
      return getBundledAssetPath(muezzinId);
    }
    // 2. مُحمّل؟
    if (await isDownloaded(muezzinId)) {
      return await getLocalPath(muezzinId);
    }
    // 3. لا يوجد
    return null;
  }

  /// ═══════════════════════════════════════════════════════════
  /// التحقق من تحميل أذان مؤذن معين
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> isDownloaded(String muezzinId) async {
    try {
      final path = await getLocalPath(muezzinId);
      final file = File(path);
      return await file.exists() && await file.length() > 100000;
    } catch (e) {
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// التحقق من توفر الأذان (مضمّن أو مُحمّل)
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> isAvailable(String muezzinId) async {
    if (isBundled(muezzinId)) return true;
    return await isDownloaded(muezzinId);
  }

  /// ═══════════════════════════════════════════════════════════
  /// ✅ عدد المؤذنين المُحمَّلين (متوافق مع الكود القديم)
  /// يُرجع عدد المؤذنين المتاحين (مضمّن + محمّل)
  /// ═══════════════════════════════════════════════════════════
  static Future<int> downloadedCount() async {
    return await availableCount();
  }

  /// ═══════════════════════════════════════════════════════════
  /// عدد المؤذنين المتاحين (مضمّن + محمّل)
  /// ═══════════════════════════════════════════════════════════
  static Future<int> availableCount() async {
    // المؤذنون المضمّنون دائماً متاحون
    int count = bundledMuezzins.length;

    // المؤذنون المُحمَّلون
    for (final id in muezzinUrls.keys) {
      if (isBundled(id)) continue;
      if (await isDownloaded(id)) count++;
    }
    return count;
  }

  /// ═══════════════════════════════════════════════════════════
  /// عدد المؤذنين المُحمَّلين فقط (بدون المضمّنين)
  /// ═══════════════════════════════════════════════════════════
  static Future<int> onlyDownloadedCount() async {
    int count = 0;
    for (final id in muezzinUrls.keys) {
      if (isBundled(id)) continue;
      if (await isDownloaded(id)) count++;
    }
    return count;
  }

  /// ═══════════════════════════════════════════════════════════
  /// عدد المؤذنين القابلين للتحميل (غير المضمّنين)
  /// ═══════════════════════════════════════════════════════════
  static int get downloadableCount {
    return muezzinUrls.keys.where((id) => !isBundled(id)).length;
  }

  /// ═══════════════════════════════════════════════════════════
  /// تحميل أذان مؤذن واحد
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> downloadMuezzin(
    String muezzinId,
    void Function(double progress) onProgress,
  ) async {
    File? tempFile;
    try {
      // إذا مضمّن → لا يحتاج تحميل
      if (isBundled(muezzinId)) {
        onProgress(1.0);
        return true;
      }

      final url = muezzinUrls[muezzinId];
      if (url == null) {
        debugPrint('⚠️ لا يوجد رابط للمؤذن: $muezzinId');
        return false;
      }

      // إذا محمّل مسبقاً
      if (await isDownloaded(muezzinId)) {
        onProgress(1.0);
        return true;
      }

      final path = await getLocalPath(muezzinId);
      tempFile = File('$path.part');

      final request = http.Request('GET', Uri.parse(url));
      final client = http.Client();

      final response = await client.send(request).timeout(
        _timeout,
        onTimeout: () {
          client.close();
          throw TimeoutException('انتهت مهلة التحميل');
        },
      );

      if (response.statusCode != 200) {
        debugPrint('⚠️ فشل تحميل $muezzinId: HTTP ${response.statusCode}');
        client.close();
        return false;
      }

      final sink = tempFile.openWrite();
      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      await for (final chunk in response.stream.timeout(_timeout)) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      if (await tempFile.length() < 100000) {
        debugPrint('⚠️ ملف صغير جداً: $muezzinId');
        await tempFile.delete();
        return false;
      }

      await tempFile.rename(path);
      onProgress(1.0);
      debugPrint('✅ تم تحميل: $muezzinId');
      return true;
    } catch (e) {
      debugPrint('❌ خطأ تحميل $muezzinId: $e');
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// تحميل جميع المؤذنين (9 فقط — المضمّنون يُتخطّون)
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, bool>> downloadAll({
    required void Function(String muezzinId, double progress) onMuezzinProgress,
    required void Function(int completed, int total) onOverallProgress,
  }) async {
    // فقط المؤذنون غير المضمّنين
    final ids = muezzinUrls.keys.where((id) => !isBundled(id)).toList();

    final results = <String, bool>{};
    int completed = 0;

    for (final id in ids) {
      final success = await downloadMuezzin(id, (progress) {
        onMuezzinProgress(id, progress);
      });
      results[id] = success;
      completed++;
      onOverallProgress(completed, ids.length);
    }

    final allSuccess = results.values.every((r) => r);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_downloadedKey, allSuccess);

    return results;
  }

  /// ═══════════════════════════════════════════════════════════
  /// حذف أذان مؤذن (غير مضمّن)
  /// ═══════════════════════════════════════════════════════════
  static Future<void> deleteMuezzin(String muezzinId) async {
    if (isBundled(muezzinId)) return;
    try {
      final path = await getLocalPath(muezzinId);
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ فشل حذف $muezzinId: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// حذف جميع الملفات المُحمَّلة (لا يحذف المضمّن)
  /// ═══════════════════════════════════════════════════════════
  static Future<void> clearAll() async {
    try {
      final dir = await _getAdhanDir();
      if (await dir.exists()) await dir.delete(recursive: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_downloadedKey, false);
    } catch (e) {
      debugPrint('⚠️ فشل الحذف: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// التحقق من تحميل جميع المؤذنين
  /// ═══════════════════════════════════════════════════════════
  static Future<bool> isAllDownloaded() async {
    for (final id in muezzinUrls.keys) {
      if (isBundled(id)) continue;
      if (!await isDownloaded(id)) return false;
    }
    return true;
  }
}
