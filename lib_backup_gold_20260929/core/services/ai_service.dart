import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة الذكاء الاصطناعي باستخدام DeepSeek API
/// ⚠️ المفتاح لا يُخزَّن في الكود - يُدخل من الإعدادات
class AIService {
  // ============================================================
  // 🔑 مفتاح API - يُدخل من الإعدادات ويُحفظ في SharedPreferences
  // ============================================================
  static const String _defaultApiKey = '';
  static const String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _prefsKey = 'deepseek_api_key';
  
  static String? _apiKey;

  // ============================================================
  // إدارة المفتاح
  // ============================================================
  
  /// تحميل المفتاح من التخزين المحلي
  static Future<void> _loadApiKey() async {
    if (_apiKey != null) return;
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_prefsKey);
    _apiKey = (savedKey != null && savedKey.isNotEmpty) ? savedKey : _defaultApiKey;
  }

  /// حفظ المفتاح في التخزين المحلي
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
    _apiKey = key;
  }

  /// حذف المفتاح
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _apiKey = null;
  }

  /// التحقق من وجود مفتاح
  static Future<bool> hasApiKey() async {
    await _loadApiKey();
    return _apiKey != null && _apiKey!.isNotEmpty;
  }

  // ============================================================
  // إرسال السؤال
  // ============================================================
  
  static Future<String> askQuestion(String question) async {
    await _loadApiKey();
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      return '⚠️ **مطلوب مفتاح DeepSeek API**\n\n'
             '🔑 **للحصول على مفتاح مجاني:**\n'
             '1. افتح: https://platform.deepseek.com/api_keys\n'
             '2. سجل الدخول بحسابك\n'
             '3. أنشئ مفتاحاً جديداً\n'
             '4. انسخ المفتاح (يبدأ بـ "sk-")\n\n'
             '📌 **أين أضعه؟**\n'
             '• اذهب إلى الإعدادات ⚙️\n'
             '• اختر "🤖 ذكاء"\n'
             '• الصق المفتاح واضغط حفظ';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': 'أنت مساعد إسلامي ذكي متخصص في الإجابة عن الأسئلة الدينية. أنت خبير في القرآن الكريم، التفسير، الحديث، الفقه، العقيدة، السيرة النبوية، والأخلاق الإسلامية. قدم إجابات دقيقة ومفصلة مع الاستشهاد بالأدلة من الكتاب والسنة إن أمكن. استخدم اللغة العربية الفصحى.'
            },
            {'role': 'user', 'content': question}
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        } else {
          return '⚠️ لم يتم الحصول على رد.';
        }
      } else if (response.statusCode == 401) {
        return '⚠️ مفتاح DeepSeek API غير صالح.';
      } else if (response.statusCode == 402) {
        return '⚠️ رصيد الحساب غير كافٍ.';
      } else if (response.statusCode == 429) {
        return '⚠️ تجاوزت حد الاستخدام.';
      } else {
        return '⚠️ خطأ في الاتصال (رمز ${response.statusCode}).';
      }
    } catch (e) {
      return '⚠️ تعذر الاتصال: $e';
    }
  }

  // ============================================================
  // اختبار الاتصال
  // ============================================================
  
  static Future<bool> testConnection() async {
    try {
      await _loadApiKey();
      if (_apiKey == null || _apiKey!.isEmpty) return false;
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [{'role': 'user', 'content': 'مرحبا'}],
          'max_tokens': 10,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // حالة الـ API
  // ============================================================
  
  static Future<Map<String, dynamic>> getApiStatus() async {
    await _loadApiKey();
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    final isActive = hasKey ? await testConnection() : false;
    
    return {
      'hasKey': hasKey,
      'isActive': isActive,
      'keyPreview': hasKey ? '${_apiKey!.substring(0, 8)}...' : 'غير موجود',
      'model': 'deepseek-chat',
    };
  }
}
