import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../quran/models/surah_model.dart';
import '../../quran/services/quran_service.dart';
import '../../quran/models/ayah_model.dart';

class SurahDetailScreen extends StatefulWidget {
  final SurahModel surah;
  final String reciterId;
  const SurahDetailScreen({super.key, required this.surah, required this.reciterId});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  List<AyahModel> _ayahs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int? _playingAyah;

  @override
  void initState() {
    super.initState();
    _loadAyahs();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAyahs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final ayahs = await QuranService.fetchSurahAyahs(widget.surah.number);
      setState(() {
        _ayahs = ayahs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _playAyah(AyahModel ayah) async {
    try {
      // قد يكون هناك رابط لتشغيل آية معينة، لكن في الغالب نستخدم السورة كاملة
      // نستخدم نفس رابط السورة، لكن نبدأ من الآية المحددة (صعب)، لذا سنشغل السورة كاملة
      final url = QuranService.getRecitationUrl(widget.surah.number, widget.reciterId);
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
        return;
      }
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        title: Text(widget.surah.name, style: const TextStyle(color: Color(0xFFD4AF37))),
        backgroundColor: const Color(0xFF1C2541),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _ayahs.isNotEmpty ? () => _playAyah(_ayahs[0]) : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.orange, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadAyahs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ayahs.length,
                  itemBuilder: (context, index) {
                    final ayah = _ayahs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2541).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${ayah.number}',
                            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ayah.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Amiri',
                              height: 1.8,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
