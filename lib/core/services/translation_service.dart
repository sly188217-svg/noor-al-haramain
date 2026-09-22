import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 📚 خدمة الترجمة الشاملة
/// ✅ ترجمة واجهة التطبيق (8 لغات)
/// ✅ ترجمة آيات القرآن (AlQuran Cloud API)
/// ✅ ترجمة الكلمات المفردة (cache محلي)
/// ═══════════════════════════════════════════════════════════
class TranslationService {
  // ═══════════════════════════════════════════════════════════
  // 🌍 قائمة اللغات المتاحة
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, String>> languages = [
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'ur', 'name': 'اردو', 'flag': '🇵🇰'},
    {'code': 'id', 'name': 'Indonesia', 'flag': '🇮🇩'},
    {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
  ];

  // ═══════════════════════════════════════════════════════════
  // 📝 ترجمة واجهة التطبيق
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _translations = {
    // ═══════════════════ العربية ═══════════════════
    'ar': {
      'nav_prayer': 'الصلاة',
      'nav_quran': 'المصحف',
      'nav_library': 'المكتبة',
      'nav_azkar': 'الأذكار',
      'nav_ai': 'المساعد',
      'nav_settings': 'الإعدادات',
      'app_title': 'نور الحرمين',
      'app_subtitle': 'Noor Al-Haramain',
      'home': 'الرئيسية',
      'loading': 'جاري التحميل...',
      'error': 'حدث خطأ',
      'retry': 'إعادة المحاولة',
      'close': 'إغلاق',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'next': 'التالي',
      'previous': 'السابق',
      'play': 'تشغيل',
      'pause': 'إيقاف',
      'read_with_me': 'اقرأ معي',
      'reciter': 'القارئ',
      'speed': 'السرعة',
      'repeat': 'التكرار',
      'hifz_mode': 'وضع الحفظ',
      'tajweed': 'التجويد',
      'translation': 'الترجمة',
      'test_mode': 'وضع الاختبار',
      'my_progress': 'تقدمي',
      'ayah': 'آية',
      'surah': 'سورة',
      'accuracy': 'الدقة',
      'correct': 'صحيح',
      'wrong': 'خطأ',
      'missing': 'ناقص',
      'extra': 'زائد',
    },

    // ═══════════════════ English ═══════════════════
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
      'error': 'Error occurred',
      'retry': 'Retry',
      'close': 'Close',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'next': 'Next',
      'previous': 'Previous',
      'play': 'Play',
      'pause': 'Pause',
      'read_with_me': 'Read with Me',
      'reciter': 'Reciter',
      'speed': 'Speed',
      'repeat': 'Repeat',
      'hifz_mode': 'Hifz Mode',
      'tajweed': 'Tajweed',
      'translation': 'Translation',
      'test_mode': 'Test Mode',
      'my_progress': 'My Progress',
      'ayah': 'Ayah',
      'surah': 'Surah',
      'accuracy': 'Accuracy',
      'correct': 'Correct',
      'wrong': 'Wrong',
      'missing': 'Missing',
      'extra': 'Extra',
    },

    // ═══════════════════ Français ═══════════════════
    'fr': {
      'nav_prayer': 'Prière',
      'nav_quran': 'Coran',
      'nav_library': 'Bibliothèque',
      'nav_azkar': 'Invocations',
      'nav_ai': 'Assistant',
      'nav_settings': 'Paramètres',
      'app_title': 'Noor Al-Haramain',
      'app_subtitle': 'Nour des Deux Sanctuaires',
      'home': 'Accueil',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'retry': 'Réessayer',
      'close': 'Fermer',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'next': 'Suivant',
      'previous': 'Précédent',
      'play': 'Jouer',
      'pause': 'Pause',
      'read_with_me': 'Lis avec moi',
      'reciter': 'Récitateur',
      'speed': 'Vitesse',
      'repeat': 'Répéter',
      'hifz_mode': 'Mode Mémorisation',
      'tajweed': 'Tajwid',
      'translation': 'Traduction',
      'test_mode': 'Mode Test',
      'my_progress': 'Mes Progrès',
      'ayah': 'Verset',
      'surah': 'Sourate',
      'accuracy': 'Précision',
      'correct': 'Correct',
      'wrong': 'Incorrect',
      'missing': 'Manquant',
      'extra': 'Supplémentaire',
    },

