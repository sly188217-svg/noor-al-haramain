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
    {'code': 'bn', 'name': 'বল', 'flag': '🇧🇩'},
    {'code': 'fa', 'name': 'فارسی', 'flag': '🇮🇷'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'hi', 'name': 'हन्द', 'flag': '🇮🇳'},
    {'code': 'sw', 'name': 'Kiswahili', 'flag': '🇰🇪'},
  ];

  static String _cachedLang = 'ar';

  static const Map<String, Map<String, String>> _uiTexts = {
    'ar': {
      'app_name': 'نور الحرمين',
      'welcome': 'مرحباً بك',
      'loading': 'جاري التحميل...',
      'error': 'حدث خطأ',
      'retry': 'إعادة المحاولة',
      'prayer_times': 'أوقات الصلاة',
      'quran': 'القرآن الكريم',
      'adhan': 'الأذان',
      'settings': 'الإعدادات',
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    },
    'en': {
      'app_name': 'Noor Al Haramain',
      'welcome': 'Welcome',
      'loading': 'Loading...',
      'error': 'An error occurred',
      'retry': 'Retry',
      'prayer_times': 'Prayer Times',
      'quran': 'The Holy Quran',
      'adhan': 'Adhan',
      'settings': 'Settings',
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    },
  };

  static Future<String> getCurrentLang() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('translation_lang') ?? 'ar';
    _cachedLang = lang;
    return lang;
  }

  static Future<void> setLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_lang', code);
    _cachedLang = code;
  }

  /// ✅ يستقبل معاملًا ثانيًا اختياريًا (langCode أو fallback)
  static String getText(String key, [dynamic second]) {
    String? langCode;
    String? fallback;
    if (second is String) {
      if (_uiTexts.containsKey(second)) {
        langCode = second;
      } else {
        fallback = second;
      }
    }
    final lang = langCode ?? _cachedLang;
    return _uiTexts[lang]?[key]
        ?? _uiTexts['en']?[key]
        ?? _uiTexts['ar']?[key]
        ?? fallback
        ?? key;
  }

  static Future<String?> getAyahTranslation({
    required int surahNumber,
    required int ayahNumber,
    required String langCode,
  }) async {
    if (langCode == 'ar') return null;
    try {
      final url =
          'https://api.alquran.cloud/v1/ayah/$surahNumber:$ayahNumber/$langCode';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['text'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
