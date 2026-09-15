import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/book_model.dart';
import '../models/hadith_model.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة المكتبة — مصادر موثوقة ومُختبرة
/// ═══════════════════════════════════════════════════════════
/// 
/// ✅ الحديث: fawazahmed0/hadith-api (.min.json)
/// ✅ التفسير: quran.com API
/// ✅ السيرة/الفقه: ملفات محلية
/// 
class LibraryService {
  /// 🧠 ذاكرة RAM
  static final Map<String, List<dynamic>> _memoryCache = {};

  // ═══════════════════════════════════════════════════════════
  // قائمة الكتب (12 كتاباً)
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, String>> _books = [
    // ─── 📖 الحديث ───
    {'id': 'bukhari', 'title': 'صحيح البخاري', 'author': 'محمد بن إسماعيل البخاري', 'category': 'الحديث', 'description': 'أصح كتب الحديث بعد القرآن الكريم', 'chapters': '97', 'hadithCount': '7275', 'source': 'hadith'},
    {'id': 'muslim', 'title': 'صحيح مسلم', 'author': 'مسلم بن الحجاج', 'category': 'الحديث', 'description': 'ثاني أصح كتب الحديث', 'chapters': '54', 'hadithCount': '5362', 'source': 'hadith'},
    {'id': 'abudawud', 'title': 'سنن أبي داود', 'author': 'أبو داود السجستاني', 'category': 'الحديث', 'description': 'من أمهات كتب الحديث الستة', 'chapters': '37', 'hadithCount': '4800', 'source': 'hadith'},
    {'id': 'tirmidhi', 'title': 'جامع الترمذي', 'author': 'محمد بن عيسى الترمذي', 'category': 'الحديث', 'description': 'من أمهات كتب الحديث الستة', 'chapters': '46', 'hadithCount': '3956', 'source': 'hadith'},
    {'id': 'nasai', 'title': 'سنن النسائي', 'author': 'أحمد بن شعيب النسائي', 'category': 'الحديث', 'description': 'من الكتب الستة', 'chapters': '51', 'hadithCount': '5761', 'source': 'hadith'},
    {'id': 'ibnmajah', 'title': 'سنن ابن ماجه', 'author': 'ابن ماجه القزويني', 'category': 'الحديث', 'description': 'سادس الكتب الستة', 'chapters': '37', 'hadithCount': '4341', 'source': 'hadith'},
    {'id': 'malik', 'title': 'موطأ مالك', 'author': 'مالك بن أنس', 'category': 'الحديث', 'description': 'أول كتاب جامع في الحديث والفقه', 'chapters': '61', 'hadithCount': '1860', 'source': 'hadith'},

    // ─── 📖 التفسير ───
    {'id': 'ar-tafsir-ibn-kathir', 'title': 'تفسير ابن كثير', 'author': 'ابن كثير الدمشقي', 'category': 'التفسير', 'description': 'من أشهر كتب التفسير بالمأثور', 'chapters': '114', 'hadithCount': '0', 'source': 'tafsir'},
    {'id': 'ar-tafsir-al-jalalayn', 'title': 'تفسير الجلالين', 'author': 'المحلي والسيوطي', 'category': 'التفسير', 'description': 'تفسير موجز لجميع الآيات', 'chapters': '114', 'hadithCount': '0', 'source': 'tafsir'},
    {'id': 'ar-tafseer-al-saddi', 'title': 'تفسير السعدي', 'author': 'عبد الرحمن السعدي', 'category': 'التفسير', 'description': 'تيسير الكريم الرحمن', 'chapters': '114', 'hadithCount': '0', 'source': 'tafsir'},

    // ─── 🕌 السيرة ───
    {'id': 'seerah', 'title': 'السيرة النبوية', 'author': 'مختصرة', 'category': 'السيرة', 'description': 'محطات من حياة النبي ﷺ', 'chapters': '50', 'hadithCount': '50', 'source': 'local'},

    // ─── ⚖️ الفقه ───
    {'id': 'fiqh', 'title': 'أحكام الفقه', 'author': 'مختصرة', 'category': 'الفقه', 'description': 'أحكام الطهارة والصلاة', 'chapters': '20', 'hadithCount': '30', 'source': 'local'},
  ];

  static List<BookModel> getBooks() =>
      _books.map((b) => BookModel.fromJson(b)).toList();

