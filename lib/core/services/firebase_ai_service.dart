import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

/// خدمة الذكاء الاصطناعي — Firebase AI Logic (بدون مفتاح API)
class FirebaseAiService {
  static const String _modelName = 'gemini-flash-latest';

  static GenerativeModel _getModel() {
    return FirebaseAI.googleAI().generativeModel(model: _modelName);
  }

  static Future<String> askQuestion(String prompt) async {
    try {
      final model = _getModel();
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'لا يوجد رد';
    } catch (e) {
      debugPrint('❌ Firebase AI error: $e');
      if (e.toString().contains('UNAUTHENTICATED') ||
          e.toString().contains('permission-denied')) {
        return '⚠️ يرجى تسجيل الدخول أولاً لاستخدام المساعد الذكي.';
      }
      if (e.toString().contains('quota') ||
          e.toString().contains('RESOURCE_EXHAUSTED')) {
        return '⚠️ تجاوزت الحد المسموح. حاول لاحقاً.';
      }
      return '⚠️ تعذر الحصول على رد: $e';
    }
  }

  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    try {
      final prompt = '''
أنت خبير في تصحيح تلاوة القرآن الكريم.

النص الصحيح:
$correctAyah

ما قرأه المستخدم:
$userRecitation

قارن كلمة بكلمة وأعد JSON فقط بهذا الشكل (بدون أي نص إضافي):
{
  "accuracy": 85,
  "words": [
    {"user": "الكلمة_التي_قرأها", "correct": "الكلمة_الصحيحة", "status": "correct"}
  ],
  "feedback": "ملاحظات مختصرة"
}

القواعد:
- status = "correct" للكلمة الصحيحة
- status = "wrong" للكلمة الخاطئة
- status = "missing" للكلمة الناقصة
- status = "extra" للكلمة الزائدة
- accuracy نسبة مئوية 0-100
''';

      final model = _getModel();
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';

      String cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '');
      }
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e) {
        debugPrint('⚠️ فشل JSON: $e');
      }

      return {'accuracy': 0, 'words': [], 'feedback': text};
    } catch (e) {
      debugPrint('❌ Firebase AI error: $e');
      return {'accuracy': 0, 'words': [], 'feedback': 'خطأ: $e'};
    }
  }
}
