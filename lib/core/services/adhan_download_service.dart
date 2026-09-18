import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// ═══════════════════════════════════════════════════════════
/// 🎵 خدمة الأذان — 12 ملف صوتي مضمّن في assets/adhan/raw/
/// ✅ المفاتيح موحّدة مع notification_service.dart
/// ═══════════════════════════════════════════════════════════
class AdhanDownloadService {
  /// ✅ المؤذنون المضمّنون (3 يظهرون دائماً)
  static const Set<String> bundledMuezzins = {
    'adhan_sudais',
    'adhan_yasser',
    'adhan_almuaiqly',
  };

  /// ✅ خريطة الملفات — ID → اسم الملف
  /// ⚠️ المفاتيح تطابق notification_service.muezzins
  static const Map<String, String> adhanFiles = {
    'adhan_sudais': 'adhan_sudais.mp3',
    'adhan_yasser': 'adhan_yasser.mp3',
    'adhan_almuaiqly': 'adhan_almuaiqly.mp3',
    'adhan_alafasy': 'adhan_alafasy.mp3',
    'adhan_abdalbaset': 'adhan_abdalbaset.mp3',
    'adhan_ghamdi': 'adhan_ghamdi.mp3',
    'adhan_shamiree': 'adhan_shamiree.mp3',
    'adhan_makkah': 'adhan_makkah.mp3',
    'adhan_madina': 'adhan_madina.mp3',
    'adhan_alaqsa': 'adhan_alaqsa.mp3',
    'adhan_masr': 'adhan_masr.mp3',
    'adhan_amman': 'adhan_amman.mp3',
  };

  static bool isBundled(String muezzinId) {
    return bundledMuezzins.contains(muezzinId);
  }

  static int get totalCount => adhanFiles.length;
  static int get bundledCount => bundledMuezzins.length;
  static int get downloadableCount => 0;

  /// ✅ المسار الكامل: assets/adhan/raw/xxx.mp3
  static Future<String?> getPlayablePath(String muezzinId) async {
    final fileName = adhanFiles[muezzinId];
    if (fileName == null) {
      debugPrint('⚠️ لا يوجد ملف للمؤذن: $muezzinId');
      return null;
    }

    final assetPath = 'assets/adhan/raw/$fileName';

    try {
      await rootBundle.load(assetPath);
      debugPrint('✅ الأذان متاح: $assetPath');
      return assetPath;
    } catch (e) {
      debugPrint('❌ الأذان غير موجود: $assetPath');
      return null;
    }
  }

  /// ✅ المسار لـ AssetSource (بدون "assets/")
  static Future<String?> getAssetSourcePath(String muezzinId) async {
    final path = await getPlayablePath(muezzinId);
    if (path == null) return null;
    return path.replaceFirst('assets/', '');
  }

  static Future<bool> isAvailable(String muezzinId) async {
    return adhanFiles.containsKey(muezzinId);
  }

  static List<String> get allMuezzinIds => adhanFiles.keys.toList();

  // للتوافق مع الكود القديم
  static Future<int> downloadedCount() async => adhanFiles.length;
  static Future<int> availableCount() async => adhanFiles.length;
  static Future<int> onlyDownloadedCount() async => adhanFiles.length;
  static Future<bool> isDownloaded(String _) async => true;
  static Future<bool> isAllDownloaded() async => true;

  static Future<void> clearAll() async {}
  static Future<void> deleteMuezzin(String _) async {}

  static final Map<String, String> muezzinUrls = {};

  // ═══════════════════════════════════════════════════════════
  // Stub methods — للتوافق مع settings_tab
  // ═══════════════════════════════════════════════════════════

  static Future<bool> downloadMuezzin(
    String muezzinId,
    void Function(double progress) onProgress,
  ) async {
    if (adhanFiles.containsKey(muezzinId)) {
      onProgress(1.0);
      return true;
    }
    onProgress(1.0);
    return false;
  }

  static Future<Map<String, bool>> downloadAll({
    required void Function(String muezzinId, double progress) onMuezzinProgress,
    required void Function(int completed, int total) onOverallProgress,
  }) async {
    final ids = adhanFiles.keys.toList();
    final results = <String, bool>{};
    int completed = 0;
    for (final id in ids) {
      onMuezzinProgress(id, 1.0);
      results[id] = true;
      completed++;
      onOverallProgress(completed, ids.length);
    }
    return results;
  }
}
