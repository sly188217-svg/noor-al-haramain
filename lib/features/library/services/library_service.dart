import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_model.dart';

class LibraryService {
  // ✅ قائمة كتب السلف الأساسية (المتوفرة عبر API)
  static const List<Map<String, String>> _books = [
    {
      'id': 'bukhari',
      'title': 'صحيح البخاري',
      'author': 'محمد بن إسماعيل البخاري',
      'category': 'الحديث',
      'description': 'أصح كتب الحديث بعد القرآن الكريم، يحتوي على 7275 حديثاً',
      'chapters': '97',
      'hadithCount': '7275',
    },
    {
      'id': 'muslim',
      'title': 'صحيح مسلم',
      'author': 'مسلم بن الحجاج',
      'category': 'الحديث',
      'description': 'ثاني أصح كتب الحديث، يحتوي على 5362 حديثاً',
      'chapters': '54',
      'hadithCount': '5362',
    },
    {
      'id': 'abudawud',
      'title': 'سنن أبي داود',
      'author': 'أبو داود السجستاني',
      'category': 'الحديث',
      'description': 'جمع فيه 4800 حديثاً',
      'chapters': '37',
      'hadithCount': '4800',
    },
    {
      'id': 'tirmidhi',
      'title': 'سنن الترمذي',
      'author': 'محمد بن عيسى الترمذي',
      'category': 'الحديث',
      'description': 'جمع فيه 3956 حديثاً',
      'chapters': '46',
      'hadithCount': '3956',
    },
    {
      'id': 'nasai',
      'title': 'سنن النسائي',
      'author': 'أحمد بن شعيب النسائي',
      'category': 'الحديث',
      'description': 'جمع فيه 5761 حديثاً',
      'chapters': '51',
      'hadithCount': '5761',
    },
    {
      'id': 'ibnmajah',
      'title': 'سنن ابن ماجه',
      'author': 'ابن ماجه القزويني',
      'category': 'الحديث',
      'description': 'جمع فيه 4341 حديثاً',
      'chapters': '37',
      'hadithCount': '4341',
    },
    {
      'id': 'muwatta',
      'title': 'موطأ مالك',
      'author': 'مالك بن أنس',
      'category': 'الحديث',
      'description': 'أول كتاب جامع في الحديث والفقه',
      'chapters': '61',
      'hadithCount': '1860',
    },
    {
      'id': 'ahmad',
      'title': 'مسند أحمد',
      'author': 'أحمد بن حنبل',
      'category': 'الحديث',
      'description': 'أكبر مسند في الإسلام، يحتوي على أكثر من 40000 حديث',
      'chapters': '0',
      'hadithCount': '40000',
    },
  ];

  // ✅ الحصول على قائمة الكتب
  static List<BookModel> getBooks() {
    return _books.map((b) => BookModel.fromJson(b)).toList();
  }

  // ✅ الحصول على كتاب معين
  static BookModel? getBookById(String id) {
    try {
      final book = _books.firstWhere((b) => b['id'] == id);
      return BookModel.fromJson(book);
    } catch (e) {
      return null;
    }
  }

  // ✅ جلب الأحاديث من API (fawazahmed0/hadith-api)[reference:8]
  static Future<List<HadithModel>> fetchHadiths({
    required String bookId,
    int start = 1,
    int limit = 50,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'hadiths_${bookId}_${start}_$limit';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final List<dynamic> data = jsonDecode(cached);
        return data.map((h) => HadithModel.fromJson(h)).toList();
      } catch (e) {
        // بيانات تالفة
      }
    }

    try {
      // استخدام API fawazahmed0
      final url =
          'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-$bookId.json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          // تخزين مؤقت
          await prefs.setString(cacheKey, jsonEncode(data));
          return data.map((h) => HadithModel.fromJson(h)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ✅ جلب حديث معين
  static Future<HadithModel?> fetchHadith({
    required String bookId,
    required int hadithNumber,
  }) async {
    try {
      final url =
          'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-$bookId/$hadithNumber.json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HadithModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ البحث عن أحاديث (باستخدام dorar_hadith)[reference:9]
  static Future<List<HadithModel>> searchHadiths(String query) async {
    try {
      // استخدام dorar_hadith للبحث المتقدم
      // ملاحظة: هذا يتطلب استيراد dorar_hadith
      // final client = DorarClient();
      // final results = await client.searchHadith(
      //   HadithSearchParams(value: query, page: 1),
      // );
      // return results.data.map((h) => HadithModel(...)).toList();

      // حالياً نعيد بيانات وهمية للتجربة
      await Future.delayed(const Duration(seconds: 1));
      return [
        HadithModel(
          number: 1,
          text: 'عن أبي هريرة رضي الله عنه قال: قال رسول الله ﷺ: "من صام رمضان إيماناً واحتساباً غفر له ما تقدم من ذنبه"',
          narrator: 'أبو هريرة',
          grade: 'صحيح',
          bookName: 'صحيح البخاري',
        ),
      ];
    } catch (e) {
      return [];
    }
  }
}
