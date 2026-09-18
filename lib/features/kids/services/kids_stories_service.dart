import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 📚 خدمة قصص الأطفال — تحميل من الإنترنت فقط
/// ═══════════════════════════════════════════════════════════
class KidsStoriesService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/sly188217-svg/noor-al-haramain/main/remote_data/kids_stories_full.json';

  static const String _cacheKey = 'kids_stories_full_cache';
  static const String _cacheTimeKey = 'kids_stories_cache_time';

  static List<Map<String, dynamic>>? _cachedStories;
  static List<Map<String, dynamic>>? _cachedCategories;

  static Future<Map<String, dynamic>> loadStories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedStories != null) {
      return {
        'stories': _cachedStories!,
        'categories': _cachedCategories ?? [],
      };
    }

    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        _cachedStories = cached['stories'];
        _cachedCategories = cached['categories'];

        final prefs = await SharedPreferences.getInstance();
        final lastUpdate = prefs.getInt(_cacheTimeKey) ?? 0;
        final daysSince =
            (DateTime.now().millisecondsSinceEpoch - lastUpdate) /
                (1000 * 60 * 60 * 24);
        if (daysSince > 7) {
          _refreshInBackground();
        }

        return {
          'stories': _cachedStories!,
          'categories': _cachedCategories!,
        };
      }
    }

    final data = await _fetchFromInternet();
    return data;
  }

  static Future<Map<String, dynamic>> _fetchFromInternet() async {
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

    await _saveCache(data);

    _cachedStories = stories;
    _cachedCategories = categories;

    debugPrint('✅ تم تحميل ${stories.length} قصة');
    return {'stories': stories, 'categories': categories};
  }

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

  static Future<void> _refreshInBackground() async {
    try {
      final response = await http
          .get(Uri.parse(
              '$_remoteUrl?v=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        await _saveCache(data);
        debugPrint('✅ تحديث خلفي للقصص');
      }
    } catch (e) {}
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
