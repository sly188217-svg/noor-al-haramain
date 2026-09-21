import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_service.dart';
import 'models/surah_model.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — تصميم احترافي كالمصحف الحقيقي
/// ✅ إطار مزخرف متعدد الطبقات
/// ✅ خلفية ورقية كريمية
/// ✅ خط Amiri للنص القرآني
/// ✅ أرقام آيات في دوائر ذهبية مزخرفة
/// ✅ رأس سورة بزخرفة إسلامية
/// ═══════════════════════════════════════════════════════════
class MushafScreen extends StatefulWidget {
  final int initialSurah;

  const MushafScreen({super.key, this.initialSurah = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SurahModel> _surahs = [];
  int _currentSurahIndex = 0;
  bool _isLoading = true;
  bool _isPlaying = false;
  String _selectedReciter = 'maher';
  double _fontSize = 26.0;

  // ═══════════════════════════════════════════════════════════
  // 🎨 ألوان المصحف الشريف
  // ═══════════════════════════════════════════════════════════
  static const Color _paperColor = Color(0xFFFAF3E0); // ورق كريمي
  static const Color _innerPaper = Color(0xFFFFFBF0); // ورق داخلي
  static const Color _inkColor = Color(0xFF1A1A1A); // حبر أسود
  static const Color _goldDark = Color(0xFFB8860B); // ذهبي غامق
  static const Color _goldLight = Color(0xFFD4AF37); // ذهبي فاتح
  static const Color _borderColor = Color(0xFF8B6F47); // بني محروق

  @override
  void initState() {
    super.initState();
    _currentSurahIndex = widget.initialSurah - 1;
    _loadQuran();
    _loadPreferences();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedReciter = prefs.getString('quran_reciter') ?? 'maher';
        _fontSize = prefs.getDouble('quran_font_size') ?? 26.0;
      });
    }
  }

  Future<void> _loadQuran() async {
    try {
      final surahs = await QuranService.loadQuran();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ فشل تحميل القرآن: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 قائمة السور
  // ═══════════════════════════════════════════════════════════
  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _innerPaper,
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
                  color: _goldDark,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: _innerPaper, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'قائمة السور',
                        style: TextStyle(
                          color: _innerPaper,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _innerPaper.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentSurahIndex + 1} / 114',
                        style: const TextStyle(
                            color: _innerPaper, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _surahs.length,
                  itemBuilder: (context, index) {
                    final surah = _surahs[index];
                    final isActive = index == _currentSurahIndex;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _goldLight.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isActive
                            ? Border.all(color: _goldLight, width: 1.5)
                            : null,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _goldDark
                                : _goldLight.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? _goldDark : _goldLight,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${surah.number}',
                              style: TextStyle(
                                color: isActive
                                    ? _innerPaper
                                    : _goldDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          surah.name,
                          style: TextStyle(
                            color: _inkColor,
                            fontSize: 17,
                            fontFamily: 'Amiri',
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${surah.numberOfAyahs} آية • ${surah.revelationType == "Meccan" ? "مكية" : "مدنية"}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentSurahIndex = index);
                          _pageController.jumpToPage(index);
                        },
                      ),
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
  // 🎧 تشغيل السورة
  // ═══════════════════════════════════════════════════════════
  Future<void> _playSurah() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      final surahNumber = _surahs[_currentSurahIndex].number;
      final url = QuranService.getRecitationUrl(surahNumber, _selectedReciter);

      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _isPlaying = true);

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تعذر تشغيل التلاوة')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 البحث
  // ═══════════════════════════════════════════════════════════
  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _innerPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _goldDark, width: 1.5),
        ),
        title: const Text('🔍 البحث في المصحف',
            style: TextStyle(color: _goldDark, fontFamily: 'Amiri')),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _inkColor),
          decoration: InputDecoration(
            hintText: 'اكتب كلمة للبحث...',
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: const Icon(Icons.search, color: _goldDark),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: _goldLight.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: _goldLight.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final query = controller.text.trim();
              if (query.isEmpty) return;
              Navigator.pop(context);

              try {
                final results = await QuranService.searchQuran(query);
                if (results.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ لا توجد نتائج')),
                    );
                  }
                  return;
                }
                final first = results.first;
                final surahNumber = first['surahNumber'] as int;
                final surahIndex = _surahs
                    .indexWhere((s) => s.number == surahNumber);
                if (surahIndex >= 0) {
                  setState(() => _currentSurahIndex = surahIndex);
                  _pageController.jumpToPage(surahIndex);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '🔍 ${results.length} نتيجة — ${first['surahName']} آية ${first['ayahNumber']}'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('⚠️ خطأ: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldDark,
              foregroundColor: _innerPaper,
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 صفحة السورة الكاملة
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahPage(SurahModel surah) {
    return Container(
      color: _paperColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Container(
          // 🌟 الإطار الخارجي المزخرف
          decoration: BoxDecoration(
            color: _innerPaper,
            border: Border.all(color: _goldDark, width: 3),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _goldDark.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            // 🌟 الإطار الداخلي المزدوج
            decoration: BoxDecoration(
              border: Border.all(color: _goldLight, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ═══════════════════════════════════════════════════
                // 📜 رأس السورة المزخرف
                // ═══════════════════════════════════════════════════
                _buildOrnateHeader(surah),

                const SizedBox(height: 18),

                // ═══════════════════════════════════════════════════
                // 🕌 البسملة داخل إطار فني (ما عدا التوبة)
                // ═══════════════════════════════════════════════════
                if (surah.number != 9) ...[
                  _buildBismillah(),
                  const SizedBox(height: 18),
                ],

                // ═══════════════════════════════════════════════════
                // 📖 النص القرآني المتواصل
                // ═══════════════════════════════════════════════════
                _buildContinuousText(surah),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 📜 رأس سورة مزخرف بشكل احترافي
  Widget _buildOrnateHeader(SurahModel surah) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _innerPaper,
        border: Border.all(color: _goldDark, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: _goldLight, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // زخرفة يسار
            const _OrnateDecoration(isLeft: true),
            const SizedBox(width: 14),
            // اسم السورة
            Flexible(
              child: Text(
                surah.name,
                style: const TextStyle(
                  color: _inkColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 14),
            // زخرفة يمين
            const _OrnateDecoration(isLeft: false),
          ],
        ),
      ),
    );
  }

  /// 🕌 بسملة داخل إطار فني
  Widget _buildBismillah() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: _goldLight, width: 1.5),
          borderRadius: BorderRadius.circular(30),
          color: _goldLight.withValues(alpha: 0.08),
        ),
        child: const Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          style: TextStyle(
            color: _inkColor,
            fontSize: 22,
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
            height: 1.8,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  /// 📖 النص القرآني المتواصل الاحترافي
  Widget _buildContinuousText(SurahModel surah) {
    if (surah.ayahs == null || surah.ayahs!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'لا توجد آيات',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    final List<InlineSpan> spans = [];

    for (int i = 0; i < surah.ayahs!.length; i++) {
      final ayah = surah.ayahs![i];

      // نص الآية
      spans.add(TextSpan(
        text: '${ayah.text} ',
        style: TextStyle(
          color: _inkColor,
          fontSize: _fontSize,
          fontFamily: 'Amiri',
          height: 2.4,
          letterSpacing: 0.2,
        ),
      ));

      // رقم الآية داخل دائرة مزخرفة
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildAyahNumber(ayah.number),
      ));

      spans.add(const TextSpan(text: '  '));
    }

    return RichText(
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// ⭕ دائرة رقم الآية المزخرفة
  Widget _buildAyahNumber(int number) {
    final size = _fontSize + 8;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _innerPaper,
        shape: BoxShape.circle,
        border: Border.all(color: _goldDark, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: _goldDark.withValues(alpha: 0.2),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _goldLight.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              _toArabicNumber(number),
              style: TextStyle(
                color: _goldDark,
                fontSize: _fontSize * 0.48,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// تحويل الأرقام إلى أرقام عربية
  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الواجهة الرئيسية
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paperColor,
      appBar: AppBar(
        backgroundColor: _goldDark,
        foregroundColor: _innerPaper,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _surahs.isEmpty
                    ? 'المصحف الشريف'
                    : _surahs[_currentSurahIndex].name,
                style: const TextStyle(
                  fontSize: 17,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizeDialog,
            tooltip: 'حجم الخط',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'بحث',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showSurahPicker,
            tooltip: 'قائمة السور',
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _playSurah,
            tooltip: 'استمع',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _goldDark))
          : _surahs.isEmpty
              ? const Center(
                  child: Text(
                    '⚠️ تعذر تحميل المصحف',
                    style: TextStyle(color: _inkColor),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _surahs.length,
                        onPageChanged: (index) {
                          setState(() => _currentSurahIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return _buildSurahPage(_surahs[index]);
                        },
                      ),
                    ),
                    _buildBottomNav(),
                  ],
                ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _goldDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: _innerPaper, size: 18),
            onPressed: _currentSurahIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            tooltip: 'السابقة',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentSurahIndex + 1) / 114,
                    backgroundColor:
                        _innerPaper.withValues(alpha: 0.2),
                    color: _goldLight,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'سورة ${_currentSurahIndex + 1} من ١١٤',
                  style: const TextStyle(
                    color: _innerPaper,
                    fontSize: 11,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: _innerPaper, size: 18),
            onPressed: _currentSurahIndex < _surahs.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            tooltip: 'التالية',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 نافذة حجم الخط
  // ═══════════════════════════════════════════════════════════
  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _innerPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _goldDark, width: 1.5),
        ),
        title: const Text('🔤 حجم الخط',
            style: TextStyle(color: _goldDark, fontFamily: 'Amiri')),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'حجم النص: ${_fontSize.toInt()}',
                  style: const TextStyle(color: _inkColor),
                ),
                Slider(
                  value: _fontSize,
                  min: 18,
                  max: 40,
                  divisions: 22,
                  activeColor: _goldDark,
                  label: _fontSize.toInt().toString(),
                  onChanged: (v) {
                    setDialogState(() => _fontSize = v);
                    setState(() {});
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('إغلاق', style: TextStyle(color: _goldDark)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('quran_font_size', _fontSize);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldDark,
              foregroundColor: _innerPaper,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 زخرفة جانبية لرأس السورة (Custom Painter)
// ═══════════════════════════════════════════════════════════════
class _OrnateDecoration extends StatelessWidget {
  final bool isLeft;
  const _OrnateDecoration({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 20,
      child: CustomPaint(
        painter: _OrnatePainter(
          color: const Color(0xFFB8860B),
          flip: isLeft,
        ),
      ),
    );
  }
}

class _OrnatePainter extends CustomPainter {
  final Color color;
  final bool flip;
  _OrnatePainter({required this.color, this.flip = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // زخرفة: خط + حلقة + نقطة
    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width * 0.5, size.height / 2);
    canvas.drawPath(path, paint);

    // حلقة
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height / 2),
      size.height * 0.35,
      paint,
    );

    // نقطة داخل الحلقة
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height / 2),
      2,
      fillPaint,
    );

    // خط أخير
    final path2 = Path();
    path2.moveTo(size.width * 0.8, size.height / 2);
    path2.lineTo(size.width, size.height / 2);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
