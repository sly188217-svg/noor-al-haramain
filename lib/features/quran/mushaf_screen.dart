import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/quran_service.dart';

/// ═══════════════════════════════════════════════════════════
/// شاشة المصحف الكامل — 604 صفحة بصفحات حقيقية
/// ═══════════════════════════════════════════════════════════
/// 
/// استخدام qcf_quran:
/// - 604 خط QCF مضمّن (مطابق للمصحف المدني)
/// - عرض صفحة بصفحة (PageView)
/// - تصميم احترافي
/// 
class MushafScreen extends StatefulWidget {
  /// الصفحة الابتدائية (1 = الفاتحة)
  final int initialPage;

  const MushafScreen({super.key, this.initialPage = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late int _currentPage;
  late PageController _pageController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  String _selectedReciter = 'maher';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadReciter();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadReciter() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedReciter = prefs.getString('quran_reciter') ?? 'maher';
      });
    }
  }

  /// الانتقال إلى صفحة معينة
  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _pageController.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// عرض قائمة السور
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
                child: const Row(
                  children: [
                    Icon(Icons.menu_book,
                        color: Color(0xFFD4AF37), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '📖 قائمة السور',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                    final surahNum = index + 1;
                    final surahName = getSurahNameArabic(surahNum);
                    // احصل على صفحة بداية السورة
                    final pageNum = getPageNumber(surahNum, 1);

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD4AF37)),
                        ),
                        child: Center(
                          child: Text(
                            '$surahNum',
                            style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      title: Text(
                        surahName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                      subtitle: Text(
                        'صفحة $pageNum',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToPage(pageNum);
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

  /// البحث في المصحف
  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('🔍 البحث في المصحف',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final query = controller.text.trim();
              if (query.isEmpty) return;

              try {
                final results = searchWords(query);
                Navigator.pop(context);

                if (results['result'] is List &&
                    results['result'].isNotEmpty) {
                  final first = results['result'][0];
                  final page = getPageNumber(
                      first['suraNumber'], first['verseNumber']);
                  _goToPage(page);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '🔍 ${results['occurences']} نتيجة — أول نتيجة: صفحة $page'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ لا توجد نتائج')),
                    );
                  }
                }
              } catch (e) {
                Navigator.pop(context);
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

  /// تشغيل تلاوة الصفحة الحالية
  Future<void> _playCurrentSurah() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      // احصل على رقم السورة من الصفحة الحالية
      // (صفحة 1 = الفاتحة، وهكذا — نحتاج ربط صفحة بسورة)
      // سنشغّل سورة الفاتحة كاختبار افتراضي
      final url = QuranService.getRecitationUrl(1, _selectedReciter);

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
            Text(
              'المصحف — صفحة $_currentPage / 604',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
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
            onPressed: _playCurrentSurah,
            tooltip: 'استمع',
          ),
        ],
      ),

      body: Stack(
        children: [
          // المصحف نفسه
          PageviewQuran(
            controller: _pageController,
            initialPageNumber: _currentPage,
            onPageChanged: (page) {
              if (mounted) setState(() => _currentPage = page);
            },
          ),

          // شريط التقدم أسفل الشاشة
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // زر السابق
                  IconButton(
                    icon: const Icon(Icons.arrow_forward,
                        color: Color(0xFFD4AF37)),
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    tooltip: 'السابق',
                  ),

                  // شريط التقدم
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _currentPage / 604,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFD4AF37),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'صفحة $_currentPage من 604',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // زر التالي
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFFD4AF37)),
                    onPressed: _currentPage < 604
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    tooltip: 'التالي',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
