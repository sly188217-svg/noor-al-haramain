class MuezzinData {
  /// قائمة المؤذنين المتوفرين محلياً (12 مؤذناً)
  static final List<Map<String, String>> muezzins = [
    {'id': 'marwan', 'name': 'محمد مروان القصاص'},
    {'id': 'yasser', 'name': 'ياسر القطامي'},
    {'id': 'afasy', 'name': 'مشاري العفاسي'},
    {'id': 'sudais', 'name': 'عبد الرحمن السديس'},
    {'id': 'ali_jaber', 'name': 'علي جابر'},
    {'id': 'ahmad_hajjim', 'name': 'أحمد الحجيمي'},
    {'id': 'basir_dosari', 'name': 'باسر الدوسري'},
    {'id': 'abdullah_juhani', 'name': 'عبد الله عواد الجهني'},
    {'id': 'abdullah_busfar', 'name': 'عبد الله بصفر'},
    {'id': 'khalid_qahdani', 'name': 'خالد القحطاني'},
    {'id': 'salah_budair', 'name': 'صلاح البدير'},
    {'id': 'husary', 'name': 'محمود خليل الحصري'},
  ];

  /// الحصول على مسار الأذان المحلي حسب المؤذن والصلاة
  /// يعمل بدون إنترنت
  static String getLocalAdhanPath(String muezzinId, String prayerName) {
    final Map<String, String> prayerToFile = {
      'الفجر': 'fajr',
      'الشروق': 'fajr',
      'الظهر': 'dhuhr',
      'العصر': 'asr',
      'المغرب': 'maghrib',
      'العشاء': 'isha',
    };
    final fileName = prayerToFile[prayerName] ?? 'fajr';
    return 'assets/adhan/$muezzinId/$fileName.mp3';
  }

  /// الحصول على رابط الأذان من الإنترنت (احتياطي)
  static String getAdhanUrl(String muezzinId) {
    final Map<String, String> urls = {
      'marwan': 'https://server8.mp3quran.net/adhan/marwan.mp3',
      'yasser': 'https://server8.mp3quran.net/adhan/yasser.mp3',
      'afasy': 'https://server8.mp3quran.net/afasy/adhan/Fajr.mp3',
      'sudais': 'https://server8.mp3quran.net/adhan/sudais.mp3',
    };
    return urls[muezzinId] ?? urls['marwan']!;
  }

  /// الحصول على اسم المؤذن من معرفه
  static String getMuezzinName(String muezzinId) {
    try {
      return muezzins.firstWhere((m) => m['id'] == muezzinId)['name'] ?? 'مؤذن';
    } catch (e) {
      return 'مؤذن';
    }
  }
}
