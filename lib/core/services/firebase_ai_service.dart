import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🤖 خدمة الذكاء الاصطناعي — Groq API (مجاني)
/// ✅ يجرب عدة موديلات تلقائياً حتى ينجح أحدها
/// ═══════════════════════════════════════════════════════════
class FirebaseAiService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// ✅ قائمة الموديلات (يجربها بالترتيب حتى ينجح واحد)
  static const List<String> _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-70b-versatile',
    'llama3-70b-8192',
    'llama-3.1-8b-instant',
    'llama3-8b-8192',
    'mixtral-8x7b-32768',
    'gemma2-9b-it',
  ];

  /// ✅ الموديل النشط (يُحفظ بعد نجاحه)
  static String? _activeModel;

  // ═══════════════════════════════════════════════════════════
  // 🎁 نظام التجربة المجانية
  // ═══════════════════════════════════════════════════════════
  static const int _freeAiQuestions = 5;
  static const int _freeCorrections = 3;
  static const String _aiCountKey = 'ai_questions_used';
  static const String _correctionCountKey = 'corrections_used';
  static const String _isPremiumKey = 'is_premium';
  static const String _activeModelKey = 'groq_active_model';

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPremiumKey) ?? false;
  }

  static Future<int> remainingAiQuestions() async {
    if (await isPremium()) return 999999;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_aiCountKey) ?? 0;
    return (_freeAiQuestions - used).clamp(0, _freeAiQuestions);
  }

  static Future<int> remainingCorrections() async {
    if (await isPremium()) return 999999;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_correctionCountKey) ?? 0;
    return (_freeCorrections - used).clamp(0, _freeCorrections);
  }

  static Future<void> _incrementAiCount() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_aiCountKey) ?? 0;
    await prefs.setInt(_aiCountKey, used + 1);
  }

  static Future<void> _incrementCorrectionCount() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_correctionCountKey) ?? 0;
    await prefs.setInt(_correctionCountKey, used + 1);
  }

  static Future<void> activatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, true);
  }

  static Future<void> deactivatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, false);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 اختيار الموديل النشط (مع التبديل التلقائي)
  // ═══════════════════════════════════════════════════════════
  static Future<String> _getActiveModel() async {
    if (_activeModel != null) return _activeModel!;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_activeModelKey);
    if (saved != null && saved.isNotEmpty) {
      _activeModel = saved;
      return saved;
    }
    return _models.first;
  }

  static Future<void> _setActiveModel(String model) async {
    _activeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, model);
    debugPrint('✅ الموديل النشط: $model');
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 إرسال طلب مع تجربة موديلات متعددة
  // ═══════════════════════════════════════════════════════════
  static Future<http.Response?> _sendRequest(
    Map<String, dynamic> body,
    {Duration timeout = const Duration(seconds: 60)}
  ) async {
    // ابدأ بالموديل النشط أولاً
    final active = await _getActiveModel();
    final modelsToTry = [active, ..._models.where((m) => m != active)];

    for (final model in modelsToTry) {
      try {
        body['model'] = model;
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          // نجح! احفظ الموديل
          await _setActiveModel(model);
          return response;
        }

        if (response.statusCode == 404 ||
            response.body.contains('model_not_found') ||
            response.body.contains('does not exist')) {
          debugPrint('⚠️ الموديل $model غير متاح، جرب التالي...');
          continue;
        }

        // خطأ آخر (401, 429, ...)
        return response;
      } catch (e) {
        debugPrint('⚠️ خطأ مع $model: $e');
        continue;
      }
    }

    // فشلت كل الموديلات
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 المساعد الذكي
  // ═══════════════════════════════════════════════════════════
  static Future<String> askQuestion(String question) async {
    if (_apiKey.isEmpty) {
      return '⚠️ مفتاح Groq API غير موجود.';
    }

    if (!await isPremium()) {
      final remaining = await remainingAiQuestions();
      if (remaining <= 0) {
        return '🔒 **انتهت تجربتك المجانية**\n\n'
            'استخدمت 5 أسئلة مجانية.\n\n'
            '💎 **للاشتراك:**\n'
            '• شهرياً: \$2.99\n'
            '• سنوياً: \$19.99\n\n'
            'اذهب إلى الإعدادات ← الاشتراك';
      }
    }

    try {
      final response = await _sendRequest({
        'messages': [
          {
            'role': 'system',
            'content': '''
أنت "المرشد" — مساعد إسلامي ذكي متخصص في:
- القرآن الكريم والتفسير
- الحديث النبوي وعلومه
- الفقه الإسلامي والمذاهب
- العقيدة والتوحيد
- السيرة النبوية
- الأخلاق والتزكية
- التاريخ الإسلامي

قواعد صارمة:
1. أجب فقط عن الأسئلة الدينية الإسلامية.
2. إذا سُئلت عن شيء خارج الدين، اعتذر بلطف.
3. استشهد بالأدلة من القرآن والسنة.
4. اذكر المصادر (اسم السورة ورقم الآية).
5. اتبع منهج أهل السنة والجماعة.
6. اكتب بالعربية الفصحى الواضحة.
'''
          },
          {'role': 'user', 'content': question}
        ],
        'max_tokens': 2000,
        'temperature': 0.7,
      });

      if (response == null) {
        return '⚠️ جميع الموديلات غير متاحة. حاول لاحقاً.';
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'];
        await _incrementAiCount();
        return text?.toString().trim() ?? '⚠️ لا يوجد رد.';
      } else if (response.statusCode == 401) {
        return '⚠️ مفتاح Groq غير صالح.';
      } else if (response.statusCode == 429) {
        return '⚠️ تجاوزت حد الاستخدام. حاول بعد دقيقة.';
      } else {
        debugPrint('❌ Groq ${response.statusCode}: ${response.body}');
        return '⚠️ خطأ ${response.statusCode}.';
      }
    } catch (e) {
      debugPrint('❌ Groq error: $e');
      return '⚠️ تعذر الاتصال: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 تصحيح التلاوة
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    if (_apiKey.isEmpty) {
      return {'accuracy': 0, 'words': [], 'feedback': 'مفتاح Groq غير موجود'};
    }

    if (!await isPremium()) {
      final remaining = await remainingCorrections();
      if (remaining <= 0) {
        return {
          'accuracy': 0,
          'words': [],
          'feedback': '🔒 انتهت تجربتك المجانية.\n💎 اشترك: \$2.99 شهرياً',
        };
      }
    }

    try {
      final prompt = '''
أنت خبير في تصحيح تلاوة القرآن الكريم برواية حفص.

النص الصحيح:
$correctAyah

ما قرأه المستخدم:
$userRecitation

أعد JSON فقط:
{
  "accuracy": 85,
  "words": [
    {"user": "الكلمة", "correct": "الصحيحة", "status": "correct"},
    {"user": "خطأ", "correct": "صواب", "status": "wrong"},
    {"user": "", "correct": "ناقصة", "status": "missing"},
    {"user": "زائدة", "correct": "", "status": "extra"}
  ],
  "feedback": "ملاحظات مختصرة"
}

⚠️ JSON فقط بدون أي نص آخر.
''';

      final response = await _sendRequest({
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2000,
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      });

      if (response == null || response.statusCode != 200) {
        return {
          'accuracy': 0,
          'words': [],
          'feedback': response != null
              ? 'خطأ ${response.statusCode}'
              : 'جميع الموديلات غير متاحة',
        };
      }

      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] ?? '{}';

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
        if (decoded is Map<String, dynamic>) {
          await _incrementCorrectionCount();
          decoded['accuracy'] = decoded['accuracy'] ?? 0;
          decoded['words'] = decoded['words'] ?? [];
          decoded['feedback'] = decoded['feedback'] ?? '';
          return decoded;
        }
      } catch (e) {
        debugPrint('⚠️ فشل JSON: $e');
      }

      return {'accuracy': 0, 'words': [], 'feedback': text};
    } catch (e) {
      debugPrint('❌ Groq error: $e');
      return {'accuracy': 0, 'words': [], 'feedback': 'خطأ: $e'};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 التعرف الديناميكي على الآية
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> identifyAyah(String spokenText) async {
    if (_apiKey.isEmpty || spokenText.trim().isEmpty) return null;

    try {
      final prompt = '''
قرأ المستخدم آية قرآنية، وهذا ما تعرّف عليه النظام من صوته:
"$spokenText"

حدد السورة ورقم الآية. أعد JSON فقط:
{
  "surah": "اسم السورة",
  "surahNumber": 1,
  "ayahNumber": 1,
  "confidence": 95,
  "matchedText": "النص القرآني الصحيح"
}

إذا لم تتعرف: {"surah": null, "confidence": 0}

⚠️ JSON فقط.
''';

      final response = await _sendRequest(
        {
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 500,
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        },
        timeout: const Duration(seconds: 30),
      );

      if (response == null || response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] ?? '{}';

      String cleaned = text.trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic> && decoded['surah'] != null) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('❌ identifyAyah error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 جلب قائمة الموديلات المتاحة (للتشخيص)
  // ═══════════════════════════════════════════════════════════
  static Future<List<String>> fetchAvailableModels() async {
    if (_apiKey.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> models = data['data'] ?? [];
      return models.map((m) => m['id']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      debugPrint('❌ fetchModels error: $e');
      return [];
    }
  }
}
