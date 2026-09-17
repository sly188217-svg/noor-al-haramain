import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// ═══════════════════════════════════════════════════════════
/// 🎵 خدمة الأذان — 12 ملف صوتي مضمّن في assets/adhan/raw/
/// ✅ جميع الأصوات حقيقية وتعمل 100% بدون إنترنت
/// ═══════════════════════════════════════════════════════════
class AdhanDownloadService {
  /// ✅ المؤذنون المضمّنون (3 يظهرون دائماً)
  static const Set<String> bundledMuezzins = {
    'marwan',
    'yasser',
    'salah_budair',
  };

  /// ✅ خريطة الملفات — ID → اسم الملف داخل assets/adhan/raw/
  static const Map<String, String> adhanFiles = {
    // المضمّنون (3)
    'marwan': 'adhan_sudais.mp3',
    'yasser': 'adhan_yasser.mp3',
    'salah_budair': 'adhan_almuaiqly.mp3',
    // القابلون للتحميل (9) — لكنها مضمّنة فعلياً
    'afasy': 'adhan_alafasy.mp3',
    'abdalbaset': 'adhan_abdalbaset.mp3',
    'ghamdi': 'adhan_ghamdi.mp3',
    'shamiree': 'adhan_shamiree.mp3',
    'makkah': 'adhan_makkah.mp3',
    'madina': 'adhan_madina.mp3',
    'alaqsa': 'adhan_alaqsa.mp3',
    'masr': 'adhan_masr.mp3',
    'amman': 'adhan_amman.mp3',
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
}
