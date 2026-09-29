import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';
import 'recitation_corrector.dart';

/// ═══════════════════════════════════════════════════════════
/// 🤖 خدمة الذكاء الاصطناعي — Groq API (مباشر)
/// ✅ Whisper v3 Turbo لتحويل الصوت
/// ✅ مقارنة ذكية مع التشكيل
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
    'groq/compound',
    'groq/compound-mini',
  ];

  static String? _activeModel;
  static const String _activeModelKey = 'groq_active_model';

  // ═══════════════════════════════════════════════════════════
  // 🎤 Whisper: تحويل الصوت إلى نص
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

      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['language'] = 'ar'
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0';

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
        return '🔒 انتهت تجربتك المجانية لليوم.\n'
            '⏰ يتجدد تلقائياً غداً\n\n'
            '💎 للاشتراك: \$2.99/شهر أو \$19.99/سنة';
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
- الفقه الإسلامي
- العقيدة والتوحيد
- السيرة النبوية

قواعد:
1. أجب فقط عن الأسئلة الدينية.
2. استشهد بالأدلة.
3. اتبع منهج أهل السنة والجماعة.
4. اكتب بالعربية الفصحى.
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
  // 🔤 إعادة بناء التشكيل
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

📖 الآية الصحيحة:
$correctText

🎤 ما قرأه المستخدم:
$userText

📋 مهمتك:
أعد بناء نص المستخدم بإضافة التشكيل المناسب لكل كلمة **بناءً على ما قرأه هو فعلاً**.

⚠️ قواعد:
1. حافظ على كلمات المستخدم كما هي.
2. أضف التشكيل حسب ما نطق به.
3. إذا لم تستطع، استخدم التشكيل من الآية الصحيحة.

📤 أعد JSON فقط:
{
  "reconstructed": "النص المُعاد بالتشكيل",
  "words": {
    "الحمد": "الْحَمْدُ",
    "لله": "لِلَّهِ"
  }
}
''';

      final response = await _sendRequest(
        {
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 1500,
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        },
        timeout: const Duration(seconds: 45),
      );

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
  // 📖 تحليل التلاوة الكامل
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
          'stats': {},
          'feedback': '🔒 انتهت تجربتك المجانية.\n⏰ يتجدد غداً',
        };
      }
    }

    try {
      debugPrint('🎯 جاري إعادة بناء التشكيل...');
      final tashkeelResult = await reconstructTashkeel(
        userText: userRecitation,
        correctText: correctAyah,
      );

      final reconstructedText =
          tashkeelResult['reconstructed']?.toString() ?? userRecitation;

      debugPrint('📝 النص الأصلي: $userRecitation');
      debugPrint('📝 النص المُعاد: $reconstructedText');

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
        'stats': {},
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
قرأ المستخدم آية قرآنية، وهذا ما تعرّف عليه النظام:
"$spokenText"

حدد السورة ورقم الآية.

أعد JSON فقط:
{
  "surah": "اسم السورة",
  "surahNumber": 1,
  "ayahNumber": 1,
  "confidence": 95,
  "matchedText": "النص الصحيح مع التشكيل"
}

إذا لم تتعرف: {"surah": null, "confidence": 0}
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
  // 🎯 الموديل النشط
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
