import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_service.dart';
import 'models/surah_model.dart';
import 'read_with_me_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — مطابقة للمصحف المدني المطبوع
/// ✅ إطار مزخرف بأربع طبقات مع زخارف الزوايا
/// ✅ شريط سورة بأرابيسك كامل
/// ✅ بسملة في لوحة بيضاوية بأطراف مدببة
/// ✅ مداليات الآيات بأشكال زهرية
/// ✅ خلفية ورقية كريمية
/// ✅ خط Amiri بخطوط ضبط عالية
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
  double _fontSize = 24.0;

  // 🎨 ألوان المصحف المدني المطبوع
  static const Color _bgColor = Color(0xFFEDE4D0);
  static const Color _paperColor = Color(0xFFFFFDF6);
  static const Color _inkColor = Color(0xFF1F1B16);
  static const Color _goldColor = Color(0xFFB8860B);
  static const Color _goldLight = Color(0xFFD4AF37);
  static const Color _frameColor = Color(0xFF7A5F1A);
  static const Color _decorColor = Color(0xFF8B6F2C);

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
        _fontSize = prefs.getDouble('quran_font_size') ?? 24.0;
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
  // 🔍 كشف البسملة للتصفية
  // ═══════════════════════════════════════════════════════════
  bool _isBismillah(String text) {
    final clean = text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    return clean.startsWith('بسم') &&
        clean.contains('الله') &&
        clean.contains('الرحمن') &&
        clean.contains('الرحيم') &&
        clean.length <= 30;
  }

  void _openReadWithMe() {
    if (_surahs.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadWithMeScreen(
          surahNumber: _surahs[_currentSurahIndex].number,
        ),
      ),
    );
  }

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
                  color: _decorColor,
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
                              ? _decorColor
                              : _goldColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: _decorColor),
                        ),
                        child: Center(
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                              color: isActive ? _paperColor : _decorColor,
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

  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _paperColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _decorColor, width: 1.5),
        ),
        title: const Text('🔍 البحث في المصحف',
            style: TextStyle(color: _decorColor, fontFamily: 'Amiri')),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _inkColor),
          decoration: InputDecoration(
            hintText: 'اكتب كلمة للبحث...',
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: const Icon(Icons.search, color: _decorColor),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: _goldColor.withValues(alpha: 0.5)),
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
              backgroundColor: _decorColor,
              foregroundColor: _paperColor,
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 صفحة السورة — مطابقة للمصحف المدني
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahPage(SurahModel surah) {
    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(4),
      child: Container(
        // ═══ الإطار الخارجي (أسود سميك) ═══
        decoration: BoxDecoration(
          color: _paperColor,
          border: Border.all(color: _frameColor, width: 2.5),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          // ═══ الإطار الثاني (ذهبي) ═══
          decoration: BoxDecoration(
            border: Border.all(color: _decorColor, width: 1.2),
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            // ═══ الإطار الثالث (ذهبي رفيع) ═══
            decoration: BoxDecoration(
              border: Border.all(
                color: _decorColor.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              // ═══ الإطار الرابع الداخلي ═══
              decoration: BoxDecoration(
                border: Border.all(
                  color: _decorColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 📜 شريط السورة
                    _buildSurahBand(surah),
                    const SizedBox(height: 12),

                    // 🕌 البسملة في اللوحة
                    if (surah.number != 9) ...[
                      _buildBismillahPlaque(),
                      const SizedBox(height: 12),
                    ],

                    // 📖 النص القرآني
                    _buildContinuousText(surah),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 📜 شريط السورة المزخرف (بطول كامل مثل المصحف)
  Widget _buildSurahBand(SurahModel surah) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: _decorColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: _decorColor.withValues(alpha: 0.5),
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            // 🎨 زخرفة يسار
            const SizedBox(width: 6),
            _buildCornerOrnament(),
            // 📛 اسم السورة
            Expanded(
              child: Center(
                child: Text(
                  _formatSurahName(surah),
                  style: const TextStyle(
                    color: _inkColor,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 🎨 زخرفة يمين
            _buildCornerOrnament(),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerOrnament() {
    return SizedBox(
      width: 28,
      height: 20,
      child: CustomPaint(
        painter: _CornerOrnamentPainter(color: _decorColor),
      ),
    );
  }

  String _formatSurahName(SurahModel surah) {
    final name = surah.name.replaceAll('سورة ', '').trim();
    final type = surah.revelationType == 'Meccan' ? 'مكية' : 'مدنية';
    final ayahs = surah.numberOfAyahs;
    return 'سُورَةُ $name — $type — $ayahs آية';
  }

  /// 🕌 لوحة البسملة البيضاوية
  Widget _buildBismillahPlaque() {
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _BismillahPlaquePainter(color: _decorColor),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 60),
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(
                color: _inkColor,
                fontSize: 20,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }

  /// 📖 النص القرآني (مع تصفية البسملة + مداليات الآيات)
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

      // 🚫 تصفية البسملة من الآيات
      if (_isBismillah(ayah.text)) continue;

      spans.add(TextSpan(
        text: '${ayah.text} ',
        style: TextStyle(
          color: _inkColor,
          fontSize: _fontSize,
          fontFamily: 'Amiri',
          height: 2.2,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w400,
        ),
      ));

      // ⭕ مدالية رقم الآية
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildAyahMedallion(ayah.number),
      ));

      spans.add(const TextSpan(text: '  '));
    }

    return RichText(
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// ⭕ مدالية رقم الآية (شكل زهري كالمصحف)
  Widget _buildAyahMedallion(int number) {
    final size = _fontSize + 6;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AyahMedallionPainter(color: _decorColor),
          child: Center(
            child: Text(
              _toArabicNumber(number),
              style: TextStyle(
                color: _decorColor,
                fontSize: _fontSize * 0.38,
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
        backgroundColor: _decorColor,
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
              child: CircularProgressIndicator(color: _decorColor))
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
      decoration: const BoxDecoration(color: _decorColor),
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
                    color: _goldLight,
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
          side: const BorderSide(color: _decorColor, width: 1.5),
        ),
        title: const Text('🔤 حجم الخط',
            style: TextStyle(color: _decorColor, fontFamily: 'Amiri')),
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
                  min: 16,
                  max: 36,
                  divisions: 20,
                  activeColor: _decorColor,
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
                const Text('إغلاق', style: TextStyle(color: _decorColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('quran_font_size', _fontSize);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _decorColor,
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
// 🎨 Custom Painters
// ═══════════════════════════════════════════════════════════════

/// 🎨 زخرفة جانبية لشريط السورة
class _CornerOrnamentPainter extends CustomPainter {
  final Color color;
  _CornerOrnamentPainter({required this.color});

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

    // خط أفقي
    canvas.drawLine(Offset(0, cy), Offset(w * 0.3, cy), paint);

    // حلقة
    canvas.drawCircle(Offset(w * 0.45, cy), 4, paint);
    canvas.drawCircle(Offset(w * 0.45, cy), 1.8, fillPaint);

    // نجمة صغيرة
    final starPath = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2) - math.pi / 2;
      final x = w * 0.7 + 4 * math.cos(angle);
      final y = cy + 4 * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, paint);

    // خط أخير
    canvas.drawLine(Offset(w * 0.85, cy), Offset(w, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🕌 لوحة البسملة البيضاوية
class _BismillahPlaquePainter extends CustomPainter {
  final Color color;
  _BismillahPlaquePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    // الشكل البيضاوي الخارجي
    final path = Path();
    path.moveTo(20, cy);
    path.quadraticBezierTo(20, 0, 60, 0);
    path.lineTo(w - 60, 0);
    path.quadraticBezierTo(w - 20, 0, w - 20, cy);
    path.quadraticBezierTo(w - 20, h, w - 60, h);
    path.lineTo(60, h);
    path.quadraticBezierTo(20, h, 20, cy);
    path.close();
    canvas.drawPath(path, paint);

    // خط رفيع داخلي
    final innerPath = Path();
    innerPath.moveTo(24, cy);
    innerPath.quadraticBezierTo(24, 4, 62, 4);
    innerPath.lineTo(w - 62, 4);
    innerPath.quadraticBezierTo(w - 24, 4, w - 24, cy);
    innerPath.quadraticBezierTo(w - 24, h - 4, w - 62, h - 4);
    innerPath.lineTo(62, h - 4);
    innerPath.quadraticBezierTo(24, h - 4, 24, cy);
    innerPath.close();

    canvas.drawPath(
      innerPath,
      paint
        ..strokeWidth = 0.6
        ..color = color.withValues(alpha: 0.6),
    );

    // زخارف على الأطراف المدببة
    canvas.drawCircle(Offset(22, cy), 2, fillPaint);
    canvas.drawCircle(Offset(w - 22, cy), 2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ⭕ مدالية رقم الآية (شكل زهري مطابق للمصحف المدني)
class _AyahMedallionPainter extends CustomPainter {
  final Color color;
  _AyahMedallionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 1;

    // ✨ الشكل الخارجي: زهرة من 12 بتلة
    final flowerPath = Path();
    const petals = 12;
    for (int i = 0; i < petals * 2; i++) {
      final angle = (i * math.pi / petals) - (math.pi / 2);
      final r = i.isEven ? outerR : outerR * 0.92;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        flowerPath.moveTo(x, y);
      } else {
        flowerPath.lineTo(x, y);
      }
    }
    flowerPath.close();
    canvas.drawPath(flowerPath, paint);

    // حلقة داخلية 1
    canvas.drawCircle(center, outerR * 0.78, paint..strokeWidth = 0.7);

    // حلقة داخلية 2
    canvas.drawCircle(center, outerR * 0.62, paint..strokeWidth = 0.5);

    // حلقة داخلية 3 (صغيرة حول الرقم)
    canvas.drawCircle(center, outerR * 0.45, paint..strokeWidth = 0.4);

    // نقاط بين البتلات
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi / petals) - (math.pi / 2);
      final x = center.dx + outerR * 0.85 * math.cos(angle);
      final y = center.dy + outerR * 0.85 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 0.8, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
