import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// ═══════════════════════════════════════════════════════════
/// خدمة الذكاء الاصطناعي — Gemini REST API مباشرة
/// ═══════════════════════════════════════════════════════════
class FirebaseAiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> askQuestion(String prompt) async {
    if (_apiKey.isEmpty) {
      return '⚠️ مفتاح Gemini API غير موجود.\n\n'
          'اذهب إلى: الإعدادات ← الذكاء الاصطناعي ← أضف المفتاح';
    }

    try {
      final url = 'https://generativelanguage.googleapis.com/'
          'v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Gemini HTTP ${response.statusCode}: ${response.body}');
        return '⚠️ خطأ ${response.statusCode} — تحقق من مفتاح API';
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      return text?.toString() ?? 'لا يوجد رد';
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return '⚠️ تعذر الحصول على رد: $e';
    }
  }

  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    if (_apiKey.isEmpty) {
      return {
        'accuracy': 0,
        'words': [],
        'feedback': 'مفتاح Gemini API غير موجود',
      };
    }

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

      final url = 'https://generativelanguage.googleapis.com/'
          'v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return {
          'accuracy': 0,
          'words': [],
          'feedback': 'خطأ ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';

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

      return {
        'accuracy': 0,
        'words': [],
        'feedback': text,
      };
    } catch (e) {
      return {
        'accuracy': 0,
        'words': [],
        'feedback': 'خطأ: $e',
      };
    }
  }
}
