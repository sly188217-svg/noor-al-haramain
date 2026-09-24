import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_service.dart';
import 'models/surah_model.dart';
import 'read_with_me_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — مطابقة تماماً للمصحف المدني المطبوع
/// ✅ إطار ذهبي مزخرف كامل
/// ✅ شريط سورة بأرابيسك متصل
/// ✅ مداليات ذهبية كبيرة
/// ✅ أرقام محلية لكل سورة (1، 2، 3...)
/// ✅ البسملة آية 1 في الفاتحة
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

  // 🎨 الألوان (مطابقة للمصحف المطبوع)
  static const Color _bgColor = Color(0xFFEDE4D0);
  static const Color _paperColor = Color(0xFFFFFEF7);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _goldColor = Color(0xFFB8935A);
  static const Color _goldDark = Color(0xFF7A5F1A);
  static const Color _goldLight = Color(0xFFD4B876);

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
                    const Icon(Icons.menu_book, color: _paperColor, size: 24),
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
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${surah.ayahCount} آية • ${surah.revelationTypeAr}',
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
                  BorderSide(color: _goldColor.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
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
  // 🎨 صفحة السورة — مطابقة للمصحف المدني المطبوع
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahPage(SurahModel surah) {
    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: _OrnateFramePainter(
          goldColor: _goldColor,
          goldDark: _goldDark,
          goldLight: _goldLight,
          paperColor: _paperColor,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 📜 شريط السورة المزخرف
                _buildSurahBand(surah),
                const SizedBox(height: 20),

                // 📖 النص القرآني
                _buildContinuousText(surah),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 📜 شريط السورة المزخرف (مطابق للصورة)
  Widget _buildSurahBand(SurahModel surah) {
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _SurahBandPainter(
          goldColor: _goldColor,
          darkGold: _goldDark,
          lightGold: _goldLight,
          paperColor: _paperColor,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 110),
            child: Text(
              'سُورَةُ ${surah.name.replaceAll("سورة ", "").replaceAll("سُورَةُ ", "")}',
              style: const TextStyle(
                color: _inkColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }

  /// 📖 النص القرآني (البسملة كآية 1، أرقام محلية)
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

      // 📝 نص الآية
      spans.add(TextSpan(
        text: '${ayah.text} ',
        style: TextStyle(
          color: _inkColor,
          fontSize: _fontSize,
          fontFamily: 'Amiri',
          height: 2.3,
          letterSpacing: 0.2,
        ),
      ));

      // ⭕ مدالية رقم الآية (✅ نستخدم numberInSurah للأرقام المحلية)
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildAyahMedallion(ayah.numberInSurah),
      ));

      spans.add(const TextSpan(text: '  '));
    }

    return RichText(
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// ⭕ مدالية رقم الآية (ذهبية كبيرة)
  Widget _buildAyahMedallion(int number) {
    final size = _fontSize + 6;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AyahMedallionPainter(
            color: _goldDark,
            lightColor: _goldLight,
          ),
          child: Center(
            child: Text(
              _toArabicNumber(number),
              style: TextStyle(
                color: _goldDark,
                fontSize: _fontSize * 0.36,
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
          ? const Center(child: CircularProgressIndicator(color: _goldDark))
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
            child: const Text('إغلاق', style: TextStyle(color: _goldDark)),
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
// 🎨 Custom Painters
// ═══════════════════════════════════════════════════════════════

/// 🖼️ الإطار الذهبي المزخرف الكامل
class _OrnateFramePainter extends CustomPainter {
  final Color goldColor;
  final Color goldDark;
  final Color goldLight;
  final Color paperColor;

  _OrnateFramePainter({
    required this.goldColor,
    required this.goldDark,
    required this.goldLight,
    required this.paperColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1️⃣ خلفية بيضاء للصفحة
    final bgPaint = Paint()..color = paperColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2️⃣ الإطار الخارجي (مستطيل ذهبي سميك)
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(4, 4, w - 4, h - 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      outerRect,
      Paint()
        ..color = goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 3️⃣ الإطار الثاني (رفيع داخلي)
    final inner1Rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(10, 10, w - 10, h - 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      inner1Rect,
      Paint()
        ..color = goldColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 4️⃣ الإطار الثالث (أرق)
    final inner2Rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(14, 14, w - 14, h - 14),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      inner2Rect,
      Paint()
        ..color = goldColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // 5️⃣ زخارف الزوايا الأربع
    _drawCornerOrnament(canvas, Offset(20, 20), 1, goldDark);
    _drawCornerOrnament(canvas, Offset(w - 20, 20), 2, goldDark);
    _drawCornerOrnament(canvas, Offset(20, h - 20), 3, goldDark);
    _drawCornerOrnament(canvas, Offset(w - 20, h - 20), 4, goldDark);

    // 6️⃣ زخارف على منتصف الأطراف
    _drawMiddleOrnament(canvas, Offset(w / 2, 12), false, goldDark);
    _drawMiddleOrnament(canvas, Offset(w / 2, h - 12), false, goldDark);
  }

  void _drawCornerOrnament(
      Canvas canvas, Offset center, int corner, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // دائرة
    canvas.drawCircle(center, 6, paint);
    canvas.drawCircle(center, 3, fillPaint);

    // خطوط صغيرة باتجاه داخل الصفحة
    for (int i = 0; i < 2; i++) {
      final angle = _getCornerAngle(corner, i);
      final x1 = center.dx + 8 * math.cos(angle);
      final y1 = center.dy + 8 * math.sin(angle);
      final x2 = center.dx + 14 * math.cos(angle);
      final y2 = center.dy + 14 * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  double _getCornerAngle(int corner, int index) {
    switch (corner) {
      case 1: // يسار أعلى
        return index == 0 ? (math.pi / 4) : 0;
      case 2: // يمين أعلى
        return index == 0 ? (3 * math.pi / 4) : math.pi;
      case 3: // يسار أسفل
        return index == 0 ? (-math.pi / 4) : 0;
      case 4: // يمين أسفل
        return index == 0 ? (-3 * math.pi / 4) : math.pi;
      default:
        return 0;
    }
  }

  void _drawMiddleOrnament(
      Canvas canvas, Offset center, bool vertical, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // زخرفة على شكل ورقة صغيرة
    canvas.drawCircle(center, 4, paint);
    canvas.drawCircle(center, 2, fillPaint);
    canvas.drawLine(
      Offset(center.dx - 15, center.dy),
      Offset(center.dx - 7, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 7, center.dy),
      Offset(center.dx + 15, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 📜 شريط السورة المزخرف
class _SurahBandPainter extends CustomPainter {
  final Color goldColor;
  final Color darkGold;
  final Color lightGold;
  final Color paperColor;

  _SurahBandPainter({
    required this.goldColor,
    required this.darkGold,
    required this.lightGold,
    required this.paperColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = darkGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final goldFill = Paint()
      ..color = lightGold.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    // 1️⃣ المستطيل الرئيسي (خلفية ذهبية فاتحة)
    final mainRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(70, 4, w - 70, h - 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(mainRect, goldFill);
    canvas.drawRRect(mainRect, paint);

    // 2️⃣ الإطار الداخلي
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(73, 7, w - 73, h - 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      innerRect,
      Paint()
        ..color = darkGold.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // 3️⃣ دوائر صغيرة عند أطراف المستطيل
    canvas.drawCircle(Offset(75, cy), 2.5, Paint()..color = darkGold);
    canvas.drawCircle(Offset(w - 75, cy), 2.5, Paint()..color = darkGold);

    // 4️⃣ أرابيسك يسار
    _drawArabesque(canvas, Offset(35, cy), 32, paint, darkGold, false);

    // 5️⃣ أرابيسك يمين
    _drawArabesque(canvas, Offset(w - 35, cy), 32, paint, darkGold, true);
  }

  void _drawArabesque(
    Canvas canvas,
    Offset center,
    double width,
    Paint paint,
    Color color,
    bool flip,
  ) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final h = center.dy;

    // شكل زخرفي (نصف دائرة + خطوط)
    final path = Path();
    if (!flip) {
      path.moveTo(center.dx + width / 2, h);
      path.quadraticBezierTo(
        center.dx + width / 4,
        h - 12,
        center.dx,
        h - 6,
      );
      path.quadraticBezierTo(
        center.dx - width / 4,
        h,
        center.dx - width / 2,
        h,
      );
      path.quadraticBezierTo(
        center.dx - width / 4,
        h + 12,
        center.dx,
        h + 6,
      );
      path.quadraticBezierTo(
        center.dx + width / 4,
        h,
        center.dx + width / 2,
        h,
      );
    } else {
      path.moveTo(center.dx - width / 2, h);
      path.quadraticBezierTo(
        center.dx - width / 4,
        h - 12,
        center.dx,
        h - 6,
      );
      path.quadraticBezierTo(
        center.dx + width / 4,
        h,
        center.dx + width / 2,
        h,
      );
      path.quadraticBezierTo(
        center.dx + width / 4,
        h + 12,
        center.dx,
        h + 6,
      );
      path.quadraticBezierTo(
        center.dx - width / 4,
        h,
        center.dx - width / 2,
        h,
      );
    }
    path.close();

    // ملء وإطار
    canvas.drawPath(
      path,
      Paint()
        ..color = lightGold.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, paint);

    // نقاط زخرفية
    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final x = center.dx + 8 * math.cos(angle);
      final y = center.dy + 4 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.2, fillPaint);
    }

    // دائرة مركزية
    canvas.drawCircle(center, 3, fillPaint);
    canvas.drawCircle(center, 1.5, Paint()..color = paperColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ⭕ مدالية رقم الآية (كبيرة وواضحة)
class _AyahMedallionPainter extends CustomPainter {
  final Color color;
  final Color lightColor;

  _AyahMedallionPainter({
    required this.color,
    required this.lightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final lightFill = Paint()
      ..color = lightColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final accentFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 1;

    // 1️⃣ دائرة خارجية
    canvas.drawCircle(center, outerR, paint);

    // 2️⃣ نجمة زهرية (12 رأس)
    final flowerPath = Path();
    const petals = 12;
    for (int i = 0; i < petals * 2; i++) {
      final angle = (i * math.pi / petals) - (math.pi / 2);
      final r = i.isEven ? outerR * 0.98 : outerR * 0.78;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        flowerPath.moveTo(x, y);
      } else {
        flowerPath.lineTo(x, y);
      }
    }
    flowerPath.close();

    canvas.drawPath(flowerPath, lightFill);
    canvas.drawPath(flowerPath, paint);

    // 3️⃣ حلقة داخلية
    canvas.drawCircle(center, outerR * 0.65, paint..strokeWidth = 0.8);

    // 4️⃣ حلقة حول الرقم
    canvas.drawCircle(center, outerR * 0.42, paint..strokeWidth = 0.5);

    // 5️⃣ نقاط على الرؤوس
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi / petals) - (math.pi / 2);
      final x = center.dx + outerR * 0.88 * math.cos(angle);
      final y = center.dy + outerR * 0.88 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.2, accentFill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
