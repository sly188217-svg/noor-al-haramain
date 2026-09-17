/// ═══════════════════════════════════════════════════════════
/// بيانات المؤذنين — 11 صوت حقيقي من islamcan.com
/// ═══════════════════════════════════════════════════════════
class MuezzinData {
  static final List<Map<String, dynamic>> muezzins = [
    // ═══════════════════════════════════════════════════════════
    // 📦 المضمّنون (3 مؤذنين — يظهرون دائماً)
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'marwan',
      'name': 'أذان عمّان (الأردن)',
      'country': '🇯🇴 الأردن',
      'bundled': true,
    },
    {
      'id': 'yasser',
      'name': 'الشيخ ياسر الدوسري',
      'country': '🇸🇦 السعودية',
      'bundled': true,
    },
    {
      'id': 'salah_budair',
      'name': 'الشيخ ماهر المعيقلي',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': true,
    },

    // ═══════════════════════════════════════════════════════════
    // 📥 القابلون للتحميل (8 مؤذنين)
    // ═══════════════════════════════════════════════════════════
    {
      'id': 'afasy',
      'name': 'الشيخ مشاري العفاسي',
      'country': '🇰🇼 الكويت',
      'bundled': false,
    },
    {
      'id': 'abdalbaset',
      'name': 'الشيخ عبد الباسط عبد الصمد',
      'country': '🇪🇬 مصر',
      'bundled': false,
    },
    {
      'id': 'ghamdi',
      'name': 'الشيخ سعد الغامدي',
      'country': '🇸🇦 السعودية',
      'bundled': false,
    },
    {
      'id': 'shamiree',
      'name': 'الشيخ عبد الرحمن الشميري',
      'country': '🇾🇪 اليمن',
      'bundled': false,
    },
    {
      'id': 'makkah',
      'name': 'أذان الحرم المكي',
      'country': '🇸🇦 مكة المكرمة',
      'bundled': false,
    },
    {
      'id': 'madina',
      'name': 'أذان المسجد النبوي',
      'country': '🇸🇦 المدينة المنورة',
      'bundled': false,
    },
    {
      'id': 'alaqsa',
      'name': 'أذان المسجد الأقصى',
      'country': '🇵🇸 القدس',
      'bundled': false,
    },
    {
      'id': 'masr',
      'name': 'أذان مصر (عبد الباسط)',
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
}
