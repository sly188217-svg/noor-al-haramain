import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/quran_service.dart';
import 'models/ayah_model.dart';
import 'hifz_mode.dart';
import '../../core/services/firebase_ai_service.dart';
import '../../core/services/progress_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎙️ اقرأ معي — النسخة الاحترافية الشاملة
/// ✅ التحكم بسرعة القارئ (0.5x - 1.5x)
/// ✅ تكرار الآية (1, 3, 5, 10 مرات)
/// ✅ تعدد القراء (6 قراء)
/// ✅ وضع الحفظ Hifz Mode (5 مستويات)
/// ✅ النقر على كلمة لسماعها
/// ✅ تتبع التقدم والإنجازات
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

  List<AyahModel> _ayahs = [];
  List<String> _currentWords = [];
  int _currentAyahIndex = 0;
  int _highlightedWordIndex = -1;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _autoAdvance = true;

  // ⚡ السرعة
  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  // 🔁 التكرار
  int _repeatCount = 1;
  int _currentRepeat = 0;
  static const List<int> _repeatOptions = [1, 3, 5, 10];

  // 🎙️ القارئ
  String _selectedReciter = 'Husary_128kbps';
  static const List<Map<String, String>> _reciters = [
    {'id': 'Husary_128kbps', 'name': 'الحصري'},
    {'id': 'Abdul_Basit_Murattal_192kbps', 'name': 'عبد الباسط'},
    {'id': 'Maher_AlMuaiqly_128kbps', 'name': 'ماهر المعيقلي'},
    {'id': 'Minshawy_Murattal_128kbps', 'name': 'المنشاوي'},
    {'id': 'Ghamadi_40kbps', 'name': 'سعد الغامدي'},
    {'id': 'Yasser_Ad-Dussary_128kbps', 'name': 'ياسر الدوسري'},
  ];

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  final Set<int> _userCorrectWords = {};
  final Set<int> _userWrongWords = {};

  // 🧠 وضع الحفظ
  int _hifzLevel = 1;
  List<bool> _hiddenMask = [];

  // 👆 كلمة مختارة
  int? _selectedWordIndex;

  // 📊 تتبع التقدم
  bool _hasSaved = false;

  // 🎨 الألوان
  static const Color _paperColor = Color(0xFFFBF6E9);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _goldColor = Color(0xFFB8860B);
  static const Color _goldLight = Color(0xFFD4AF37);
  static const Color _frameColor = Color(0xFF9C7A3C);

  @override
  void initState() {
    super.initState();
    _loadSurah();
    _loadPreferences();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _totalDuration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _currentPosition = p);
      _updateHighlight(p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      _handleAyahComplete();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _playbackSpeed = prefs.getDouble('read_speed') ?? 1.0;
      _repeatCount = prefs.getInt('read_repeat') ?? 1;
      _selectedReciter =
          prefs.getString('read_reciter') ?? 'Husary_128kbps';
      _hifzLevel = prefs.getInt('read_hifz_level') ?? 1;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('read_speed', _playbackSpeed);
    await prefs.setInt('read_repeat', _repeatCount);
    await prefs.setString('read_reciter', _selectedReciter);
    await prefs.setInt('read_hifz_level', _hifzLevel);
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
    _currentRepeat = 0;
    _selectedWordIndex = null;
    _hasSaved = false;

    // 🧠 توليد قناع الإخفاء
    _hiddenMask = HifzMode.generateHiddenMask(
      _currentWords.length,
      _hifzLevel,
      widget.surahNumber * 1000 + ayah.number,
    );
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
    await _playCurrentAyah();
  }

  Future<void> _playCurrentAyah() async {
    final ayah = _ayahs[_currentAyahIndex];
    final surahStr = widget.surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayah.number.toString().padLeft(3, '0');
    final url =
        'https://everyayah.com/data/$_selectedReciter/$surahStr$ayahStr.mp3';

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('❌ play: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _handleAyahComplete() {
    setState(() {
      _isPlaying = false;
      _highlightedWordIndex = _currentWords.length - 1;
    });

    // 🔁 التكرار
    if (_currentRepeat + 1 < _repeatCount) {
      setState(() => _currentRepeat++);
      Future.delayed(const Duration(milliseconds: 500), _playCurrentAyah);
      return;
    }

    // ⏭️ التنقل التلقائي
    if (_autoAdvance) {
      Future.delayed(const Duration(milliseconds: 1500), _nextAyah);
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
  // ⏭️ التنقل
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
  // 🎤 التسجيل
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

      // 📊 حفظ التقدم
      if (!_hasSaved) {
        final correct = _userCorrectWords.length;
        final wrong = _userWrongWords.length;
        final total = correct + wrong;
        if (total > 0) {
          final acc = (correct / total * 100).round();
          _hasSaved = true;

          await ProgressService.saveAyahResult(
            surahNumber: widget.surahNumber,
            ayahNumber: ayah.number,
            accuracy: acc,
            correctWords: correct,
            totalWords: total,
          );

          if (mounted) {
            final unlocked = await ProgressService.getUnlockedAchievements();
            if (unlocked.isNotEmpty) {
              await _showAchievementIfNew(unlocked);
            }
          }
        }
      }

      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ process: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showAchievementIfNew(Set<String> unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList('shown_achievements') ?? [];
    final newOnes = unlocked.where((id) => !shown.contains(id)).toList();

    for (final id in newOnes) {
      final ach = ProgressService.allAchievements.firstWhere(
        (a) => a['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (ach.isEmpty) continue;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🏆 ${ach['name']} — ${ach['desc']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            backgroundColor: _goldColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (newOnes.isNotEmpty) {
      await prefs.setStringList('shown_achievements', [...shown, ...newOnes]);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⚙️ نوافذ الإعدادات
  // ═══════════════════════════════════════════════════════════
  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, color: _goldColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              '⚡ سرعة القراءة',
              style: TextStyle(
                color: _inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _speeds.map((s) {
                final isActive = _playbackSpeed == s;
                return GestureDetector(
                  onTap: () {
                    setState(() => _playbackSpeed = s);
                    _audioPlayer.setPlaybackRate(s);
                    _savePreferences();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? _goldColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _goldColor, width: 1.5),
                    ),
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        color: isActive ? _paperColor : _goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚡ 0.5x للأطفال والمبتدئين',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepeatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.repeat, color: _goldColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              '🔁 عدد مرات التكرار',
              style: TextStyle(
                color: _inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _repeatOptions.map((r) {
                final isActive = _repeatCount == r;
                return GestureDetector(
                  onTap: () {
                    setState(() => _repeatCount = r);
                    _savePreferences();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? _goldColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _goldColor, width: 1.5),
                    ),
                    child: Text(
                      r == 1 ? 'مرة' : '$r مرات',
                      style: TextStyle(
                        color: isActive ? _paperColor : _goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '🔁 تكرار الآية يساعد على الحفظ',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showReciterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: _goldColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              '🎙️ اختر القارئ',
              style: TextStyle(
                color: _inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 16),
            ..._reciters.map((r) {
              final isActive = _selectedReciter == r['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedReciter = r['id']!);
                    _savePreferences();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _goldColor.withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? _goldColor : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _goldColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          r['name']!,
                          style: TextStyle(
                            color: _inkColor,
                            fontSize: 16,
                            fontFamily: 'Amiri',
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showHifzDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology, color: _goldColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              '🧠 وضع الحفظ (Hifz)',
              style: TextStyle(
                color: _inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'اختر مستوى إخفاء الكلمات لاختبار حفظك',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...HifzMode.levels.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final lvl = entry.value;
              final isActive = _hifzLevel == idx;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hifzLevel = idx;
                      _prepareCurrentAyah();
                    });
                    _savePreferences();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _goldColor.withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? _goldColor : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(lvl['icon']!,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lvl['name']!,
                                style: const TextStyle(
                                  color: _inkColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                lvl['desc']!,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check_circle, color: _goldColor),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 نافذة التقدم
  // ═══════════════════════════════════════════════════════════
  Future<void> _showProgressDialog() async {
    final progress = await ProgressService.getProgress();
    final streak = await ProgressService.getStreak();
    final unlocked = await ProgressService.getUnlockedAchievements();

    if (!mounted) return;

    final totalAyahs = progress.length;
    final streakDays = (streak['days'] as int?) ?? 0;

    double avgAcc = 0;
    if (progress.isNotEmpty) {
      final total = progress.values
          .map((p) => (p['accuracy'] as num?)?.toDouble() ?? 0)
          .reduce((a, b) => a + b);
      avgAcc = total / progress.length;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _paperColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _goldColor, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: _goldColor),
            SizedBox(width: 8),
            Text(
              '📊 تقدمي',
              style: TextStyle(
                color: _goldColor,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statRow('📖', 'الآيات المقروءة', '$totalAyahs'),
              _statRow('🎯', 'متوسط الدقة', '${avgAcc.round()}%'),
              _statRow('🔥', 'سلسلة الأيام', '$streakDays يوم'),
              _statRow(
                '🏆',
                'الإنجازات',
                '${unlocked.length}/${ProgressService.allAchievements.length}',
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                '🏆 الإنجازات:',
                style: TextStyle(
                  color: _goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...ProgressService.allAchievements.map((a) {
                final isUnlocked = unlocked.contains(a['id']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        isUnlocked ? Icons.check_circle : Icons.lock_outline,
                        color: isUnlocked ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${a['name']} — ${a['desc']}',
                          style: TextStyle(
                            color: isUnlocked ? _inkColor : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق',
                style: TextStyle(color: _goldColor)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _inkColor, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _goldColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بناء الكلمة
  // ═══════════════════════════════════════════════════════════
  Widget _buildWord(int index) {
    final word = _currentWords[index];
    final isHidden = _hifzLevel > 1 &&
        index < _hiddenMask.length &&
        _hiddenMask[index];
    final isSelected = _selectedWordIndex == index;

    Color color = _inkColor;
    Color? bgColor;
    TextDecoration decoration = TextDecoration.none;
    String displayWord = word;

    if (_userWrongWords.contains(index)) {
      color = Colors.red;
      decoration = TextDecoration.underline;
    } else if (_userCorrectWords.contains(index)) {
      color = Colors.green.shade700;
    } else if (index == _highlightedWordIndex && !isHidden) {
      color = Colors.white;
      bgColor = _goldColor;
    } else if (isHidden) {
      color = Colors.grey.shade400;
      displayWord = HifzMode.getMaskedWord(word);
    }

    if (isSelected) {
      bgColor = Colors.blue.shade100;
      color = Colors.blue.shade900;
    }

    return GestureDetector(
      onTap: () => _onWordTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: bgColor != null
            ? BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: Text(
          displayWord,
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
      ),
    );
  }

  /// 👆 النقر على كلمة
  void _onWordTap(int index) {
    if (index >= _currentWords.length) return;

    setState(() => _selectedWordIndex = index);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '👆 "${_currentWords[index]}"',
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: _goldColor,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _selectedWordIndex = null);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الواجهة الرئيسية
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0E8D0),
      appBar: AppBar(
        backgroundColor: _goldColor,
        foregroundColor: _paperColor,
        elevation: 0,
        title: const Text(
          '🎙️ اقرأ معي',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showProgressDialog,
            tooltip: '📊 تقدمي',
          ),
          IconButton(
            icon: Icon(_autoAdvance ? Icons.sync : Icons.sync_disabled),
            onPressed: () => setState(() => _autoAdvance = !_autoAdvance),
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
                    _buildSettingsBar(),
                    _buildInfoBar(),
                    Expanded(child: _buildTextPanel()),
                    _buildControls(),
                  ],
                ),
    );
  }

  Widget _buildSettingsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: _goldColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          _settingChip(
            icon: Icons.speed,
            label: '${_playbackSpeed}x',
            onTap: _showSpeedDialog,
          ),
          const SizedBox(width: 4),
          _settingChip(
            icon: Icons.repeat,
            label: _repeatCount == 1 ? 'مرة' : '×$_repeatCount',
            onTap: _showRepeatDialog,
          ),
          const SizedBox(width: 4),
          _settingChip(
            icon: Icons.person,
            label: _reciters
                .firstWhere(
                  (r) => r['id'] == _selectedReciter,
                  orElse: () => _reciters.first,
                )['name']!,
            onTap: _showReciterDialog,
          ),
          const SizedBox(width: 4),
          _settingChip(
            icon: Icons.psychology,
            label: '🧠 $_hifzLevel',
            onTap: _showHifzDialog,
          ),
        ],
      ),
    );
  }

  Widget _settingChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _paperColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _goldColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _goldColor, size: 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _inkColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    final ayah = _ayahs[_currentAyahIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _paperColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          if (_repeatCount > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                '🔁 ${_currentRepeat + 1}/$_repeatCount',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (_hifzLevel > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple),
              ),
              child: Text(
                '🧠 $_hifzLevel/5',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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

  Widget _buildTextPanel() {
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('✅', 'صحيح', correct, Colors.green.shade700),
          _statItem('❌', 'خطأ', wrong, Colors.red.shade700),
          _statItem('🎯', 'الدقة', accuracy, _goldColor),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String label, int value, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          '$value${label == "الدقة" ? "%" : ""}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlButton(
                icon: Icons.skip_previous,
                label: 'السابق',
                onTap: _prevAyah,
                enabled: _currentAyahIndex > 0,
              ),
              _controlButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                label: _isPlaying ? 'إيقاف' : 'استمع',
                onTap: _togglePlay,
                large: true,
                color: _goldColor,
              ),
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
