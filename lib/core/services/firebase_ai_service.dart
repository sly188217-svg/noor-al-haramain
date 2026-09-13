import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة الذكاء الاصطناعي — Firebase AI Logic
/// ═══════════════════════════════════════════════════════════
class FirebaseAiService {
  static GenerativeModel? _model;
  static bool _initialized = false;

  /// تهيئة النموذج
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
      _model = googleAI.generativeModel(model: 'gemini-2.0-flash');
      _initialized = true;
      debugPrint('✅ Firebase AI Service جاهز');
    } catch (e) {
      debugPrint('❌ فشل تهيئة Firebase AI: $e');
      rethrow;
    }
  }

  /// إرسال نص إلى Gemini
  static Future<String> askQuestion(String prompt) async {
    try {
      await _ensureInitialized();
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? 'لم يتم استلام رد.';
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      return '⚠️ تعذر الحصول على رد: $e';
    }
  }

  /// تحويل صوت إلى نص
  static Future<String> transcribeAudio({
    required File audioFile,
    String language = 'ar',
  }) async {
    try {
      await _ensureInitialized();
      final bytes = await audioFile.readAsBytes();

      final response = await _model!.generateContent([
        Content.multi([
          InlineDataPart('audio/wav', bytes),
          TextPart('قم بنسخ هذا الصوت العربي بدقة. اللغة: $language'),
        ]),
      ]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      return '';
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// ✅ تحليل التلاوة كلمة بكلمة (JSON)
  /// ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    try {
      await _ensureInitialized();

      final prompt = '''
أنت خبير في تصحيح تلاوة القرآن الكريم.

**النص الصحيح (الآية كاملة):**
$correctAyah

**ما قرأه المستخدم:**
$userRecitation

**المطلوب:**
قارن الكلمتين كلمة بكلمة. أعد النتيجة بصيغة JSON فقط، بدون أي نص إضافي أو علامات markdown.

**الصيغة المطلوبة بالضبط:**
{
  "accuracy": 85,
  "words": [
    {"user": "الكلمة_التي_قرأها", "correct": "الكلمة_الصحيحة", "status": "correct"},
    {"user": "الكلمة_الخاطئة", "correct": "الكلمة_الصحيحة", "status": "wrong"}
  ],
  "feedback": "ملاحظة مختصرة"
}

**قواعد مهمة:**
- status = "correct" إذا كانت الكلمة صحيحة 100%
- status = "wrong" إذا كانت الكلمة خاطئة أو مختلفة
- status = "missing" إذا لم يقرأها المستخدم
- status = "extra" إذا قرأ كلمة زائدة
- accuracy = نسبة مئوية (0-100)
- يجب أن تحتوي "words" على كل كلمات الآية بالترتيب

**أعد JSON فقط. ابدأ بـ { وانته بـ }.**
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';

      // تنظيف الاستجابة
      String cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```[a-z]*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
      }
      cleaned = cleaned.trim();

      // استخراج JSON
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        debugPrint('⚠️ فشل تحليل JSON: $e');
      }

      // فشل التحليل — نرجع نتيجة افتراضية
      return {
        'accuracy': 0,
        'words': [],
        'feedback': text,
      };
    } catch (e) {
      debugPrint('❌ خطأ في التحليل: $e');
      return {
        'accuracy': 0,
        'words': [],
        'feedback': 'تعذر التحليل: $e',
      };
    }
  }

  /// التعرف التلقائي على السورة والآية
  static Future<String> detectSurahAndAyah(String recitation) async {
    try {
      await _ensureInitialized();
      final prompt = '''
حدد السورة ورقم الآية لهذا النص:
$recitation

أعد فقط: السورة: [الاسم] | الآية: [الرقم]
''';
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      return '';
    }
  }

  /// اختبار الاتصال
  static Future<bool> testConnection() async {
    try {
      final response = await askQuestion('قل: مرحباً');
      return response.isNotEmpty && !response.startsWith('⚠️');
    } catch (e) {
      return false;
    }
  }

  static void reset() {
    _model = null;
    _initialized = false;
  }
}
