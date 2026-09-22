/// ═══════════════════════════════════════════════════════════
/// 🎯 مصحح التلاوة الصارم
/// ✅ مقارنة محلية (بدون AI)
/// ✅ يكشف: صحيح / خطأ / ناقص / زائد
/// ✅ يهتم بالتشكيل
/// ═══════════════════════════════════════════════════════════

class LetterFeedback {
  final String letter;
  final String status;
  LetterFeedback({required this.letter, required this.status});
}

class WordFeedback {
  final String userWord;
  final String correctWord;
  final String status;
  final List<LetterFeedback> letters;

  WordFeedback({
    required this.userWord,
    required this.correctWord,
    required this.status,
    this.letters = const [],
  });

  Map<String, dynamic> toJson() => {
        'user': userWord,
        'correct': correctWord,
        'status': status,
      };
}

class RecitationResult {
  final int accuracy;
  final List<WordFeedback> words;
  final String feedback;
  RecitationResult({
    required this.accuracy,
    required this.words,
    required this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'accuracy': accuracy,
        'words': words.map((w) => w.toJson()).toList(),
        'feedback': feedback,
      };
}

class RecitationCorrector {
  static const String _tashkeel = 'ًٌٍَُِّْٰٕٓٔ';

  static String removeTashkeel(String text) {
    final buffer = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (!_tashkeel.contains(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }

  static String normalize(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String cleanPunctuation(String text) {
    return text.replaceAll(RegExp(r'[،.؛:!?\(\)\[\]{}«»""'']'), ' ');
  }

  static RecitationResult compare({
    required String userText,
    required String correctText,
  }) {
    final cleanUser = cleanPunctuation(userText).trim();
    final cleanCorrect = cleanPunctuation(correctText).trim();

    final userWords =
        cleanUser.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final correctWords =
        cleanCorrect.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final results = <WordFeedback>[];
    final alignment = _alignWords(userWords, correctWords);

    for (final pair in alignment) {
      final userWord = pair.userWord;
      final correctWord = pair.correctWord;

      if (userWord == null || userWord.isEmpty) {
        results.add(WordFeedback(
          userWord: '',
          correctWord: correctWord ?? '',
          status: 'missing',
        ));
        continue;
      }

      if (correctWord == null || correctWord.isEmpty) {
        results.add(WordFeedback(
          userWord: userWord,
          correctWord: '',
          status: 'extra',
        ));
        continue;
      }

      final comparison = _compareWords(userWord, correctWord);
      results.add(WordFeedback(
        userWord: userWord,
        correctWord: correctWord,
        status: comparison.status,
        letters: comparison.letters,
      ));
    }

    final correctCount = results.where((w) => w.status == 'correct').length;
    final total = results.length;
    final accuracy = total > 0 ? ((correctCount / total) * 100).round() : 0;

    return RecitationResult(
      accuracy: accuracy,
      words: results,
      feedback: _buildFeedback(accuracy, results),
    );
  }

  static List<_WordPair> _alignWords(
    List<String> userWords,
    List<String> correctWords,
  ) {
    final result = <_WordPair>[];
    int i = 0, j = 0;

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

      final uNorm = normalize(removeTashkeel(userWords[i]));
      final cNorm = normalize(removeTashkeel(correctWords[j]));

      if (uNorm == cNorm) {
        result.add(
            _WordPair(userWord: userWords[i], correctWord: correctWords[j]));
        i++;
        j++;
      } else {
        final uNextNorm = i + 1 < userWords.length
            ? normalize(removeTashkeel(userWords[i + 1]))
            : null;
        final cNextNorm = j + 1 < correctWords.length
            ? normalize(removeTashkeel(correctWords[j + 1]))
            : null;

        if (uNextNorm == cNorm) {
          result.add(_WordPair(userWord: userWords[i], correctWord: null));
          i++;
        } else if (cNextNorm == uNorm) {
          result.add(_WordPair(userWord: null, correctWord: correctWords[j]));
          j++;
        } else {
          result.add(
              _WordPair(userWord: userWords[i], correctWord: correctWords[j]));
          i++;
          j++;
        }
      }
    }

    return result;
  }

  static _WordComparison _compareWords(String userWord, String correctWord) {
    if (userWord == correctWord) {
      return _WordComparison(
        status: 'correct',
        letters: userWord
            .split('')
            .map((c) => LetterFeedback(letter: c, status: 'correct'))
            .toList(),
      );
    }

    final userNorm = normalize(userWord);
    final correctNorm = normalize(correctWord);

    if (userNorm == correctNorm) {
      return _WordComparison(
        status: 'wrong',
        letters: correctWord
            .split('')
            .map((c) => LetterFeedback(letter: c, status: 'wrong'))
            .toList(),
      );
    }

    final letters = _compareLetters(userWord, correctWord);
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

  static String _buildFeedback(int accuracy, List<WordFeedback> words) {
    final wrong = words.where((w) => w.status == 'wrong').length;
    final missing = words.where((w) => w.status == 'missing').length;
    final extra = words.where((w) => w.status == 'extra').length;

    if (accuracy == 100) return '🌟 ممتاز! تلاوة صحيحة تماماً';
    if (accuracy >= 90) return '✅ تلاوة جيدة جداً — راجع $wrong خطأ';
    if (accuracy >= 75) return '👍 تلاوة جيدة — $wrong خطأ، $missing ناقص';
    if (accuracy >= 50) {
      return '⚠️ تحتاج مراجعة — $wrong خطأ، $missing ناقص، $extra زائد';
    }
    return '❌ راجع الآية جيداً ثم أعد المحاولة';
  }
}

class _WordPair {
  final String? userWord;
  final String? correctWord;
  _WordPair({this.userWord, this.correctWord});
}

class _WordComparison {
  final String status;
  final List<LetterFeedback> letters;
  _WordComparison({required this.status, required this.letters});
}
