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

  static String _normalizeArabic(String text) {
    String r = text;
    r = r.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    r = r.replaceAll(RegExp(r'[أإآ]'), 'ا');
    r = r.replaceAll(RegExp(r'[ةه]'), 'ه');
    r = r.replaceAll(RegExp(r'[ىي]'), 'ي');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  static Future<String?> transcribeAudio(String audioFilePath, {String? correctText}) async {
    try {
      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['language'] = 'ar'
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0';
      if (correctText != null && correctText.isNotEmpty) request.fields['prompt'] = correctText;
      request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));
      final res = await request.send().timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        return jsonDecode(body)['text']?.toString() ?? '';
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> identifyAyah(String spokenText) async {
    if (spokenText.trim().isEmpty) return null;
    try {
      final prompt = 'قرأ المستخدم آية: "$spokenText"\nأعد JSON: {"surah": "...", "surahNumber": 1, "ayahNumber": 1, "confidence": 95}';
      final response = await _sendRequest({
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 500, 'temperature': 0.1, 'response_format': {'type': 'json_object'},
      });
      if (response == null || response.statusCode != 200) return null;
      final text = (jsonDecode(response.body)['choices']?[0]?['message']?['content'] ?? '{}').toString();
      String cleaned = text.trim();
      final start = cleaned.indexOf('{'); final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic> && decoded['surah'] != null) return decoded;
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> analyzeRecitation({required String userRecitation, required String correctAyah, String languageCode = 'ar'}) async {
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
        if (userWord == null) { status = 'missing'; missingCount++; detail = languageCode == 'ar' ? 'لم تقرأ هذه الكلمة' : 'Missing word'; }
        else if (userWord == correctWords[i]) { status = 'correct'; correctCount++; }
        else { status = 'wrong'; wrongCount++; detail = languageCode == 'ar' ? 'قرأت "$origUser" والصحيح "$origCorrect"' : 'You said "$origUser" but correct is "$origCorrect"'; }
        wordsResult.add({'correct': origCorrect, 'user': origUser, 'status': status, 'detail': detail});
      }

      for (int i = correctWords.length; i < userWords.length; i++) {
        extraCount++;
        wordsResult.add({'correct': '', 'user': origUserWords[i], 'status': 'extra', 'detail': languageCode == 'ar' ? 'كلمة زائدة' : 'Extra word'});
      }

      final accuracy = correctWords.isEmpty ? 0.0 : (correctCount / correctWords.length) * 100;
      String tashkeelFeedback = '';
      
      if (wrongCount > 0 && wrongCount <= 5) {
        final wrongWords = wordsResult.where((w) => w['status'] == 'wrong').map((w) => '"${w['user']}" instead of "${w['correct']}"').join(', ');
        final prompt = 'The user read the Ayah: "$correctAyah"\nMistakes: $wrongWords\n\nProvide precise feedback on Tashkeel and pronunciation.\nReply in language code: "$languageCode". Keep it brief (3 lines).';
        try {
          final aiResponse = await _sendRequest({'messages': [{'role': 'system', 'content': 'You are a Quran expert. Follow the requested language.'}, {'role': 'user', 'content': prompt}], 'max_tokens': 300, 'temperature': 0.3});
          if (aiResponse != null && aiResponse.statusCode == 200) {
            tashkeelFeedback = (jsonDecode(aiResponse.body)['choices']?[0]?['message']?['content'] ?? '').toString();
          }
        } catch (e) {}
      }

      String feedback = accuracy >= 95 ? '🌟 Excellent!' : (accuracy >= 70 ? '✅ Good!' : '⚠️ Needs practice.');
      if (tashkeelFeedback.isNotEmpty) feedback = '$feedback\n\n📚 Notes:\n$tashkeelFeedback';
      await UsageService.incrementRecitation();
      return {'accuracy': accuracy, 'words': wordsResult, 'stats': {'correct': correctCount, 'wrong': wrongCount, 'missing': missingCount, 'extra': extraCount, 'total': correctWords.length}, 'feedback': feedback};
    } catch (e) { return {'accuracy': 0, 'words': [], 'stats': {}, 'feedback': '⚠️ $e'}; }
  }

  static Future<String> askQuestion(String question) async {
    try {
      final response = await _sendRequest({
        'messages': [
          {'role': 'system', 'content': 'أنت "المرشد" مساعد إسلامي متبع لمنهج أهل السنة والجماعة. قاعدة إلزامية: يجب أن تجيب بنفس اللغة التي كُتب بها السؤال (عربي، إنجليزي، فرنسي، إلخ). لا تجب بالإنجليزية إذا كان السؤال بالعربية.'},
          {'role': 'user', 'content': question}
        ],
        'max_tokens': 1024, 'temperature': 0.5,
      });
      if (response == null) return '⚠️ تعذر الاتصال بالخادم. تأكد من الإنترنت.';
      if (response.statusCode == 200) {
        final content = (jsonDecode(response.body)['choices']?[0]?['message']?['content'] ?? '').toString();
        return content.isNotEmpty ? content : '⚠️ لا يوجد رد.';
      }
      return '⚠️ خطأ (${response.statusCode})';
    } catch (e) { return '⚠️ تعذر الاتصال: $e'; }
  }

  static Future<String> _getActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_active_model') ?? _models.first;
  }

  static Future<http.Response?> _sendRequest(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 60)}) async {
    final active = await _getActiveModel();
    final modelsToTry = [active, ..._models.where((m) => m != active)];
    for (final model in modelsToTry) {
      try {
        body['model'] = model;
        final response = await http.post(Uri.parse(_chatUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(timeout);
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
