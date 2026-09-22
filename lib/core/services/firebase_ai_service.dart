import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';
import 'recitation_corrector.dart';

/// ═══════════════════════════════════════════════════════════
/// 🤖 خدمة الذكاء الاصطناعي — Groq API
/// ✅ Whisper لتحويل الصوت إلى نص (مع prompt لتحسين الدقة)
/// ✅ Groq AI للمساعد الذكي
/// ✅ إعادة بناء التشكيل للتلاوة
/// ✅ مقارنة محلية للتلاوة (RecitationCorrector)
/// ═══════════════════════════════════════════════════════════
class FirebaseAiService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _chatUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _whisperUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';

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

  // ═══════════════════════════════════════════════════════════
  // 🎤 Whisper: تحويل الصوت إلى نص (مع prompt اختياري)
  // ═══════════════════════════════════════════════════════════
  static Future<String?> transcribeAudio(
    String audioFilePath, {
    String? correctText,
  }) async {
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ مفتاح Groq غير موجود');
      return null;
    }

    try {
      debugPrint('🎤 جاري تحويل الصوت إلى نص...');
      if (correctText != null && correctText.isNotEmpty) {
        final preview = correctText.length > 50
            ? correctText.substring(0, 50)
            : correctText;
        debugPrint('📝 مع prompt: $preview...');
      }

      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-large-v3'
        ..fields['language'] = 'ar'
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0';

      // 🔑 تمرير النص الصحيح كـ prompt لتحسين استقبال الكلمات
      if (correctText != null && correctText.isNotEmpty) {
        request.fields['prompt'] = correctText;
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
      ));

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 90),
          );

      if (streamedResponse.statusCode == 200) {
        final body = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(body);
        final text = data['text']?.toString() ?? '';
        debugPrint('✅ Whisper: $text');
        return text.isNotEmpty ? text : null;
      } else {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('❌ Whisper ${streamedResponse.statusCode}: $body');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Whisper error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 المساعد الذكي "المرشد"
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
  // 🎯 إعادة بناء التشكيل بالذكاء الاصطناعي
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> reconstructTashkeel({
    required String userText,
    required String correctText,
  }) async {
    if (_apiKey.isEmpty) {
      return {'reconstructed': userText, 'words': {}};
    }

    try {
      final prompt = '''
لديك آية قرآنية بالتشكيل الكامل، ونص مقروء بدون تشكيل.
مهمتك: أعد بناء النص المقروء بإضافة التشكيل المناسب لكل كلمة، بناءً على ما قرأه المستخدم فعلاً (وليس بناءً على الآية الصحيحة).

📖 الآية الصحيحة (بالتشكيل):
$correctText

🎤 ما قرأه المستخدم (بدون تشكيل):
$userText

⚠️ قواعد مهمة:
1. حافظ على كلمات المستخدم كما هي - لا تستبدلها بكلمات الآية الصحيحة.
2. أضف التشكيل لكل كلمة حسب ما نطق بها المستخدم فعلاً.
3. إذا لم تستطع تحديد التشكيل بدقة، استخدم التشكيل الأقرب من الآية الصحيحة.
4. الكلمات الناقصة أو الزائدة تبقى كما هي بدون تغيير.

📤 أعد JSON فقط:
{
  "reconstructed": "النص المُعاد بناؤه بالتشكيل كاملاً",
  "words": {
    "الحمد": "الْحَمْدُ",
    "لله": "لِلَّهِ",
    "رب": "رَبِّ",
    "الناس": "النَّاسِ"
  }
}

⚠️ JSON فقط بدون شرح.
''';

      final response = await _sendRequest({
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 1500,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      });

      if (response == null || response.statusCode != 200) {
        return {'reconstructed': userText, 'words': {}};
      }

      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] ?? '{}';

      String cleaned = text.trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'reconstructed': userText, 'words': {}};
    } catch (e) {
      debugPrint('❌ reconstructTashkeel error: $e');
      return {'reconstructed': userText, 'words': {}};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 تصحيح التلاوة الكامل (Whisper + Tashkeel AI + Local)
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
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
      // 1️⃣ إعادة بناء التشكيل بالذكاء الاصطناعي
      debugPrint('🎯 جاري إعادة بناء التشكيل...');
      final tashkeelResult = await reconstructTashkeel(
        userText: userRecitation,
        correctText: correctAyah,
      );

      final reconstructedText =
          tashkeelResult['reconstructed']?.toString() ?? userRecitation;

      debugPrint('📝 النص الأصلي: $userRecitation');
      debugPrint('📝 النص المُعاد: $reconstructedText');

      // 2️⃣ المقارنة مع التشكيل
      final result = RecitationCorrector.compareWithTashkeel(
        originalUser: userRecitation,
        reconstructedUser: reconstructedText,
        correctText: correctAyah,
        tashkeelResult: tashkeelResult,
      );

      await UsageService.incrementRecitation();
      return result.toJson();
    } catch (e) {
      debugPrint('❌ خطأ في المقارنة: $e');
      return {
        'accuracy': 0,
        'words': [],
        'feedback': '⚠️ تعذر التحليل: $e',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 التعرف على الآية
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> identifyAyah(String spokenText) async {
    if (_apiKey.isEmpty || spokenText.trim().isEmpty) return null;

    try {
      final prompt = '''
قرأ المستخدم آية قرآنية، وهذا ما تعرّف عليه النظام من صوته (Whisper):
"$spokenText"

حدد السورة ورقم الآية من القرآن الكريم (114 سورة، 6236 آية).

⚠️ ملاحظات:
- قد يكون النص المُحوَّل بدون تشكيل.
- ابحث عن الآية الأقرب في المعنى والكلمات.
- استخدم معرفتك الكاملة بالقرآن.

أعد JSON فقط:
{
  "surah": "اسم السورة",
  "surahNumber": 1,
  "ayahNumber": 1,
  "confidence": 95,
  "matchedText": "النص القرآني الصحيح مع التشكيل"
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
  // 🎯 الموديل النشط (مع fallback تلقائي)
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
              Uri.parse(_chatUrl),
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
          debugPrint('⚠️ $model غير متاح، جرب التالي...');
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
}
