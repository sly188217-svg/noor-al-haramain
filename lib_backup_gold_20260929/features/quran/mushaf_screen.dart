import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_themes.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — QCF (مطابق للمصحف المطبوع)
/// ✅ خطوط QCF الأصلية لكل صفحة
/// ✅ 604 صفحة مطابقة لمصحف المدينة
/// ✅ 8 ثيمات قابلة للتغيير
/// ✅ البسملة فوق السورة (غير مرقمة)
/// ═══════════════════════════════════════════════════════════
class MushafScreen extends StatefulWidget {
  final int initialPage;
  final int? initialSurah;

  const MushafScreen({
    super.key,
    this.initialPage = 1,
    this.initialSurah,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  double _fontSizeFactor = 1.0;
  bool _isLoading = true;
  bool _showControls = true;
  QuranTheme _theme = QuranThemes.all.first;

  @override
  void initState() {
    super.initState();
    _currentPage = _resolveInitialPage();
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadPreferences();
  }

  int _resolveInitialPage() {
    if (widget.initialSurah != null) {
      try {
        final page = getPageNumber(widget.initialSurah!, 1);
        if (page > 0) return page;
      } catch (_) {}
    }
    return widget.initialPage.clamp(1, 604);
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _fontSizeFactor =
            prefs.getDouble('quran_font_factor') ?? 1.0;
        final themeId = prefs.getString('quran_theme_id') ?? 'classic';
        _theme = QuranThemes.getById(themeId);
        final savedPage = prefs.getInt('quran_last_page');
        if (savedPage != null &&
            savedPage > 0 &&
            widget.initialSurah == null) {
          _currentPage = savedPage.clamp(1, 604);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentPage - 1);
            }
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('quran_font_factor', size);
  }

  Future<void> _saveTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_theme_id', themeId);
  }

  Future<void> _saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _pageController.jumpToPage(page - 1);
    setState(() => _currentPage = page);
    _saveCurrentPage(page);
  }

  void _nextPage() => _goToPage(_currentPage + 1);
  void _prevPage() => _goToPage(_currentPage - 1);

  // ═══════════════════════════════════════════════════════════
  // 🎨 نافذة اختيار الثيم
  // ═══════════════════════════════════════════════════════════
  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.uiSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _theme.appBarColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.palette,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '🎨 اختر ثيم المصحف',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: QuranThemes.all.length,
                  itemBuilder: (context, index) {
                    final theme = QuranThemes.all[index];
                    final isSelected = theme.id == _theme.id;
                    return _buildThemeCard(theme, isSelected);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeCard(QuranTheme theme, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _theme = theme);
        _saveTheme(theme.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تطبيق ثيم "${theme.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.pageBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.appBarColor
                : theme.appBarColor.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(theme.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    theme.name,
                    style: TextStyle(
                      color: theme.uiText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.pageBackgroundColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            theme.verseTextColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'بِسْمِ ٱللَّهِ',
                      style: TextStyle(
                        color: theme.verseTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: theme.appBarColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 قائمة السور
  // ═══════════════════════════════════════════════════════════
  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.uiSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _theme.appBarColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '📖 قائمة السور',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '114 سورة',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 114,
                  itemBuilder: (context, index) {
                    final surahNumber = index + 1;
                    String surahName;
                    try {
                      surahName = getSurahNameArabic(surahNumber);
                    } catch (_) {
                      surahName = 'سورة $surahNumber';
                    }
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _theme.appBarColor
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: _theme.appBarColor),
                        ),
                        child: Center(
                          child: Text(
                            '$surahNumber',
                            style: TextStyle(
                              color: _theme.appBarColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        surahName,
                        style: TextStyle(
                          color: _theme.uiText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        try {
                          final page =
                              getPageNumber(surahNumber, 1);
                          _goToPage(page);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('⚠️ تعذر الانتقال: $e')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 حجم الخط
  // ═══════════════════════════════════════════════════════════
  void _showFontSizeDialog() {
    double tempSize = _fontSizeFactor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _theme.uiSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _theme.appBarColor, width: 1.5),
        ),
        title: Text(
          '🔤 حجم الخط',
          style: TextStyle(color: _theme.appBarColor),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الحجم: ${(tempSize * 100).toInt()}%',
                  style: TextStyle(color: _theme.uiText),
                ),
                Slider(
                  value: tempSize,
                  min: 0.7,
                  max: 1.5,
                  divisions: 16,
                  activeColor: _theme.appBarColor,
                  label: '${(tempSize * 100).toInt()}%',
                  onChanged: (v) =>
                      setDialogState(() => tempSize = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveFontSize(tempSize);
              if (mounted) {
                setState(() => _fontSizeFactor = tempSize);
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.appBarColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 البناء الرئيسي
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _theme.pageBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
              color: _theme.appBarColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _theme.pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: _theme.appBarColor,
        foregroundColor: _theme.appBarTextColor,
        elevation: 0,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 20),
            SizedBox(width: 8),
            Text(
              'المصحف الشريف',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showThemePicker,
            tooltip: '🎨 الثيم',
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizeDialog,
            tooltip: '🔤 حجم الخط',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showSurahPicker,
            tooltip: '📋 السور',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // ═══════════════════════════════════════════════
            // 📖 عرض المصحف بـ QCF
            // ═══════════════════════════════════════════════
            PageviewQuran(
              controller: _pageController,
              initialPageNumber: _currentPage,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _saveCurrentPage(page);
              },
              theme: QcfThemeData(
                // ✅ المعاملات الصحيحة من المكتبة
                verseTextColor: _theme.verseTextColor,
                verseNumberColor: _theme.verseNumberColor,
                basmalaColor: _theme.basmalaColor,
                headerTextColor: _theme.headerTextColor,
                pageBackgroundColor: _theme.pageBackgroundColor,
                // إظهار البسملة فوق السورة (غير مرقمة)
                showBasmala: true,
                showHeader: true,
              ),
            ),

            // شريط معلومات علوي
            if (_showControls)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: _buildInfoBar(),
              ),

            // شريط تنقل سفلي
            if (_showControls)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _buildBottomNav(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _theme.uiSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _theme.appBarColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${_theme.emoji} ${_theme.name}',
              style: TextStyle(
                color: _theme.appBarColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _theme.appBarColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'صفحة $_currentPage / 604',
              style: TextStyle(
                color: _theme.appBarColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _theme.uiSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _theme.appBarColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: _theme.appBarColor, size: 18),
            onPressed: _currentPage > 1 ? _prevPage : null,
            tooltip: 'السابق',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _currentPage / 604,
                    backgroundColor:
                        _theme.appBarColor.withValues(alpha: 0.15),
                    color: _theme.appBarColor,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الصفحة $_currentPage من 604',
                  style: TextStyle(
                    color: _theme.appBarColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: _theme.appBarColor, size: 18),
            onPressed: _currentPage < 604 ? _nextPage : null,
            tooltip: 'التالي',
          ),
        ],
      ),
    );
  }
}
