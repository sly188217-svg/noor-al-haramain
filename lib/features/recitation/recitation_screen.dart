import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import '../quran/models/surah_model.dart';
import '../quran/models/ayah_model.dart';
import '../quran/services/quran_service.dart';
import '../../core/services/firebase_ai_service.dart';
import '../../core/services/usage_service.dart';

/// نموذج كلمة في المقارنة
class _WordFeedback {
  final String userWord;
  final String correctWord;
  final String status; // correct / wrong / missing / extra

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

/// ═══════════════════════════════════════════════════════════
/// شاشة تصحيح التلاوة — كلمة بكلمة
/// ═══════════════════════════════════════════════════════════
class RecitationScreen extends StatefulWidget {
  const RecitationScreen({super.key});

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _speechAvailable = false;
  bool _isPremium = false;

  int _remainingRecitations = 3;

  String _userRecitation = '';
  String _correctAyah = '';
  double _accuracy = 0;
  String _feedback = '';
  List<_WordFeedback> _words = [];

  List<SurahModel> _surahs = [];
  int _selectedSurah = 1;
  int _selectedAyah = 1;
  List<AyahModel> _ayahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadQuran();
    _loadUserStatus();
  }

  @override
  void dispose() {
    _speech.stop();
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

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
            if (_userRecitation.isNotEmpty) _analyzeRecitation();
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (e) {
      if (mounted) setState(() => _speechAvailable = false);
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
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final canRecite = await UsageService.canRecite();
      if (!canRecite) {
        _showLimitDialog();
        return;
      }
    }

    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        _showSnack('⚠️ التعرف الصوتي غير متوفر');
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _userRecitation = '';
      _accuracy = 0;
      _feedback = '🎤 استمع... تلُ الآية الآن';
      _words = [];
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _userRecitation = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'ar_SA',
    );
  }

  Future<void> _analyzeRecitation() async {
    if (_userRecitation.trim().isEmpty || _correctAyah.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _feedback = '🔍 جاري التحليل...';
    });

    try {
      final result = await FirebaseAiService.analyzeRecitation(
        userRecitation: _userRecitation,
        correctAyah: _correctAyah,
      );

      await UsageService.incrementRecitation();
      final remaining = await UsageService.remainingRecitations();

      // تحويل الكلمات
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _feedback = '⚠️ تعذر التحليل: $e';
      });
    }
  }

  Future<void> _playHusary() async {
    try {
      final padded = _selectedSurah.toString().padLeft(3, '0');
      final url = 'https://server13.mp3quran.net/husary/$padded.mp3';

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
                  _buildSelectors(),
                  const SizedBox(height: 12),
                  _buildAyahCard(),
                  const SizedBox(height: 12),
                  _buildControls(),
                  const SizedBox(height: 12),
                  if (_userRecitation.isNotEmpty) _buildUserRecitation(),
                  if (_words.isNotEmpty) _buildWordByWord(),
                  if (_feedback.isNotEmpty) _buildFeedback(),
                  const SizedBox(height: 16),
                  _buildHint(),
                ],
              ),
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
                  ? 'متبقي لك $_remainingRecitations من التصحيحات المجانية اليوم'
                  : 'انتهى الحد اليومي — عاود غداً',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _selectedSurah,
            dropdownColor: const Color(0xFF1C2541),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'السورة',
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
            decoration: InputDecoration(
              labelText: 'الآية',
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
                _userRecitation = '';
                _accuracy = 0;
                _feedback = '';
                _words = [];
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAyahCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('📖 النص الصحيح',
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            _correctAyah,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 20,
              fontFamily: 'Amiri',
              height: 1.9,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSpeaking ? _stopAudio : _playHusary,
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
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
            onPressed: _isProcessing ? null : _toggleListening,
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            label: Text(_isListening ? '⏹ إيقاف' : '🎤 ابدأ التلاوة'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isListening ? Colors.red : const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
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
          const Text('🎤 ما قرأته',
              style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            _userRecitation,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Amiri',
              height: 1.7,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ عرض التصحيح كلمة بكلمة
  // ═══════════════════════════════════════════════════════════
  Widget _buildWordByWord() {
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
          Row(
            children: const [
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 14,
            alignment: WrapAlignment.end,
            textDirection: TextDirection.rtl,
            children: _words.map((w) => _buildWordChip(w)).toList(),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendItem(Colors.green, 'صحيح'),
              _legendItem(Colors.red, 'خطأ'),
              _legendItem(Colors.grey, 'ناقص'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(_WordFeedback w) {
    Color borderColor;
    Color bgColor;
    String displayWord;
    String? correctionWord;

    switch (w.status) {
      case 'correct':
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.15);
        displayWord = w.correctWord;
        correctionWord = null;
        break;
      case 'missing':
        borderColor = Colors.grey;
        bgColor = Colors.grey.withValues(alpha: 0.15);
        displayWord = w.correctWord;
        correctionWord = w.correctWord;
        break;
      case 'extra':
        borderColor = Colors.orange;
        bgColor = Colors.orange.withValues(alpha: 0.15);
        displayWord = w.userWord;
        correctionWord = null;
        break;
      case 'wrong':
      default:
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.15);
        displayWord = w.userWord.isEmpty ? w.correctWord : w.userWord;
        correctionWord = w.correctWord;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            displayWord,
            style: TextStyle(
              color: borderColor,
              fontSize: 18,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          if (correctionWord != null && correctionWord != displayWord) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '↳ $correctionWord',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ],
      ),
    );
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

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accuracyColor().withValues(alpha: 0.5)),
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
                      minHeight: 10,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _feedback,
            style: TextStyle(color: _accuracyColor(), fontSize: 14),
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
      child: const Text(
        '💡 اختر السورة والآية، ثم اضغط "ابدأ التلاوة". '
        'يمكنك سماع تلاوة الشيخ الحصري أولاً، ثم تلُ أنت الآية.',
        style: TextStyle(color: Colors.white70, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
