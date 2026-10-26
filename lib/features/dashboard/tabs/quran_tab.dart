import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../widgets/professional_ui.dart';
import '../../quran/models/surah_model.dart';
import '../../quran/services/quran_service.dart';
import '../../quran/mushaf_screen.dart';
import 'quran_surah_detail.dart';

class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  String _searchQuery = "";
  List<SurahModel> _surahs = [];
  List<SurahModel> _filteredSurahs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedReciter = 'maher';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingSurah;
  bool _isPlaying = false;
  
  // لتتبع السور التي تم تحميلها
  Set<int> _downloadedSurahs = {};
  int? _downloadingSurah;

  @override
  void initState() {
    super.initState();
    _loadReciterPreference();
    _loadQuran();
    _checkDownloadedSurahs();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _loadReciterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final reciter = prefs.getString('quran_reciter') ?? 'maher';
    final exists = QuranService.reciters.any((r) => r['id'] == reciter);
    if (mounted) {
      setState(() => _selectedReciter = exists ? reciter : 'maher');
    }
  }

  Future<void> _loadQuran() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
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
        setState(() { _errorMessage = '⚠️ فشل تحميل المصحف: $e'; _isLoading = false; });
      }
    }
  }

  Future<void> _checkDownloadedSurahs() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio_full');
    if (!await folder.exists()) return;

    final files = folder.listSync();
    final downloaded = <int>{};
    for (var file in files) {
      if (file.path.endsWith('.mp3')) {
        final fileName = file.path.split('/').last;
        final parts = fileName.split('_');
        if (parts.length >= 2 && parts[0] == _selectedReciter) {
          final surahNum = int.tryParse(parts[1].replaceAll('.mp3', ''));
          if (surahNum != null) downloaded.add(surahNum);
        }
      }
    }
    if (mounted) setState(() => _downloadedSurahs = downloaded);
  }

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

  Future<void> _playRecitation(SurahModel surah) async {
    try {
      if (_playingSurah == surah.number && _isPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final surahStr = surah.number.toString().padLeft(3, '0');
      final filePath = '${dir.path}/quran_audio_full/${_selectedReciter}_$surahStr.mp3';
      final file = File(filePath);

      // ✅ إعدادات العمل في الخلفية
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          audioFocus: AndroidAudioFocus.gain,
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
        ),
      ));

      if (await file.exists()) {
        await _audioPlayer.play(DeviceFileSource(filePath));
      } else {
        final url = QuranService.getRecitationUrl(surah.number, _selectedReciter);
        await _audioPlayer.play(UrlSource(url));
      }

      if (mounted) {
        setState(() { _playingSurah = surah.number; _isPlaying = true; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت')),
        );
      }
    }
  }

  Future<void> _downloadSurah(SurahModel surah) async {
    if (_downloadingSurah != null) return;
    
    setState(() => _downloadingSurah = surah.number);
    
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio_full');
    if (!await folder.exists()) await folder.create(recursive: true);

    final surahStr = surah.number.toString().padLeft(3, '0');
    final filePath = '${folder.path}/${_selectedReciter}_$surahStr.mp3';
    final url = QuranService.getRecitationUrl(surah.number, _selectedReciter);

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _downloadedSurahs.add(surah.number);
            _downloadingSurah = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ تم تحميل ${surah.name} بنجاح للاستماع بدون إنترنت')),
          );
        }
      } else {
        throw Exception('فشل التحميل');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingSurah = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ فشل تحميل السورة. حاول لاحقاً.')),
        );
      }
    }
  }

  void _showReciterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('اختر القارئ', style: TextStyle(color: Color(0xFF4A90E2))),
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
                      color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4A90E2)) : null,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('quran_reciter', reciter['id']!);

                    if (_isPlaying) await _audioPlayer.stop();

                    if (!mounted) return;
                    setState(() {
                      _selectedReciter = reciter['id']!;
                      _isPlaying = false;
                      _playingSurah = null;
                    });
                    
                    _checkDownloadedSurahs(); // إعادة فحص السور المحملة للقارئ الجديد

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MushafScreen()));
              },
              child: ProCard(
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Color(0xFF4A90E2), size: 40),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📖 اقرأ المصحف ككتاب', style: TextStyle(color: Color(0xFF4A90E2), fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('604 صفحة بتصميم المصحف المدني', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFF4A90E2), size: 16),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProCard(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _filterSurahs,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: lang == 'ar' ? '🔍 ابحث عن سورة...' : '🔍 Search for a surah...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.record_voice_over, color: Color(0xFF4A90E2)),
                        tooltip: 'اختر القارئ',
                        onPressed: _showReciterDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📖 ${_filteredSurahs.length} سورة', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      '🎙️ ${QuranService.reciters.firstWhere((r) => r['id'] == _selectedReciter, orElse: () => QuranService.reciters.first)['name']!}',
                      style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _filteredSurahs.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredSurahs.length,
                            itemBuilder: (context, index) {
                              return _buildSurahCard(_filteredSurahs[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahCard(SurahModel surah) {
    final isPlaying = _playingSurah == surah.number && _isPlaying;
    final isDownloaded = _downloadedSurahs.contains(surah.number);
    final isDownloading = _downloadingSurah == surah.number;

    return ProCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(
          surah.name,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${surah.numberOfAyahs} آية • ${surah.revelationType == "Meccan" ? "مكية" : "مدنية"}',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ زر التحميل
            isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
                  )
                : IconButton(
                    icon: Icon(
                      isDownloaded ? Icons.check_circle : Icons.download,
                      color: isDownloaded ? Colors.green : Colors.teal,
                    ),
                    onPressed: isDownloaded ? null : () => _downloadSurah(surah),
                    tooltip: isDownloaded ? 'تم التحميل' : 'تحميل السورة',
                  ),
            // ✅ زر التشغيل
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF4A90E2)),
              onPressed: () => _playRecitation(surah),
            ),
            // ✅ زر فتح السورة للقراءة
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuranSurahDetail(surah: surah)),
          );
        },
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
            const Icon(Icons.error_outline, color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuran,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90E2), foregroundColor: Colors.black),
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
            Text('لا توجد نتائج', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
