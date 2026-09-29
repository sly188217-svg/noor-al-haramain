import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎨 ثيمات المصحف
/// ═══════════════════════════════════════════════════════════
class QuranTheme {
  final String id;
  final String name;
  final String emoji;

  // ألوان QcfThemeData
  final Color verseTextColor;      // لون نص الآيات
  final Color verseNumberColor;    // لون رقم الآية
  final Color basmalaColor;        // لون البسملة
  final Color headerTextColor;     // لون نص رأس السورة
  final Color pageBackgroundColor; // لون خلفية الصفحة

  // ألوان التطبيق (UI)
  final Color appBarColor;
  final Color appBarTextColor;
  final Color uiSurface;
  final Color uiText;

  const QuranTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.verseTextColor,
    required this.verseNumberColor,
    required this.basmalaColor,
    required this.headerTextColor,
    required this.pageBackgroundColor,
    required this.appBarColor,
    required this.appBarTextColor,
    required this.uiSurface,
    required this.uiText,
  });
}

class QuranThemes {
  static const List<QuranTheme> all = [
    // 📜 كلاسيكي (مصحف المدينة)
    QuranTheme(
      id: 'classic',
      name: 'كلاسيكي',
      emoji: '📜',
      verseTextColor: Color(0xFF000000),
      verseNumberColor: Color(0xFF8B4513),
      basmalaColor: Color(0xFF000000),
      headerTextColor: Color(0xFF000000),
      pageBackgroundColor: Color(0xFFFFFDF7),
      appBarColor: Color(0xFF9C7A3C),
      appBarTextColor: Color(0xFFFFFDF7),
      uiSurface: Color(0xFFFFFDF7),
      uiText: Color(0xFF1A1A1A),
    ),

    // 📄 أبيض نقي
    QuranTheme(
      id: 'white',
      name: 'أبيض',
      emoji: '📄',
      verseTextColor: Color(0xFF000000),
      verseNumberColor: Color(0xFF555555),
      basmalaColor: Color(0xFF000000),
      headerTextColor: Color(0xFF000000),
      pageBackgroundColor: Color(0xFFFFFFFF),
      appBarColor: Color(0xFF333333),
      appBarTextColor: Color(0xFFFFFFFF),
      uiSurface: Color(0xFFFFFFFF),
      uiText: Color(0xFF000000),
    ),

    // 🌙 ليلي
    QuranTheme(
      id: 'night',
      name: 'ليلي',
      emoji: '🌙',
      verseTextColor: Color(0xFFF0F0F0),
      verseNumberColor: Color(0xFFD4AF37),
      basmalaColor: Color(0xFFF0F0F0),
      headerTextColor: Color(0xFFD4AF37),
      pageBackgroundColor: Color(0xFF1A1A1A),
      appBarColor: Color(0xFF0D0D0D),
      appBarTextColor: Color(0xFFD4AF37),
      uiSurface: Color(0xFF232323),
      uiText: Color(0xFFF0F0F0),
    ),

    // 🏜️ سيبيا
    QuranTheme(
      id: 'sepia',
      name: 'سيبيا',
      emoji: '🏜️',
      verseTextColor: Color(0xFF3B2F1E),
      verseNumberColor: Color(0xFF8B6914),
      basmalaColor: Color(0xFF3B2F1E),
      headerTextColor: Color(0xFF8B6914),
      pageBackgroundColor: Color(0xFFF4ECD8),
      appBarColor: Color(0xFF8B6914),
      appBarTextColor: Color(0xFFFAF3E0),
      uiSurface: Color(0xFFFAF3E0),
      uiText: Color(0xFF3B2F1E),
    ),

    // 🌿 أخضر
    QuranTheme(
      id: 'green',
      name: 'أخضر',
      emoji: '🌿',
      verseTextColor: Color(0xFF1A1A1A),
      verseNumberColor: Color(0xFF1B5E20),
      basmalaColor: Color(0xFF1A1A1A),
      headerTextColor: Color(0xFF1B5E20),
      pageBackgroundColor: Color(0xFFE8F5E9),
      appBarColor: Color(0xFF1B5E20),
      appBarTextColor: Color(0xFFF1F8E9),
      uiSurface: Color(0xFFF1F8E9),
      uiText: Color(0xFF1A1A1A),
    ),

    // 🕌 ذهبي ملكي
    QuranTheme(
      id: 'royal',
      name: 'ذهبي',
      emoji: '🕌',
      verseTextColor: Color(0xFFF5F1E8),
      verseNumberColor: Color(0xFFD4AF37),
      basmalaColor: Color(0xFFF5F1E8),
      headerTextColor: Color(0xFFD4AF37),
      pageBackgroundColor: Color(0xFF0B132B),
      appBarColor: Color(0xFF0B132B),
      appBarTextColor: Color(0xFFD4AF37),
      uiSurface: Color(0xFF1C2541),
      uiText: Color(0xFFF5F1E8),
    ),

    // 🌸 وردي
    QuranTheme(
      id: 'rose',
      name: 'وردي',
      emoji: '🌸',
      verseTextColor: Color(0xFF3E0025),
      verseNumberColor: Color(0xFF880E4F),
      basmalaColor: Color(0xFF3E0025),
      headerTextColor: Color(0xFF880E4F),
      pageBackgroundColor: Color(0xFFFCE4EC),
      appBarColor: Color(0xFF880E4F),
      appBarTextColor: Color(0xFFFFF0F5),
      uiSurface: Color(0xFFFFF0F5),
      uiText: Color(0xFF3E0025),
    ),

    // 🌊 سماوي
    QuranTheme(
      id: 'sky',
      name: 'سماوي',
      emoji: '🌊',
      verseTextColor: Color(0xFF0D2B4E),
      verseNumberColor: Color(0xFF0D47A1),
      basmalaColor: Color(0xFF0D2B4E),
      headerTextColor: Color(0xFF0D47A1),
      pageBackgroundColor: Color(0xFFE3F2FD),
      appBarColor: Color(0xFF0D47A1),
      appBarTextColor: Color(0xFFF0F8FF),
      uiSurface: Color(0xFFF0F8FF),
      uiText: Color(0xFF0D2B4E),
    ),
  ];

  static QuranTheme getById(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => all.first,
    );
  }
}
