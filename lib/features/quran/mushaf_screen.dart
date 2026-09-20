import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_service.dart';
import 'models/surah_model.dart';

/// ═══════════════════════════════════════════════════════════
/// 📖 شاشة المصحف — عرض نصي متواصل كالمصحف الحقيقي
/// ✅ نص متواصل (ليس قائمة)
/// ✅ أرقام الآيات في دوائر ذهبية
/// ✅ خط Amiri
/// ✅ تصميم احترافي
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
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Color(0xFF1C2541),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: Color(0xFFD4AF37), size: 24),
                    const SizedBox(width: 8),
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
                    Text(
                      '${_currentSurahIndex + 1} / 114',
                      style: const TextStyle(
                          color: Color(0xFFD4AF37), fontSize: 12),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: const Color(0xFFD4AF37)),
                        ),
                        child: Center(
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : const Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      title: Text(
                        surah.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                      subtitle: Text(
                        '${surah.numberOfAyahs} آية — ${surah.revelationType == "Meccan" ? "مكية" : "مدنية"}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
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
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('🔍 البحث في المصحف',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'اكتب كلمة للبحث...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFFD4AF37)),
            filled: true,
            fillColor: const Color(0xFF0B132B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
                      duration: const Duration(seconds: 3),
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
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 عرض السورة كنص متواصل
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahPage(SurahModel surah) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ═══════════════════════════════════════════════════
          // 📖 رأس السورة (إطار مزخرف)
          // ═══════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  const Color(0xFFD4AF37).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  surah.name,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${surah.revelationType == "Meccan" ? "مكية" : "مدنية"} — ${surah.numberOfAyahs} آية',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════
          // 🕌 البسملة (ما عدا التوبة)
          // ═══════════════════════════════════════════════════
          if (surah.number != 9) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 28,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  height: 2.0,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════
          // 📖 نص السورة المتواصل (مثل المصحف الحقيقي)
          // ═══════════════════════════════════════════════════
          _buildContinuousText(surah),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// ✅ بناء النص المتواصل مع أرقام الآيات
  Widget _buildContinuousText(SurahModel surah) {
    if (surah.ayahs == null || surah.ayahs!.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد آيات',
          style: TextStyle(color: Colors.white54),
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
          color: Colors.white,
          fontSize: _fontSize,
          fontFamily: 'Amiri',
          height: 2.2,
        ),
      ));

      // رقم الآية داخل دائرة ذهبية
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: _fontSize + 10,
          height: _fontSize + 10,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              _toArabicNumber(ayah.number),
              style: TextStyle(
                color: const Color(0xFFD4AF37),
                fontSize: _fontSize * 0.55,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ),
        ),
      ));

      // مسافة بعد الرقم
      spans.add(const TextSpan(text: ' '));
    }

    return RichText(
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// تحويل الأرقام إلى أرقام عربية (١٢٣)
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
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        foregroundColor: const Color(0xFFD4AF37),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.menu_book, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _surahs.isEmpty
                    ? 'المصحف'
                    : _surahs[_currentSurahIndex].name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // زر تصغير/تكبير الخط
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizeDialog,
            tooltip: 'حجم الخط',
          ),
          // زر البحث
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'بحث',
          ),
          // زر قائمة السور
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showSurahPicker,
            tooltip: 'قائمة السور',
          ),
          // زر التلاوة
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _playSurah,
            tooltip: 'استمع',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _surahs.isEmpty
              ? const Center(
                  child: Text(
                    '⚠️ تعذر تحميل المصحف',
                    style: TextStyle(color: Colors.white),
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

                    // شريط التنقل السفلي
                    _buildBottomNav(),
                  ],
                ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // السورة السابقة
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFFD4AF37), size: 18),
            onPressed: _currentSurahIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            tooltip: 'السورة السابقة',
          ),

          // معلومات السورة
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: (_currentSurahIndex + 1) / 114,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFD4AF37),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 3),
                Text(
                  'سورة ${_currentSurahIndex + 1} من 114',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // السورة التالية
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: Color(0xFFD4AF37), size: 18),
            onPressed: _currentSurahIndex < _surahs.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            tooltip: 'السورة التالية',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 نافذة تغيير حجم الخط
  // ═══════════════════════════════════════════════════════════
  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('🔤 حجم الخط',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'حجم النص: ${_fontSize.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
                Slider(
                  value: _fontSize,
                  min: 18,
                  max: 40,
                  divisions: 22,
                  activeColor: const Color(0xFFD4AF37),
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
            child: const Text('إغلاق',
                style: TextStyle(color: Color(0xFFD4AF37))),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('quran_font_size', _fontSize);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
