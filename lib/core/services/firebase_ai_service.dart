import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';
import 'recitation_corrector.dart';
import 'certificate_pinning_service.dart';

class FirebaseAiService {
  static String get _workerUrl => dotenv.env['WORKER_URL'] ?? 'https://noor-groq-proxy-v2.sly188217.workers.dev';
  static String get _chatUrl => '$_workerUrl/chat';
  static String get _whisperUrl => '$_workerUrl/whisper';

  static const List<String> _models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

  // ✅ دالة إزالة التشكيل للمقارنة
  static String removeTashkeel(String text) {
    return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  }

  static Future<String?> transcribeAudio(String audioFilePath, {String? correctText}) async {
    final isSecure = await CertificatePinningService.verifyConnection();
    if (!isSecure) return null;
    try {
      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['language'] = 'ar'
        ..fields['response_format'] = 'json';
      if (correctText != null && correctText.isNotEmpty) request.fields['prompt'] = correctText;
      request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));
      final res = await request.send().timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        return jsonDecode(body)['text']?.toString();
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<String> askQuestion(String question) async {
    try {
      final response = await _sendRequest({
        'messages': [
          {'role': 'system', 'content': 'أنت "المرشد" مساعد إسلامي. أجب بدقة واختصار.'},
          {'role': 'user', 'content': question}
        ],
        'max_tokens': 1024,
        'temperature': 0.5,
      });

      if (response == null) return '⚠️ تعذر الاتصال بالخادم. تأكد من الإنترنت.';
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['choices']?[0]?['message']?['content']?.toString().trim() ?? '⚠️ لا يوجد رد.';
      }
      return '⚠️ خطأ (${response.statusCode})';
    } catch (e) { return '⚠️ تعذر الاتصال: $e'; }
  }

  static Future<Map<String, dynamic>> analyzeRecitation({required String userRecitation, required String correctAyah}) async {
    try {
      // ✅ إزالة التشكيل من كلا النصين قبل المقارنة
      final cleanUser = removeTashkeel(userRecitation);
      final cleanCorrect = removeTashkeel(correctAyah);
      
      final tashkeelResult = await reconstructTashkeel(userText: cleanUser, correctText: cleanCorrect);
      final result = RecitationCorrector.compareWithTashkeel(
        originalUser: userRecitation,
        reconstructedUser: tashkeelResult['reconstructed']?.toString() ?? userRecitation,
        correctText: correctAyah,
        tashkeelResult: tashkeelResult,
      );
      await UsageService.incrementRecitation();
      return result.toJson();
    } catch (e) {
      return {'accuracy': 0, 'words': [], 'stats': {}, 'feedback': '⚠️ تعذر التحليل: $e'};
    }
  }

  static Future<Map<String, dynamic>> reconstructTashkeel({required String userText, required String correctText}) async {
    try {
      final prompt = 'لديك آية: "$correctText"\nونص بدون تشكيل: "$userText"\nأعد JSON: {"reconstructed": "النص", "words": {}}';
      final response = await _sendRequest({
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 1000,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      }, timeout: const Duration(seconds: 45));
      if (response == null || response.statusCode != 200) return {'reconstructed': userText, 'words': {}};
      final text = jsonDecode(response.body)['choices']?[0]?['message']?['content'] ?? '{}';
      String cleaned = text.trim();
      final start = cleaned.indexOf('{'); final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
      return jsonDecode(cleaned) as Map<String, dynamic>? ?? {'reconstructed': userText, 'words': {}};
    } catch (e) { return {'reconstructed': userText, 'words': {}}; }
  }

  static Future<String?> _getActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_active_model') ?? _models.first;
  }

  static Future<http.Response?> _sendRequest(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 60)}) async {
    final isSecure = await CertificatePinningService.verifyConnection();
    if (!isSecure) return null;
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
        if (response.statusCode == 400) continue;
      } catch (e) { continue; }
    }
    return null;
  }
}
