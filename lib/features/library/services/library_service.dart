import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';
import '../models/hadith_model.dart';

class LibraryService {
  static final Map<String, List<HadithModel>> _cache = {};

  static const List<Map<String, String>> _books = [
    // الحديث
    {'id': 'bukhari', 'title': 'صحيح البخاري', 'author': 'محمد بن إسماعيل البخاري', 'category': 'الحديث', 'description': 'أصح كتب الحديث بعد القرآن', 'chapters': '97', 'hadithCount': '7275'},
    {'id': 'muslim', 'title': 'صحيح مسلم', 'author': 'مسلم بن الحجاج', 'category': 'الحديث', 'description': 'ثاني أصح كتب الحديث', 'chapters': '54', 'hadithCount': '5362'},
    {'id': 'abudawud', 'title': 'سنن أبي داود', 'author': 'أبو داود السجستاني', 'category': 'الحديث', 'description': 'من الكتب الستة', 'chapters': '37', 'hadithCount': '4800'},
    {'id': 'tirmidhi', 'title': 'جامع الترمذي', 'author': 'الترمذي', 'category': 'الحديث', 'description': 'من الكتب الستة', 'chapters': '46', 'hadithCount': '3956'},
    {'id': 'nasai', 'title': 'سنن النسائي', 'author': 'النسائي', 'category': 'الحديث', 'description': 'من الكتب الستة', 'chapters': '51', 'hadithCount': '5761'},
    {'id': 'ibnmajah', 'title': 'سنن ابن ماجه', 'author': 'ابن ماجه', 'category': 'الحديث', 'description': 'من الكتب الستة', 'chapters': '37', 'hadithCount': '4341'},
    {'id': 'malik', 'title': 'موطأ مالك', 'author': 'مالك بن أنس', 'category': 'الحديث', 'description': 'أول كتاب جامع', 'chapters': '61', 'hadithCount': '1860'},
    {'id': 'nawawi', 'title': 'الأربعون النووية', 'author': 'النووي', 'category': 'الحديث', 'description': '42 حديثاً جامعاً', 'chapters': '42', 'hadithCount': '42'},
    {'id': 'riyadussalihin', 'title': 'رياض الصالحين', 'author': 'النووي', 'category': 'الحديث', 'description': 'منتخب من الأحاديث', 'chapters': '372', 'hadithCount': '1896'},
    // التفسير
    {'id': 'ar-tafsir-ibn-kathir', 'title': 'تفسير ابن كثير', 'author': 'ابن كثير الدمشقي', 'category': 'التفسير', 'description': 'تفسير القرآن العظيم', 'chapters': '114', 'hadithCount': '6236'},
    {'id': 'ar-tafsir-al-jalalayn', 'title': 'تفسير الجلالين', 'author': 'المحلي والسيوطي', 'category': 'التفسير', 'description': 'تفسير موجز', 'chapters': '114', 'hadithCount': '6236'},
    {'id': 'ar-tafseer-al-saddi', 'title': 'تفسير السعدي', 'author': 'عبد الرحمن السعدي', 'category': 'التفسير', 'description': 'تيسير الكريم الرحمن', 'chapters': '114', 'hadithCount': '6236'},
    // السيرة
    {'id': 'seerah', 'title': 'السيرة النبوية الكاملة', 'author': 'من مصادر موثوقة', 'category': 'السيرة', 'description': 'سيرة النبي ﷺ كاملة', 'chapters': '47', 'hadithCount': '47'},
    // الفقه
    {'id': 'fiqh', 'title': 'أحكام الفقه الإسلامي', 'author': 'من مصادر موثوقة', 'category': 'الفقه', 'description': 'الطهارة والصلاة والزكاة والصيام والحج', 'chapters': '50', 'hadithCount': '50'},
  ];

  static List<BookModel> getBooks() =>
      _books.map((b) => BookModel.fromJson(b)).toList();

  static BookModel? getBookById(String id) {
    try {
      return BookModel.fromJson(_books.firstWhere((b) => b['id'] == id));
    } catch (_) {
      return null;
    }
  }

