import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 📚 خدمة قصص الأطفال — تحميل من Assets المحلية
/// ✅ 50 قصة في 6 تصنيفات
/// ✅ Cache في SharedPreferences
/// ✅ تحديث خلفي اختياري (اختياري)
/// ═══════════════════════════════════════════════════════════
class KidsStoriesService {
  /// 📁 مسار الملف المحلي (الأساسي)
  static const String _localAsset = 'assets/data/kids_stories.json';

  /// 🌐 رابط احتياطي (إن أردت التحديث عن بعد)
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/sly188217-svg/noor-al-haramain/main/assets/data/kids_stories.json';

  static const String _cacheKey = 'kids_stories_full_cache_v2';
  static const String _cacheTimeKey = 'kids_stories_cache_time_v2';

  static List<Map<String, dynamic>>? _cachedStories;
  static List<Map<String, dynamic>>? _cachedCategories;

  // ═══════════════════════════════════════════════════════════
  // 📥 تحميل القصص
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> loadStories({
    bool forceRefresh = false,
  }) async {
    // 1️⃣ من الذاكرة
    if (!forceRefresh && _cachedStories != null) {
      return {
        'stories': _cachedStories!,
        'categories': _cachedCategories ?? [],
      };
    }

    // 2️⃣ من Cache (SharedPreferences)
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        _cachedStories = cached['stories'];
        _cachedCategories = cached['categories'];
        return cached;
      }
    }

    // 3️⃣ من Assets المحلية (الأساسي)
    try {
      final data = await _loadFromAssets();
      await _saveCache(data);
      _cachedStories = data['stories'];
      _cachedCategories = data['categories'];
      return data;
    } catch (e) {
      debugPrint('⚠️ فشل تحميل من Assets: $e');
    }

    // 4️⃣ من الإنترنت (احتياطي)
    try {
      final data = await _loadFromInternet();
      await _saveCache(data);
      _cachedStories = data['stories'];
      _cachedCategories = data['categories'];
      return data;
    } catch (e) {
      debugPrint('⚠️ فشل تحميل من الإنترنت: $e');
    }

    // 5️⃣ فشل — إرجاع قائمة فارغة
    return {'stories': [], 'categories': []};
  }

  // ═══════════════════════════════════════════════════════════
  // 📁 تحميل من Assets المحلية
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> _loadFromAssets() async {
    debugPrint('📁 تحميل القصص من Assets المحلية...');

    final raw = await rootBundle.loadString(_localAsset);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final stories = List<Map<String, dynamic>>.from(
      (data['stories'] as List).map((s) => Map<String, dynamic>.from(s)),
    );
    final categories = List<Map<String, dynamic>>.from(
      (data['categories'] as List).map((c) => Map<String, dynamic>.from(c)),
    );

    debugPrint('✅ تم تحميل ${stories.length} قصة من Assets');
    return {'stories': stories, 'categories': categories};
  }

  // ═══════════════════════════════════════════════════════════
  // 🌐 تحميل من الإنترنت (احتياطي فقط)
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> _loadFromInternet() async {
    debugPrint('🌐 تحميل القصص من الإنترنت...');

    final response = await http
        .get(Uri.parse(
            '$_remoteUrl?v=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    final stories = List<Map<String, dynamic>>.from(
      (data['stories'] as List).map((s) => Map<String, dynamic>.from(s)),
    );
    final categories = List<Map<String, dynamic>>.from(
      (data['categories'] as List).map((c) => Map<String, dynamic>.from(c)),
    );

    debugPrint('✅ تم تحميل ${stories.length} قصة من الإنترنت');
    return {'stories': stories, 'categories': categories};
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Cache
  // ═══════════════════════════════════════════════════════════
  static Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('⚠️ فشل حفظ cache: $e');
    }
  }

  static Future<Map<String, dynamic>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final data = jsonDecode(cached);
      return {
        'stories': List<Map<String, dynamic>>.from(
          (data['stories'] as List).map((s) => Map<String, dynamic>.from(s)),
        ),
        'categories': List<Map<String, dynamic>>.from(
          (data['categories'] as List)
              .map((c) => Map<String, dynamic>.from(c)),
        ),
      };
    } catch (e) {
      debugPrint('⚠️ فشل قراءة cache: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    _cachedStories = null;
    _cachedCategories = null;
  }

  static Future<DateTime?> getLastUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTimeKey);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }
}
