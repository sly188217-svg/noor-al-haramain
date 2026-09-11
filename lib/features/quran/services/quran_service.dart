import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah_model.dart';
import '../models/ayah_model.dart';

class QuranService {
  static const String _quranFile = 'assets/data/quran_full.json';
  static const String _apiUrl = 'https://api.alquran.cloud/v1/quran/quran-uthmani';
  
  static List<SurahModel>? _cachedSurahs;
  static bool _isLoading = false;

  // ============================================================
  // 1. تحميل القرآن (من الملف المحلي أولاً، ثم من API إذا لزم)
  // ============================================================
  static Future<List<SurahModel>> loadQuran() async {
    // إذا كانت البيانات مخزنة مسبقاً، نعيدها مباشرة
    if (_cachedSurahs != null) {
      return _cachedSurahs!;
    }

    // منع التحميل المتكرر
    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _cachedSurahs ?? [];
    }
    _isLoading = true;

    try {
      // 1. محاولة تحميل الملف المحلي
      try {
        final String jsonString = await rootBundle.loadString(_quranFile);
        final Map<String, dynamic> data = jsonDecode(jsonString);
        final surahsList = data['data']['surahs'] as List;
        
        if (surahsList.isNotEmpty && _isQuranComplete(surahsList)) {
          final surahs = _parseSurahs(surahsList);
          _cachedSurahs = surahs;
          _isLoading = false;
          return surahs;
        }
      } catch (e) {
        print('⚠️ الملف المحلي غير مكتمل أو تالف: $e');
      }

      // 2. إذا فشل الملف المحلي، نحاول التحميل من API
      return await _loadFromApi();

    } catch (e) {
      _isLoading = false;
      throw Exception('⚠️ تعذر تحميل القرآن: $e');
    }
  }

  // ============================================================
  // 2. التحقق من اكتمال القرآن
  // ============================================================
  static bool _isQuranComplete(List surahsList) {
    // تأكد من وجود 114 سورة
    if (surahsList.length < 114) return false;
    
    // تأكد من أن السورة الأولى تحتوي على آيات
    final firstSurah = surahsList.first;
    if (firstSurah['ayahs'] == null) return false;
    
    final ayahs = firstSurah['ayahs'] as List;
    if (ayahs.length < 7) return false; // سورة الفاتحة 7 آيات
    
    return true;
  }

  // ============================================================
  // 3. تحميل من API وحفظ محلياً
  // ============================================================
  static Future<List<SurahModel>> _loadFromApi() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل القرآن من الخادم (${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception('خطأ في الاستجابة: ${data['status']}');
      }

      final surahsList = data['data']['surahs'] as List;
      final surahs = _parseSurahs(surahsList);
      _cachedSurahs = surahs;
      _isLoading = false;
      
      return surahs;
    } catch (e) {
      _isLoading = false;
      rethrow;
    }
  }

  // ============================================================
  // 4. تحويل JSON إلى نماذج
  // ============================================================
  static List<SurahModel> _parseSurahs(List surahsList) {
    return surahsList.map((s) {
      return SurahModel(
        number: s['number'] ?? 0,
        name: s['name'] ?? '',
        englishName: s['englishName'] ?? '',
        englishNameTranslation: s['englishNameTranslation'] ?? '',
        numberOfAyahs: s['numberOfAyahs'] ?? 0,
        revelationType: s['revelationType'] ?? '',
        ayahs: s['ayahs'] != null
            ? (s['ayahs'] as List).map((a) => AyahModel.fromJson(a)).toList()
            : [],
      );
    }).toList();
  }

  // ============================================================
  // 5. جلب آيات سورة معينة من API (تحديث)
  // ============================================================
  static Future<List<AyahModel>> fetchAyahsFromApi(int surahNumber) async {
    try {
      final url = 'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-uthmani';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الآيات');
      }
      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception('خطأ في الاستجابة: ${data['status']}');
      }
      final ayahs = data['data']['ayahs'] as List;
      return ayahs.map((a) => AyahModel.fromJson(a)).toList();
    } catch (e) {
      throw Exception('⚠️ فشل تحميل الآيات: $e');
    }
  }

  // ============================================================
  // 6. الحصول على سورة معينة
  // ============================================================
  static Future<SurahModel?> getSurah(int surahNumber) async {
    final surahs = await loadQuran();
    try {
      return surahs.firstWhere((s) => s.number == surahNumber);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // 7. الحصول على آية معينة
  // ============================================================
  static Future<AyahModel?> getAyah(int surahNumber, int ayahNumber) async {
    final surah = await getSurah(surahNumber);
    if (surah == null || surah.ayahs == null) return null;
    try {
      return surah.ayahs!.firstWhere((a) => a.number == ayahNumber);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // 8. البحث في القرآن
  // ============================================================
  static Future<List<Map<String, dynamic>>> searchQuran(String query) async {
    final surahs = await loadQuran();
    List<Map<String, dynamic>> results = [];
    
    for (var surah in surahs) {
      if (surah.ayahs == null) continue;
      for (var ayah in surah.ayahs!) {
        if (ayah.text.contains(query)) {
          results.add({
            'surahNumber': surah.number,
            'surahName': surah.name,
            'ayahNumber': ayah.number,
            'text': ayah.text,
            'page': ayah.page,
          });
        }
      }
    }
    return results;
  }

  // ============================================================
  // 9. التلاوة الصوتية (عبر الإنترنت)
  // ============================================================
  static final List<Map<String, String>> reciters = [
    {'id': 'maher', 'name': 'ماهر المعيقلي', 'nameAr': 'ماهر المعيقلي'},
    {'id': 'minshawi', 'name': 'محمد صديق المنشاوي', 'nameAr': 'محمد صديق المنشاوي'},
    {'id': 'husary', 'name': 'محمود خليل الحصري', 'nameAr': 'محمود خليل الحصري'},
    {'id': 'afasy', 'name': 'مشاري العفاسي', 'nameAr': 'مشاري العفاسي'},
    {'id': 'ghamdi', 'name': 'سعود الشريم', 'nameAr': 'سعود الشريم'},
  ];

  static String getRecitationUrl(int surahNumber, String reciterId) {
    final padded = surahNumber.toString().padLeft(3, '0');
    switch (reciterId) {
      case 'maher':
        return 'https://server8.mp3quran.net/afs/$padded.mp3';
      case 'minshawi':
        return 'https://server8.mp3quran.net/minshawi/$padded.mp3';
      case 'husary':
        return 'https://server8.mp3quran.net/husary/$padded.mp3';
      case 'afasy':
        return 'https://server8.mp3quran.net/afasy/$padded.mp3';
      case 'ghamdi':
        return 'https://server8.mp3quran.net/ghamdi/$padded.mp3';
      default:
        return 'https://server8.mp3quran.net/afs/$padded.mp3';
    }
  }

  // ============================================================
  // 10. تحديد القارئ المفضل
  // ============================================================
  static Future<void> setPreferredReciter(String reciterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_reciter', reciterId);
  }

  static Future<String> getPreferredReciter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_reciter') ?? 'maher';
  }
}
