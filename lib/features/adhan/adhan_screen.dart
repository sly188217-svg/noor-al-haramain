import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/notification_service.dart';

class AdhanScreen extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final String cityName;
  final String muezzinName; // يحتوي على ID مثل adhan_sudais
  final bool isIqamaOnly;

  const AdhanScreen({super.key, required this.prayerName, required this.prayerTime, required this.cityName, required this.muezzinName, this.isIqamaOnly = false});

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _errorMessage = '';

  // ✅ تحويل الـ ID إلى اسم الشيخ
  String _getMuezzinDisplayName(String id) {
    final match = NotificationService.muezzins.firstWhere((m) => m['file'] == id, orElse: () => {'name': id});
    return match['name'] ?? id;
  }

  @override
  void initState() {
    super.initState();
    _playAudio();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      String assetPath = widget.isIqamaOnly ? 'adhan/iqama.mp3' : 'adhan/raw/${widget.muezzinName}.mp3';
      
      await _audioPlayer.play(AssetSource(assetPath));
      if (mounted) setState(() => _isPlaying = true);
      
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _errorMessage = '⚠️ ملف الصوت لـ "${_getMuezzinDisplayName(widget.muezzinName)}" غير موجود في مجلد assets/adhan/raw/';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B), // لون داكن
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: Text(widget.isIqamaOnly ? 'الإقامة' : 'الأذان', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mosque, color: Color(0xFF4A90E2), size: 80),
              const SizedBox(height: 20),
              Text(widget.prayerName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
              const SizedBox(height: 10),
              Text('المؤذن: ${_getMuezzinDisplayName(widget.muezzinName)}', style: const TextStyle(color: Colors.white70, fontSize: 18, fontFamily: 'Amiri')),
              const SizedBox(height: 5),
              Text('${widget.cityName} • ${widget.prayerTime}', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 30),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                ),
              if (_isPlaying)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4A90E2)),
                    SizedBox(height: 10),
                    Text('جاري التشغيل...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  _audioPlayer.stop();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('إغلاق'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
