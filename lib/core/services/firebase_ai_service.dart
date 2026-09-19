import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🤖 خدمة الذكاء الاصطناعي — Groq API (مجاني)
/// ✅ يستخدم Firestore للعدادات (لا يمكن التلاعب)
/// ✅ يقرأ التشكيل والحركات
/// ═══════════════════════════════════════════════════════════
class FirebaseAiService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static const List<String> _models = [
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'qwen/qwen3.8-27b',
    'allam-2-7b',
    'groq/compound',
    'groq/compound-mini',
  ];

  static String? _activeModel;
  static const String _activeModelKey = 'groq_active_model';

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

  static Future<http.Response?> _sendRequest(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
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
          await _setActiveModel(model);
          return response;
        }

        if (response.statusCode == 404 ||
            response.body.contains('model_not_found') ||
            response.body.contains('does not exist')) {
          continue;
        }

        return response;
      } catch (e) {
        debugPrint('⚠️ خطأ مع $model: $e');
        continue;
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 المساعد الذكي
  // ═══════════════════════════════════════════════════════════
  static Future<String> askQuestion(String question) async {
    if (_apiKey.isEmpty) {
      return '⚠️ مفتاح Groq API غير موجود.';
    }

    if (!await UsageService.isPremium()) {
      final remaining = await UsageService.remainingChats();
      if (remaining <= 0) {
        return '🔒 **انتهت تجربتك المجانية لليوم**\n\n'
            '⏰ يتجدد تلقائياً غداً\n\n'
            '💎 **للاشتراك الفوري:**\n'
            '• شهرياً: \$2.99\n'
            '• سنوياً: \$19.99';
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
        await UsageService.incrementChat();
        return text?.toString().trim() ?? '⚠️ لا يوجد رد.';
      } else if (response.statusCode == 401) {
        return '⚠️ مفتاح Groq غير صالح.';
      } else if (response.statusCode == 429) {
        return '⚠️ تجاوزت حد الاستخدام. حاول بعد دقيقة.';
      } else {
        return '⚠️ خطأ ${response.statusCode}.';
      }
    } catch (e) {
      return '⚠️ تعذر الاتصال: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 تصحيح التلاوة — مع قراءة الحركات
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    if (_apiKey.isEmpty) {
      return {'accuracy': 0, 'words': [], 'feedback': 'مفتاح Groq غير موجود'};
    }

    if (!await UsageService.isPremium()) {
      final remaining = await UsageService.remainingRecitations();
      if (remaining <= 0) {
        return {
          'accuracy': 0,
          'words': [],
          'feedback': '🔒 انتهت تجربتك المجانية لليوم.\n⏰ يتجدد غداً',
        };
      }
    }

    try {
      final prompt = '''
أنت خبير في تصحيح تلاوة القرآن الكريم برواية حفص عن عاصم.

النص الصحيح (بالرسم العثماني مع التشكيل الكامل):
$correctAyah

ما قرأه المستخدم:
$userRecitation

⚠️ مهم جداً:
- قارن **مع التشكيل** (الحركات: فتحة، ضمة، كسرة، سكون، شدة، مد، تنوين)
- إذا أخطأ في الحركة، اعتبره "wrong"
- أعد النص الصحيح **مع التشكيل** في حقل "correct"

أعد JSON فقط:
{
  "accuracy": 85,
  "words": [
    {"user": "الْحَمْدُ", "correct": "الْحَمْدُ", "status": "correct"},
    {"user": "الحمد", "correct": "الْحَمْدُ", "status": "wrong"},
    {"user": "", "correct": "لِلَّهِ", "status": "missing"},
    {"user": "زيادة", "correct": "", "status": "extra"}
  ],
  "feedback": "ملاحظات عن الحركات والتشكيل"
}

⚠️ JSON فقط.
''';

      final response = await _sendRequest({
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2000,
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
      });

      if (response == null || response.statusCode != 200) {
        return {
          'accuracy': 0,
          'words': [],
          'feedback': 'خطأ في الاتصال',
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
          await UsageService.incrementRecitation();
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
}
