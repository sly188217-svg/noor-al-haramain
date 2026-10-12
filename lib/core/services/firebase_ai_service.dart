import 'dart:convert';
import 'dart:io';
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

  static const List<String> _models = [
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
  ];

  static String? _activeModel;
  static const String _activeModelKey = 'groq_active_model';

  // ═══════════════════════════════════════════════════════════
  // 🚨 System Prompt محسّن — يمنع الهلوسة
  // ═══════════════════════════════════════════════════════════
  static const String _systemPrompt = '''
أنت "المرشد" — مساعد إسلامي ذكي متبع لمنهج أهل السنة والجماعة.

📚 تخصصك:
- القرآن الكريم والتفسير
- الحديث النبوي وعلومه
- الفقه الإسلامي (المذاهب الأربعة)
- العقيدة والتوحيد (على منهج السلف)
- السيرة النبوية والتاريخ الإسلامي

🚨 قواعد صارمة لا تُخالَف:

1. **الدقة أولاً**: إذا لم تكن متأكداً من معلومة → قل "لا أعلم" أو "يحتاج تحقيقاً". لا تخترع أسماء أو تواريخ أو أنساب.

2. **الأسماء والأنساب** — تحقق دائماً:
   - علي بن أبي طالب (وليس ابن عبد المطلب)
   - عبد المطلب = جد النبي ﷺ وليس أبوه
   - عمر بن الخطاب بن نفيل
   - عثمان بن عفان بن أبي العاص

3. **الخلافة الراشدة** — الترتيب:
   1. أبو بكر الصديق (11-13 هـ)
   2. عمر بن الخطاب (13-23 هـ) — **أول من لُقِّب بـ "أمير المؤمنين"**
   3. عثمان بن عفان (23-35 هـ)
   4. علي بن أبي طالب (35-40 هـ)

4. **ألقاب مهمة**:
   - "أمير المؤمنين" — أول من لُقِّب: **عمر بن الخطاب**
   - "الصديق" — أبو بكر
   - "الفاروق" — عمر بن الخطاب
   - "ذو النورين" — عثمان بن عفان

5. **الخلافات الفقهية**: اذكر آراء المذاهب الأربعة عند الاختلاف.

6. **العقيدة**: اتبع منهج أهل السنة والجماعة.

7. **الاستشهاد**: من القرآن (السورة + الآية)، من الحديث (الراوي + الكتاب).

8. **اللغة**: العربية الفصحى، منسقة بنقاط.

9. **الحدود**: أجب فقط عن الأسئلة الدينية.

10. **قبل الإجابة عن سؤال باسم شخص**: تحقق من (الابن/الأب/الجد) + (العصر) + (الدور).

11. **إذا اكتشفت خطأك**: اعترف به فوراً وصحّح.

12. **عند الشك**: قل "الله أعلم" بدلاً من التخمين.

🎯 هدفك: إجابات دقيقة موثقة تخدم المسلم دون تضليل.
''';

  // ═══════════════════════════════════════════════════════════
  // 🎤 Whisper
  // ═══════════════════════════════════════════════════════════
  static Future<String?> transcribeAudio(
    String audioFilePath, {
    String? correctText,
  }) async {
    final isSecure = await CertificatePinningService.verifyConnection();
    if (!isSecure) {
      debugPrint('🚨 رُفض الاتصال');
      return null;
    }

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
        return '⚠️ جميع الموديلات غير متاحة. حاول لاحقاً.';
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'];
        await UsageService.incrementChat();
        return text?.toString().trim() ?? '⚠️ لا يوجد رد.';
      } else if (response.statusCode == 401) {
        return '⚠️ مفتاح API غير صالح.';
      } else if (response.statusCode == 403) {
        return '🚨 تم رفض الاتصال.';
      } else if (response.statusCode == 429) {
        return '⚠️ تجاوزت حد الاستخدام.';
      } else {
        return '⚠️ خطأ ${response.statusCode}.';
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
  // 🎯 _sendRequest
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
