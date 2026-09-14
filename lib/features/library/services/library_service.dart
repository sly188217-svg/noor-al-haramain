import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';
import '../models/hadith_model.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة المكتبة — إنترنت فقط + تخزين في RAM
/// ═══════════════════════════════════════════════════════════
/// 
/// ✅ لا تخزين دائم على الهاتف
/// ✅ تحميل عند الفتح + تخزين في RAM للجلسة
/// ✅ 10 كتب من fawazahmed0/hadith-api
/// 
class LibraryService {
  /// 🧠 ذاكرة مؤقتة (تُمسح عند إغلاق التطبيق)
  static final Map<String, List<dynamic>> _memoryCache = {};

  static const List<Map<String, String>> _books = [
    {
      'id': 'bukhari',
      'title': 'صحيح البخاري',
      'author': 'محمد بن إسماعيل البخاري',
      'category': 'الحديث',
      'description': 'أصح كتب الحديث بعد القرآن الكريم',
      'chapters': '97',
      'hadithCount': '7275',
    },
    {
      'id': 'muslim',
      'title': 'صحيح مسلم',
      'author': 'مسلم بن الحجاج',
      'category': 'الحديث',
      'description': 'ثاني أصح كتب الحديث',
      'chapters': '54',
      'hadithCount': '5362',
    },
    {
      'id': 'abudawud',
      'title': 'سنن أبي داود',
      'author': 'أبو داود السجستاني',
      'category': 'الحديث',
      'description': 'من أمهات كتب الحديث الستة',
      'chapters': '37',
      'hadithCount': '4800',
    },
    {
      'id': 'tirmidhi',
      'title': 'جامع الترمذي',
      'author': 'محمد بن عيسى الترمذي',
      'category': 'الحديث',
      'description': 'من أمهات كتب الحديث الستة',
      'chapters': '46',
      'hadithCount': '3956',
    },
    {
      'id': 'nasai',
      'title': 'سنن النسائي',
      'author': 'أحمد بن شعيب النسائي',
      'category': 'الحديث',
      'description': 'من الكتب الستة',
      'chapters': '51',
      'hadithCount': '5761',
    },
    {
      'id': 'ibnmajah',
      'title': 'سنن ابن ماجه',
      'author': 'ابن ماجه القزويني',
      'category': 'الحديث',
      'description': 'سادس الكتب الستة',
      'chapters': '37',
      'hadithCount': '4341',
    },
    {
      'id': 'malik',
      'title': 'موطأ مالك',
      'author': 'مالك بن أنس',
      'category': 'الحديث',
      'description': 'أول كتاب جامع في الحديث والفقه',
      'chapters': '61',
      'hadithCount': '1860',
    },
    {
      'id': 'ahmed',
      'title': 'مسند أحمد',
      'author': 'أحمد بن حنبل',
      'category': 'الحديث',
      'description': 'أكبر مسند في الإسلام',
      'chapters': '0',
      'hadithCount': '40000',
    },
    {
      'id': 'nawawi',
      'title': 'الأربعون النووية',
      'author': 'يحيى بن شرف النووي',
      'category': 'الحديث',
      'description': '42 حديثاً جامعاً لأصول الدين',
      'chapters': '42',
      'hadithCount': '42',
    },
    {
      'id': 'riyadussalihin',
      'title': 'رياض الصالحين',
      'author': 'يحيى بن شرف النووي',
      'category': 'الحديث',
      'description': 'منتخب من الأحاديث الصحيحة',
      'chapters': '372',
      'hadithCount': '1896',
    },
  ];

  static List<BookModel> getBooks() {
    return _books.map((b) => BookModel.fromJson(b)).toList();
  }

  static BookModel? getBookById(String id) {
    try {
      final book = _books.firstWhere((b) => b['id'] == id);
      return BookModel.fromJson(book);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // تحميل كتاب (من RAM أو من الإنترنت)
  // ═══════════════════════════════════════════════════════════
  static Future<List<dynamic>> _loadFullBook(String bookId) async {
    if (_memoryCache.containsKey(bookId)) {
      debugPrint('⚡ $bookId من RAM (${_memoryCache[bookId]!.length} حديث)');
      return _memoryCache[bookId]!;
    }

    final url =
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-$bookId.json';

    debugPrint('📥 تحميل $bookId...');

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('فشل تحميل $bookId: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final hadiths = _extractHadiths(data);

    if (hadiths.isEmpty) throw Exception('لا توجد أحاديث');

    _memoryCache[bookId] = hadiths;
    debugPrint('✅ $bookId جاهز (${hadiths.length} حديث)');
    return hadiths;
  }

  static List<dynamic> _extractHadiths(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['hadiths'] is List) return data['hadiths'];
      if (data['data'] is List) return data['data'];
    }
    return [];
  }

  static Future<List<HadithModel>> fetchHadiths({
    required String bookId,
    int start = 1,
    int limit = 50,
  }) async {
    final all = await _loadFullBook(bookId);
    final startIdx = (start - 1).clamp(0, all.length);
    final endIdx = (startIdx + limit).clamp(0, all.length);
    if (startIdx >= all.length) return [];
    return all
        .sublist(startIdx, endIdx)
        .map((h) => HadithModel.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  static Future<int> getHadithCount(String bookId) async {
    try {
      final all = await _loadFullBook(bookId);
      return all.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<HadithModel>> searchInBook({
    required String bookId,
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];
    final all = await _loadFullBook(bookId);
    final results = <HadithModel>[];
    for (final h in all) {
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
        final cached = await searchInBook(bookId: bookId, query: query, limit: 20);
        results.addAll(cached);
        if (results.length >= 50) break;
      } catch (e) {}
    }
    return results;
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static bool isBookLoaded(String bookId) => _memoryCache.containsKey(bookId);
  static int get loadedBooksCount => _memoryCache.length;
}
