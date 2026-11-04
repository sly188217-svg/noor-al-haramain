kkimport 'package:shared_preferences/shared_preferences.dart';
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
    {'code': 'ml', 'name': 'മലയള', 'flag': '🇮🇳'},
    {'code': 'ta', 'name': 'தமழ்', 'flag': '🇮🇳'},
    {'code': 'te', 'name': 'తెలగ', 'flag': '🇮🇳'},
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

  // ✅ كاش للغة الحالية (لأن getText متزامنة)
  static String _cachedLang = 'en';
  static String get cachedLang => _cachedLang;

  // ✅ قاموس نصوص الواجهة — أضف/وسّع المفاتيح حسب استدعاءاتك الفعلية
  static const Map<String, Map<String, String>> _uiTexts = {
    'ar': {
      'app_name': 'نور الحرمين',
      'app_name_full': 'نور الحرمين العالمي',
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
      'next_prayer': 'الصلاة القادمة',
      'remaining': 'المتبقي',
      'home': 'الرئيسية',
      'kids': 'الأطفال',
      'recitation': 'التلاوة',
      'read_with_me': 'اقرأ معي',
    },
    'en': {
      'app_name': 'Noor Al Haramain',
      'app_name_full': 'Noor Al Haramain Global',
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
      'next_prayer': 'Next Prayer',
      'remaining': 'Remaining',
      'home': 'Home',
      'kids': 'Kids',
      'recitation': 'Recitation',
      'read_with_me': 'Read With Me',
    },
    // يمكنك إضافة بقية اللغات (fr, es, tr, ...) بنفس النمط لاحقاً
  };

  static Future<String> getCurrentLang() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('translation_lang') ?? 'en';
    _cachedLang = lang; // ✅ تحديث الكاش
    return lang;
  }

  static Future<void> setLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_lang', code);
    _cachedLang = code; // ✅ تحديث الكاش
  }

  /// ✅ الدالة المفقودة — تُستخدم في dashboard_screen و splash_screen
  /// تعمل بشكل متزامن (sync) باستخدام الكاش
  static String getText(String key, {String? langCode}) {
    final lang = langCode ?? _cachedLang;
    return _uiTexts[lang]?[key]
        ?? _uiTexts['en']?[key]
        ?? _uiTexts['ar']?[key]
        ?? key; // fallback: أرجع المفتاح نفسه
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
    } catch (e) {
      // ignore: avoid_print
      print('getAyahTranslation error: $e');
      return null;
    }
  }
}
