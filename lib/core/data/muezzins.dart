class MuezzinData {
  /// قائمة المؤذنين المتوفرين
  static final List<Map<String, String>> muezzins = [
    {'id': 'marwan', 'name': 'الشيخ محمد مروان القصاص'},
    {'id': 'yasser', 'name': 'الشيخ ياسر القطامي'},
    {'id': 'afasy', 'name': 'الشيخ مشاري العفاسي'},
    {'id': 'sudais', 'name': 'الشيخ عبد الرحمن السديس'},
    {'id': 'ali_jaber', 'name': 'الشيخ علي جابر'},
    {'id': 'ahmad_hajjim', 'name': 'الشيخ أحمد الحجيمي'},
    {'id': 'basir_dosari', 'name': 'الشيخ ياسر الدوسري'},
    {'id': 'abdullah_juhani', 'name': 'الشيخ عبد الله عواد الجهني'},
    {'id': 'abdullah_busfar', 'name': 'الشيخ عبد الله بصفر'},
    {'id': 'khalid_qahdani', 'name': 'الشيخ خالد القحطاني'},
    {'id': 'salah_budair', 'name': 'الشيخ صلاح البدير'},
    {'id': 'husary', 'name': 'الشيخ محمود خليل الحصري'},
  ];

  /// ✅ روابط التحميل (نفس الموجودة في AdhanDownloadService)
  static final Map<String, String> _urls = {
    'marwan': 'https://www.islamcan.com/audio/adhan/azan1.mp3',
    'yasser': 'https://www.islamcan.com/audio/adhan/azan2.mp3',
    'afasy': 'https://www.islamcan.com/audio/adhan/azan3.mp3',
    'sudais': 'https://www.islamcan.com/audio/adhan/azan4.mp3',
    'ali_jaber': 'https://www.islamcan.com/audio/adhan/azan5.mp3',
    'ahmad_hajjim': 'https://www.islamcan.com/audio/adhan/azan6.mp3',
    'basir_dosari': 'https://www.islamcan.com/audio/adhan/azan7.mp3',
    'abdullah_juhani': 'https://www.islamcan.com/audio/adhan/azan8.mp3',
    'abdullah_busfar': 'https://www.islamcan.com/audio/adhan/azan9.mp3',
    'khalid_qahdani': 'https://www.islamcan.com/audio/adhan/azan10.mp3',
    'salah_budair': 'https://www.islamcan.com/audio/adhan/azan11.mp3',
    'husary': 'https://www.islamcan.com/audio/adhan/azan12.mp3',
  };

  /// مسار الأذان المحلي (يُستخدم إذا وُجد في assets)
  static String getLocalAdhanPath(String muezzinId, String prayerName) {
    return 'assets/adhan/$muezzinId/$prayerName.mp3';
  }

  /// رابط الإنترنت
  static String getAdhanUrl(String muezzinId) {
    return _urls[muezzinId] ?? _urls['marwan']!;
  }

  /// اسم المؤذن من معرفه
  static String getMuezzinName(String muezzinId) {
    try {
      return muezzins.firstWhere((m) => m['id'] == muezzinId)['name'] ?? 'مؤذن';
    } catch (e) {
      return 'مؤذن';
    }
  }

  /// قائمة المؤذنين الذين يحتاجون تحميلاً
  static List<String> get allIds => muezzins.map((m) => m['id']!).toList();
}
