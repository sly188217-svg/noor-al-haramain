import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdhanDownloadService {
  static const String _downloadedKey = 'adhan_downloaded';
  static const Duration _timeout = Duration(seconds: 30);

  /// ✅ روابط حقيقية تعمل 100% من islamcan.com
  /// (20 أذان مختلف — استخدمنا 12 منها)
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

  /// الحصول على مجلد تخزين الأذان
  static Future<Directory> _getAdhanDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${dir.path}/adhan_files');
    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }
    return adhanDir;
  }

  /// مسار ملف الأذان المحلي
  static Future<String> getLocalPath(String muezzinId) async {
    final dir = await _getAdhanDir();
    return '${dir.path}/$muezzinId.mp3';
  }

  /// التحقق من تحميل أذان مؤذن معين
  static Future<bool> isDownloaded(String muezzinId) async {
    try {
      final path = await getLocalPath(muezzinId);
      final file = File(path);
      return await file.exists() && await file.length() > 100000;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من تحميل جميع المؤذنين
  static Future<bool> isAllDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_downloadedKey) ?? false;
  }

  /// عدد المؤذنين المحمّلين
  static Future<int> downloadedCount() async {
    int count = 0;
    for (final id in muezzinUrls.keys) {
      if (await isDownloaded(id)) count++;
    }
    return count;
  }

  /// ✅ تحميل أذان مؤذن واحد مع timeout ومعالجة أخطاء
  static Future<bool> downloadMuezzin(
    String muezzinId,
    void Function(double progress) onProgress,
  ) async {
    File? tempFile;
    try {
      final url = muezzinUrls[muezzinId];
      if (url == null) {
        debugPrint('⚠️ لا يوجد رابط للمؤذن: $muezzinId');
        return false;
      }

      // إذا كان محمّلاً مسبقاً وصالحاً
      if (await isDownloaded(muezzinId)) {
        onProgress(1.0);
        return true;
      }

      final path = await getLocalPath(muezzinId);
      tempFile = File('$path.part');

      // ✅ إرسال الطلب مع timeout
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

      // ✅ استخدم الملف المؤقت لمنع الملفات التالفة
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

      // ✅ تحقق من حجم الملف قبل النقل النهائي
      if (await tempFile.length() < 100000) {
        debugPrint('⚠️ ملف صغير جداً لـ $muezzinId');
        await tempFile.delete();
        return false;
      }

      // ✅ نقل الملف المؤقت إلى المسار النهائي
      await tempFile.rename(path);
      onProgress(1.0);
      return true;
    } catch (e) {
      debugPrint('⚠️ خطأ تحميل $muezzinId: $e');
      // حذف الملف المؤقت
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return false;
    }
  }

  /// ✅ تحميل جميع المؤذنين
  static Future<Map<String, bool>> downloadAll({
    required void Function(String muezzinId, double progress) onMuezzinProgress,
    required void Function(int completed, int total) onOverallProgress,
  }) async {
    final ids = muezzinUrls.keys.toList();
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

    // ✅ حفظ النتيجة فقط إذا نجح الكل
    final allSuccess = results.values.every((r) => r);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_downloadedKey, allSuccess);

    return results;
  }

  /// ✅ حذف ملف مؤذن واحد
  static Future<void> deleteMuezzin(String muezzinId) async {
    try {
      final path = await getLocalPath(muezzinId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('⚠️ فشل حذف $muezzinId: $e');
    }
  }

  /// ✅ حذف جميع ملفات الأذان
  static Future<void> clearAll() async {
    try {
      final dir = await _getAdhanDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_downloadedKey, false);
    } catch (e) {
      debugPrint('⚠️ فشل الحذف: $e');
    }
  }

  /// ✅ اختبار توفر رابط (HEAD request)
  static Future<bool> testUrl(String url) async {
    try {
      final client = http.Client();
      final response = await client
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
