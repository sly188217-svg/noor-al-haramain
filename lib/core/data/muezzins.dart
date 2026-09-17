/// ═══════════════════════════════════════════════════════════
/// بيانات المؤذنين — 12 صوت حقيقي من مصادر مجانية
/// ═══════════════════════════════════════════════════════════
class MuezzinData {
  static final List<Map<String, dynamic>> muezzins = [
    // ═══════════════════════════════════════════════════════════
    // 📦 المضمّنون (3 مؤذنين — بدون إنترنت)
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'marwan',
      'name': 'الشيخ عبد الرحمن السديس',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': true,
      'file': 'adhan_sudais.mp3',
    },
    {
      'id': 'yasser',
      'name': 'الشيخ ياسر الدوسري',
      'country': '🇸🇦 السعودية',
      'bundled': true,
      'file': 'adhan_yasser.mp3',
    },
    {
      'id': 'salah_budair',
      'name': 'الشيخ ماهر المعيقلي',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': true,
      'file': 'adhan_almuaiqly.mp3',
    },

    // ═══════════════════════════════════════════════════════════
    // 📥 القابلون للتحميل (9 مؤذنين — أصوات حقيقية)
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'afasy',
      'name': 'الشيخ مشاري العفاسي',
      'country': '🇰🇼 الكويت',
      'bundled': false,
      'file': 'adhan_alafasy.mp3',
    },
    {
      'id': 'abdalbaset',
      'name': 'الشيخ عبد الباسط عبد الصمد',
      'country': '🇪🇬 مصر',
      'bundled': false,
      'file': 'adhan_abdalbaset.mp3',
    },
    {
      'id': 'ghamdi',
      'name': 'الشيخ سعد الغامدي',
      'country': '🇸🇦 السعودية',
      'bundled': false,
      'file': 'adhan_ghamdi.mp3',
    },
    {
      'id': 'shamiree',
      'name': 'الشيخ عبد الرحمن الشميري',
      'country': '🇾🇪 اليمن',
      'bundled': false,
      'file': 'adhan_shamiree.mp3',
    },
    {
      'id': 'makkah',
      'name': 'أذان الحرم المكي',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': false,
      'file': 'adhan_makkah.mp3',
    },
    {
      'id': 'madina',
      'name': 'أذان المسجد النبوي',
      'country': '🇸🇦 المدينة المنورة',
      'bundled': false,
      'file': 'adhan_madina.mp3',
    },
    {
      'id': 'alaqsa',
      'name': 'أذان المسجد الأقصى',
      'country': '🇵🇸 القدس',
      'bundled': false,
      'file': 'adhan_alaqsa.mp3',
    },
    {
      'id': 'masr',
      'name': 'أذان مصر (عبد الباسط)',
      'country': '🇪🇬 مصر',
      'bundled': false,
      'file': 'adhan_masr.mp3',
    },
    {
      'id': 'amman',
      'name': 'أذان عمّان (الأردن)',
      'country': '🇯🇴 الأردن',
      'bundled': false,
      'file': 'adhan_amman.mp3',
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

  static String? getMuezzinFile(String muezzinId) {
    try {
      final m = muezzins.firstWhere((m) => m['id'] == muezzinId);
      return m['file'] as String?;
    } catch (e) {
      return null;
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
}
