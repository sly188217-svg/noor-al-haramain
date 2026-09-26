import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/quran_service.dart';
import 'models/ayah_model.dart';
import 'models/surah_model.dart';
import 'hifz_mode.dart';
import '../../core/services/firebase_ai_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/tajweed_colorer.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/usage_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎙️ اقرأ معي — مع دعم التشكيل
/// ✅ مقارنة مزدوجة (بدون/مع تشكيل)
/// ✅ عرض تفاصيل أخطاء التشكيل
/// ✅ معالجة أخطاء كاملة
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

  late int _currentSurahNumber;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _autoAdvance = true;
  bool _hasSaved = false;

  String _processingStatus = '';
  String _processingError = '';
  String _lastTranscription = '';
  double _accuracy = 0;

  bool _isPremium = false;
  int _remainingReadWithMe = 3;
  bool _isLocked = false;

  List<SurahModel> _allSurahs = [];

  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  int _repeatCount = 1;
  int _currentRepeat = 0;
  static const List<int> _repeatOptions = [1, 3, 5, 10];

  String _selectedReciter = 'Husary_128kbps';
  static const List<Map<String, String>> _reciters = [
    {'id': 'Husary_128kbps', 'name': 'الحصري'},
    {'id': 'Abdul_Basit_Murattal_192kbps', 'name': 'عبد الباسط'},
    {'id': 'Maher_AlMuaiqly_128kbps', 'name': 'ماهر المعيقلي'},
    {'id': 'Minshawy_Murattal_128kbps', 'name': 'المنشاوي'},
    {'id': 'Ghamadi_40kbps', 'name': 'سعد الغامدي'},
    {'id': 'Yasser_Ad-Dussary_128kbps', 'name': 'ياسر الدوسري'},
  ];

  int _hifzLevel = 1;
  List<bool> _hiddenMask = [];

  int? _selectedWordIndex;

  bool _showTajweed = false;
  bool _showTranslation = false;
  String _currentLang = 'ar';
  String? _ayahTranslation;

  bool _testMode = false;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // ═══════════════════════════════════════════════════════
  // 📊 نتائج التصحيح التفصيلية
  // ═══════════════════════════════════════════════════════
  final Set<int> _userCorrectWords = {};
  final Set<int> _userWrongWords = {};
  final Set<int> _userMissingWords = {};
  final Set<int> _userExtraWords = {};
  final Set<int> _userTashkeelWrongWords = {};
  final Map<int, String> _wordDetails = {};

  static const Color _paperColor = Color(0xFFFBF6E9);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _goldColor = Color(0xFFB8860B);
  static const Color _goldLight = Color(0xFFD4AF37);
  static const Color _frameColor = Color(0xFF9C7A3C);

  @override
  void initState() {
    super.initState();
    _currentSurahNumber = widget.surahNumber;
    _setupAudioListeners();
    _loadAllSurahs();
    _loadSurah();
    _loadPreferences();
    _loadTranslationPrefs();
    _loadUsageStatus();
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

  Future<void> _loadAllSurahs() async {
    try {
      final surahs = await QuranService.loadQuran();
      if (!mounted) return;
      setState(() => _allSurahs = surahs);
    } catch (e) {
      debugPrint('⚠️ فشل تحميل السور: $e');
    }
  }

  String _getCurrentSurahName() {
    if (_allSurahs.isEmpty) return 'اقرأ معي';
    try {
      final surah = _allSurahs.firstWhere(
        (s) => s.number == _currentSurahNumber,
      );
      return surah.name.replaceAll('سورة ', '');
    } catch (_) {
      return 'اقرأ معي';
    }
  }

  Future<void> _changeSurah(int newSurahNumber) async {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _isLoading = true;
      _currentAyahIndex = 0;
      _highlightedWordIndex = -1;
      _clearResults();
      _currentSurahNumber = newSurahNumber;
      _processingStatus = '';
      _processingError = '';
      _lastTranscription = '';
      _accuracy = 0;
    });

    try {
      final surah = await QuranService.getSurah(newSurahNumber);
      if (surah?.ayahs == null || surah!.ayahs!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _ayahs = surah.ayahs!;
        _currentAyahIndex = 0;
        _isLoading = false;
      });
      _prepareCurrentAyah();
    } catch (e) {
      debugPrint('❌ فشل تغيير السورة: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearResults() {
    _userCorrectWords.clear();
    _userWrongWords.clear();
    _userMissingWords.clear();
    _userExtraWords.clear();
    _userTashkeelWrongWords.clear();
    _wordDetails.clear();
  }

  void _showSurahPicker() {
    final searchController = TextEditingController();
    List<SurahModel> filtered = List.from(_allSurahs);

    showModalBottomSheet(
      context: context,
      backgroundColor: _paperColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
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
                      color: _goldColor,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book,
                            color: _paperColor, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '📚 اختر سورة',
                            style: TextStyle(
                              color: _paperColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.close, color: _paperColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchController,
                      onChanged: (q) {
                        setModalState(() {
                          if (q.isEmpty) {
                            filtered = List.from(_allSurahs);
                          } else {
                            filtered = _allSurahs.where((s) {
                              return s.name.contains(q) ||
                                  s.number.toString() == q ||
                                  s.number.toString().startsWith(q);
                            }).toList();
                          }
                        });
                      },
                      style: const TextStyle(color: _inkColor),
                      decoration: InputDecoration(
                        hintText: '🔍 ابحث عن سورة...',
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                            const Icon(Icons.search, color: _goldColor),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: _goldColor.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final surah = filtered[index];
                        final isCurrent =
                            surah.number == _currentSurahNumber;
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? _goldColor
                                  : _goldColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: _goldColor),
                            ),
                            child: Center(
                              child: Text(
                                '${surah.number}',
                                style: TextStyle(
                                  color: isCurrent
                                      ? _paperColor
                                      : _goldColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            surah.name,
                            style: TextStyle(
                              color: _inkColor,
                              fontSize: 16,
                              fontFamily: 'Amiri',
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${surah.numberOfAyahs} آية',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 11),
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFFB8860B))
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            if (!isCurrent) {
                              _changeSurah(surah.number);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
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

  Future<void> _loadTranslationPrefs() async {
    final lang = await TranslationService.getCurrentLang();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentLang = lang;
      _showTranslation = prefs.getBool('show_translation') ?? false;
      _showTajweed = prefs.getBool('show_tajweed') ?? false;
    });
  }

  Future<void> _loadUsageStatus() async {
    final isPremium = await UsageService.isPremium();
    final remaining = await UsageService.remainingReadWithMe();
    if (!mounted) return;
    setState(() {
      _isPremium = isPremium;
      _remainingReadWithMe = remaining;
      _isLocked = !isPremium && remaining <= 0;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('read_speed', _playbackSpeed);
    await prefs.setInt('read_repeat', _repeatCount);
    await prefs.setString('read_reciter', _selectedReciter);
    await prefs.setInt('read_hifz_level', _hifzLevel);
  }

  Future<void> _saveQuickPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadSurah() async {
    try {
      final surah = await QuranService.getSurah(_currentSurahNumber);
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
    _clearResults();
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _currentRepeat = 0;
    _selectedWordIndex = null;
    _hasSaved = false;
    _ayahTranslation = null;
    _processingStatus = '';
    _processingError = '';
    _lastTranscription = '';
    _accuracy = 0;

    _hiddenMask = HifzMode.generateHiddenMask(
      _currentWords.length,
      _hifzLevel,
      _currentSurahNumber * 1000 + ayah.number,
    );

    if (_showTranslation && _currentLang != 'ar') {
      _loadAyahTranslation();
    }
  }

  Future<void> _loadAyahTranslation() async {
    if (_currentAyahIndex >= _ayahs.length) return;
    final ayah = _ayahs[_currentAyahIndex];
    final trans = await TranslationService.getAyahTranslation(
      surahNumber: _currentSurahNumber,
      ayahNumber: ayah.number,
      langCode: _currentLang,
    );
    if (!mounted) return;
    setState(() => _ayahTranslation = trans);
  }

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
    final surahStr = _currentSurahNumber.toString().padLeft(3, '0');
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

    if (_currentRepeat + 1 < _repeatCount) {
      setState(() => _currentRepeat++);
      Future.delayed(const Duration(milliseconds: 500), _playCurrentAyah);
      return;
    }

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

  Future<void> _toggleRecording() async {
    if (_isLocked) {
      setState(() => _isLocked = true);
      return;
    }

    if (_isRecording) {
      try {
        final path = await _recorder.stop();
        if (mounted) setState(() => _isRecording = false);
        if (path != null) await _processRecording(path);
      } catch (e) {
        debugPrint('❌ stop: $e');
        if (mounted) {
          setState(() {
            _isRecording = false;
            _processingError = '⚠️ فشل إيقاف التسجيل';
          });
        }
      }
      return;
    }

    if (!_isPremium) {
      final canUse = await UsageService.canReadWithMe();
      if (!canUse) {
        setState(() => _isLocked = true);
        return;
      }
    }

    if (!await _hasMicPermission()) {
      if (mounted) {
        setState(() {
          _processingError = '⚠️ يجب منح إذن الميكروفون';
        });
      }
      return;
    }

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
          _clearResults();
          _processingStatus = '';
          _processingError = '';
          _lastTranscription = '';
          _accuracy = 0;
        });
      }
    } catch (e) {
      debugPrint('❌ record start: $e');
      if (mounted) {
        setState(() => _processingError = '⚠️ فشل بدء التسجيل');
      }
    }
  }

  Future<bool> _hasMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 معالجة التسجيل
  // ═══════════════════════════════════════════════════════════
  Future<void> _processRecording(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _processingError = '⚠️ ملف التسجيل غير موجود';
          _isProcessing = false;
        });
      }
      return;
    }

    final fileSize = await file.length();
    if (fileSize < 1000) {
      if (mounted) {
        setState(() {
          _processingError = '⚠️ التسجيل قصير جداً';
          _isProcessing = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _processingStatus = '📤 جاري إرسال الصوت...';
        _processingError = '';
      });
    }

    try {
      final ayah = _ayahs[_currentAyahIndex];

      // 1️⃣ Whisper
      if (mounted) {
        setState(() => _processingStatus = '🎤 جاري تحويل الصوت إلى نص...');
      }

      String? transcribed;
      try {
        transcribed = await FirebaseAiService.transcribeAudio(
          path,
          correctText: ayah.text,
        ).timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            debugPrint('⏱️ انتهت مهلة Whisper');
            return null;
          },
        );
      } catch (e) {
        transcribed = null;
      }

      if (transcribed == null || transcribed.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
          _processingError =
              '⚠️ لم يتم التعرف على الصوت.\n\n'
              'تحقق من:\n'
              '• القراءة بصوت واضح\n'
              '• قرب الميكروفون\n'
              '• عدم وجود ضوضاء';
        });
        _deleteFile(path);
        return;
      }

      if (mounted) {
        setState(() {
          _lastTranscription = transcribed!;
          _processingStatus = '🔍 جاري تحليل التلاوة مع التشكيل...';
        });
      }

      // 2️⃣ التحليل
      Map<String, dynamic> result;
      try {
        result = await FirebaseAiService.analyzeRecitation(
          userRecitation: transcribed,
          correctAyah: ayah.text,
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            return <String, dynamic>{
              'accuracy': 0,
              'words': [],
              'stats': {},
              'feedback': '⏱️ انتهت مهلة التحليل.',
            };
          },
        );
      } catch (e) {
        result = <String, dynamic>{
          'accuracy': 0,
          'words': [],
          'stats': {},
          'feedback': '⚠️ تعذر التحليل: $e',
        };
      }

      // 3️⃣ استخراج النتائج
      final words = result['words'] as List?;
      final accuracy = (result['accuracy'] as num?)?.toDouble() ?? 0;
      final feedback = result['feedback']?.toString() ?? '';
      final stats = result['stats'] as Map<String, dynamic>?;

      if (words != null) {
        for (int i = 0; i < words.length && i < _currentWords.length; i++) {
          final w = words[i];
          if (w is! Map) continue;

          final status = w['status']?.toString();
          final userWord = w['user']?.toString() ?? '';
          final correctWord = w['correct']?.toString() ?? '';
          final tashkeelIssue = w['tashkeel_issue']?.toString();

          switch (status) {
            case 'correct':
              _userCorrectWords.add(i);
              break;
            case 'wrong':
              _userWrongWords.add(i);
              if (userWord.isNotEmpty && userWord != correctWord) {
                _wordDetails[i] = 'قرأت: $userWord\nالصحيح: $correctWord';
              }
              break;
            case 'missing':
              _userMissingWords.add(i);
              _wordDetails[i] = 'لم تقرأها';
              break;
            case 'extra':
              _userExtraWords.add(i);
              _wordDetails[i] = 'كلمة زائدة';
              break;
            case 'tashkeel_wrong':
              _userTashkeelWrongWords.add(i);
              if (tashkeelIssue != null) {
                _wordDetails[i] = tashkeelIssue;
              }
              break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _accuracy = accuracy;
        _isProcessing = false;
        _processingStatus = '';
      });

      _showResultDialog(feedback, accuracy, stats);

      // حفظ التقدم
      if (!_hasSaved) {
        final correct = _userCorrectWords.length;
        final wrong = _userWrongWords.length +
            _userMissingWords.length +
            _userExtraWords.length +
            _userTashkeelWrongWords.length;
        final total = correct + wrong;
        if (total > 0) {
          _hasSaved = true;
          try {
            await ProgressService.saveAyahResult(
              surahNumber: _currentSurahNumber,
              ayahNumber: ayah.number,
              accuracy: accuracy.round(),
              correctWords: correct,
              totalWords: _currentWords.length,
            );
          } catch (e) {
            debugPrint('⚠️ فشل حفظ التقدم: $e');
          }
        }
      }

      // خصم من التجربة
      if (!_isPremium) {
        await UsageService.incrementReadWithMe();
        final remaining = await UsageService.remainingReadWithMe();
        if (mounted) {
          setState(() {
            _remainingReadWithMe = remaining;
            if (remaining <= 0) _isLocked = true;
          });
        }
      }

      _deleteFile(path);
    } catch (e) {
      debugPrint('❌ process error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
          _processingError = '⚠️ تعذر التحليل: $e';
        });
      }
      _deleteFile(path);
    }
  }

  void _deleteFile(String path) {
    try {
      File(path).delete().catchError((_) => File(path));
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 نافذة النتيجة (مع تفاصيل التشكيل)
  // ═══════════════════════════════════════════════════════════
  void _showResultDialog(
      String feedback, double accuracy, Map<String, dynamic>? stats) {
    final correct = _userCorrectWords.length;
    final wrong = _userWrongWords.length;
    final missing = _userMissingWords.length;
    final extra = _userExtraWords.length;
    final tashkeel = _userTashkeelWrongWords.length;
    final total = _currentWords.length;

    Color accColor;
    String accEmoji;
    if (accuracy >= 95) {
      accColor = Colors.green;
      accEmoji = '🌟';
    } else if (accuracy >= 85) {
      accColor = Colors.lightGreen;
      accEmoji = '✅';
    } else if (accuracy >= 70) {
      accColor = Colors.orange;
      accEmoji = '👍';
    } else if (accuracy >= 50) {
      accColor = Colors.deepOrange;
      accEmoji = '⚠️';
    } else {
      accColor = Colors.red;
      accEmoji = '❌';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _paperColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accColor, width: 2),
        ),
        title: Row(
          children: [
            Text(accEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الدقة: ${accuracy.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: accColor,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // إحصائيات
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statBadge('✅', 'صحيح', correct, Colors.green),
                        _statBadge('❌', 'خطأ', wrong, Colors.red),
                        _statBadge('🔤', 'تشكيل', tashkeel, Colors.purple),
                      ],
                    ),
                    if (missing > 0 || extra > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (missing > 0)
                            _statBadge('⭕', 'ناقص', missing, Colors.grey),
                          if (extra > 0)
                            _statBadge('➕', 'زائد', extra, Colors.orange),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'إجمالي كلمات الآية: $total',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // ملاحظة التشكيل
              if (tashkeel > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.text_fields,
                          color: Colors.purple.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🔤 $tashkeel كلمة صحيحة لكن تشكيلها مختلف. راجع الحركات.',
                          style: TextStyle(
                            color: Colors.purple.shade900,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // التقييم
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: _goldColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feedback,
                          style: const TextStyle(
                            color: _inkColor,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ما قرأته
              if (_lastTranscription.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '📝 ما قرأته:',
                  style: TextStyle(
                    color: _goldColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    _lastTranscription,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontFamily: 'Amiri',
                      height: 1.8,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],

              // النص الصحيح
              const SizedBox(height: 12),
              const Text(
                '📖 النص الصحيح:',
                style: TextStyle(
                  color: _goldColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  _ayahs[_currentAyahIndex].text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontFamily: 'Amiri',
                    height: 1.8,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(_clearResults);
            },
            child: const Text(
              '🔄 إعادة',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_autoAdvance && _currentAyahIndex < _ayahs.length - 1) {
                _nextAyah();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String icon, String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$icon $label',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔒 شاشة القفل
  // ═══════════════════════════════════════════════════════════
  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: _paperColor,
      appBar: AppBar(
        backgroundColor: _goldColor,
        foregroundColor: _paperColor,
        elevation: 0,
        title: const Text(
          '🎙️ اقرأ معي',
          style: TextStyle(
              fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _goldColor.withValues(alpha: 0.15),
                  border: Border.all(color: _goldColor, width: 2),
                ),
                child: const Icon(
                  Icons.lock,
                  color: Color(0xFFB8860B),
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🔒 انتهت التجربة المجانية',
                style: TextStyle(
                  color: Color(0xFFB8860B),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'لقد استخدمت 3 تجارب مجانية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _goldColor.withValues(alpha: 0.3),
                      _goldColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _goldColor, width: 2),
                ),
                child: const Column(
                  children: [
                    Text(
                      '💎 اشترك في Premium',
                      style: TextStyle(
                        color: Color(0xFFB8860B),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '\$2.99 / شهر',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '✨ تصحيح تلاوة غير محدود\n'
                      '✨ اقرأ معي غير محدود\n'
                      '✨ أسئلة غير محدودة للمرشد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💎 قريباً: صفحة الاشتراك'),
                        backgroundColor: Color(0xFFB8860B),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star, size: 24),
                  label: const Text(
                    '💎 اشترك الآن',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: _paperColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                        color: isActive
                            ? _goldColor
                            : Colors.grey.shade300,
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
                        color: isActive
                            ? _goldColor
                            : Colors.grey.shade300,
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
                          const Icon(Icons.check_circle,
                              color: _goldColor),
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

  void _showLanguageDialog() {
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
            const Icon(Icons.translate, color: _goldColor, size: 32),
            const SizedBox(height: 8),
            const Text(
              '📚 الترجمة',
              style: TextStyle(
                color: _inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: TranslationService.languages.map((l) {
                final isActive = _currentLang == l['code'];
                return GestureDetector(
                  onTap: () async {
                    await TranslationService.setLang(l['code']!);
                    if (!mounted) return;
                    setState(() {
                      _currentLang = l['code']!;
                      _showTranslation = l['code'] != 'ar';
                    });
                    await _saveQuickPref(
                        'show_translation', _showTranslation);
                    await _loadAyahTranslation();
                    if (mounted) Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? _goldColor : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _goldColor, width: 1.5),
                    ),
                    child: Text(
                      '${l['flag']} ${l['name']}',
                      style: TextStyle(
                        color: isActive ? _paperColor : _inkColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
    double thickness = 2.5;
    String displayWord = word;

    if (isSelected) {
      bgColor = Colors.blue.shade100;
      color = Colors.blue.shade900;
    } else if (_userTashkeelWrongWords.contains(index)) {
      // ✅ لون بنفسجي لخطأ التشكيل
      color = Colors.purple.shade700;
      bgColor = Colors.purple.shade50;
    } else if (_userWrongWords.contains(index)) {
      color = Colors.red.shade700;
      decoration = TextDecoration.underline;
      thickness = 3;
    } else if (_userMissingWords.contains(index)) {
      color = Colors.grey.shade500;
      decoration = TextDecoration.lineThrough;
      thickness = 2;
    } else if (_userExtraWords.contains(index)) {
      color = Colors.orange.shade700;
      decoration = TextDecoration.lineThrough;
      thickness = 2;
    } else if (_userCorrectWords.contains(index)) {
      color = Colors.green.shade700;
    } else if (index == _highlightedWordIndex && !isHidden) {
      color = Colors.white;
      bgColor = _goldColor;
    } else if (isHidden) {
      color = Colors.grey.shade400;
      displayWord = HifzMode.getMaskedWord(word);
    }

    return GestureDetector(
      onTap: () => _onWordTap(index),
      child: Tooltip(
        message: _wordDetails[index] ?? '',
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
              decorationThickness: thickness,
            ),
          ),
        ),
      ),
    );
  }

  void _onWordTap(int index) {
    if (index >= _currentWords.length) return;

    setState(() => _selectedWordIndex = index);

    final detail = _wordDetails[index] ?? '';
    final wordTranslation = TranslationService.getWordTranslation(
        _currentWords[index], _currentLang);

    if (mounted) {
      Color bgColor = _goldColor;
      if (_userTashkeelWrongWords.contains(index)) {
        bgColor = Colors.purple.shade700;
      } else if (_userWrongWords.contains(index)) {
        bgColor = Colors.red.shade700;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isNotEmpty
                ? '👆 "${_currentWords[index]}"\n\n$detail'
                : wordTranslation != null
                    ? '👆 "${_currentWords[index]}" — $wordTranslation'
                    : '👆 "${_currentWords[index]}"',
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: bgColor,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _selectedWordIndex = null);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الواجهة الرئيسية
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0E8D0),
      appBar: AppBar(
        backgroundColor: _goldColor,
        foregroundColor: _paperColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'رجوع',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _getCurrentSurahName(),
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: _showSurahPicker,
            tooltip: '📚 تغيير السورة',
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: _goldColor.withValues(alpha: 0.15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
            const SizedBox(width: 4),
            _settingChip(
              icon: Icons.palette,
              label: _showTajweed ? '🎨 تجويد' : '🎨 عادي',
              onTap: () {
                setState(() => _showTajweed = !_showTajweed);
                _saveQuickPref('show_tajweed', _showTajweed);
              },
            ),
            const SizedBox(width: 4),
            _settingChip(
              icon: Icons.translate,
              label: '📚 ترجمة',
              onTap: _showLanguageDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _paperColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _goldColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _goldColor, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: _inkColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    final ayah = _ayahs[_currentAyahIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _paperColor,
      child: Column(
        children: [
          Row(
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
              if (_repeatCount > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    '🔁 ${_currentRepeat + 1}/$_repeatCount',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (_hifzLevel > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Text(
                    '🧠 $_hifzLevel/5',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
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
          if (!_isPremium) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingReadWithMe > 0
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _remainingReadWithMe > 0
                      ? Colors.blue
                      : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _remainingReadWithMe > 0
                        ? Icons.card_giftcard
                        : Icons.hourglass_empty,
                    color: _remainingReadWithMe > 0
                        ? Colors.blue
                        : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _remainingReadWithMe > 0
                        ? '🎁 متبقي: $_remainingReadWithMe تجارب'
                        : '🔒 انتهت التجربة',
                    style: TextStyle(
                      color: _remainingReadWithMe > 0
                          ? Colors.blue
                          : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              if (_showTranslation && _ayahTranslation != null) ...[
                const SizedBox(height: 20),
                _buildTranslationBox(),
              ],
              const SizedBox(height: 20),
              if (_userTashkeelWrongWords.isNotEmpty) _buildTashkeelLegend(),
              if (_userCorrectWords.isNotEmpty ||
                  _userWrongWords.isNotEmpty ||
                  _userMissingWords.isNotEmpty ||
                  _userExtraWords.isNotEmpty)
                _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationBox() {
    final langData = TranslationService.languages.firstWhere(
      (l) => l['code'] == _currentLang,
      orElse: () => {'name': 'English', 'flag': '🇬🇧'},
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Colors.blue, size: 18),
              const SizedBox(width: 6),
              Text(
                '📚 ${langData['flag']} ${langData['name']}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _ayahTranslation ?? '...',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              height: 1.7,
            ),
            textDirection: (_currentLang == 'ar' || _currentLang == 'ur')
                ? TextDirection.rtl
                : TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  Widget _buildTashkeelLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.text_fields,
              color: Colors.purple.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔤 الكلمات باللون البنفسجي صحيحة لكن تشكيلها مختلف. اضغط عليها لرؤية التفاصيل.',
              style: TextStyle(
                color: Colors.purple.shade900,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final correct = _userCorrectWords.length;
    final wrong = _userWrongWords.length;
    final missing = _userMissingWords.length;
    final extra = _userExtraWords.length;
    final tashkeel = _userTashkeelWrongWords.length;

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
          if (missing > 0)
            _statItem('⭕', 'ناقص', missing, Colors.grey.shade700),
          if (extra > 0)
            _statItem('➕', 'زائد', extra, Colors.orange.shade700),
          if (tashkeel > 0)
            _statItem('🔤', 'تشكيل', tashkeel, Colors.purple.shade700),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String label, int value, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
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
          if (_isProcessing || _processingStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _processingStatus,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_processingError.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _processingError,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.red.shade700, size: 18),
                    onPressed: () =>
                        setState(() => _processingError = ''),
                  ),
                ],
              ),
            ),

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
                    : (_isProcessing ? 'جاري...' : 'اقرأ'),
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
