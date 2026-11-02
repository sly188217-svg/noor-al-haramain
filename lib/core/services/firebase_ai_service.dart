import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';

class FirebaseAiService {
  static String get _workerUrl => dotenv.env['WORKER_URL'] ?? 'https://noor-groq-proxy-v2.sly188217.workers.dev';
  static String get _chatUrl => '$_workerUrl/chat';
  static String get _whisperUrl => '$_workerUrl/whisper';

  static const List<String> _models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

  // ✅ إزالة التشكيل للمقارنة الأساسية
  static String _normalizeArabic(String text) {
    String r = text;
    r = r.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    r = r.replaceAll(RegExp(r'[أإآ]'), 'ا');
    r = r.replaceAll(RegExp(r'[ةه]'), 'ه');
    r = r.replaceAll(RegExp(r'[ىي]'), 'ي');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  // ✅ تحويل الصوت إلى نص
  static Future<String?> transcribeAudio(String audioFilePath, {String? correctText}) async {
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
      final res = await request.send().timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        return jsonDecode(body)['text']?.toString() ?? '';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ تحليل التلاوة (يدعم جميع اللغات في الردود)
  static Future<Map<String, dynamic>> analyzeRecitation({
    required String userRecitation,
    required String correctAyah,
    String languageCode = 'ar', // ✅ إضافة لغة التطبيق
  }) async {
    try {
      final cleanUser = _normalizeArabic(userRecitation);
      final cleanCorrect = _normalizeArabic(correctAyah);

      final userWords = cleanUser.split(' ').where((w) => w.isNotEmpty).toList();
      final correctWords = cleanCorrect.split(' ').where((w) => w.isNotEmpty).toList();
      final origCorrectWords = correctAyah.split(' ').where((w) => w.isNotEmpty).toList();
      final origUserWords = userRecitation.split(' ').where((w) => w.isNotEmpty).toList();

      List<Map<String, dynamic>> wordsResult = [];
      int correctCount = 0, wrongCount = 0, missingCount = 0, extraCount = 0;

      for (int i = 0; i < correctWords.length; i++) {
        final userWord = i < userWords.length ? userWords[i] : null;
        final origCorrect = i < origCorrectWords.length ? origCorrectWords[i] : '';
        final origUser = i < origUserWords.length ? origUserWords[i] : '';

        String status; String? detail;
        if (userWord == null) { 
          status = 'missing'; missingCount++; 
          detail = languageCode == 'ar' ? 'لم تقرأ هذه الكلمة' : 'Missing word';
        } else if (userWord == correctWords[i]) { 
          status = 'correct'; correctCount++; 
        } else { 
          status = 'wrong'; wrongCount++; 
          detail = languageCode == 'ar' ? 'قرأت "$origUser" والصحيح "$origCorrect"' : 'You said "$origUser" but correct is "$origCorrect"';
        }

        wordsResult.add({'correct': origCorrect, 'user': origUser, 'status': status, 'detail': detail});
      }

      for (int i = correctWords.length; i < userWords.length; i++) {
        extraCount++;
        wordsResult.add({
          'correct': '', 'user': origUserWords[i], 'status': 'extra', 
          'detail': languageCode == 'ar' ? 'كلمة زائدة' : 'Extra word',
        });
      }

      final accuracy = correctWords.isEmpty ? 0.0 : (correctCount / correctWords.length) * 100;
      String? tashkeelFeedback;

      // ✅ تحليل التشكيل بالذكاء الاصطناعي بنفس لغة التطبيق
      if (wrongCount > 0 && wrongCount <= 5) {
        final wrongWords = wordsResult
            .where((w) => w['status'] == 'wrong')
            .map((w) => '"${w['user']}" instead of "${w['correct']}"').join(', ');

        final prompt = '''
The user read the Ayah: "$correctAyah"
But made mistakes in these words: $wrongWords

Please provide precise feedback on:
1. Correct Tashkeel (vowels: Fatha, Damma, Kasra, Sukun).
2. Pronunciation (Makhraj) if there is a difference.
3. Tajweed tips.
**IMPORTANT: You MUST reply in the language code: "$languageCode".** (e.g., if "ar" reply in Arabic, if "en" reply in English).
Keep it very brief (3-4 lines max).
''';

        try {
          final aiResponse = await _sendRequest({
            'messages': [
              {'role': 'system', 'content': 'You are a strict Quran recitation expert. Follow the requested language strictly.'},
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 300,
            'temperature': 0.3,
          });
          if (aiResponse != null && aiResponse.statusCode == 200) {
            tashkeelFeedback = jsonDecode(aiResponse.body)['choices']?[0]?['message']?['content']?.toString();
          }
        } catch (e) {}
      }

      String feedback;
      if (accuracy >= 95) feedback = languageCode == 'ar' ? '🌟 ممتاز! تلاوة صحيحة ومتقنة.' : '🌟 Excellent! Perfect recitation.';
      else if (accuracy >= 85) feedback = languageCode == 'ar' ? '✅ جيد جداً! واصل التحسين.' : '✅ Very good! Keep improving.';
      else if (accuracy >= 70) feedback = languageCode == 'ar' ? '👍 جيد، لكن يحتاج إلى مزيد من الدقة.' : '👍 Good, but needs more accuracy.';
      else if (accuracy >= 50) feedback = languageCode == 'ar' ? '⚠️ تلاوة متوسطة، يرجى الاستماع للقارئ وإعادة المحاولة.' : '⚠️ Average, listen to the reciter and try again.';
      else feedback = languageCode == 'ar' ? '❌ تلاوة ضعيفة، استمع جيداً للقارئ ثم أعد.' : '❌ Weak recitation, listen carefully and retry.';

      if (tashkeelFeedback != null && tashkeelFeedback.isNotEmpty) {
        feedback = '$feedback\n\n📚 ${languageCode == 'ar' ? 'ملاحظات المرشد' : 'Murshid Notes'}:\n$tashkeelFeedback';
      }

      await UsageService.incrementRecitation();
      return {'accuracy': accuracy, 'words': wordsResult, 'stats': {'correct': correctCount, 'wrong': wrongCount, 'missing': missingCount, 'extra': extraCount, 'total': correctWords.length}, 'feedback': feedback};
    } catch (e) {
      return {'accuracy': 0, 'words': [], 'stats': {}, 'feedback': '⚠️ $e'};
    }
  }

  // ✅ المرشد (يدعم جميع اللغات)
  static Future<String> askQuestion(String question) async {
    try {
      final response = await _sendRequest({
        'messages': [
          {'role': 'system', 'content': 'أنت "المرشد" مساعد إسلامي متبع لمنهج أهل السنة والجماعة. اعتمد على أقوال ابن باز وابن عثيمين والفوزان. أجب بدقة واختصار. **قاعدة هامة جداً: أجب بنفس اللغة التي كُتب بها السؤال.**'},
          {'role': 'user', 'content': question}
        ],
        'max_tokens': 1024,
        'temperature': 0.5,
      });
      if (response == null) return '⚠️ تعذر الاتصال بالخادم.';
      if (response.statusCode == 200) {
        final content = jsonDecode(response.body)['choices']?[0]?['message']?['content']?.toString() ?? '';
        return content.isNotEmpty ? content : '⚠️ لا يوجد رد.';
      }
      return '⚠️ خطأ (${response.statusCode})';
    } catch (e) {
      return '⚠️ تعذر الاتصال: $e';
    }
  }

  static Future<String?> _getActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_active_model') ?? _models.first;
  }

  static Future<http.Response?> _sendRequest(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 60)}) async {
    final active = await _getActiveModel();
    final modelsToTry = [active, ..._models.where((m) => m != active)];

    for (final model in modelsToTry) {
      try {
        body['model'] = model;
        final response = await http.post(
          Uri.parse(_chatUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('groq_active_model', model);
          return response;
        }
      } catch (e) { continue; }
    }
    return null;
  }
}
