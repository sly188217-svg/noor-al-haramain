/// ═══════════════════════════════════════════════════════════
/// 📚 قواعد التجويد - كشف تلقائي
/// ═══════════════════════════════════════════════════════════
class TajweedRule {
  final String name;
  final String description;
  final String color;
  TajweedRule({
    required this.name,
    required this.description,
    required this.color,
  });
}

class TajweedRules {
  /// الأحرف التي تُظهر الغنة (ن، م مع شدة)
  static const String _ghunnahLetters = 'نم';

  /// أحرف الإخفاء (15 حرفاً)
  static const String _ikhfaLetters = 'صذثكجشقسزدطزفتضظ';

  /// أحرف الإدغام
  static const String _idghamLetters = 'يرملون';

  /// أحرف الإقلاب
  static const String _iqlabLetters = 'ب';

  /// أحرف القلقلة
  static const String _qalqalahLetters = 'قطبجد';

  /// ═══════════════════════════════════════════════════════
  /// كشف قواعد التجويد في كلمة
  /// ═══════════════════════════════════════════════════════
  static List<TajweedRule> detect(String word) {
    final rules = <TajweedRule>[];

    // 🔵 غنة - إذا وُجد ن أو م مع شدة
    if (word.contains('ّ')) {
      for (final letter in _ghunnahLetters.split('')) {
        if (word.contains('$letterّ')) {
          rules.add(TajweedRule(
            name: 'غُنّة',
            description: 'أظهر الغنة بمقدار حركتين',
            color: '#4CAF50',
          ));
          break;
        }
      }
    }

    // 🔵 إقلاب - ن ساكنة أو تنوين يتبعها ب
    if (RegExp('نْ|ً|ٍ|ٌ').hasMatch(word) && _iqlabLetters.contains(word[word.length - 1])) {
      rules.add(TajweedRule(
        name: 'إقلاب',
        description: 'اقلب النون ميماً مخفاة',
        color: '#2196F3',
      ));
    }

    // 🔵 إخفاء - ن ساكنة أو تنوين + حرف إخفاء
    for (final letter in _ikhfaLetters.split('')) {
      if (word.contains('نْ$letter') || word.contains('$letterً') || word.contains('$letterٍ') || word.contains('$letterٌ')) {
        rules.add(TajweedRule(
          name: 'إخفاء',
          description: 'أخفِ النون مع الغنة حركتين',
          color: '#9C27B0',
        ));
        break;
      }
    }

    // 🔵 إدغام - ن ساكنة أو تنوين + حرف إدغام
    for (final letter in _idghamLetters.split('')) {
      if (word.contains('نْ$letter') || word.contains('$letterً') || word.contains('$letterٍ') || word.contains('$letterٌ')) {
        rules.add(TajweedRule(
          name: 'إدغام',
          description: 'أدغم النون في الحرف التالي',
          color: '#FF9800',
        ));
        break;
      }
    }

    // 🔵 قلقلة - حرف قلقلة ساكن
    for (final letter in _qalqalahLetters.split('')) {
      if (word.contains('$letterْ') || word.endsWith(letter)) {
        rules.add(TajweedRule(
          name: 'قلقلة',
          description: 'أظهر القلقلة عند النطق',
          color: '#F44336',
        ));
        break;
      }
    }

    // 🔵 مد طبيعي - ا، و، ي بعد حركة مناسبة
    if (word.contains('َا') || word.contains('ُو') || word.contains('ِي')) {
      rules.add(TajweedRule(
        name: 'مد طبيعي',
        description: 'مدّ بمقدار حركتين',
        color: '#00BCD4',
      ));
    }

    return rules;
  }
}
