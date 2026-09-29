import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/language_provider.dart';
import '../../quran/models/surah_model.dart';
import '../../quran/services/quran_service.dart';
import '../../quran/mushaf_screen.dart';

class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  List<SurahModel> _surahs = [];
  List<SurahModel> _filteredSurahs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedReciter = 'maher';
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingSurah;
  bool _isPlaying = false;
  SurahModel? _selectedSurah;
  bool _showAyahs = false;

  @override
  void initState() {
    super.initState();
    _loadReciterPreference();
    _loadQuran();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ تحميل تفضيل القارئ مع التحقق
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadReciterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final reciter = prefs.getString('quran_reciter') ?? 'maher';

    // ✅ تحقق أن القارئ موجود في القائمة الحالية
    final exists = QuranService.reciters.any((r) => r['id'] == reciter);

    if (mounted) {
      setState(() => _selectedReciter = exists ? reciter : 'maher');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // تحميل القرآن
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadQuran() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final surahs = await QuranService.loadQuran();
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _filteredSurahs = surahs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '⚠️ فشل تحميل المصحف: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // البحث عن سورة
  // ═══════════════════════════════════════════════════════════
  void _filterSurahs(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSurahs = _surahs;
      } else {
        _filteredSurahs = _surahs.where((s) {
          return s.name.contains(query) ||
              s.englishName.toLowerCase().contains(query.toLowerCase()) ||
              s.number.toString() == query;
        }).toList();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // فتح السورة (عرض الآيات)
  // ═══════════════════════════════════════════════════════════
  void _openSurah(SurahModel surah) {
    setState(() {
      _selectedSurah = surah;
      _showAyahs = true;
    });
  }

  void _goBackToSurahs() {
    setState(() {
      _showAyahs = false;
      _selectedSurah = null;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // تشغيل التلاوة
  // ═══════════════════════════════════════════════════════════
  Future<void> _playRecitation(SurahModel surah) async {
    try {
      final url =
          QuranService.getRecitationUrl(surah.number, _selectedReciter);

      if (_playingSurah == surah.number && _isPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      await _audioPlayer.play(UrlSource(url));

      if (mounted) {
        setState(() {
          _playingSurah = surah.number;
          _isPlaying = true;
        });
      }

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('⚠️ تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // اختيار القارئ
  // ═══════════════════════════════════════════════════════════
  void _showReciterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          title: const Text('اختر القارئ',
              style: TextStyle(color: Color(0xFFD4AF37))),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: QuranService.reciters.length,
              itemBuilder: (context, index) {
                final reciter = QuranService.reciters[index];
                final isSelected = reciter['id'] == _selectedReciter;
                return ListTile(
                  title: Text(
                    reciter['name']!,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFD4AF37)
                          : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check,
                          color: Color(0xFFD4AF37))
                      : null,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                        'quran_reciter', reciter['id']!);

                    if (_isPlaying) {
                      await _audioPlayer.stop();
                    }

                    if (!mounted) return;
                    setState(() {
                      _selectedReciter = reciter['id']!;
                      _isPlaying = false;
                      _playingSurah = null;
                    });

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '✅ تم اختيار ${reciter['name']}')),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // الواجهة الرئيسية
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    // ─── عرض الآيات (سورة مفتوحة) ───
    if (_showAyahs && _selectedSurah != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2541),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(0xFFD4AF37)),
            onPressed: _goBackToSurahs,
          ),
          title: Text(_selectedSurah!.name,
              style: const TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: Icon(
                _isPlaying && _playingSurah == _selectedSurah!.number
                    ? Icons.pause
                    : Icons.play_arrow,
                color: const Color(0xFFD4AF37),
              ),
              onPressed: () => _playRecitation(_selectedSurah!),
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _selectedSurah!.ayahs?.length ?? 0,
          itemBuilder: (context, index) {
            final ayah = _selectedSurah!.ayahs![index];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${ayah.number}',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ayah.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Amiri',
                        height: 1.6,
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // ─── قائمة السور ───
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 🆕 بطاقة المصحف ككتاب
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MushafScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      const Color(0xFFD4AF37).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: Color(0xFFD4AF37), size: 40),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📖 اقرأ المصحف ككتاب',
                              style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('604 صفحة بتصميم المصحف المدني',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFFD4AF37), size: 16),
                  ],
                ),
              ),
            ),
          ),

          // ─── شريط البحث + القارئ ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1C2541),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: _filterSurahs,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: lang == 'ar'
                              ? '🔍 ابحث عن سورة...'
                              : '🔍 Search for a surah...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFFD4AF37)),
                          filled: true,
                          fillColor: const Color(0xFF0B132B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.record_voice_over,
                          color: Color(0xFFD4AF37)),
                      tooltip: 'اختر القارئ',
                      onPressed: _showReciterDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📖 ${_filteredSurahs.length} سورة',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    Text(
                      '🎙️ ${QuranService.reciters.firstWhere(
                            (r) => r['id'] == _selectedReciter,
                            orElse: () => QuranService.reciters.first,
                          )['name']!}',
                      style: const TextStyle(
                          color: Color(0xFFD4AF37), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── قائمة السور ───
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37)))
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _filteredSurahs.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredSurahs.length,
                            itemBuilder: (context, index) {
                              return _buildSurahCard(
                                  _filteredSurahs[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahCard(SurahModel surah) {
    final isPlaying = _playingSurah == surah.number && _isPlaying;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFFD4AF37)
              : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          surah.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${surah.numberOfAyahs} آية • ${surah.revelationType == "Meccan" ? "مكية" : "مدنية"}',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFFD4AF37),
              ),
              onPressed: () => _playRecitation(surah),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
        onTap: () => _openSurah(surah),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuran,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 60),
            SizedBox(height: 16),
            Text('لا توجد نتائج',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
