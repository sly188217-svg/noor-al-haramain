import 'tajweed_rules.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎯 مصحح التلاوة مع تصحيح التشكيل بالذكاء الاصطناعي
/// ═══════════════════════════════════════════════════════════

class LetterFeedback {
  final String letter;
  final String status;
  const LetterFeedback({required this.letter, required this.status});
}

class WordFeedback {
  final String userWord;
  final String correctWord;
  final String status;
  final List<LetterFeedback> letters;
  final List<TajweedRule> tajweedRules;
  final String? tashkeelNote; // ملاحظة عن خطأ التشكيل

  const WordFeedback({
    required this.userWord,
    required this.correctWord,
    required this.status,
    this.letters = const [],
    this.tajweedRules = const [],
    this.tashkeelNote,
  });

  Map<String, dynamic> toJson() => {
        'user': userWord,
        'correct': correctWord,
        'status': status,
        'tashkeelNote': tashkeelNote,
      };
}

class RecitationResult {
  final int accuracy;
  final List<WordFeedback> words;
  final String feedback;
  final int totalWords;
  final int correctWords;
  final int wrongWords;
  final int missingWords;
  final int extraWords;

  const RecitationResult({
    required this.accuracy,
    required this.words,
    required this.feedback,
    required this.totalWords,
    required this.correctWords,
    required this.wrongWords,
    required this.missingWords,
    required this.extraWords,
  });

  Map<String, dynamic> toJson() => {
        'accuracy': accuracy,
        'words': words.map((w) => w.toJson()).toList(),
        'feedback': feedback,
        'stats': {
          'total': totalWords,
          'correct': correctWords,
          'wrong': wrongWords,
          'missing': missingWords,
          'extra': extraWords,
        },
      };
}

class RecitationCorrector {
  static const String _tashkeel = 'ًٌٍَُِّْٰٕٓٔ';
  static const String _punctuation = '،.؛:!?()[]{}«»""\'\'`~@#\$%^&*_-+=|/\\<>';

  // ═══════════════════════════════════════════════════════════
  // 🔧 المعالجة الأساسية
  // ═══════════════════════════════════════════════════════════

