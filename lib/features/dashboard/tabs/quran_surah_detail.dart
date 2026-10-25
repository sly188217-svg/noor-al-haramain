import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../quran/models/surah_model.dart';
import '../../quran/models/ayah_model.dart';
import '../../quran/services/quran_service.dart';
import '../../../core/services/usage_service.dart';

class QuranSurahDetail extends StatefulWidget {
  final SurahModel surah;
  const QuranSurahDetail({super.key, required this.surah});

  @override
  State<QuranSurahDetail> createState() => _QuranSurahDetailState();
}

class _QuranSurahDetailState extends State<QuranSurahDetail> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<AyahModel> _ayahs = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  
  // متغيرات التنزيل
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;

  // القارئ الافتراضي (عبد الباسط)
  final String _reciter = 'afs'; 
  final String _reciterName = 'عبد الباسط عبد الصمد';

  static const Color _bg = Color(0xFF0B132B);
  static const Color _surface = Color(0xFF1C2541);
  static const Color _gold = Color(0xFF4A90E2);

  @override
  void initState() {
    super.initState();
    _loadAyahs();
    _checkIfDownloaded();
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

  Future<void> _loadAyahs() async {
    try {
      final surah = await QuranService.getSurah(widget.surah.number);
      if (mounted) {
        setState(() {
          _ayahs = surah?.ayahs ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ إصلاح الخطأ: فصل الـ await عن دالة setState
  Future<void> _checkIfDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final surahStr = widget.surah.number.toString().padLeft(3, '0');
    final file = File('${dir.path}/quran_audio_full/${_reciter}_$surahStr.mp3');
    final exists = await file.exists(); // await هنا خارج setState
    if (mounted) {
      setState(() => _isDownloaded = exists);
    }
  }

  // دالة التشغيل (تقرأ من الملف المحلي إذا وُجد)
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final surahStr = widget.surah.number.toString().padLeft(3, '0');
    final filePath = '${dir.path}/quran_audio_full/${_reciter}_$surahStr.mp3';
    final file = File(filePath);

    try {
      if (await file.exists()) {
        await _audioPlayer.play(DeviceFileSource(filePath));
      } else {
        final url = 'https://server8.mp3quran.net/$_reciter/$surahStr.mp3';
        await _audioPlayer.play(UrlSource(url));
      }
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تعذر تشغيل السورة. تأكد من الإنترنت.')),
        );
      }
    }
  }

  // دالة تحميل السورة
  Future<void> _downloadSurah() async {
    if (_isDownloading || _isDownloaded) return;
    
    // التحقق من الاشتراك (اختياري)
    if (!await UsageService.isPremium()) {
      final canUse = await UsageService.canReadWithMe(); // نستخدم نفس عداد التجربة
      if (!canUse) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('🔒 اشترك في Premium للتحميل غير المحدود')),
           );
         }
         return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio_full');
    if (!await folder.exists()) await folder.create(recursive: true);

    final surahStr = widget.surah.number.toString().padLeft(3, '0');
    final filePath = '${folder.path}/${_reciter}_$surahStr.mp3';
    final url = 'https://server8.mp3quran.net/$_reciter/$surahStr.mp3';

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        final file = File(filePath);
        final sink = file.openWrite();
        int downloaded = 0;

        await response.stream.listen((chunk) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _downloadProgress = downloaded / contentLength;
            });
          }
        }).asFuture();

        await sink.close();
        
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تحميل السورة بنجاح للاستماع بدون إنترنت')),
          );
        }
      } else {
        throw Exception('فشل التحميل');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ فشل تحميل السورة. حاول لاحقاً.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(
          widget.surah.name,
          style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // زر التنزيل في شريط العنوان العلوي
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      color: _gold,
                      strokeWidth: 3,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: Icon(
                _isDownloaded ? Icons.check_circle : Icons.download,
                color: _isDownloaded ? Colors.green : _gold,
              ),
              onPressed: _isDownloaded ? null : _downloadSurah,
              tooltip: _isDownloaded ? 'تم التحميل' : 'تحميل السورة',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Column(
              children: [
                // شريط التشغيل
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: _surface,
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_reciterName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const Text('استماع للسورة كاملة', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: _bg,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // عرض الآيات
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ayahs.length,
                    itemBuilder: (context, index) {
                      final ayah = _ayahs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gold.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _gold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${ayah.number}',
                                    style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              ayah.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: 'Amiri',
                                height: 2.0,
                              ),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