    // ═══════════════════ Türkçe ═══════════════════
    'tr': {
      'nav_prayer': 'Namaz',
      'nav_quran': 'Kur\'an',
      'nav_library': 'Kütüphane',
      'nav_azkar': 'Zikirler',
      'nav_ai': 'Asistan',
      'nav_settings': 'Ayarlar',
      'app_title': 'Nur Al-Haremeyn',
      'app_subtitle': 'İki Harem\'in Nuru',
      'home': 'Ana Sayfa',
      'loading': 'Yükleniyor...',
      'error': 'Hata oluştu',
      'retry': 'Yeniden Dene',
      'close': 'Kapat',
      'save': 'Kaydet',
      'cancel': 'İptal',
      'delete': 'Sil',
      'edit': 'Düzenle',
      'next': 'Sonraki',
      'previous': 'Önceki',
      'play': 'Oynat',
      'pause': 'Durdur',
      'read_with_me': 'Benimle Oku',
      'reciter': 'Okuyucu',
      'speed': 'Hız',
      'repeat': 'Tekrarla',
      'hifz_mode': 'Ezber Modu',
      'tajweed': 'Tecvid',
      'translation': 'Çeviri',
      'test_mode': 'Test Modu',
      'my_progress': 'İlerlemem',
      'ayah': 'Ayet',
      'surah': 'Sure',
      'accuracy': 'Doğruluk',
      'correct': 'Doğru',
      'wrong': 'Yanlış',
      'missing': 'Eksik',
      'extra': 'Fazla',
    },

    // ═══════════════════ اردو ═══════════════════
    'ur': {
      'nav_prayer': 'نماز',
      'nav_quran': 'قرآن',
      'nav_library': 'کتب خانہ',
      'nav_azkar': 'اذکار',
      'nav_ai': 'معاون',
      'nav_settings': 'ترتیبات',
      'app_title': 'نور الحرمین',
      'app_subtitle': 'Noor Al-Haramain',
      'home': 'ہوم',
      'loading': 'لوڈ ہو رہا ہے...',
      'error': 'خرابی',
      'retry': 'دوبارہ کوشش',
      'close': 'بند کریں',
      'save': 'محفوظ کریں',
      'cancel': 'منسوخ',
      'delete': 'حذف',
      'edit': 'ترمیم',
      'next': 'اگلا',
      'previous': 'پچھلا',
      'play': 'چلائیں',
      'pause': 'رکیں',
      'read_with_me': 'میرے ساتھ پڑھیں',
      'reciter': 'قاری',
      'speed': 'رفتار',
      'repeat': 'تکرار',
      'hifz_mode': 'حفظ موڈ',
      'tajweed': 'تجوید',
      'translation': 'ترجمہ',
      'test_mode': 'ٹیسٹ موڈ',
      'my_progress': 'میری ترقی',
      'ayah': 'آیت',
      'surah': 'سورہ',
      'accuracy': 'درستگی',
      'correct': 'صحیح',
      'wrong': 'غلط',
      'missing': 'کم',
      'extra': 'زیادہ',
    },