  /// تحميل كتاب كامل
  static Future<List<HadithModel>> loadFullBook({
    required String bookId,
    void Function(double progress)? onProgress,
  }) async {
    if (_cache.containsKey(bookId)) {
      debugPrint('⚡ $bookId من RAM');
      return _cache[bookId]!;
    }

    final book = getBookById(bookId);
    if (book == null) return [];

    List<HadithModel> result = [];

    try {
      switch (book.category) {
        case 'الحديث':
          result = await _loadHadithBook(bookId, onProgress);
          break;
        case 'التفسير':
          result = await _loadTafsirBook(bookId, onProgress);
          break;
        case 'السيرة':
          result = _getSeerah();
          break;
        case 'الفقه':
          result = _getFiqh();
          break;
      }

      _cache[bookId] = result;
      debugPrint('✅ $bookId: ${result.length} عنصر');
      return result;
    } catch (e) {
      debugPrint('❌ فشل $bookId: $e');
      rethrow;
    }
  }

  // الحديث
  static Future<List<HadithModel>> _loadHadithBook(
    String bookId,
    void Function(double)? onProgress,
  ) async {
    final url = 'https://cdn.jsdelivr.net/gh/'
        'fawazahmed0/hadith-api@1/editions/ara-$bookId.min.json';

    debugPrint('📥 تحميل $bookId...');
    onProgress?.call(0.1);

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 5));

    onProgress?.call(0.7);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    List<dynamic> items = [];

    if (data is Map && data['hadiths'] is List) {
      items = data['hadiths'] as List;
    } else if (data is List) {
      items = data;
    } else if (data is Map && data['data'] is List) {
      items = data['data'] as List;
    }

    if (items.isEmpty) throw Exception('لا توجد أحاديث');

    onProgress?.call(0.9);

    final result = items.map((h) {
      final map = h as Map<String, dynamic>;
      final numRaw = map['hadithnumber'] ?? map['number'] ?? map['id'] ?? 0;
      final number =
          numRaw is int ? numRaw : int.tryParse(numRaw.toString()) ?? 0;
      final text = map['text']?.toString() ??
          map['arabic']?.toString() ??
          map['hadith']?.toString() ??
          '';
      return HadithModel(
        number: number,
        text: text,
        bookName: getBookById(bookId)?.title,
      );
    }).where((h) => h.text.isNotEmpty).toList();

    onProgress?.call(1.0);
    return result;
  }

  // التفسير
  static Future<List<HadithModel>> _loadTafsirBook(
    String bookId,
    void Function(double)? onProgress,
  ) async {
    debugPrint('📥 تحميل تفسير $bookId (114 سورة)...');
    final result = <HadithModel>[];

    for (int surah = 1; surah <= 114; surah++) {
      try {
        final url = 'https://cdn.jsdelivr.net/gh/'
            'spa5k/tafsir_api@main/tafsir/$bookId/$surah.json';

        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final ayahs = data['ayahs'] as List? ?? [];

          for (var a in ayahs) {
            result.add(HadithModel(
              number: a['ayah'] ?? 0,
              text:
                  '📖 ${a['text'] ?? ''}\n\n${'─' * 30}\n\n${a['tafsir'] ?? ''}',
              bookName: 'سورة ${_surahName(surah)} - آية ${a['ayah']}',
            ));
          }
        }

        onProgress?.call(surah / 114);
      } catch (e) {
        debugPrint('⚠️ فشل سورة $surah: $e');
      }
    }

    onProgress?.call(1.0);
    return result;
  }

  // السيرة
  static List<HadithModel> _getSeerah() {
    return [
      HadithModel(number: 1, text: 'وُلد النبي محمد ﷺ في مكة المكرمة عام الفيل (570م)، يوم الاثنين من شهر ربيع الأول، بعد وفاة والده عبد الله بن عبد المطلب.', bookName: 'المولد'),
      HadithModel(number: 2, text: 'أرضعته حليمة السعدية في بادية بني سعد، وبقي فيها حتى سن الرابعة.', bookName: 'الرضاعة'),
      HadithModel(number: 3, text: 'توفيت أمه آمنة بنت وهب وهو في السادسة من عمره، فكفله جده عبد المطلب.', bookName: 'وفاة الأم'),
      HadithModel(number: 4, text: 'توفي جده عبد المطلب وهو في الثامنة، فكفله عمه أبو طالب.', bookName: 'كفالة العم'),
      HadithModel(number: 5, text: 'رعى الغنم في صغره، ثم سافر مع عمه إلى الشام للتجارة.', bookName: 'رعي الغنم'),
      HadithModel(number: 6, text: 'عُرف ﷺ بين قريش بالصادق الأمين، وكان يحفظ الأمانات ويصل الأرحام.', bookName: 'الصادق الأمين'),
      HadithModel(number: 7, text: 'شارك في حرب الفجار ودفع الله به عن قريش، وكان ينصر المظلوم.', bookName: 'حرب الفجار'),
      HadithModel(number: 8, text: 'شارك في حلف الفضول لحماية المظلومين في مكة.', bookName: 'حلف الفضول'),
      HadithModel(number: 9, text: 'وضع الحجر الأسود في مكانه حين اختلفت قريش، وكان عمره 35 سنة.', bookName: 'بناء الكعبة'),
      HadithModel(number: 10, text: 'تزوج خديجة بنت خويلد رضي الله عنها وعمره 25 سنة، وكانت أول من آمن به.', bookName: 'الزواج بخديجة'),
      HadithModel(number: 11, text: 'رزقه الله منها القاسم وعبد الله وأم كلثوم وزينب ورقية وفاطمة.', bookName: 'الذرية'),
      HadithModel(number: 12, text: 'في سن الأربعين، نزل الوحي في غار حراء بأول آيات سورة العلق: "اقرأ باسم ربك الذي خلق".', bookName: 'بدء الوحي'),
      HadithModel(number: 13, text: 'عاد ﷺ إلى خديجة يرجف فؤاده فقال: "زملوني زملوني"، فأنزل الله: "يا أيها المدثر".', bookName: 'أول ما نزل'),
      HadithModel(number: 14, text: 'أول من آمن به: خديجة، وأبو بكر، وعلي، وزيد بن حارثة.', bookName: 'أول المؤمنين'),
      HadithModel(number: 15, text: 'دعا إلى الإسلام سراً ثلاث سنوات، ثم أمره الله بالجهر: "فاصدع بما تؤمر".', bookName: 'الدعوة السرية'),
      HadithModel(number: 16, text: 'أسلم على يديه كثيرون، منهم عثمان بن عفان، والزبير، وعبد الرحمن بن عوف.', bookName: 'السابقون'),
      HadithModel(number: 17, text: 'صبر ﷺ وأصحابه على أذى قريش، وأوذوا في سبيل الله.', bookName: 'الصبر على الأذى'),
      HadithModel(number: 18, text: 'هاجر بعض الصحابة إلى الحبشة عند النجاشي، فأكرمهم.', bookName: 'الهجرة إلى الحبشة'),
      HadithModel(number: 19, text: 'حاصرت قريش بني هاشم في شعب أبي طالب ثلاث سنوات.', bookName: 'حصار الشعب'),
      HadithModel(number: 20, text: 'في عام الحزن (10 من البعثة)، توفيت خديجة وعمه أبو طالب.', bookName: 'عام الحزن'),
      HadithModel(number: 21, text: 'خرج ﷺ إلى الطائف يدعو أهلها، فردوه وأغروا به السفهاء.', bookName: 'رحلة الطائف'),
      HadithModel(number: 22, text: 'عُرج به ﷺ إلى السماء في حادثة الإسراء والمعراج، وفُرضت الصلوات الخمس.', bookName: 'الإسراء والمعراج'),
      HadithModel(number: 23, text: 'بايعته الأنصار في بيعة العقبة الأولى، وأسلم منهم 12 رجلاً.', bookName: 'العقبة الأولى'),
      HadithModel(number: 24, text: 'في بيعة العقبة الثانية، بايعه 73 رجلاً وامرأتان على النصرة.', bookName: 'العقبة الثانية'),
      HadithModel(number: 25, text: 'أذن الله له بالهجرة إلى المدينة، فهاجر مع أبي بكر الصديق.', bookName: 'الهجرة'),
      HadithModel(number: 26, text: 'اختفيا في غار ثور ثلاث ليالٍ، فقال ﷺ لأبي بكر: "لا تحزن إن الله معنا".', bookName: 'غار ثور'),
      HadithModel(number: 27, text: 'وصل ﷺ إلى قباء، وأسس أول مسجد في الإسلام.', bookName: 'مسجد قباء'),
      HadithModel(number: 28, text: 'بنى المسجد النبوي، وآخى بين المهاجرين والأنصار.', bookName: 'المسجد النبوي'),
      HadithModel(number: 29, text: 'كتب صحيفة المدينة لتنظيم العلاقات بين المسلمين واليهود.', bookName: 'الصحيفة'),
      HadithModel(number: 30, text: 'في السنة 2 هـ، انتصر المسلمون في غزوة بدر الكبرى وهم 313 رجلاً.', bookName: 'غزوة بدر'),
      HadithModel(number: 31, text: 'في السنة 3 هـ، كان اختبار المسلمين في غزوة أحد، واستشهد 70 صحابياً.', bookName: 'غزوة أحد'),
      HadithModel(number: 32, text: 'في السنة 4 هـ، وقعت غزوة بني النضير لإخراج اليهود من المدينة.', bookName: 'بني النضير'),
      HadithModel(number: 33, text: 'في السنة 5 هـ، حاصرت قريش المدينة في غزوة الخندق، فنجّاهم الله.', bookName: 'غزوة الخندق'),
      HadithModel(number: 34, text: 'في السنة 6 هـ، عقد صلح الحديبية الذي كان فتحاً مبيناً.', bookName: 'صلح الحديبية'),
      HadithModel(number: 35, text: 'في السنة 7 هـ، فتح المسلمون خيبر بعد حصارها.', bookName: 'فتح خيبر'),
      HadithModel(number: 36, text: 'في السنة 8 هـ، كان فتح مكة الأكبر، وحُطمت الأصنام حول الكعبة.', bookName: 'فتح مكة'),
      HadithModel(number: 37, text: 'قال ﷺ لأهل مكة: "اذهبوا فأنتم الطلقاء"، بعد أن كانوا يؤذونه.', bookName: 'العفو العام'),
      HadithModel(number: 38, text: 'في السنة 8 هـ، كانت غزوة حنين ثم غزوة الطائف.', bookName: 'حنين والطائف'),
      HadithModel(number: 39, text: 'في السنة 9 هـ، كانت غزوة تبوك آخر غزواته ﷺ.', bookName: 'غزوة تبوك'),
      HadithModel(number: 40, text: 'في السنة 9 هـ، وفدت القبائل العربية إلى المدينة مسلمة.', bookName: 'عام الوفود'),
      HadithModel(number: 41, text: 'في السنة 10 هـ، حج ﷺ حجة الوداع بأكثر من 100,000 مسلم.', bookName: 'حجة الوداع'),
      HadithModel(number: 42, text: 'خطب ﷺ خطبة الوداع في عرفة، وأوصى بحقوق النساء والعبيد والأموال.', bookName: 'خطبة الوداع'),
      HadithModel(number: 43, text: 'قال ﷺ: "تركت فيكم ما إن أخذتم به لن تضلوا: كتاب الله وسنتي".', bookName: 'الوصية'),
      HadithModel(number: 44, text: 'مرض ﷺ في آخر حياته، وأمر أبا بكر أن يصلي بالناس.', bookName: 'المرض'),
      HadithModel(number: 45, text: 'توفي ﷺ يوم الاثنين 12 ربيع الأول 11 هـ، وعمره 63 سنة.', bookName: 'الوفاة'),
      HadithModel(number: 46, text: 'دُفن ﷺ في حجرة عائشة رضي الله عنها، حيث مات.', bookName: 'الدفن'),
      HadithModel(number: 47, text: 'كان آخر ما قاله ﷺ: "الصلاة الصلاة وما ملكت أيمانكم".', bookName: 'آخر الوصايا'),
    ];
  }

  // الفقه
  static List<HadithModel> _getFiqh() {
    return [
      HadithModel(number: 1, text: 'قال ﷺ: "الطهور شطر الإيمان"، والطهارة شرط لصحة الصلاة.', bookName: 'فضل الطهارة'),
      HadithModel(number: 2, text: 'الوضوء: غسل الكفين، المضمضة، الاستنشاق، غسل الوجه، غسل اليدين إلى المرفقين، مسح الرأس، غسل الرجلين إلى الكعبين.', bookName: 'صفة الوضوء'),
      HadithModel(number: 3, text: 'نواقض الوضوء: الخارج من السبيلين، زوال العقل، النوم العميق، لمس الفرج بغير حائل.', bookName: 'نواقض الوضوء'),
      HadithModel(number: 4, text: 'الغسل: يجب من الجنابة، والحيض، والنفاس، وعند دخول الإسلام.', bookName: 'الغسل'),
      HadithModel(number: 5, text: 'التيمم: يُشرع عند فقد الماء أو العجز عن استعماله، بالصعيد الطاهر.', bookName: 'التيمم'),
      HadithModel(number: 6, text: 'المسح على الخفين: يجوز للمقيم يوماً وليلة، وللمسافر ثلاثة أيام بلياليها.', bookName: 'المسح على الخفين'),
      HadithModel(number: 7, text: 'شروط الصلاة: الطهارة، استقبال القبلة، ستر العورة، دخول الوقت، النية.', bookName: 'شروط الصلاة'),
      HadithModel(number: 8, text: 'أركان الصلاة: تكبيرة الإحرام، قراءة الفاتحة، الركوع، الاعتدال، السجود، الجلوس بين السجدتين، التشهد الأخير، التسليم.', bookName: 'أركان الصلاة'),
      HadithModel(number: 9, text: 'واجبات الصلاة: تكبيرات الانتقال، التسبيح في الركوع والسجود، قول "سمع الله لمن حمده".', bookName: 'واجبات الصلاة'),
      HadithModel(number: 10, text: 'سنن الصلاة: رفع اليدين، دعاء الاستفتاح، الاستعاذة، التأمين.', bookName: 'سنن الصلاة'),
      HadithModel(number: 11, text: 'مبطلات الصلاة: الكلام العمد، الأكل والشرب، الحدث، كشف العورة، تغيير النية.', bookName: 'مبطلات الصلاة'),
      HadithModel(number: 12, text: 'صلاة الجماعة: سنة مؤكدة، وأفضل من صلاة الفرد بسبع وعشرين درجة.', bookName: 'صلاة الجماعة'),
      HadithModel(number: 13, text: 'صلاة الجمعة: واجبة على الرجال الأحرار البالغين المقيمين الأصحاء.', bookName: 'صلاة الجمعة'),
      HadithModel(number: 14, text: 'صلاة المسافر: تُقصَر الرباعية إلى ركعتين، ويجوز الجمع بين الظهر والعصر.', bookName: 'صلاة المسافر'),
      HadithModel(number: 15, text: 'صلاة المريض: يصلي حسب استطاعته، قائماً أو قاعداً أو على جنب.', bookName: 'صلاة المريض'),
      HadithModel(number: 16, text: 'صلاة الخوف: تُصلى جماعة بإمام واحد، وتختلف كيفيتها حسب الحال.', bookName: 'صلاة الخوف'),
      HadithModel(number: 17, text: 'السنن الرواتب: 12 ركعة في اليوم والليلة، منها 4 قبل الظهر، و2 بعده.', bookName: 'السنن الرواتب'),
      HadithModel(number: 18, text: 'صلاة الوتر: سنة مؤكدة، وأقلها ركعة، وأكثرها 11 ركعة.', bookName: 'صلاة الوتر'),
      HadithModel(number: 19, text: 'صلاة الضحى: سنة، وأقلها ركعتان، وأكثرها 12 ركعة.', bookName: 'صلاة الضحى'),
      HadithModel(number: 20, text: 'صلاة الاستخارة: ركعتان ثم دعاء الاستخارة.', bookName: 'صلاة الاستخارة'),
      HadithModel(number: 21, text: 'الزكاة: الركن الثالث من أركان الإسلام، تجب على المسلم الحر المالك للنصاب.', bookName: 'وجوب الزكاة'),
      HadithModel(number: 22, text: 'نصاب الذهب: 85 جراماً، ونصاب الفضة: 595 جراماً.', bookName: 'نصاب الذهب والفضة'),
      HadithModel(number: 23, text: 'مقدار زكاة المال: ربع العشر (2.5%).', bookName: 'مقدار الزكاة'),
      HadithModel(number: 24, text: 'زكاة الفطر: صاع من طعام عن كل فرد، تُخرج قبل صلاة العيد.', bookName: 'زكاة الفطر'),
      HadithModel(number: 25, text: 'مصارف الزكاة الثمانية: الفقراء، المساكين، العاملون عليها، المؤلفة قلوبهم، الرقاب، الغارمون، في سبيل الله، ابن السبيل.', bookName: 'مصارف الزكاة'),
      HadithModel(number: 26, text: 'الصيام: الركن الرابع، فرض في رمضان على كل مسلم بالغ عاقل قادر مقيم.', bookName: 'وجوب الصيام'),
      HadithModel(number: 27, text: 'مفطرات الصيام: الأكل والشرب عمداً، الجماع، التقيؤ عمداً، الحيض والنفاس، الردة.', bookName: 'مفطرات الصيام'),
      HadithModel(number: 28, text: 'من أفطر ناسياً: فليتم صومه، فإنما أطعمه الله وسقاه.', bookName: 'النسيان'),
      HadithModel(number: 29, text: 'صيام التطوع: الاثنين والخميس، 13-14-15 من كل شهر، عرفة، عاشوراء.', bookName: 'صيام التطوع'),
      HadithModel(number: 30, text: 'ليلة القدر: في العشر الأواخر من رمضان، خير من ألف شهر.', bookName: 'ليلة القدر'),
      HadithModel(number: 31, text: 'الاعتكاف: سنة في العشر الأواخر من رمضان.', bookName: 'الاعتكاف'),
      HadithModel(number: 32, text: 'الحج: الركن الخامس، يجب مرة واحدة في العمر على المستطيع.', bookName: 'وجوب الحج'),
      HadithModel(number: 33, text: 'مواقيت الحج: شوال، ذو القعدة، وعشر من ذي الحجة.', bookName: 'مواقيت الحج'),
      HadithModel(number: 34, text: 'أركان الحج: الإحرام، الطواف، السعي، الوقوف بعرفة، الحلق أو التقصير.', bookName: 'أركان الحج'),
      HadithModel(number: 35, text: 'واجبات الحج: الإحرام من الميقات، الوقوف بمزدلفة، المبيت بمنى، رمي الجمار.', bookName: 'واجبات الحج'),
      HadithModel(number: 36, text: 'محظورات الإحرام: قص الشعر، تقليم الأظافر، الطيب، الصيد، النكاح، الجماع.', bookName: 'محظورات الإحرام'),
      HadithModel(number: 37, text: 'العمرة: واجبة مرة في العمر، وتُصلى بعد الطواف والسعي.', bookName: 'العمرة'),
      HadithModel(number: 38, text: 'البيع: يجب أن يكون بالتراضي، وأن يكون المبيع معلوماً ومقدوراً على تسليمه.', bookName: 'البيع'),
      HadithModel(number: 39, text: 'الربا محرم: وهو زيادة على رأس المال بغير حق، وهو من الكبائر.', bookName: 'الربا'),
      HadithModel(number: 40, text: 'الغرر محرم: وهو البيع المجهول أو المشكوك فيه.', bookName: 'الغرر'),
      HadithModel(number: 41, text: 'الإجارة: عقد على منفعة معلومة بمقابل معلوم.', bookName: 'الإجارة'),
      HadithModel(number: 42, text: 'الرهن: توثيق الدين بعين قابلة للبيع.', bookName: 'الرهن'),
      HadithModel(number: 43, text: 'النكاح: سنة مؤكدة، ويجب على من يخاف العنت.', bookName: 'النكاح'),
      HadithModel(number: 44, text: 'شروط النكاح: الولي، الشهود، الرضا، المهر، الكفاءة.', bookName: 'شروط النكاح'),
      HadithModel(number: 45, text: 'المحرمات من النساء: الأمهات، البنات، الأخوات، العمات، الخالات، بنات الأخ، بنات الأخت.', bookName: 'المحرمات'),
      HadithModel(number: 46, text: 'الطلاق: مباح لكنه أبغض الحلال إلى الله.', bookName: 'الطلاق'),
      HadithModel(number: 47, text: 'العدة: للمطلقة 3 حيض أو 3 أشهر، وللمتوفى عنها زوجها 4 أشهر و10 أيام.', bookName: 'العدة'),
      HadithModel(number: 48, text: 'النفقة: واجبة على الزوج لزوجته وأولاده بالمعروف.', bookName: 'النفقة'),
      HadithModel(number: 49, text: 'الوصية: تجوز في الثلث فقط، ولا تجوز لوارث.', bookName: 'الوصية'),
      HadithModel(number: 50, text: 'التركة: تُقسم بعد الوصية والديون على الورثة حسب الفرائض.', bookName: 'الميراث'),
    ];
  }

  static String _surahName(int number) {
    const names = [
      'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
      'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
      'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
      'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
      'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
      'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
      'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
      'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
      'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
      'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
      'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
      'المسد', 'الإخلاص', 'الفلق', 'الناس',
    ];
    if (number < 1 || number > 114) return '';
    return names[number - 1];
  }

  static void clearCache() => _cache.clear();
}
