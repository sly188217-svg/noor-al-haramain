import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../quran/models/surah_model.dart';
import '../quran/models/ayah_model.dart';
import '../quran/services/quran_service.dart';
import '../../core/services/firebase_ai_service.dart';
import '../../core/services/usage_service.dart';

class _WordFeedback {
  final String userWord;
  final String correctWord;
  final String status;

  _WordFeedback({
    required this.userWord,
    required this.correctWord,
    required this.status,
  });

  factory _WordFeedback.fromJson(Map<String, dynamic> json) {
    return _WordFeedback(
      userWord: json['user']?.toString() ?? '',
      correctWord: json['correct']?.toString() ?? '',
      status: json['status']?.toString() ?? 'correct',
    );
  }
}

class RecitationScreen extends StatefulWidget {
  const RecitationScreen({super.key});

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _isPremium = false;
  bool _autoDetectMode = true;
  String? _recordingPath;

  int _remainingRecitations = 3;

  String _userRecitation = '';
  String _correctAyah = '';
  double _accuracy = 0;
  String _feedback = '';
  List<_WordFeedback> _words = [];

  String? _detectedSurahName;
  int? _detectedSurahNumber;
  int? _detectedAyahNumber;

  List<SurahModel> _surahs = [];
  int _selectedSurah = 1;
  int _selectedAyah = 1;
  List<AyahModel> _ayahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuran();
    _loadUserStatus();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserStatus() async {
    try {
      final isPremium = await UsageService.isPremium();
      final remaining = await UsageService.remainingRecitations();
      if (!mounted) return;
      setState(() {
        _isPremium = isPremium;
        _remainingRecitations = remaining;
      });
    } catch (_) {}
  }