  static String removeTashkeel(String text) {
    final buffer = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (!_tashkeel.contains(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }

  static bool hasTashkeel(String text) {
    for (final r in text.runes) {
      if (_tashkeel.contains(String.fromCharCode(r))) return true;
    }
    return false;
  }

  static String normalize(String text) {
    var result = removeTashkeel(text);
    result = result
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll('ـ', '');
    return result.trim();
  }

  static String cleanPunctuation(String text) {
    final buffer = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (!_punctuation.contains(ch)) buffer.write(ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _splitWords(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 المقارنة الرئيسية - تفهم التشكيل
  // ═══════════════════════════════════════════════════════════

  /// المقارنة مع التشكيل المُعاد بناؤه
  /// [reconstructedUser] هو نص المستخدم بعد إضافة التشكيل بواسطة AI
  static RecitationResult compareWithTashkeel({
    required String originalUser,
    required String reconstructedUser,
    required String correctText,
    required Map<String, dynamic> tashkeelResult,
  }) {
    // محاذاة الكلمات
    final cleanCorrect = cleanPunctuation(correctText);
    final cleanReconstructed = cleanPunctuation(reconstructedUser);

    final correctWords = _splitWords(cleanCorrect);
    final reconstructedWords = _splitWords(cleanReconstructed);

    // خريطة التشكيل من AI: { "الحمد": "الْحَمْدُ", ... }
    final tashkeelMap = <String, String>{};
    if (tashkeelResult['words'] is Map) {
      (tashkeelResult['words'] as Map).forEach((k, v) {
        tashkeelMap[k.toString()] = v.toString();
      });
    }

    final results = <WordFeedback>[];
    int correctCount = 0;
    int wrongCount = 0;
    int missingCount = 0;
    int extraCount = 0;

    final minLen = correctWords.length < reconstructedWords.length
        ? correctWords.length
        : reconstructedWords.length;

    for (int i = 0; i < minLen; i++) {
      final userWord = reconstructedWords[i];
      final correctWord = correctWords[i];

      // 1. مقارنة بدون تشكيل أولاً
      final uNorm = normalize(userWord);
      final cNorm = normalize(correctWord);

      if (uNorm != cNorm) {
        // كلمة خطأ
        results.add(WordFeedback(
          userWord: userWord,
          correctWord: correctWord,
          status: 'wrong',
          tajweedRules: TajweedRules.detect(correctWord),
        ));
        wrongCount++;
        continue;
      }

      // 2. الكلمات متطابقة بدون تشكيل → فحص التشكيل
      // استخدام النص الأصلي (بدون تشكيل) للبحث في خريطة AI
      final userOriginalWord = i < _splitWords(cleanPunctuation(originalUser)).length
          ? _splitWords(cleanPunctuation(originalUser))[i]
          : '';

      // هل AI أعاد بناء هذه الكلمة؟
      final aiReconstructed = tashkeelMap[userOriginalWord];

      // 3. مقارنة التشكيل
      if (aiReconstructed != null &&
          aiReconstructed.isNotEmpty &&
          aiReconstructed != correctWord) {
        // هناك خطأ في التشكيل
        results.add(WordFeedback(
          userWord: aiReconstructed,
          correctWord: correctWord,
          status: 'wrong',
          tashkeelNote: 'خطأ في التشكيل',
          tajweedRules: TajweedRules.detect(correctWord),
        ));
        wrongCount++;
      } else if (userWord == correctWord) {
        // مطابقة تامة (نادراً ما يحدث من Whisper)
        results.add(WordFeedback(
          userWord: userWord,
          correctWord: correctWord,
          status: 'correct',
          tajweedRules: TajweedRules.detect(correctWord),
        ));
        correctCount++;
      } else {
        // بدون تشكيل لكن صحيح
        results.add(WordFeedback(
          userWord: userWord,
          correctWord: correctWord,
          status: 'correct',
          tajweedRules: TajweedRules.detect(correctWord),
        ));
        correctCount++;
      }
    }

    // كلمات ناقصة
    for (int i = minLen; i < correctWords.length; i++) {
      results.add(WordFeedback(
        userWord: '',
        correctWord: correctWords[i],
        status: 'missing',
        tajweedRules: TajweedRules.detect(correctWords[i]),
      ));
      missingCount++;
    }

    // كلمات زائدة
    for (int i = minLen; i < reconstructedWords.length; i++) {
      results.add(WordFeedback(
        userWord: reconstructedWords[i],
        correctWord: '',
        status: 'extra',
      ));
      extraCount++;
    }

    final total = results.length;
    final accuracy = total > 0 ? ((correctCount / total) * 100).round() : 0;

    return RecitationResult(
      accuracy: accuracy,
      words: results,
      feedback: _buildFeedback(accuracy, correctCount, wrongCount, missingCount, extraCount),
      totalWords: total,
      correctWords: correctCount,
      wrongWords: wrongCount,
      missingWords: missingCount,
      extraWords: extraCount,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 المقارنة بدون تشكيل (احتياطية)
  // ═══════════════════════════════════════════════════════════

  static RecitationResult compare({
    required String userText,
    required String correctText,
  }) {
    final cleanUser = cleanPunctuation(userText);
    final cleanCorrect = cleanPunctuation(correctText);
    final userHasTashkeel = hasTashkeel(cleanUser);

    final userWords = _splitWords(cleanUser);
    final correctWords = _splitWords(cleanCorrect);

    final alignment = _smartAlign(userWords, correctWords, userHasTashkeel);

    final results = <WordFeedback>[];
    int correctCount = 0, wrongCount = 0, missingCount = 0, extraCount = 0;

    for (final pair in alignment) {
      final u = pair.userWord;
      final c = pair.correctWord;

      if (u == null || u.isEmpty) {
        results.add(WordFeedback(
          userWord: '',
          correctWord: c ?? '',
          status: 'missing',
          tajweedRules: c != null ? TajweedRules.detect(c) : [],
        ));
        missingCount++;
        continue;
      }

      if (c == null || c.isEmpty) {
        results.add(WordFeedback(
          userWord: u,
          correctWord: '',
          status: 'extra',
        ));
        extraCount++;
        continue;
      }

      final comparison = _compareWords(u, c, userHasTashkeel);
      results.add(WordFeedback(
        userWord: u,
        correctWord: c,
        status: comparison.status,
        letters: comparison.letters,
        tajweedRules: TajweedRules.detect(c),
      ));

      if (comparison.status == 'correct') {
        correctCount++;
      } else {
        wrongCount++;
      }
    }

    final total = results.length;
    final accuracy = total > 0 ? ((correctCount / total) * 100).round() : 0;

    return RecitationResult(
      accuracy: accuracy,
      words: results,
      feedback: _buildFeedback(accuracy, correctCount, wrongCount, missingCount, extraCount),
      totalWords: total,
      correctWords: correctCount,
      wrongWords: wrongCount,
      missingWords: missingCount,
      extraWords: extraCount,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🧠 المحاذاة الذكية
  // ═══════════════════════════════════════════════════════════

  static List<_WordPair> _smartAlign(
    List<String> userWords,
    List<String> correctWords,
    bool strict,
  ) {
    final result = <_WordPair>[];
    int i = 0, j = 0;
    String norm(String w) => strict ? w : normalize(w);

    while (i < userWords.length || j < correctWords.length) {
      if (i >= userWords.length) {
        result.add(_WordPair(userWord: null, correctWord: correctWords[j]));
        j++;
        continue;
      }
      if (j >= correctWords.length) {
        result.add(_WordPair(userWord: userWords[i], correctWord: null));
        i++;
        continue;
      }

      final uNorm = norm(userWords[i]);
      final cNorm = norm(correctWords[j]);

      if (uNorm == cNorm) {
        result.add(_WordPair(userWord: userWords[i], correctWord: correctWords[j]));
        i++;
        j++;
        continue;
      }

      final uNext = i + 1 < userWords.length ? norm(userWords[i + 1]) : null;
      final cNext = j + 1 < correctWords.length ? norm(correctWords[j + 1]) : null;

      if (uNext != null && uNext == cNorm) {
        result.add(_WordPair(userWord: userWords[i], correctWord: null));
        i++;
        continue;
      }
      if (cNext != null && cNext == uNorm) {
        result.add(_WordPair(userWord: null, correctWord: correctWords[j]));
        j++;
        continue;
      }

      result.add(_WordPair(userWord: userWords[i], correctWord: correctWords[j]));
      i++;
      j++;
    }

    return result;
  }

  static _WordComparison _compareWords(String userWord, String correctWord, bool strict) {
    if (userWord == correctWord) {
      return _WordComparison(
        status: 'correct',
        letters: userWord.split('').map((c) => LetterFeedback(letter: c, status: 'correct')).toList(),
      );
    }

    if (!strict) {
      if (normalize(userWord) == normalize(correctWord)) {
        return _WordComparison(
          status: 'correct',
          letters: correctWord.split('').map((c) => LetterFeedback(letter: c, status: 'correct')).toList(),
        );
      }
    }

    final letters = _compareLetters(
      strict ? userWord : removeTashkeel(userWord),
      strict ? correctWord : removeTashkeel(correctWord),
    );
    return _WordComparison(status: 'wrong', letters: letters);
  }

  static List<LetterFeedback> _compareLetters(String user, String correct) {
    final result = <LetterFeedback>[];
    final maxLen = correct.length > user.length ? correct.length : user.length;

    for (int i = 0; i < maxLen; i++) {
      final u = i < user.length ? user[i] : null;
      final c = i < correct.length ? correct[i] : null;

      if (u == null) {
        result.add(LetterFeedback(letter: c!, status: 'missing'));
      } else if (c == null) {
        result.add(LetterFeedback(letter: u, status: 'extra'));
      } else if (u == c) {
        result.add(LetterFeedback(letter: c, status: 'correct'));
      } else {
        result.add(LetterFeedback(letter: c, status: 'wrong'));
      }
    }
    return result;
  }

  static String _buildFeedback(int accuracy, int correct, int wrong, int missing, int extra) {
    if (accuracy == 100) return '🌟 ممتاز! تلاوة صحيحة تماماً';
    if (accuracy >= 95) return '✅ تلاوة ممتازة — $wrong خطأ';
    if (accuracy >= 90) return '✅ تلاوة جيدة جداً — راجع $wrong كلمة';
    if (accuracy >= 75) {
      final parts = <String>[];
      if (wrong > 0) parts.add('$wrong خطأ');
      if (missing > 0) parts.add('$missing ناقص');
      if (extra > 0) parts.add('$extra زائد');
      return '👍 تلاوة جيدة — ${parts.join("، ")}';
    }
    if (accuracy >= 50) {
      final parts = <String>[];
      if (wrong > 0) parts.add('$wrong خطأ');
      if (missing > 0) parts.add('$missing ناقص');
      if (extra > 0) parts.add('$extra زائد');
      return '⚠️ راجع: ${parts.join("، ")}';
    }
    return '❌ راجع الآية جيداً ثم أعد المحاولة';
  }
}

class _WordPair {
  final String? userWord;
  final String? correctWord;
  const _WordPair({this.userWord, this.correctWord});
}

class _WordComparison {
  final String status;
  final List<LetterFeedback> letters;
  const _WordComparison({required this.status, required this.letters});
}