    // ═══════════════════ Indonesia ═══════════════════
    'id': {
      'nav_prayer': 'Sholat',
      'nav_quran': 'Al-Quran',
      'nav_library': 'Perpustakaan',
      'nav_azkar': 'Dzikir',
      'nav_ai': 'Asisten',
      'nav_settings': 'Pengaturan',
      'app_title': 'Nur Al-Haramain',
      'app_subtitle': 'Cahaya Dua Tanah Suci',
      'home': 'Beranda',
      'loading': 'Memuat...',
      'error': 'Terjadi kesalahan',
      'retry': 'Coba lagi',
      'close': 'Tutup',
      'save': 'Simpan',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'edit': 'Edit',
      'next': 'Berikutnya',
      'previous': 'Sebelumnya',
      'play': 'Putar',
      'pause': 'Jeda',
      'read_with_me': 'Baca Bersamaku',
      'reciter': 'Qari',
      'speed': 'Kecepatan',
      'repeat': 'Ulangi',
      'hifz_mode': 'Mode Hafalan',
      'tajweed': 'Tajwid',
      'translation': 'Terjemahan',
      'test_mode': 'Mode Ujian',
      'my_progress': 'Kemajuanku',
      'ayah': 'Ayat',
      'surah': 'Surah',
      'accuracy': 'Akurasi',
      'correct': 'Benar',
      'wrong': 'Salah',
      'missing': 'Kurang',
      'extra': 'Lebih',
    },

    // ═══════════════════ Русский ═══════════════════
    'ru': {
      'nav_prayer': 'Молитва',
      'nav_quran': 'Коран',
      'nav_library': 'Библиотека',
      'nav_azkar': 'Азкары',
      'nav_ai': 'Помощник',
      'nav_settings': 'Настройки',
      'app_title': 'Нур аль-Харамайн',
      'app_subtitle': 'Свет двух святынь',
      'home': 'Главная',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'retry': 'Повторить',
      'close': 'Закрыть',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'edit': 'Редактировать',
      'next': 'Далее',
      'previous': 'Назад',
      'play': 'Воспроизвести',
      'pause': 'Пауза',
      'read_with_me': 'Читай со мной',
      'reciter': 'Чтец',
      'speed': 'Скорость',
      'repeat': 'Повтор',
      'hifz_mode': 'Режим заучивания',
      'tajweed': 'Таджвид',
      'translation': 'Перевод',
      'test_mode': 'Режим теста',
      'my_progress': 'Мой прогресс',
      'ayah': 'Аят',
      'surah': 'Сура',
      'accuracy': 'Точность',
      'correct': 'Правильно',
      'wrong': 'Ошибка',
      'missing': 'Пропущено',
      'extra': 'Лишнее',
    },

