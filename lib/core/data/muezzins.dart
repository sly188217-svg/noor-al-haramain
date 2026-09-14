/// ═══════════════════════════════════════════════════════════
/// بيانات المؤذنين
/// ═══════════════════════════════════════════════════════════
/// 
/// 📦 مضمّن (bundled): 3 مؤذنين في التطبيق — يعملون بدون إنترنت
/// 📥 للتحميل: 9 مؤذنين من الإنترنت
class MuezzinData {
  static final List<Map<String, dynamic>> muezzins = [
    // ═══════════════════════════════════════════════════════════
    // 📦 المؤذنون المضمّنون (يعملون بدون إنترنت)
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'marwan',
      'name': 'الشيخ محمد مروان القصاص',
      'country': '🇸🇾 سوريا',
      'bundled': true,
    },
    {
      'id': 'yasser',
      'name': 'الشيخ ياسر القطامي',
      'country': '🇸🇦 السعودية',
      'bundled': true,
    },
    {
      'id': 'salah_budair',
      'name': 'الشيخ صلاح البدير',
      'country': '🇸🇦 المدينة المنورة',
      'bundled': true,
    },

    // ═══════════════════════════════════════════════════════════
    // 📥 المؤذنون القابلون للتحميل
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'afasy',
      'name': 'الشيخ مشاري العفاسي',
      'country': '🇰🇼 الكويت',
      'bundled': false,
    },
    {
      'id': 'sudais',
      'name': 'الشيخ عبد الرحمن السديس',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': false,
    },
    {
      'id': 'ali_jaber',
      'name': 'الشيخ علي جابر',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': false,
    },
    {
      'id': 'ahmad_hajjim',
      'name': 'الشيخ أحمد الحجيمي',
      'country': '🇸🇦 السعودية',
      'bundled': false,
    },
    {
      'id': 'basir_dosari',
      'name': 'الشيخ ياسر الدوسري',
      'country': '🇸🇦 السعودية',
      'bundled': false,
    },
    {
      'id': 'abdullah_juhani',
      'name': 'الشيخ عبد الله عواد الجهني',
      'country': '🇸🇦 السعودية',
      'bundled': false,
    },
    {
      'id': 'abdullah_busfar',
      'name': 'الشيخ عبد الله بصفر',
      'country': '🇾🇪 اليمن',
      'bundled': false,
    },
    {
      'id': 'khalid_qahdani',
      'name': 'الشيخ خالد القحطاني',
      'country': '🇸🇦 السعودية',
      'bundled': false,
    },
    {
      'id': 'husary',
      'name': 'الشيخ محمود خليل الحصري',
      'country': '🇪🇬 مصر',
      'bundled': false,
    },
  ];

  static String getMuezzinName(String muezzinId) {
    try {
      final m = muezzins.firstWhere((m) => m['id'] == muezzinId);
      return m['name'] as String;
    } catch (e) {
      return 'مؤذن';
    }
  }

  static String getMuezzinCountry(String muezzinId) {
    try {
      final m = muezzins.firstWhere((m) => m['id'] == muezzinId);
      return m['country'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  static bool isBundled(String muezzinId) {
    try {
      final m = muezzins.firstWhere((m) => m['id'] == muezzinId);
      return m['bundled'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  static List<Map<String, dynamic>> get bundledMuezzins =>
      muezzins.where((m) => m['bundled'] == true).toList();

  static List<Map<String, dynamic>> get downloadableMuezzins =>
      muezzins.where((m) => m['bundled'] == false).toList();

  static int get bundledCount =>
      muezzins.where((m) => m['bundled'] == true).length;

  static int get downloadableCount =>
      muezzins.where((m) => m['bundled'] == false).length;

  static String getLocalAdhanPath(String muezzinId, String prayerName) {
    return 'assets/adhan/$muezzinId/adhan.mp3';
  }
}
