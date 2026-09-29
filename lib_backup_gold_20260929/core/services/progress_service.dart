import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 📊 خدمة تتبع التقدم
/// ✅ تتبع دقة كل سورة
/// ✅ سلسلة الأيام المتتابعة
/// ✅ الإنجازات
/// ═══════════════════════════════════════════════════════════

class ProgressService {
  static const String _progressKey = 'user_progress_v1';
  static const String _streakKey = 'user_streak_v1';
  static const String _achievementsKey = 'user_achievements_v1';

  // ═══════════════════════════════════════════════════════════
  // 📊 تتبع التقدم حسب السورة
  // ═══════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// حفظ نتيجة آية
  static Future<void> saveAyahResult({
    required int surahNumber,
    required int ayahNumber,
    required int accuracy,
    required int correctWords,
    required int totalWords,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getProgress();
    final key = '${surahNumber}_${ayahNumber}';
    progress[key] = {
      'surah': surahNumber,
      'ayah': ayahNumber,
      'accuracy': accuracy,
      'correct': correctWords,
      'total': totalWords,
      'lastAttempt': DateTime.now().toIso8601String(),
      'attempts': ((progress[key]?['attempts'] ?? 0) as int) + 1,
    };

    await prefs.setString(_progressKey, jsonEncode(progress));
    await _updateStreak();
    await _checkAchievements(progress);
  }

  /// جلب أفضل نتيجة لآية
  static Future<int> getBestAccuracy(int surahNumber, int ayahNumber) async {
    final progress = await getProgress();
    final key = '${surahNumber}_$ayahNumber';
    return (progress[key]?['accuracy'] as int?) ?? 0;
  }

  /// جلب إحصائيات سورة
  static Future<Map<String, dynamic>> getSurahStats(int surahNumber) async {
    final progress = await getProgress();
    final surahProgress = progress.values
        .where((p) => p['surah'] == surahNumber)
        .toList();

    if (surahProgress.isEmpty) {
      return {'ayahs': 0, 'avgAccuracy': 0};
    }

    final totalAcc = surahProgress
        .map((p) => (p['accuracy'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a + b);

    return {
      'ayahs': surahProgress.length,
      'avgAccuracy': (totalAcc / surahProgress.length).round(),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 سلسلة الأيام المتتابعة
  // ═══════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_streakKey);
    if (raw == null) return {'days': 0, 'lastDate': null};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {'days': 0, 'lastDate': null};
    }
  }

  static Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = await getStreak();
    final today = _today();

    final lastDate = streak['lastDate'] as String?;
    int days = (streak['days'] as int?) ?? 0;

    if (lastDate == today) {
      // نفس اليوم — لا تغيير
      return;
    }

    final yesterday = _yesterday();
    if (lastDate == yesterday) {
      // متتابع
      days++;
    } else {
      // سلسلة جديدة
      days = 1;
    }

    await prefs.setString(
      _streakKey,
      jsonEncode({'days': days, 'lastDate': today}),
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterday() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════
  // 🏆 الإنجازات
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, dynamic>> allAchievements = [
    {'id': 'first_recitation', 'name': '🎯 البداية', 'desc': 'أول تلاوة', 'threshold': 1},
    {'id': 'ten_ayahs', 'name': '📖 نشيط', 'desc': '10 آيات', 'threshold': 10},
    {'id': 'fifty_ayahs', 'name': '🌱 متعلم', 'desc': '50 آية', 'threshold': 50},
    {'id': 'hundred_ayahs', 'name': '📚 دارس', 'desc': '100 آية', 'threshold': 100},
    {'id': 'five_hundred', 'name': '🌟 حافظ صغير', 'desc': '500 آية', 'threshold': 500},
    {'id': 'thousand_ayahs', 'name': '💎 حافظ', 'desc': '1000 آية', 'threshold': 1000},
    {'id': 'streak_7', 'name': '🔥 أسبوع', 'desc': '7 أيام متتابعة', 'threshold': 7},
    {'id': 'streak_30', 'name': '🏆 شهر', 'desc': '30 يوم متتابع', 'threshold': 30},
    {'id': 'streak_100', 'name': '👑 مئة يوم', 'desc': '100 يوم متتابع', 'threshold': 100},
  ];

  static Future<Set<String>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_achievementsKey);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _checkAchievements(Map<String, dynamic> progress) async {
    final unlocked = await getUnlockedAchievements();
    final streak = await getStreak();
    final streakDays = (streak['days'] as int?) ?? 0;
    final totalAyahs = progress.length;

    final newUnlocked = <String>[];

    for (final ach in allAchievements) {
      final id = ach['id'] as String;
      if (unlocked.contains(id)) continue;

      final threshold = ach['threshold'] as int;
      if (id.startsWith('streak_')) {
        if (streakDays >= threshold) newUnlocked.add(id);
      } else {
        if (totalAyahs >= threshold) newUnlocked.add(id);
      }
    }

    if (newUnlocked.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final combined = {...unlocked, ...newUnlocked};
      await prefs.setString(_achievementsKey, jsonEncode(combined.toList()));
      debugPrint('🏆 إنجازات جديدة: $newUnlocked');
    }
  }

  /// إعادة تعيين كل التقدم
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
    await prefs.remove(_streakKey);
    await prefs.remove(_achievementsKey);
  }
}