  Future<void> _loadQuran() async {
    try {
      final surahs = await QuranService.loadQuran();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _isLoading = false;
      });
      await _loadAyahs(_selectedSurah);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAyahs(int surahNumber) async {
    try {
      final surah = await QuranService.getSurah(surahNumber);
      if (!mounted) return;
      if (surah?.ayahs != null && surah!.ayahs!.isNotEmpty) {
        setState(() {
          _ayahs = surah.ayahs!;
          _selectedAyah = surah.ayahs!.first.number;
          _correctAyah = surah.ayahs!.first.text;
          _userRecitation = '';
          _accuracy = 0;
          _feedback = '';
          _words = [];
          _detectedSurahName = null;
          _detectedSurahNumber = null;
          _detectedAyahNumber = null;
        });
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 التسجيل الصوتي
  // ═══════════════════════════════════════════════════════════
  Future<bool> _hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _recorder.stop();
        debugPrint('🛑 تم إيقاف التسجيل: $path');
        if (mounted) setState(() => _isRecording = false);
        if (path != null) {
          _recordingPath = path;
          await _processAudio(path);
        }
      } catch (e) {
        debugPrint('❌ خطأ: $e');
        if (mounted) setState(() => _isRecording = false);
      }
      return;
    }

    if (!await UsageService.canRecite()) {
      _showLimitDialog();
      return;
    }

    if (!await _hasMicrophonePermission()) {
      _showSnack('⚠️ يجب منح إذن الميكروفون.');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
          _userRecitation = '';
          _accuracy = 0;
          _words = [];
          _detectedSurahName = null;
          _detectedSurahNumber = null;
          _detectedAyahNumber = null;
          _feedback = '🎤 جاري التسجيل... اقرأ الآية';
        });
      }
    } catch (e) {
      _showSnack('⚠️ فشل بدء التسجيل: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 معالجة الصوت: Whisper → Groq AI
  // ═══════════════════════════════════════════════════════════
  Future<void> _processAudio(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _feedback = '🎤 جاري تحويل الصوت إلى نص (Whisper)...';
    });

    try {
      // 1. تحويل الصوت إلى نص
      final transcribedText =
          await FirebaseAiService.transcribeAudio(audioPath);

      if (transcribedText == null || transcribedText.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _feedback = '⚠️ لم يتم التعرف على الصوت. أعد المحاولة.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _userRecitation = transcribedText;
        _feedback = '🔍 جاري التصحيح...';
      });

      // 2. التعرف على الآية (في الوضع التلقائي)
      if (_autoDetectMode && _correctAyah.isEmpty) {
        setState(() {
          _feedback = '🎯 جاري التعرف على الآية...';
        });

        final detected =
            await FirebaseAiService.identifyAyah(transcribedText);

        if (detected == null || detected['surah'] == null) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _feedback = '⚠️ لم يتم التعرف على الآية. اخترها يدوياً.';
          });
          return;
        }

        final surahNumber = detected['surahNumber'] as int?;
        final ayahNumber = detected['ayahNumber'] as int?;

        if (surahNumber == null || ayahNumber == null) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _feedback = '⚠️ لم يتم التعرف على الآية بدقة.';
          });
          return;
        }

        final ayah = await QuranService.getAyah(surahNumber, ayahNumber);
        final surah = await QuranService.getSurah(surahNumber);

        if (ayah == null || surah == null) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _feedback = '⚠️ تعذر جلب الآية.';
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _correctAyah = ayah.text;
          _detectedSurahName = surah.name;
          _detectedSurahNumber = surahNumber;
          _detectedAyahNumber = ayahNumber;
          _feedback = '✅ تم التعرف — جاري التصحيح...';
        });
      }

      // 3. التصحيح
      final result = await FirebaseAiService.analyzeRecitation(
        userRecitation: transcribedText,
        correctAyah: _correctAyah,
      );

      final remaining = await UsageService.remainingRecitations();

      final wordsList = <_WordFeedback>[];
      if (result['words'] is List) {
        for (final w in result['words']) {
          if (w is Map<String, dynamic>) {
            wordsList.add(_WordFeedback.fromJson(w));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _accuracy = (result['accuracy'] as num?)?.toDouble() ?? 0;
        _feedback = result['feedback']?.toString() ?? 'تم التحليل';
        _words = wordsList;
        _remainingRecitations = remaining;
        _isProcessing = false;
      });

      // 4. حذف الملف المؤقت
      try {
        final file = File(audioPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _feedback = '⚠️ تعذر التحليل: $e';
      });
    }
  }

  Future<void> _playHusaryAyah() async {
    try {
      final surahNum =
          _autoDetectMode ? _detectedSurahNumber : _selectedSurah;
      final ayahNum = _autoDetectMode ? _detectedAyahNumber : _selectedAyah;

      if (surahNum == null || ayahNum == null) {
        _showSnack('⚠️ لم يتم تحديد الآية بعد');
        return;
      }

      final surahStr = surahNum.toString().padLeft(3, '0');
      final ayahStr = ayahNum.toString().padLeft(3, '0');
      final url =
          'https://everyayah.com/data/Husary_128kbps/$surahStr$ayahStr.mp3';

      setState(() => _isSpeaking = true);
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isSpeaking = false);
      _showSnack('⚠️ تعذر تشغيل الصوت');
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _resetRecitation() {
    setState(() {
      _userRecitation = '';
      _accuracy = 0;
      _feedback = '';
      _words = [];
      _detectedSurahName = null;
      _detectedSurahNumber = null;
      _detectedAyahNumber = null;
      if (_autoDetectMode) _correctAyah = '';
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text('انتهى الحد اليومي',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18)),
          ],
        ),
        content: const Text(
          'لقد استخدمت 3 تصحيحات مجانية اليوم.\n⏰ يمكنك المحاولة مجدداً غداً.',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Color _accuracyColor() {
    if (_accuracy >= 90) return Colors.green;
    if (_accuracy >= 75) return Colors.lightGreen;
    if (_accuracy >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        elevation: 0,
        title: const Text('تصحيح التلاوة',
            style: TextStyle(color: Color(0xFFD4AF37))),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetRecitation,
            tooltip: 'إعادة تعيين',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLimitBanner(),
                  const SizedBox(height: 12),
                  _buildModeToggle(),
                  const SizedBox(height: 12),
                  if (!_autoDetectMode) ...[
                    _buildManualSelectors(),
                    const SizedBox(height: 12),
                  ],
                  if (_correctAyah.isNotEmpty) ...[
                    _buildDetectedInfo(),
                    const SizedBox(height: 12),
                    _buildCorrectAyahWithErrors(),
                    const SizedBox(height: 12),
                  ],
                  _buildControls(),
                  const SizedBox(height: 12),
                  if (_userRecitation.isNotEmpty) _buildUserRecitation(),
                  if (_feedback.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildFeedback(),
                  ],
                  const SizedBox(height: 16),
                  _buildHint(),
                ],
              ),
            ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _autoDetectMode = true;
                _resetRecitation();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _autoDetectMode
                      ? const Color(0xFFD4AF37)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: _autoDetectMode
                          ? Colors.black
                          : const Color(0xFFD4AF37),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '🎯 التعرف التلقائي',
                      style: TextStyle(
                        color: _autoDetectMode
                            ? Colors.black
                            : const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _autoDetectMode = false;
                _resetRecitation();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_autoDetectMode
                      ? const Color(0xFFD4AF37)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.list,
                      color: !_autoDetectMode
                          ? Colors.black
                          : const Color(0xFFD4AF37),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '📋 اختيار يدوي',
                      style: TextStyle(
                        color: !_autoDetectMode
                            ? Colors.black
                            : const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitBanner() {
    if (_isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD4AF37)),
        ),
        child: const Row(
          children: [
            Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
            SizedBox(width: 8),
            Text('Premium — تصحيح غير محدود',
                style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final color = _remainingRecitations > 1
        ? Colors.green
        : (_remainingRecitations == 1 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _remainingRecitations > 0
                  ? 'متبقي لك $_remainingRecitations من التصحيحات المجانية'
                  : 'انتهى الحد اليومي — عاود غداً',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSelectors() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedSurah,
                dropdownColor: const Color(0xFF1C2541),
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'السورة (1-114)',
                  labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                  filled: true,
                  fillColor: const Color(0xFF0B132B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _surahs.map((s) {
                  return DropdownMenuItem<int>(
                    value: s.number,
                    child: Text('${s.number}. ${s.name}',
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedSurah = v);
                  _loadAyahs(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _ayahs.any((a) => a.number == _selectedAyah)
                    ? _selectedAyah
                    : (_ayahs.isNotEmpty ? _ayahs.first.number : null),
                dropdownColor: const Color(0xFF1C2541),
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'الآية (${_ayahs.length})',
                  labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                  filled: true,
                  fillColor: const Color(0xFF0B132B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _ayahs.map((a) {
                  return DropdownMenuItem<int>(
                    value: a.number,
                    child: Text('${a.number}'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final ayah = _ayahs.firstWhere((a) => a.number == v);
                  setState(() {
                    _selectedAyah = v;
                    _correctAyah = ayah.text;
                    _detectedSurahName = null;
                    _detectedSurahNumber = null;
                    _detectedAyahNumber = null;
                    _userRecitation = '';
                    _accuracy = 0;
                    _feedback = '';
                    _words = [];
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // عرض عدد الآيات
        if (_ayahs.isNotEmpty)
          Text(
            'سورة ${_surahs.firstWhere((s) => s.number == _selectedSurah, orElse: () => _surahs.first).name} — ${_ayahs.length} آية',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildDetectedInfo() {
    if (!_autoDetectMode || _detectedSurahName == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '✅ تم التعرف: سورة $_detectedSurahName — الآية $_detectedAyahNumber',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectAyahWithErrors() {
    if (_words.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Row(
              children: [
                Icon(Icons.book, color: Color(0xFFD4AF37), size: 16),
                SizedBox(width: 6),
                Text('📖 النص الصحيح',
                    style:
                        TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _correctAyah,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 24,
                fontFamily: 'Amiri',
                height: 2.2,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.spellcheck, color: Color(0xFFD4AF37), size: 18),
              SizedBox(width: 8),
              Text(
                '📝 التصحيح كلمة بكلمة',
                style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Amiri',
                height: 2.4,
              ),
              children: _buildWordSpans(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendItem(Colors.green, 'صحيح'),
              _legendItem(Colors.red, 'خطأ'),
              _legendItem(Colors.grey, 'ناقص'),
              _legendItem(Colors.orange, 'زائد'),
            ],
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildWordSpans() {
    final spans = <TextSpan>[];

    for (var w in _words) {
      Color color;
      TextDecoration decoration = TextDecoration.none;
      String displayWord;
      FontWeight fontWeight = FontWeight.w500;
      double thickness = 1.5;

      switch (w.status) {
        case 'correct':
          color = Colors.green;
          displayWord = w.correctWord;
          break;
        case 'missing':
          color = Colors.grey;
          decoration = TextDecoration.lineThrough;
          displayWord = w.correctWord;
          break;
        case 'extra':
          color = Colors.orange;
          decoration = TextDecoration.lineThrough;
          displayWord = w.userWord;
          break;
        case 'wrong':
        default:
          color = Colors.red;
          decoration = TextDecoration.underline;
          displayWord =
              w.correctWord.isNotEmpty ? w.correctWord : w.userWord;
          fontWeight = FontWeight.bold;
          thickness = 2.5;
          break;
      }

      spans.add(TextSpan(
        text: '$displayWord ',
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontFamily: 'Amiri',
          fontWeight: fontWeight,
          decoration: decoration,
          decorationColor: color,
          decorationThickness: thickness,
        ),
      ));
    }

    return spans;
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSpeaking ? _stopAudio : _playHusaryAyah,
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, size: 20),
            label: Text(_isSpeaking ? 'إيقاف' : 'الحصري'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2541),
              foregroundColor: const Color(0xFFD4AF37),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _toggleRecording,
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              size: 20,
            ),
            label: Text(
              _isRecording
                  ? '⏹ إيقاف التسجيل'
                  : (_autoDetectMode ? '🎤 ابدأ التسجيل' : '🎤 ابدأ التلاوة'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isRecording ? Colors.red : const Color(0xFFD4AF37),
              foregroundColor: _isRecording ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRecitation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('🎤 ما قرأته (Whisper)',
                  style:
                      TextStyle(color: Colors.blueAccent, fontSize: 12)),
              SizedBox(width: 6),
              Icon(Icons.mic, color: Colors.blueAccent, size: 14),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _userRecitation,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Amiri',
              height: 1.8,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (_accuracy > 0 ? _accuracyColor() : const Color(0xFFD4AF37))
                .withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_accuracy > 0) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _accuracy / 100,
                      minHeight: 12,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(_accuracyColor()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_accuracy.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _accuracyColor(),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _feedback,
            style: TextStyle(
              color: _accuracy > 0 ? _accuracyColor() : Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _autoDetectMode
            ? '💡 اقرأ أي آية من أي سورة (114 سورة، 6236 آية)، وسيحوّلها Whisper إلى نص، ثم يصححها الذكاء الاصطناعي.'
            : '💡 اختر السورة (114) والآية من القائمة، ثم اضغط "ابدأ التلاوة". يمكنك سماع الحصري أولاً.',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
