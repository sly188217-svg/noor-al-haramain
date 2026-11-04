import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationService {
  static const List<Map<String, String>> languages = [
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'ur', 'name': 'اردو', 'flag': '🇵🇰'},
    {'code': 'id', 'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    {'code': 'bn', 'name': 'বাংলা', 'flag': '🇧🇩'},
    {'code': 'fa', 'name': 'فارسی', 'flag': '🇮🇷'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳'},
    {'code': 'sw', 'name': 'Kiswahili', 'flag': '🇰🇪'},
    {'code': 'ml', 'name': 'മലയാളം', 'flag': '🇮🇳'},
    {'code': 'ta', 'name': 'தமிழ்', 'flag': '🇮🇳'},
    {'code': 'te', 'name': 'తెలుగు', 'flag': '🇮🇳'},
    {'code': 'so', 'name': 'Soomaali', 'flag': '🇸🇴'},
    {'code': 'ha', 'name': 'Hausa', 'flag': '🇳🇬'},
    {'code': 'yo', 'name': 'Yorùbá', 'flag': '🇳🇬'},
    {'code': 'ig', 'name': 'Igbo', 'flag': '🇳🇬'},
    {'code': 'am', 'name': 'አማርኛ', 'flag': '🇪🇹'},
    {'code': 'ps', 'name': 'پښتو', 'flag': '🇦🇫'},
    {'code': 'ku', 'name': 'Kurdî', 'flag': '🇮🇶'},
    {'code': 'az', 'name': 'Azərbaycan', 'flag': '🇦🇿'},
    {'code': 'uz', 'name': 'Oʻzbek', 'flag': '🇺🇿'},
    {'code': 'kk', 'name': 'Қазақ', 'flag': '🇰🇿'},
    {'code': 'ms', 'name': 'Bahasa Melayu', 'flag': '🇲🇾'},
    {'code': 'th', 'name': 'ไทย', 'flag': '🇹🇭'},
    {'code': 'vi', 'name': 'Tiếng Việt', 'flag': '🇻🇳'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷'},
    {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹'},
    {'code': 'nl', 'name': 'Nederlands', 'flag': '🇳🇱'},
    {'code': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
    {'code': 'uk', 'name': 'Українська', 'flag': '🇺🇦'},
    {'code': 'ro', 'name': 'Română', 'flag': '🇷🇴'},
    {'code': 'el', 'name': 'Ελληνικά', 'flag': '🇬🇷'},
    {'code': 'sv', 'name': 'Svenska', 'flag': '🇸🇪'},
  ];

  static Future<String> getCurrentLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('translation_lang') ?? 'en';
  }

  static Future<void> setLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_lang', code);
  }

  static Future<String?> getAyahTranslation({
    required int surahNumber,
    required int ayahNumber,
    required String langCode,
  }) async {
    if (langCode == 'ar') return null;
    try {
      final url = 'https://api.alquran.cloud/v1/ayah/$surahNumber:$ayahNumber/$langCode';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['text'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
