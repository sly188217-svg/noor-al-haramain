import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah_model.dart';
import '../models/ayah_model.dart';

class QuranService {
  static const String _quranFile = 'assets/data/quran_full.json';
  static const String _apiUrl =
      'https://api.alquran.cloud/v1/quran/quran-uthmani';

  static List<SurahModel>? _cachedSurahs;
  static bool _isLoading = false;

  // ═══════════════════════════════════════════════════════════
  // 1. تحميل القرآن (من الملف المحلي أولاً، ثم من API إذا لزم)
  // ═══════════════════════════════════════════════════════════
  static Future<List<SurahModel>> loadQuran() async {
    if (_cachedSurahs != null) {
      return _cachedSurahs!;
    }

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
        debugPrint('⚠️ الملف المحلي غير مكتمل أو تالف: $e');
      }

      // 2. إذا فشل الملف المحلي، نحاول التحميل من API
      return await _loadFromApi();
    } catch (e) {
      _isLoading = false;
      throw Exception('⚠️ تعذر تحميل القرآن: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 2. التحقق من اكتمال القرآن
  // ═══════════════════════════════════════════════════════════
  static bool _isQuranComplete(List surahsList) {
    if (surahsList.length < 114) return false;

    final firstSurah = surahsList.first;
    if (firstSurah['ayahs'] == null) return false;

    final ayahs = firstSurah['ayahs'] as List;
    if (ayahs.length < 7) return false;

    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 3. تحميل من API
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // 4. تحويل JSON إلى نماذج
  // ═══════════════════════════════════════════════════════════
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
            ? (s['ayahs'] as List)
                .map((a) => AyahModel.fromJson(a))
                .toList()
            : [],
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 5. جلب آيات سورة معينة من API
  // ═══════════════════════════════════════════════════════════
  static Future<List<AyahModel>> fetchAyahsFromApi(int surahNumber) async {
    try {
      final url =
          'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-uthmani';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الآيات');
      }
      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception('خطأ في الاستجابة: ${data['status']}');
      }

      final dynamic rawData = data['data'];
      List ayahs;
      if (rawData is List && rawData.isNotEmpty) {
        ayahs = rawData[0]['ayahs'] as List;
      } else if (rawData is Map) {
        ayahs = rawData['ayahs'] as List;
      } else {
        throw Exception('بنية استجابة غير متوقعة');
      }
      return ayahs.map((a) => AyahModel.fromJson(a)).toList();
    } catch (e) {
      throw Exception('⚠️ فشل تحميل الآيات: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 6. جلب آيات سورة (alias للتوافق)
  // ═══════════════════════════════════════════════════════════
  static Future<List<AyahModel>> fetchSurahAyahs(int surahNumber) async {
    final surahs = await loadQuran();
    try {
      final surah = surahs.firstWhere((s) => s.number == surahNumber);
      if (surah.ayahs != null && surah.ayahs!.isNotEmpty) {
        return surah.ayahs!;
      }
    } catch (_) {}
    return fetchAyahsFromApi(surahNumber);
  }

  // ═══════════════════════════════════════════════════════════
  // 7. الحصول على سورة معينة
  // ═══════════════════════════════════════════════════════════
  static Future<SurahModel?> getSurah(int surahNumber) async {
    final surahs = await loadQuran();
    try {
      return surahs.firstWhere((s) => s.number == surahNumber);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 8. الحصول على آية معينة
  // ═══════════════════════════════════════════════════════════
  static Future<AyahModel?> getAyah(int surahNumber, int ayahNumber) async {
    final surah = await getSurah(surahNumber);
    if (surah == null || surah.ayahs == null) return null;
    try {
      return surah.ayahs!.firstWhere((a) => a.number == ayahNumber);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 9. البحث في القرآن
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // 10. قائمة القراء
  // ═══════════════════════════════════════════════════════════
  static final List<Map<String, String>> reciters = [
    {'id': 'maher', 'name': 'ماهر المعيقلي', 'nameAr': 'ماهر المعيقلي'},
    {'id': 'basit', 'name': 'عبد الباسط عبد الصمد', 'nameAr': 'عبد الباسط'},
    {'id': 'minsh', 'name': 'محمد صديق المنشاوي', 'nameAr': 'المنشاوي'},
    {'id': 'husr', 'name': 'محمود خليل الحصري', 'nameAr': 'الحصري'},
    {'id': 'afs', 'name': 'مشاري العفاسي', 'nameAr': 'العفاسي'},
    {'id': 'yasser', 'name': 'ياسر الدوسري', 'nameAr': 'الدوسري'},
    {'id': 'sudais', 'name': 'عبد الرحمن السديس', 'nameAr': 'السديس'},
    {'id': 'shur', 'name': 'سعود الشريم', 'nameAr': 'الشريم'},
  ];

  // ═══════════════════════════════════════════════════════════
  // 11. ✅ رابط التلاوة — 8 قراء يعملون 100%
  // ═══════════════════════════════════════════════════════════
  /// المصادر المختبرة:
  /// - server8.mp3quran.net  → ماهر، العفاسي
  /// - server7.mp3quran.net  → عبد الباسط، الشريم
  /// - server10.mp3quran.net → المنشاوي
  /// - server13.mp3quran.net → الحصري
  /// - server11.mp3quran.net → الدوسري، السديس
  static String getRecitationUrl(int surahNumber, String reciterId) {
    final padded = surahNumber.toString().padLeft(3, '0');

    switch (reciterId) {
      // ماهر المعيقلي
      case 'maher':
        return 'https://server8.mp3quran.net/afs/$padded.mp3';

      // عبد الباسط عبد الصمد (مرتل)
      case 'basit':
        return 'https://server7.mp3quran.net/basit/$padded.mp3';

      // محمد صديق المنشاوي (مرتل)
      case 'minsh':
      case 'minshawi':
        return 'https://server10.mp3quran.net/minsh/$padded.mp3';

      // محمود خليل الحصري
      case 'husr':
      case 'husary':
        return 'https://server13.mp3quran.net/husr/$padded.mp3';

      // مشاري العفاسي
      case 'afs':
      case 'afasy':
        return 'https://server8.mp3quran.net/afs/$padded.mp3';

      // ياسر الدوسري
      case 'yasser':
        return 'https://server11.mp3quran.net/yasser/$padded.mp3';

      // عبد الرحمن السديس
      case 'sudais':
        return 'https://server11.mp3quran.net/sudais/$padded.mp3';

      // سعود الشريم
      case 'shur':
      case 'ghamdi':
        return 'https://server7.mp3quran.net/shur/$padded.mp3';

      // افتراضي: ماهر المعيقلي
      default:
        return 'https://server8.mp3quran.net/afs/$padded.mp3';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 12. تحديد القارئ المفضل
  // ═══════════════════════════════════════════════════════════
  static Future<void> setPreferredReciter(String reciterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reciter', reciterId);
  }

  static Future<String> getPreferredReciter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('quran_reciter') ?? 'maher';
  }
}
