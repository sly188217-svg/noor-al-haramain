import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// 🧠 وضع الحفظ (Hifz Mode)
/// يخفي الكلمات تدريجياً لاختبار الحفظ
/// ═══════════════════════════════════════════════════════════

class HifzMode {
  /// إخفاء الكلمات حسب المستوى
  /// Level 1: إظهار كل شيء (100%)
  /// Level 2: إخفاء 25% من الكلمات
  /// Level 3: إخفاء 50%
  /// Level 4: إخفاء 75%
  /// Level 5: إخفاء كل شيء (التسميع الكامل)
  static List<bool> generateHiddenMask(int wordCount, int level, int seed) {
    if (level <= 1) return List.filled(wordCount, false);
    if (level >= 5) return List.filled(wordCount, true);

    final hideRatio = level == 2
        ? 0.25
        : level == 3
            ? 0.5
            : 0.75;

    final hideCount = (wordCount * hideRatio).round();
    final rng = math.Random(seed);
    final indices = List<int>.generate(wordCount, (i) => i);
    indices.shuffle(rng);

    final hidden = List.filled(wordCount, false);
    for (int i = 0; i < hideCount && i < indices.length; i++) {
      hidden[indices[i]] = true;
    }
    return hidden;
  }

  /// أسماء المستويات
  static const List<Map<String, String>> levels = [
    {'name': 'المستوى 1', 'desc': 'كل الكلمات ظاهرة', 'icon': '👁️'},
    {'name': 'المستوى 2', 'desc': 'إخفاء 25%', 'icon': '🟢'},
    {'name': 'المستوى 3', 'desc': 'إخفاء 50%', 'icon': '🟡'},
    {'name': 'المستوى 4', 'desc': 'إخفاء 75%', 'icon': '🟠'},
    {'name': 'المستوى 5', 'desc': 'تسميع كامل', 'icon': '🔴'},
  ];

  /// عرض الكلمة المخفية
  static String getMaskedWord(String word) {
    // كل حرف → خط سفلي
    return word
        .split('')
        .map((c) => c.trim().isEmpty ? ' ' : '_')
        .join('');
  }
}
