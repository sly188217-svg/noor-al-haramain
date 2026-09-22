import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎨 تلوين أحكام التجويد تلقائياً
/// ═══════════════════════════════════════════════════════════

class TajweedSpan {
  final String text;
  final TajweedType type;
  const TajweedSpan(this.text, this.type);
}

enum TajweedType {
  normal,
  ghunnah,      // غنة
  ikhfa,        // إخفاء
  idgham,       // إدغام
  iqlab,        // إقلاب
  qalqalah,     // قلقلة
  maddTabeei,   // مد طبيعي
  maddFar3i,    // مد فرعي
  lamShamsiya,  // لام شمسية
  lamQamariya,  // لام قمرية
}

class TajweedColorer {
  /// ألوان الأحكام
  static const Map<TajweedType, Color> colors = {
    TajweedType.normal: Color(0xFF1A1A1A),
    TajweedType.ghunnah: Color(0xFF4CAF50),      // أخضر
    TajweedType.ikhfa: Color(0xFF9C27B0),        // بنفسجي
    TajweedType.idgham: Color(0xFFFF9800),       // برتقالي
    TajweedType.iqlab: Color(0xFF2196F3),        // أزرق
    TajweedType.qalqalah: Color(0xFFF44336),     // أحمر
    TajweedType.maddTabeei: Color(0xFF00BCD4),   // سماوي
    TajweedType.maddFar3i: Color(0xFF3F51B5),    // أزرق غامق
    TajweedType.lamShamsiya: Color(0xFF795548),  // بني
    TajweedType.lamQamariya: Color(0xFF607D8B),  // رمادي مزرق
  };

  /// أسماء الأحكام
  static const Map<TajweedType, String> names = {
    TajweedType.normal: 'عادي',
    TajweedType.ghunnah: 'غنة',
    TajweedType.ikhfa: 'إخفاء',
    TajweedType.idgham: 'إدغام',
    TajweedType.iqlab: 'إقلاب',
    TajweedType.qalqalah: 'قلقلة',
    TajweedType.maddTabeei: 'مد طبيعي',
    TajweedType.maddFar3i: 'مد فرعي',
    TajweedType.lamShamsiya: 'لام شمسية',
    TajweedType.lamQamariya: 'لام قمرية',
  };

  /// تحليل كلمة إلى spans ملونة
  static List<TajweedSpan> colorize(String word) {
    final spans = <TajweedSpan>[];
    final runes = word.runes.toList();
    final chars = runes.map((r) => String.fromCharCode(r)).toList();

    int i = 0;
    final currentBuffer = StringBuffer();
    TajweedType currentType = TajweedType.normal;

    void flush() {
      if (currentBuffer.isNotEmpty) {
        spans.add(TajweedSpan(currentBuffer.toString(), currentType));
        currentBuffer.clear();
      }
    }

    while (i < chars.length) {
      final ch = chars[i];
      final next = i + 1 < chars.length ? chars[i + 1] : '';

      TajweedType detected = TajweedType.normal;

      // 🔵 غنة: ن أو م مع شدة
      if ((ch == 'ن' || ch == 'م') && next == 'ّ') {
        detected = TajweedType.ghunnah;
      }
      // 🔵 قلقلة: ق ط ب ج د ساكنة
      else if ('قطبجد'.contains(ch) && next == 'ْ') {
        detected = TajweedType.qalqalah;
      }
      // 🔵 إقلاب: ن ساكنة + ب
      else if (ch == 'ن' && next == 'ْ' &&
          i + 2 < chars.length && chars[i + 2] == 'ب') {
        detected = TajweedType.iqlab;
      }
      // 🔵 إخفاء: ن ساكنة + حروف الإخفاء
      else if (ch == 'ن' && next == 'ْ' &&
          i + 2 < chars.length &&
          'صذثكجشقسزدطزفتضظ'.contains(chars[i + 2])) {
        detected = TajweedType.ikhfa;
      }
      // 🔵 إدغام: ن ساكنة + حروف الإدغام
      else if (ch == 'ن' && next == 'ْ' &&
          i + 2 < chars.length &&
          'يرملون'.contains(chars[i + 2])) {
        detected = TajweedType.idgham;
      }
      // 🔵 مد طبيعي: ا و ي بعد حركة
      else if ((ch == 'ا' || ch == 'و' || ch == 'ي') &&
          i > 0 &&
          'َُِ'.contains(chars[i - 1])) {
        detected = TajweedType.maddTabeei;
      }

      if (detected != currentType) {
        flush();
        currentType = detected;
      }

      currentBuffer.write(ch);
      i++;
    }
    flush();

    return spans;
  }

  /// تحليل نص كامل (كلمات متعددة)
  static List<TajweedSpan> colorizeText(String text) {
    final words = text.split(RegExp(r'\s+'));
    final all = <TajweedSpan>[];
    for (int i = 0; i < words.length; i++) {
      all.addAll(colorize(words[i]));
      if (i < words.length - 1) {
        all.add(const TajweedSpan(' ', TajweedType.normal));
      }
    }
    return all;
  }
}
