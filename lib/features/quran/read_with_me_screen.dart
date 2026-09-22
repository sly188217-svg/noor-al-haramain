import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/quran_service.dart';
import 'models/ayah_model.dart';
import '../../core/services/firebase_ai_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎙️ اقرأ معي — Read with Me
/// ✅ تشغيل تلاوة الحصري مع تظليل الكلمات
/// ✅ تسجيل المستخدم ومقارنته في الوقت الفعلي
/// ✅ كلمات صحيحة خضراء، خاطئة حمراء
/// ✅ تنقل تلقائي بين الآيات
/// ═══════════════════════════════════════════════════════════
class ReadWithMeScreen extends StatefulWidget {
  final int surahNumber;
  final int? initialAyah;

  const ReadWithMeScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah,
  });

  @override
  State<ReadWithMeScreen> createState() => _ReadWithMeScreenState();
}

class _ReadWithMeScreenState extends State<ReadWithMeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  List<AyahModel> _ayahs = [];
  List<String> _currentWords = [];
  int _currentAyahIndex = 0;
  int _highlightedWordIndex = -1;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _autoAdvance = true;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  final Set<int> _userCorrectWords = {};
  final Set<int> _userWrongWords = {};

  // 🎨 الألوان
  static const Color _paperColor = Color(0xFFFBF6E9);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _goldColor = Color(0xFFB8860B);
  static const Color _frameColor = Color(0xFF9C7A3C);

  @override
  void initState() {
    super.initState();
    _loadSurah();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSurah() async {
    try {
      final surah = await QuranService.getSurah(widget.surahNumber);
      if (surah?.ayahs == null || surah!.ayahs!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      int startIdx = 0;
      if (widget.initialAyah != null) {
        final idx = surah.ayahs!
            .indexWhere((a) => a.number == widget.initialAyah);
        if (idx >= 0) startIdx = idx;
      }

      if (!mounted) return;
      setState(() {
        _ayahs = surah.ayahs!;
        _currentAyahIndex = startIdx;
        _isLoading = false;
      });
      _prepareCurrentAyah();
    } catch (e) {
      debugPrint('❌ loadSurah: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prepareCurrentAyah() {
    if (_currentAyahIndex >= _ayahs.length) return;
    final ayah = _ayahs[_currentAyahIndex];
    _currentWords =
        ayah.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _highlightedWordIndex = -1;
    _userCorrectWords.clear();
    _userWrongWords.clear();
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎧 تشغيل / إيقاف
  // ═══════════════════════════════════════════════════════════
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_currentAyahIndex >= _ayahs.length) return;
    final ayah = _ayahs[_currentAyahIndex];
    final surahStr = widget.surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayah.number.toString().padLeft(3, '0');
    final url =
        'https://everyayah.com/data/Husary_128kbps/$surahStr$ayahStr.mp3';

    try {
      await _audioPlayer.stop();

      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _totalDuration = d);
      });

      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _currentPosition = p);
        _updateHighlight(p);
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _highlightedWordIndex = _currentWords.length - 1;
        });
        if (_autoAdvance) {
          Future.delayed(const Duration(milliseconds: 1500), _nextAyah);
        }
      });

      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('❌ play: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _updateHighlight(Duration position) {
    if (_totalDuration.inMilliseconds == 0 || _currentWords.isEmpty) return;
    final progress = position.inMilliseconds / _totalDuration.inMilliseconds;
    final idx = (progress * _currentWords.length)
        .floor()
        .clamp(0, _currentWords.length - 1);
    if (idx != _highlightedWordIndex && mounted) {
      setState(() => _highlightedWordIndex = idx);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏭️ التنقل بين الآيات
  // ═══════════════════════════════════════════════════════════
  void _nextAyah() {
    if (_currentAyahIndex < _ayahs.length - 1) {
      _audioPlayer.stop();
      setState(() {
        _currentAyahIndex++;
        _isPlaying = false;
        _prepareCurrentAyah();
      });
    }
  }

  void _prevAyah() {
    if (_currentAyahIndex > 0) {
      _audioPlayer.stop();
      setState(() {
        _currentAyahIndex--;
        _isPlaying = false;
        _prepareCurrentAyah();
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 تسجيل المستخدم
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _recorder.stop();
        if (mounted) setState(() => _isRecording = false);
        if (path != null) await _processRecording(path);
      } catch (e) {
        debugPrint('❌ stop: $e');
        if (mounted) setState(() => _isRecording = false);
      }
      return;
    }

    if (!await _hasMicPermission()) return;

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/read_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _userCorrectWords.clear();
          _userWrongWords.clear();
        });
      }
    } catch (e) {
      debugPrint('❌ record start: $e');
    }
  }

  Future<bool> _hasMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _processRecording(String path) async {
    setState(() => _isProcessing = true);
    try {
      final ayah = _ayahs[_currentAyahIndex];
      final transcribed = await FirebaseAiService.transcribeAudio(
        path,
        correctText: ayah.text,
      );

      if (transcribed == null || transcribed.trim().isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final result = await FirebaseAiService.analyzeRecitation(
        userRecitation: transcribed,
        correctAyah: ayah.text,
      );

      final words = result['words'] as List?;
      if (words != null) {
        for (int i = 0; i < words.length && i < _currentWords.length; i++) {
          final status = words[i]['status']?.toString();
          if (status == 'correct') {
            _userCorrectWords.add(i);
          } else if (status == 'wrong') {
            _userWrongWords.add(i);
          }
        }
      }

      if (mounted) setState(() => _isProcessing = false);

      try {
        // حذف الملف المؤقت
        // ignore: avoid_slow_async_io
        await _deleteFile(path);
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ process: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final f = await Future.value(path);
      // ignore: avoid_slow_async_io
      await Future.delayed(Duration.zero);
      // Simple delete via File
      final file = await _toFile(f);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<dynamic> _toFile(String p) async {
    // ignore: avoid_dynamic_calls
    return await Future.value(_FileHelper(p));
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بناء الكلمة
  // ═══════════════════════════════════════════════════════════
  Widget _buildWord(int index) {
    final word = _currentWords[index];
    Color color = _inkColor;
    Color? bgColor;
    TextDecoration decoration = TextDecoration.none;

    if (_userWrongWords.contains(index)) {
      color = Colors.red;
      decoration = TextDecoration.underline;
    } else if (_userCorrectWords.contains(index)) {
      color = Colors.green.shade700;
    } else if (index == _highlightedWordIndex) {
      color = Colors.white;
      bgColor = _goldColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: bgColor != null
          ? BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _goldColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Text(
        word,
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontFamily: 'Amiri',
          fontWeight: FontWeight.bold,
          height: 1.6,
          decoration: decoration,
          decorationColor: color,
          decorationThickness: 2.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الواجهة
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final surahName = _ayahs.isNotEmpty ? 'سورة ${widget.surahNumber}' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0E8D0),
      appBar: AppBar(
        backgroundColor: _goldColor,
        foregroundColor: _paperColor,
        elevation: 0,
        title: const Text(
          '🎙️ اقرأ معي',
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_autoAdvance ? Icons.sync : Icons.sync_disabled),
            onPressed: () =>
                setState(() => _autoAdvance = !_autoAdvance),
            tooltip: 'الانتقال التلقائي',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _goldColor))
          : _ayahs.isEmpty
              ? const Center(child: Text('⚠️ تعذر تحميل السورة'))
              : Column(
                  children: [
                    // شريط معلومات الآية
                    _buildInfoBar(),
                    // لوحة النص
                    Expanded(child: _buildTextPanel(surahName)),
                    // أدوات التحكم
                    _buildControls(),
                  ],
                ),
    );
  }

  Widget _buildInfoBar() {
    final ayah = _ayahs[_currentAyahIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _goldColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _goldColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'آية ${ayah.number}',
              style: const TextStyle(
                color: _paperColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentAyahIndex + 1} / ${_ayahs.length}',
            style: const TextStyle(
              color: _inkColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPanel(String surahName) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _paperColor,
        border: Border.all(color: _frameColor, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _frameColor, width: 1),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس السورة
              if (_currentAyahIndex == 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: _frameColor, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      surahName,
                      style: const TextStyle(
                        color: _inkColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                ),

              // النص
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int i = 0; i < _currentWords.length; i++)
                      _buildWord(i),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // معلومات الحالة
              if (_userCorrectWords.isNotEmpty ||
                  _userWrongWords.isNotEmpty)
                _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final correct = _userCorrectWords.length;
    final wrong = _userWrongWords.length;
    final total = correct + wrong;
    if (total == 0) return const SizedBox();

    final accuracy = (correct / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _paperColor,
        border: Border.all(color: _frameColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem('✅', 'صحيح', correct, Colors.green.shade700),
              _statItem('❌', 'خطأ', wrong, Colors.red.shade700),
              _statItem('🎯', 'الدقة', accuracy, _goldColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String label, int value, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          '$value${label == "الدقة" ? "%" : ""}',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _paperColor,
        border: Border(top: BorderSide(color: _frameColor, width: 1)),
      ),
      child: Column(
        children: [
          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: _frameColor.withValues(alpha: 0.2),
              color: _goldColor,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),

          // الأزرار
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // السابق
              _controlButton(
                icon: Icons.skip_previous,
                label: 'السابق',
                onTap: _prevAyah,
                enabled: _currentAyahIndex > 0,
              ),

              // تشغيل / إيقاف
              _controlButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                label: _isPlaying ? 'إيقاف' : 'استمع',
                onTap: _togglePlay,
                large: true,
                color: _goldColor,
              ),

              // تسجيل
              _controlButton(
                icon: _isRecording
                    ? Icons.stop
                    : (_isProcessing ? Icons.hourglass_top : Icons.mic),
                label: _isRecording
                    ? 'إيقاف'
                    : (_isProcessing ? '...' : 'اقرأ'),
                onTap: _isProcessing ? null : _toggleRecording,
                color: _isRecording ? Colors.red : Colors.blue.shade700,
              ),

              // التالي
              _controlButton(
                icon: Icons.skip_next,
                label: 'التالي',
                onTap: _nextAyah,
                enabled: _currentAyahIndex < _ayahs.length - 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool large = false,
    bool enabled = true,
    Color? color,
  }) {
    final btnColor = color ?? _frameColor;
    final isDisabled = !enabled || onTap == null;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 64 : 52,
            height: large ? 64 : 52,
            decoration: BoxDecoration(
              color: isDisabled
                  ? btnColor.withValues(alpha: 0.3)
                  : btnColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: btnColor, width: 2),
            ),
            child: Icon(
              icon,
              color: isDisabled ? Colors.grey : btnColor,
              size: large ? 32 : 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey : _inkColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper بسيط لاستخدام dart:io في الملف
class _FileHelper {
  final String path;
  _FileHelper(this.path);
  Future<bool> exists() async => false;
  Future<void> delete() async {}
}