    // ═══════════════════ Español ═══════════════════
    'es': {
      'nav_prayer': 'Oración',
      'nav_quran': 'Corán',
      'nav_library': 'Biblioteca',
      'nav_azkar': 'Dhikr',
      'nav_ai': 'Asistente',
      'nav_settings': 'Ajustes',
      'app_title': 'Noor Al-Haramain',
      'app_subtitle': 'Luz de los Dos Santuarios',
      'home': 'Inicio',
      'loading': 'Cargando...',
      'error': 'Error',
      'retry': 'Reintentar',
      'close': 'Cerrar',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'next': 'Siguiente',
      'previous': 'Anterior',
      'play': 'Reproducir',
      'pause': 'Pausa',
      'read_with_me': 'Lee conmigo',
      'reciter': 'Recitador',
      'speed': 'Velocidad',
      'repeat': 'Repetir',
      'hifz_mode': 'Modo Memorización',
      'tajweed': 'Tajwid',
      'translation': 'Traducción',
      'test_mode': 'Modo Prueba',
      'my_progress': 'Mi Progreso',
      'ayah': 'Aleya',
      'surah': 'Sura',
      'accuracy': 'Precisión',
      'correct': 'Correcto',
      'wrong': 'Incorrecto',
      'missing': 'Faltante',
      'extra': 'Extra',
    },
  };

  // ═══════════════════════════════════════════════════════════
  // 🌐 API لترجمة الآيات (AlQuran Cloud)
  // ═══════════════════════════════════════════════════════════
  static const String _baseUrl = 'https://api.alquran.cloud/v1';

  static const Map<String, String> _editions = {
    'en': 'en.sahih',
    'fr': 'fr.hamidullah',
    'tr': 'tr.diyanet',
    'ur': 'ur.jalandhry',
    'id': 'id.indonesian',
    'ru': 'ru.kuliev',
    'es': 'es.cortes',
    'ar': 'quran-uthmani',
  };

  // ═══════════════════════════════════════════════════════════
  // 🔑 مفاتيح SharedPreferences
  // ═══════════════════════════════════════════════════════════
  static const String _prefsKey = 'translation_lang';

  // ═══════════════════════════════════════════════════════════
  // 🌍 إدارة اللغة
  // ═══════════════════════════════════════════════════════════

  /// جلب اللغة الحالية
  static Future<String> getCurrentLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) ?? 'ar';
  }

  /// حفظ اللغة
  static Future<void> setLang(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang);
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 ترجمة واجهة التطبيق
  // ═══════════════════════════════════════════════════════════

  /// الحصول على نص الترجمة
  static String getText(String lang, String key) {
    final languageMap = _translations[lang] ?? _translations['ar']!;
    return languageMap[key] ?? _translations['ar']?[key] ?? key;
  }

  /// الحصول على نص الترجمة بشكل متزامن (من cache)
  static String t(String key, {String lang = 'ar'}) {
    return getText(lang, key);
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 ترجمة آيات القرآن
  // ═══════════════════════════════════════════════════════════

  /// جلب ترجمة آية من AlQuran Cloud
  static Future<String?> getAyahTranslation({
    required int surahNumber,
    required int ayahNumber,
    required String langCode,
  }) async {
    if (langCode == 'ar') return null;

    final edition = _editions[langCode];
    if (edition == null) return null;

    try {
      final url = Uri.parse(
          '$_baseUrl/ayah/$surahNumber:$ayahNumber/$edition');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          return data['data']?['text']?.toString();
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل ترجمة الآية: $e');
    }
    return null;
  }

  /// جلب ترجمة سورة كاملة
  static Future<Map<int, String>?> getSurahTranslation({
    required int surahNumber,
    required String langCode,
  }) async {
    if (langCode == 'ar') return null;

    final edition = _editions[langCode];
    if (edition == null) return null;

    try {
      final url = Uri.parse('$_baseUrl/surah/$surahNumber/$edition');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          final ayahs = data['data']?['ayahs'] as List?;
          if (ayahs != null) {
            final result = <int, String>{};
            for (final a in ayahs) {
              final num = a['numberInSurah'] as int?;
              final text = a['text']?.toString();
              if (num != null && text != null) {
                result[num] = text;
              }
            }
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل ترجمة السورة: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 📚 ترجمة الكلمات المفردة (Cache محلي)
  // ═══════════════════════════════════════════════════════════

  static final Map<String, Map<String, String>> _wordTranslations = {
    // الفاتحة
    'بِسْمِ': {
      'en': 'In the name of',
      'fr': 'Au nom de',
      'tr': 'Adıyla',
      'ur': 'کے نام سے',
      'id': 'Dengan nama',
      'ru': 'Именем',
      'es': 'En el nombre de',
    },
    'اللَّهِ': {
      'en': 'Allah',
      'fr': 'Allah',
      'tr': 'Allah',
      'ur': 'اللہ',
      'id': 'Allah',
      'ru': 'Аллаха',
      'es': 'Alá',
    },
    'الرَّحْمَٰنِ': {
      'en': 'The Most Gracious',
      'fr': 'Le Tout Miséricordieux',
      'tr': 'Rahman',
      'ur': 'رحمٰن',
      'id': 'Maha Pengasih',
      'ru': 'Милостивый',
      'es': 'El Más Misericordioso',
    },
    'الرَّحِيمِ': {
      'en': 'The Most Merciful',
      'fr': 'Le Très Miséricordieux',
      'tr': 'Rahim',
      'ur': 'رحیم',
      'id': 'Maha Penyayang',
      'ru': 'Милосердный',
      'es': 'El Misericordioso',
    },
    'الْحَمْدُ': {
      'en': 'All praise',
      'fr': 'Toute louange',
      'tr': 'Hamd',
      'ur': 'تمام تعریف',
      'id': 'Segala puji',
      'ru': 'Хвала',
      'es': 'Toda alabanza',
    },
    'لِلَّهِ': {
      'en': 'is for Allah',
      'fr': 'est à Allah',
      'tr': 'Allah\'a',
      'ur': 'اللہ کے لیے',
      'id': 'bagi Allah',
      'ru': 'Аллаху',
      'es': 'es para Alá',
    },
    'رَبِّ': {
      'en': 'Lord',
      'fr': 'Seigneur',
      'tr': 'Rab',
      'ur': 'رب',
      'id': 'Tuhan',
      'ru': 'Господь',
      'es': 'Señor',
    },
    'الْعَالَمِينَ': {
      'en': 'of the worlds',
      'fr': 'des mondes',
      'tr': 'alemlerin',
      'ur': 'عالمین',
      'id': 'semesta alam',
      'ru': 'миров',
      'es': 'de los mundos',
    },
    'مَالِكِ': {
      'en': 'Master',
      'fr': 'Maître',
      'tr': 'Melik',
      'ur': 'مالک',
      'id': 'Penguasa',
      'ru': 'Владыка',
      'es': 'Soberano',
    },
    'يَوْمِ': {
      'en': 'Day',
      'fr': 'Jour',
      'tr': 'Gün',
      'ur': 'دن',
      'id': 'Hari',
      'ru': 'Дня',
      'es': 'Día',
    },
    'الدِّينِ': {
      'en': 'of Judgment',
      'fr': 'du Jugement',
      'tr': 'Hesap',
      'ur': 'جزا',
      'id': 'Pembalasan',
      'ru': 'Суда',
      'es': 'del Juicio',
    },
    'نَعْبُدُ': {
      'en': 'we worship',
      'fr': 'nous adorons',
      'tr': 'kulluk ederiz',
      'ur': 'ہم عبادت کرتے ہیں',
      'id': 'kami menyembah',
      'ru': 'поклоняемся',
      'es': 'adoramos',
    },
    'نَسْتَعِينُ': {
      'en': 'we seek help',
      'fr': 'nous implorons secours',
      'tr': 'yardım dileriz',
      'ur': 'مدد مانگتے ہیں',
      'id': 'kami memohon',
      'ru': 'просим помощи',
      'es': 'pedimos ayuda',
    },
    'اهْدِنَا': {
      'en': 'Guide us',
      'fr': 'Guide-nous',
      'tr': 'Bizi hidayet et',
      'ur': 'ہمیں ہدایت دے',
      'id': 'Tunjukilah kami',
      'ru': 'Веди нас',
      'es': 'Guíanos',
    },
    'الصِّرَاطَ': {
      'en': 'the path',
      'fr': 'le chemin',
      'tr': 'yolu',
      'ur': 'راستہ',
      'id': 'jalan',
      'ru': 'путь',
      'es': 'el camino',
    },
    'الْمُسْتَقِيمَ': {
      'en': 'the straight',
      'fr': 'le droit',
      'tr': 'dosdoğru',
      'ur': 'سیدھا',
      'id': 'yang lurus',
      'ru': 'прямой',
      'es': 'recto',
    },
  };

  /// ترجمة كلمة مفردة
  static String? getWordTranslation(String word, String lang) {
    if (lang == 'ar') return null;
    final clean = word.replaceAll(RegExp(r'[،.؛:!?]'), '').trim();
    return _wordTranslations[clean]?[lang];
  }
}
