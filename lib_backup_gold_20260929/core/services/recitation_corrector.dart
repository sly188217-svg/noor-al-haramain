import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎯 مقارن التلاوة الذكي — يراعي التشكيل
/// ✅ مقارنة مزدوجة (بدون تشكيل + مع تشكيل)
/// ✅ كشف أخطاء التشكيل
/// ✅ Levenshtein Distance للأخطاء البسيطة
/// ✅ عرض تفاصيل دقيقة
/// ═══════════════════════════════════════════════════════════
class RecitationResult {
  final int accuracy;
  final List<Map<String, dynamic>> words;
  final String feedback;
  final Map<String, int> stats;

  RecitationResult({
    required this.accuracy,
    required this.words,
    required this.feedback,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'accuracy': accuracy,
        'words': words,
        'feedback': feedback,
        'stats': stats,
      };
}

class RecitationCorrector {
  // ═══════════════════════════════════════════════════════════
  // 🔤 إزالة التشكيل
  // ═══════════════════════════════════════════════════════════
  static String stripTashkeel(String text) {
    return text
        // حركات قصيرة
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        // ألف خنجرية
        .replaceAll('\u0670', '')
        // تطويل
        .replaceAll('\u0640', '')
        // همزة الوصل
        .replaceAll('\u0671', 'ا')
        .trim();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 تنظيف النص
  // ═══════════════════════════════════════════════════════════
  static String _clean(String text) {
    return text
        .replaceAll(RegExp(r'[،.؛؟!:«»""]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 المقارنة الكاملة مع التشكيل
  // ═══════════════════════════════════════════════════════════
  static RecitationResult compareWithTashkeel({
    required String originalUser,
    required String reconstructedUser,
    required String correctText,
    Map<String, dynamic>? tashkeelResult,
  }) {
    final userWords = _clean(originalUser).split(' ').where((w) => w.isNotEmpty).toList();
    final reconstructedWords =
        _clean(reconstructedUser).split(' ').where((w) => w.isNotEmpty).toList();
    final correctWords =
        _clean(correctText).split(' ').where((w) => w.isNotEmpty).toList();

    final wordsResult = <Map<String, dynamic>>[];
    int correctCount = 0;
    int wrongCount = 0;
    int missingCount = 0;
    int extraCount = 0;
    int tashkeelIssues = 0;

    // ═══════════════════════════════════════════════════════════
    // 📊 مقارنة كلمة بكلمة
    // ═══════════════════════════════════════════════════════════
    for (int i = 0; i < correctWords.length; i++) {
      final correctWord = correctWords[i];
      final correctStripped = stripTashkeel(correctWord);

      final userWord = i < userWords.length ? userWords[i] : '';
      final userStripped = stripTashkeel(userWord);

      final reconstructedWord =
          i < reconstructedWords.length ? reconstructedWords[i] : '';
      final reconstructedStripped = stripTashkeel(reconstructedWord);

      String status;
      String? tashkeelIssue;

      if (userWord.isEmpty) {
        // ⭕ كلمة ناقصة
        status = 'missing';
        missingCount++;
      } else if (userStripped == correctStripped) {
        // ✅ الكلمة صحيحة بدون تشكيل — تحقق من التشكيل
        if (userWord == correctWord) {
          // ✅ مطابقة كاملة (حرف + تشكيل)
          status = 'correct';
          correctCount++;
        } else {
          // ⚠️ نفس الكلمة بدون تشكيل — نتحقق من التشكيل
          // إذا كان AI أضاف تشكيلاً مطابقاً، اعتبرها صحيحة
          if (reconstructedWord.isNotEmpty &&
              reconstructedStripped == correctStripped) {
            // الكلمة نفسها، التشكيل مختلف قليلاً
            // نقارن الحروف الكاملة
            if (reconstructedWord == correctWord) {
              status = 'correct';
              correctCount++;
            } else {
              // تشكيل مختلف — لكن الكلمة صحيحة
              status = 'tashkeel_wrong';
              tashkeelIssue =
                  'الكلمة صحيحة، لكن التشكيل مختلف:\nأنت: $userWord\nالصحيح: $correctWord';
              tashkeelIssues++;
              wrongCount++;
            }
          } else {
            // الكلمة صحيحة بدون تشكيل، ولا يوجد بيانات تشكيل
            status = 'correct';
            correctCount++;
          }
        }
      } else if (_isSimilar(userStripped, correctStripped)) {
        // ⚠️ خطأ بسيط في حرف واحد
        status = 'wrong';
        wrongCount++;
      } else {
        // ❌ كلمة مختلفة تماماً
        status = 'wrong';
        wrongCount++;
      }

      wordsResult.add({
        'user': userWord,
        'correct': correctWord,
        'status': status,
        'tashkeel_issue': tashkeelIssue,
      });
    }

    // كلمات زائدة
    if (userWords.length > correctWords.length) {
      for (int i = correctWords.length; i < userWords.length; i++) {
        extraCount++;
        wordsResult.add({
          'user': userWords[i],
          'correct': '',
          'status': 'extra',
        });
      }
    }

    // ═══════════════════════════════════════════════════════════
    // 📊 حساب الدقة
    // ═══════════════════════════════════════════════════════════
    final total = correctWords.length;
    final accuracy = total > 0 ? (correctCount / total * 100).round() : 0;

    // ═══════════════════════════════════════════════════════════
    // 💬 التقييم
    // ═══════════════════════════════════════════════════════════
    String feedback;
    if (accuracy >= 95 && tashkeelIssues == 0) {
      feedback = '🌟 ما شاء الله! تلاوة ممتازة مع ضبط كامل للتشكيل.';
    } else if (accuracy >= 95 && tashkeelIssues > 0) {
      feedback =
          '⭐ تلاوة ممتازة! لكن راجع التشكيل في $tashkeelIssues كلمة.';
    } else if (accuracy >= 85) {
      feedback = '✅ تلاوة جيدة. راجع الكلمات المميزة بالأحمر.';
    } else if (accuracy >= 70) {
      feedback =
          '👍 تلاوة مقبولة. ركّز على التشكيل والكلمات الملونة.';
    } else if (accuracy >= 50) {
      feedback =
          '⚠️ تحتاج مراجعة. اقرأ ببطء وركّز على كل كلمة مع تشكيلها.';
    } else {
      feedback =
          '❌ تلاوة ضعيفة. استمع للقارئ أولاً، ثم أعد القراءة.';
    }

    // ملاحظة إضافية عن التشكيل
    if (tashkeelIssues > 0) {
      feedback +=
          '\n\n🔤 **ملاحظة التشكيل**: $tashkeelIssues كلمة صحيحة لكن حركاتها مختلفة. '
          'راجع الفتحة (َ) والضمة (ُ) والكسرة (ِ).';
    }

    return RecitationResult(
      accuracy: accuracy,
      words: wordsResult,
      feedback: feedback,
      stats: {
        'correct': correctCount,
        'wrong': wrongCount,
        'missing': missingCount,
        'extra': extraCount,
        'total': total,
        'tashkeel_issues': tashkeelIssues,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 التحقق من تشابه كلمتين
  // ═══════════════════════════════════════════════════════════
  static bool _isSimilar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;

    // يسمح بخطأ واحد لكل 4 حروف (بما فيها 0)
    if (maxLen <= 4) return distance <= 1;
    return distance <= (maxLen / 4).ceil();
  }

  // ═══════════════════════════════════════════════════════════
  // 📐 Levenshtein Distance
  // ═══════════════════════════════════════════════════════════
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    return matrix[a.length][b.length];
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 مقارنة مبسطة (للتوافق مع الكود القديم)
  // ═══════════════════════════════════════════════════════════
  static RecitationResult compare({
    required String userRecitation,
    required String correctAyah,
  }) {
    return compareWithTashkeel(
      originalUser: userRecitation,
      reconstructedUser: userRecitation,
      correctText: correctAyah,
    );
  }
}
