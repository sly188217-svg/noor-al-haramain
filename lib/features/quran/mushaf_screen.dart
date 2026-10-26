import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_themes.dart';

class MushafScreen extends StatefulWidget {
  final int initialPage;
  final int? initialSurah;
  const MushafScreen({super.key, this.initialPage = 1, this.initialSurah});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  double _fontSizeFactor = 1.0;
  bool _isLoading = true;
  QuranTheme _theme = QuranThemes.all.first;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSizeFactor = prefs.getDouble('quran_font_factor') ?? 1.0;
        _theme = QuranThemes.getById(prefs.getString('quran_theme_id') ?? 'classic');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _theme.pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: _theme.appBarColor,
        foregroundColor: _theme.appBarTextColor,
        title: const Text('المصحف الشريف', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      ),
      // ✅ الحل: إضافة Padding لمنع تقطيع النص
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: PageviewQuran(
            controller: _pageController,
            initialPageNumber: _currentPage,
            onPageChanged: (page) => setState(() => _currentPage = page),
            theme: QcfThemeData(
              verseTextColor: _theme.verseTextColor,
              verseNumberColor: _theme.verseNumberColor,
              basmalaColor: _theme.basmalaColor,
              headerTextColor: _theme.headerTextColor,
              pageBackgroundColor: _theme.pageBackgroundColor,
              showBasmala: true,
              showHeader: true,
            ),
          ),
        ),
      ),
    );
  }
}
