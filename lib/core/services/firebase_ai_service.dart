import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';
import 'recitation_corrector.dart';
import 'certificate_pinning_service.dart';

class FirebaseAiService {
  static String get _workerUrl =>
      dotenv.env['WORKER_URL'] ??
      'https://noor-groq-proxy-v2.sly188217.workers.dev';

  static String get _chatUrl => '$_workerUrl/chat';
  static String get _whisperUrl => '$_workerUrl/whisper';

  // ✅ الموديلات الصحيحة والمتاحة حالياً في Groq (تم إزالة openai/gpt-oss)
  static const List<String> _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'mixtral-8x7b-32768',
  ];

  static String? _activeModel;
  static const String _activeModelKey = 'groq_active_model';

  // ═══════════════════════════════════════════════════════════
  // 🚨 System Prompt محدث (منهج السلف الصالح + كبار العلماء)
  // ═══════════════════════════════════════════════════════════
  static const String _systemPrompt = '''
أنت "المرشد" — مساعد إسلامي ذكي متبع لمنهج أهل السنة والجماعة والسلف الصالح.

📚 تخصصك:
- القرآن الكريم والتفسير (على تفسير السلف).
- الحديث النبوي وعلومه.
- الفقه الإسلامي.
- العقيدة والتوحيد.
- السيرة النبوية.

🚨 قواعد صارمة لا تُخالَف:
1. **الاعتماد على السلف**: إجاباتك يجب أن تلتزم بفهم السلف الصالح، وتبتعد عن البدع والمحدثات.
2. **كبار العلماء**: اعتمد في فتاويك وآرائك على علماء السنة المعاصرين، واذكرهم بالاسم عند الاقتضاء، خصوصاً:
   - سماحة الشيخ عبد العزيز بن باز (رحمه الله).
   - فضيلة الشيخ محمد بن صالح العثيمين (رحمه الله).
   - فضيلة الشيخ صالح الفوزان (حفظه الله).
   - اللجنة الدائمة للإفتاء.
3. **ذكر الأدلة**: لا تجب إلا بدليل من القرآن الكريم (اذكر السورة والآية)، أو الحديث الصحيح (اذكر الراوي والكتاب).
4. **الخلافات الفقهية**: إذا اختلف أهل العلم، اذكر أقوالهم مع الدليل، ورجّح ما رجحه كبار العلماء المذكورين أعلاه.
5. **التحذير من الفرق**: التزم بمنهج السلف، وتجنب آراء الفرق المخالفة (كالصوفية، الأشعرية، الإخوان، وغيرهم).
6. **الدقة والتحقق**: إذا لم تجد دليلاً صريحاً أو لم تكن متأكداً، قل "الله أعلم" ولا تخترع فتوى.
7. **اللغة**: العربية الفصحى، منسقة بنقاط واضحة، ومحترمة.

🎯 هدفك: إجابة السائل بفتوى شرعية صحيحة، مدعومة بالدليل، وموافقة لفهم السلف الصالح.
''';

  // ═══════════════════════════════════════════════════════════
  // 🎤 Whisper
  // ═══════════════════════════════════════════════════════════
  static Future<String?> transcribeAudio(
    String audioFilePath, {
    String? correctText,
  }) async {
    final isSecure = await CertificatePinningService.verifyConnection();
    if (!isSecure) return null;

    try {
      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['language'] = 'ar'
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0';

      if (correctText != null && correctText.isNotEmpty) {
        request.fields['prompt'] = correctText;
      }

      request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 90),
          );

      if (streamedResponse.statusCode == 200) {
        final body = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(body);
        final text = data['text']?.toString() ?? '';
        return text.isNotEmpty ? text : null;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('❌ Whisper error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 askQuestion
  // ═══════════════════════════════════════════════════════════
  static Future<String> askQuestion(String question) async {
    if (!await UsageService.isPremium()) {
      final remaining = await UsageService.remainingChats();
      if (remaining <= 0) {
        return '🔒 **انتهت تجربتك المجانية لليوم**\n\n'
            '⏰ يتجدد تلقائياً غداً\n\n'
            '💎 **للاشتراك الفوري:**\n'
            '• شهرياً: \$2.99\n'
            '• سنوياً: \$22.99\n\n'
            'افتح الإعدادات ← اشترك في Premium';
      }
    }

    try {
      final response = await _sendRequest({
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': question}
        ],
        'max_tokens': 2000,
        'temperature': 0.3,
      });

      if (response == null) {
        return '⚠️ تعذر الاتصال بالخادم. تأكد من اتصالك بالإنترنت أو حاول لاحقاً.';
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'];
        await UsageService.incrementChat();
        return text?.toString().trim() ?? '⚠️ لا يوجد رد.';
      } else if (response.statusCode == 401) {
        return '⚠️ مفتاح API غير صالح.';
      } else if (response.statusCode == 429) {
        return '⚠️ تجاوزت حد الاستخدام. حاول بعد قليل.';
      } else {
        return '⚠️ خطأ (${response.statusCode}).';
      }
    } catch (e) {
      return '⚠️ تعذر الاتصال: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 reconstructTashkeel
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> reconstructTashkeel({
    required String userText,
    required String correctText,
  }) async {
    try {
      final prompt = '''
لديك آية قرآنية بالتشكيل الكامل، ونص مقروء بدون تشكيل.

📖 الآية الصحيحة:
$correctText

🎤 ما قرأه المستخدم:
$userText

📤 أعد JSON فقط:
{"reconstructed": "النص المُعاد", "words": {"الحمد": "الْحَمْدُ"}}
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
      if (decoded is Map<String, dynamic>) return decoded;
      return {'reconstructed': userText, 'words': {}};
    } catch (e) {
      return {'reconstructed': userText, 'words': {}};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 analyzeRecitation
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
  }) async {
    if (!await UsageService.isPremium()) {
      final remaining = await UsageService.remainingRecitations();
      if (remaining <= 0) {
        return {
          'accuracy': 0, 'words': [], 'stats': {},
          'feedback': '🔒 انتهت تجربتك المجانية.\n💎 اشترك من الإعدادات',
        };
      }
    }

    try {
      final tashkeelResult = await reconstructTashkeel(
        userText: userRecitation,
        correctText: correctAyah,
      );

      final reconstructedText =
          tashkeelResult['reconstructed']?.toString() ?? userRecitation;

      final result = RecitationCorrector.compareWithTashkeel(
        originalUser: userRecitation,
        reconstructedUser: reconstructedText,
        correctText: correctAyah,
        tashkeelResult: tashkeelResult,
      );

      await UsageService.incrementRecitation();
      return result.toJson();
    } catch (e) {
      return {
        'accuracy': 0, 'words': [], 'stats': {},
        'feedback': '⚠️ تعذر التحليل: $e',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 identifyAyah
  // ═══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> identifyAyah(String spokenText) async {
    if (spokenText.trim().isEmpty) return null;

    try {
      final prompt = '''
قرأ المستخدم آية: "$spokenText"

أعد JSON:
{"surah": "...", "surahNumber": 1, "ayahNumber": 1, "confidence": 95, "matchedText": "..."}
أو {"surah": null, "confidence": 0}
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
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 _sendRequest (مع نظام التبديل التلقائي بين الموديلات)
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
  }

  static Future<http.Response?> _sendRequest(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final isSecure = await CertificatePinningService.verifyConnection();
    if (!isSecure) return null;

    final active = await _getActiveModel();
    final modelsToTry = [active, ..._models.where((m) => m != active)];

    for (final model in modelsToTry) {
      try {
        body['model'] = model;
        final response = await http.post(
          Uri.parse(_chatUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-App-Version': '1.0.0',
            'X-Platform': 'flutter',
          },
          body: jsonEncode(body),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          await _setActiveModel(model);
          return response;
        }

        // إذا لم يوجد الموديل، جرب الموديل التالي في القائمة
        if (response.statusCode == 404 ||
            response.body.contains('model_not_found')) {
          continue;
        }

        return response;
      } catch (e) {
        continue;
      }
    }

    return null;
  }
}