  static BookModel? getBookById(String id) {
    try {
      return BookModel.fromJson(_books.firstWhere((b) => b['id'] == id));
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // نقطة الدخول — حسب الفئة
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> fetchHadiths({
    required String bookId,
    int start = 1,
    int limit = 50,
  }) async {
    final book = getBookById(bookId);
    if (book == null) return [];

    try {
      switch (book.category) {
        case 'الحديث':
          return await _fetchHadiths(bookId, start, limit);
        case 'التفسير':
          return await _fetchTafsir(bookId, start, limit);
        case 'السيرة':
          return await _fetchSeerah();
        case 'الفقه':
          return await _fetchFiqh();
        default:
          return [];
      }
    } catch (e) {
      debugPrint('❌ fetchHadiths error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📚 الحديث — fawazahmed0 .min.json + RAM cache
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> _fetchHadiths(
    String bookId,
    int start,
    int limit,
  ) async {
    // 1. RAM
    if (_memoryCache.containsKey(bookId)) {
      debugPrint('⚡ $bookId من RAM');
      return _paginate(_memoryCache[bookId]!, start, limit, bookId);
    }

    // 2. تحميل من الإنترنت
    // ✅ استخدام .min.json (12x أصغر)
    final url = 'https://cdn.jsdelivr.net/gh/'
        'fawazahmed0/hadith-api@1/editions/ara-$bookId.min.json';

    debugPrint('📥 تحميل $bookId (قد يستغرق 30-60 ث)...');

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 2));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final hadiths = _extractHadiths(data);
    if (hadiths.isEmpty) throw Exception('فارغ');

    _memoryCache[bookId] = hadiths;
    debugPrint('✅ $bookId (${hadiths.length} حديث)');

    return _paginate(hadiths, start, limit, bookId);
  }

  static List<HadithModel> _paginate(
    List<dynamic> all,
    int start,
    int limit,
    String bookId,
  ) {
    final startIdx = (start - 1).clamp(0, all.length);
    final endIdx = (startIdx + limit).clamp(0, all.length);
    if (startIdx >= all.length) return [];

    return all
        .sublist(startIdx, endIdx)
        .map((h) => HadithModel.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  static List<dynamic> _extractHadiths(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['hadiths'] is List) return data['hadiths'];
      if (data['data'] is List) return data['data'];
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 التفسير — quran.com API + spa5k (سريع)
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> _fetchTafsir(
    String bookId,
    int start,
    int limit,
  ) async {
    // التفسير يُعرض سورة بسورة
    final surahNumber = start; // استخدام start كرقم السورة

    if (surahNumber < 1 || surahNumber > 114) return [];

    final url = 'https://cdn.jsdelivr.net/gh/'
        'spa5k/tafsir_api@main/tafsir/$bookId/$surahNumber.json';

    debugPrint('📥 تفسير سورة $surahNumber من $bookId');

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final ayahs = data['ayahs'] as List? ?? [];

    return ayahs.map((a) {
      return HadithModel(
        number: a['ayah'] ?? 0,
        text: '${a['text']}\n\n━━━━━━━━━━\n\n${a['tafsir'] ?? ''}',
        bookName: 'الآية ${a['ayah'] ?? 0}',
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 السيرة — ملف محلي (مضمّن)
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> _fetchSeerah() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/seerah.json');
      final data = jsonDecode(jsonString) as List;
      return data.map((e) {
        return HadithModel(
          number: e['id'] ?? 0,
          text: e['text']?.toString() ?? '',
          bookName: e['title']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ فشل تحميل السيرة: $e');
      return _seerahFallback();
    }
  }

  static List<HadithModel> _seerahFallback() {
    return [
      HadithModel(
        number: 1,
        text: 'وُلد النبي محمد ﷺ في مكة المكرمة عام الفيل (570م)، '
            'بعد وفاة والده عبد الله، وكفله جده عبد المطلب ثم عمه أبو طالب.',
        bookName: 'المولد والنشأة',
      ),
      HadithModel(
        number: 2,
        text: 'عمل النبي ﷺ في رعي الغنم ثم في التجارة، '
            'وعُرف بالصادق الأمين قبل البعثة.',
        bookName: 'الصادق الأمين',
      ),
      HadithModel(
        number: 3,
        text: 'تزوج النبي ﷺ من خديجة بنت خويلد رضي الله عنها '
            'وعمره 25 سنة، وكانت أول من آمن به.',
        bookName: 'الزواج بخديجة',
      ),
      HadithModel(
        number: 4,
        text: 'في سن الأربعين، نزل الوحي على النبي ﷺ في غار حراء '
            'بأول آيات سورة العلق: "اقرأ باسم ربك الذي خلق".',
        bookName: 'بدء الوحي',
      ),
      HadithModel(
        number: 5,
        text: 'دعا النبي ﷺ إلى الإسلام سراً ثلاث سنوات، '
            'ثم جهر بالدعوة بأمر الله.',
        bookName: 'الدعوة السرية والجهرية',
      ),
      HadithModel(
        number: 6,
        text: 'هاجر النبي ﷺ إلى المدينة المنورة عام 622م، '
            'وأسس أول دولة إسلامية، وبنى المسجد النبوي.',
        bookName: 'الهجرة إلى المدينة',
      ),
      HadithModel(
        number: 7,
        text: 'انتصر المسلمون في غزوة بدر الكبرى (2هـ) رغم قلة عددهم، '
            'وكانت أول معركة فاصلة في الإسلام.',
        bookName: 'غزوة بدر',
      ),
      HadithModel(
        number: 8,
        text: 'في العام 8 للهجرة، فتح المسلمون مكة، '
            'وعفا النبي ﷺ عن أهلها وقال: "اذهبوا فأنتم الطلقاء".',
        bookName: 'فتح مكة',
      ),
      HadithModel(
        number: 9,
        text: 'في حجة الوداع (10هـ)، خطب النبي ﷺ خطبته الشهيرة '
            'وأوصى بالمسلمين، ثم توفي ﷺ في المدينة المنورة.',
        bookName: 'حجة الوداع والوفاة',
      ),
      HadithModel(
        number: 10,
        text: 'ترك النبي ﷺ أمته على المحجة البيضاء، '
            'وأكمل الله به الدين، وأتم به النعمة.',
        bookName: 'الخاتمة',
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // ⚖️ الفقه — ملف محلي
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> _fetchFiqh() async {
    return [
      HadithModel(
        number: 1,
        text: 'الطهارة: قال ﷺ: "لا تقبل صلاة بغير طهور". '
            'ويشمل الوضوء والغسل والتيمم.',
        bookName: 'باب الطهارة',
      ),
      HadithModel(
        number: 2,
        text: 'الوضوء: غسل الوجه، ثم اليدين إلى المرفقين، '
            'ثم مسح الرأس، ثم غسل الرجلين إلى الكعبين.',
        bookName: 'باب الوضوء',
      ),
      HadithModel(
        number: 3,
        text: 'شروط الصلاة: الطهارة، استقبال القبلة، ستر العورة، '
            'دخول الوقت، النية.',
        bookName: 'باب الصلاة',
      ),
      HadithModel(
        number: 4,
        text: 'أركان الصلاة: تكبيرة الإحرام، الفاتحة، الركوع، '
            'الاعتدال، السجود، الجلوس بين السجدتين، التشهد، التسليم.',
        bookName: 'أركان الصلاة',
      ),
      HadithModel(
        number: 5,
        text: 'الزكاة: تجب في الذهب والفضة والأنعام والزروع والتجارة '
            'بشروط محددة، ومقدارها 2.5%.',
        bookName: 'باب الزكاة',
      ),
      HadithModel(
        number: 6,
        text: 'الصيام: صيام رمضان فرض، ويجب الإمساك عن الطعام '
            'والشراب من الفجر إلى المغرب.',
        bookName: 'باب الصيام',
      ),
      HadithModel(
        number: 7,
        text: 'الحج: يجب مرة واحدة في العمر على القادر، '
            'ويكون في أشهر الحج المعلومة.',
        bookName: 'باب الحج',
      ),
      HadithModel(
        number: 8,
        text: 'البيع: يجب أن يكون بالتراضي، وأن يكون المبيع '
            'معلوماً ومقدوراً على تسليمه.',
        bookName: 'باب المعاملات',
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // البحث
  // ═══════════════════════════════════════════════════════════
  static Future<List<HadithModel>> searchInBook({
    required String bookId,
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];
    if (!_memoryCache.containsKey(bookId)) return [];

    final results = <HadithModel>[];
    for (final h in _memoryCache[bookId]!) {
      if (h is Map) {
        final text = h['text']?.toString() ?? '';
        if (text.contains(query.trim())) {
          results.add(HadithModel.fromJson(h as Map<String, dynamic>));
          if (results.length >= limit) break;
        }
      }
    }
    return results;
  }

  static Future<List<HadithModel>> searchHadiths(String query) async {
    if (query.trim().isEmpty) return [];
    final results = <HadithModel>[];
    for (final bookId in _memoryCache.keys) {
      try {
        final cached =
            await searchInBook(bookId: bookId, query: query, limit: 20);
        results.addAll(cached);
        if (results.length >= 50) break;
      } catch (e) {}
    }
    return results;
  }

  static void clearMemoryCache() => _memoryCache.clear();
  static bool isBookLoaded(String bookId) => _memoryCache.containsKey(bookId);
  static int get loadedBooksCount => _memoryCache.length;
}
