import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_service.dart';
import 'models/surah_model.dart';
import 'read_with_me_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — التصميم المطابق للمصحف المطبوع
/// ✅ شريط سورة مزخرف بأرابيسك على الجانبين
/// ✅ البسملة في بيضاوي (تظهر مرة واحدة فقط)
/// ✅ أرقام الآيات في دوائر ذهبية مزخرفة
/// ✅ خلفية بيضاء نقية كالمصحف الحقيقي
/// ✅ لا تكرار للبسملة
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

  // 🎨 ألوان المصحف المطبوع
  static const Color _bgColor = Color(0xFFF5EFE0);
  static const Color _paperColor = Color(0xFFFFFEF8);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _goldColor = Color(0xFFC9A961);
  static const Color _goldDark = Color(0xFF9C7A3C);
  static const Color _frameColor = Color(0xFF9C7A3C);

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
  // 🔍 هل الآية الأولى هي البسملة؟
  // ═══════════════════════════════════════════════════════════
  bool _firstAyahIsBismillah(SurahModel surah) {
    if (surah.ayahs == null || surah.ayahs!.isEmpty) return false;
    final first = surah.ayahs!.first.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return first == 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  }

  // ═══════════════════════════════════════════════════════════
  // 🎙️ اقرأ معي
  // ═══════════════════════════════════════════════════════════
  void _openReadWithMe() {
    if (_surahs.isEmpty) return;
    final surahNumber = _surahs[_currentSurahIndex].number;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadWithMeScreen(surahNumber: surahNumber),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 قائمة السور
  // ═══════════════════════════════════════════════════════════
  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
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
                decoration: const BoxDecoration(
                  color: _goldDark,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: _paperColor, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'قائمة السور',
                        style: TextStyle(
                          color: _paperColor,
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
                        color: _paperColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentSurahIndex + 1} / 114',
                        style: const TextStyle(
                            color: _paperColor, fontSize: 12),
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

                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _goldDark
                              : _goldColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: _goldDark),
                        ),
                        child: Center(
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                              color: isActive ? _paperColor : _goldDark,
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
        backgroundColor: _paperColor,
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
              borderSide: BorderSide(color: _goldColor.withValues(alpha: 0.5)),
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
                final surahIndex =
                    _surahs.indexWhere((s) => s.number == surahNumber);
                if (surahIndex >= 0) {
                  setState(() => _currentSurahIndex = surahIndex);
                  _pageController.jumpToPage(surahIndex);
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
              foregroundColor: _paperColor,
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 صفحة السورة
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahPage(SurahModel surah) {
    return Container(
      color: _bgColor,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _paperColor,
          border: Border.all(color: _frameColor, width: 3),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _frameColor, width: 1),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 📜 شريط السورة المزخرف
                _buildSurahBand(surah),
                const SizedBox(height: 16),

                // 🕌 البسملة (مرة واحدة فقط)
                if (surah.number != 9 &&
                    !_firstAyahIsBismillah(surah)) ...[
                  _buildBismillahPlaque(),
                  const SizedBox(height: 16),
                ],

                // 📖 النص القرآني
                _buildContinuousText(surah),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 📜 شريط السورة المزخرف
  Widget _buildSurahBand(SurahModel surah) {
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _SurahBandPainter(color: _goldDark),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Text(
              'سُورَةُ ${surah.name.replaceAll("سورة ", "")}',
              style: const TextStyle(
                color: _inkColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  /// 🕌 لوحة البسملة البيضاوية
  Widget _buildBismillahPlaque() {
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _BismillahPainter(color: _goldDark),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(
                color: _inkColor,
                fontSize: 19,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }

  /// 📖 النص القرآني المتواصل
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

      spans.add(TextSpan(
        text: '${ayah.text} ',
        style: TextStyle(
          color: _inkColor,
          fontSize: _fontSize,
          fontFamily: 'Amiri',
          height: 2.2,
          letterSpacing: 0.2,
        ),
      ));

      // ⭕ رقم الآية داخل دائرة مزخرفة
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildAyahNumber(ayah.number),
      ));

      spans.add(const TextSpan(text: '  '));
    }

    return RichText(
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// ⭕ دائرة رقم الآية المزخرفة (مثل الصورة)
  Widget _buildAyahNumber(int number) {
    final size = _fontSize + 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AyahMedallionPainter(color: _goldDark),
          child: Center(
            child: Text(
              _toArabicNumber(number),
              style: TextStyle(
                color: _goldDark,
                fontSize: _fontSize * 0.42,
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
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _goldDark,
        foregroundColor: _paperColor,
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
            icon: const Icon(Icons.mic),
            onPressed: _openReadWithMe,
            tooltip: '🎙️ اقرأ معي',
          ),
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
      decoration: const BoxDecoration(color: _goldDark),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: _paperColor, size: 18),
            onPressed: _currentSurahIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentSurahIndex + 1) / 114,
                    backgroundColor: _paperColor.withValues(alpha: 0.2),
                    color: _goldColor,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'سورة ${_currentSurahIndex + 1} من ١١٤',
                  style: const TextStyle(
                    color: _paperColor,
                    fontSize: 11,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: _paperColor, size: 18),
            onPressed: _currentSurahIndex < _surahs.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _paperColor,
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
              foregroundColor: _paperColor,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 Custom Painters — الزخارف
// ═══════════════════════════════════════════════════════════════

/// 📜 شريط السورة المزخرف (مطابق للصورة)
class _SurahBandPainter extends CustomPainter {
  final Color color;
  _SurahBandPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    // الإطار الرئيسي (مستطيل مستدير الأطراف)
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, 0, w, h),
      const Radius.circular(20),
    );
    canvas.drawRRect(outerRect, paint);

    // الإطار الداخلي
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(3, 3, w - 3, h - 3),
      const Radius.circular(17),
    );
    canvas.drawRRect(innerRect, paint);

    // 🌸 زخرفة يسار
    _drawArabesque(canvas, Offset(28, cy), 14, paint, fillPaint, false);

    // 🌸 زخرفة يمين
    _drawArabesque(canvas, Offset(w - 28, cy), 14, paint, fillPaint, true);

    // خطان على جانبي الاسم
    canvas.drawLine(
      Offset(60, cy),
      Offset(80, cy),
      paint,
    );
    canvas.drawLine(
      Offset(w - 60, cy),
      Offset(w - 80, cy),
      paint,
    );
  }

  void _drawArabesque(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
    Paint fill,
    bool flip,
  ) {
    // دائرة خارجية
    canvas.drawCircle(center, radius * 0.5, stroke);

    // أوراق زهرية
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2) + (flip ? math.pi / 4 : 0);
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2, fill);
    }

    // نقطة مركزية
    canvas.drawCircle(center, 2.5, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🕌 لوحة البسملة البيضاوية
class _BismillahPainter extends CustomPainter {
  final Color color;
  _BismillahPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    // الشكل البيضاوي بأطراف مدببة
    final path = Path();
    path.moveTo(15, cy);
    path.quadraticBezierTo(15, 0, 55, 0);
    path.lineTo(w - 55, 0);
    path.quadraticBezierTo(w - 15, 0, w - 15, cy);
    path.quadraticBezierTo(w - 15, h, w - 55, h);
    path.lineTo(55, h);
    path.quadraticBezierTo(15, h, 15, cy);
    path.close();
    canvas.drawPath(path, paint);

    // خط رفيع داخلي
    final innerPath = Path();
    innerPath.moveTo(19, cy);
    innerPath.quadraticBezierTo(19, 4, 57, 4);
    innerPath.lineTo(w - 57, 4);
    innerPath.quadraticBezierTo(w - 19, 4, w - 19, cy);
    innerPath.quadraticBezierTo(w - 19, h - 4, w - 57, h - 4);
    innerPath.lineTo(57, h - 4);
    innerPath.quadraticBezierTo(19, h - 4, 19, cy);
    innerPath.close();

    canvas.drawPath(
      innerPath,
      paint
        ..strokeWidth = 0.6
        ..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ⭕ دائرة رقم الآية المزخرفة (مثل الصورة)
class _AyahMedallionPainter extends CustomPainter {
  final Color color;
  _AyahMedallionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 1;

    // الدائرة الخارجية
    canvas.drawCircle(center, outerR, paint);

    // حلقة ثانية داخلية
    canvas.drawCircle(center, outerR * 0.82, paint..strokeWidth = 0.6);

    // زخرفة الزهور: 8 نقاط
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      final x = center.dx + outerR * 0.91 * math.cos(angle);
      final y = center.dy + outerR * 0.91 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.8, fillPaint);
    }

    // حلقة ثالثة داخلية
    canvas.drawCircle(center, outerR * 0.55, paint..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
