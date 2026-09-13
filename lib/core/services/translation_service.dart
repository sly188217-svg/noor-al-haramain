class TranslationService {
  static const Map<String, Map<String, String>> _translations = {
    'ar': {
      // الشريط السفلي
      'nav_prayer': 'الصلاة',
      'nav_quran': 'المصحف',
      'nav_library': 'المكتبة',
      'nav_azkar': 'الأذكار',
      'nav_ai': 'المساعد',
      'nav_settings': 'الإعدادات',
      
      // التطبيق
      'app_title': 'نور الحرمين',
      'app_subtitle': 'Noor Al-Haramain',
      
      // الشاشات
      'home': 'الرئيسية',
      'loading': 'جاري التحميل...',
      'error': 'حدث خطأ',
      'retry': 'إعادة المحاولة',
      'close': 'إغلاق',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
    },
    'en': {
      'nav_prayer': 'Prayer',
      'nav_quran': 'Quran',
      'nav_library': 'Library',
      'nav_azkar': 'Adhkar',
      'nav_ai': 'Assistant',
      'nav_settings': 'Settings',
      'app_title': 'Noor Al-Haramain',
      'app_subtitle': 'Noor Al-Haramain',
      'home': 'Home',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'close': 'Close',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
    },
  };

  /// ✅ الحصول على النص بشكل آمن (بدون null)
  static String getText(String lang, String key) {
    // إذا اللغة غير موجودة، استخدم العربية
    final languageMap = _translations[lang] ?? _translations['ar']!;
    // إذا المفتاح غير موجود، أعد المفتاح نفسه
    return languageMap[key] ?? key;
  }
}
