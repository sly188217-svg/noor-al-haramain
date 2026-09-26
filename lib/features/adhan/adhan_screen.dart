import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/adhan_download_service.dart';
import '../../core/services/hijri_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🕌 شاشة الأذان والإقامة
/// ✅ وضعان: أذان عادي / إقامة مباشرة
/// ✅ الآية الكريمة في وضع الإقامة
/// ✅ نص على الجوانب
/// ✅ مؤقت تلقائي
/// ═══════════════════════════════════════════════════════════
class AdhanScreen extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final String cityName;
  final String muezzinName;
  final bool isIqamaOnly;

  const AdhanScreen({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.cityName,
    required this.muezzinName,
    this.isIqamaOnly = false,
  });

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _iqamaPlayer = AudioPlayer();

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // 📊 الحالات
  bool _isPlayingAdhan = false;
  bool _isPlayingDua = false;
  bool _isPlayingIqama = false;
  bool _isMuted = false;

  // 📅 التواريخ
  String _hijriDate = '';
  String _gregorianDate = '';

  // ⏰ مؤقت الإقامة
  int _iqamaMinutes = 15;
  Duration _iqamaRemaining = Duration.zero;
  Timer? _iqamaTimer;
  bool _showIqamaCounter = false;

  // 📖 الآية الكريمة
  static const String _iqamaVerse =
      'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا';

  // ⏰ الأوقات الافتراضية
  static const Map<String, int> _defaultIqamaTimes = {
    'الفجر': 20,
    'الظهر': 15,
    'العصر': 15,
    'المغرب': 7,
    'العشاء': 15,
  };

  // 📜 نصوص الأذان
  static const List<String> _adhanPhrases = [
    'الله أكبر',
    'الله أكبر',
    'أشهد أن لا إله إلا الله',
    'أشهد أن محمداً رسول الله',
    'حي على الصلاة',
    'حي على الفلاح',
    'الله أكبر',
    'لا إله إلا الله',
  ];

  // 📜 نصوص الإقامة
  static const List<String> _iqamaPhrases = [
    'قد قامت الصلاة',
    'قد قامت الصلاة',
    'الله أكبر',
    'لا إله إلا الله',
  ];

  String _activeAdhanText = 'الله أكبر';
  int _phraseIndex = 0;
  Timer? _phraseTimer;
  bool _isIqamaMode = false;

  @override
  void initState() {
    super.initState();

    try {
      _hijriDate = HijriService.getHijriDate(DateTime.now());
    } catch (_) {
      _hijriDate = '';
    }

    final now = DateTime.now();
    _gregorianDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _loadIqamaMinutes();

    // ✅ تحديد الوضع
    if (widget.isIqamaOnly) {
      // وضع الإقامة المباشر
      _isIqamaMode = true;
      _activeAdhanText = _iqamaPhrases[0];
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _playIqama();
      });
    } else {
      // الوضع العادي
      _playAdhan();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _iqamaTimer?.cancel();
    _phraseTimer?.cancel();
    _audioPlayer.dispose();
    _iqamaPlayer.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ⚙️ تحميل وقت الإقامة
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadIqamaMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prayerKey = 'iqama_${widget.prayerName}';

      int? saved = prefs.getInt(prayerKey);
      if (saved == null) {
        saved = _defaultIqamaTimes[widget.prayerName] ?? 15;
      }

      if (mounted) {
        setState(() => _iqamaMinutes = saved!);
      }
      debugPrint(
          '⏰ وقت الإقامة لصلاة ${widget.prayerName}: $_iqamaMinutes دقيقة');
    } catch (e) {
      debugPrint('⚠️ فشل تحميل وقت الإقامة: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📜 تدوير النصوص
  // ═══════════════════════════════════════════════════════════
  void _startAdhanPhraseRotation() {
    _phraseTimer?.cancel();
    _phraseTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _phraseIndex = (_phraseIndex + 1) % _adhanPhrases.length;
        _activeAdhanText = _adhanPhrases[_phraseIndex];
      });
    });
  }

  void _startIqamaPhraseRotation() {
    _phraseTimer?.cancel();
    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _phraseIndex = (_phraseIndex + 1) % _iqamaPhrases.length;
        _activeAdhanText = _iqamaPhrases[_phraseIndex];
      });
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎵 تشغيل الأذان
  // ═══════════════════════════════════════════════════════════
  Future<void> _playAdhan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String muezzinId =
          prefs.getString('selected_muezzin') ?? 'adhan_sudais';

      if (!AdhanDownloadService.adhanFiles.containsKey(muezzinId)) {
        debugPrint('⚠️ ID غير معروف: $muezzinId → استخدام الافتراضي');
        muezzinId = 'adhan_sudais';
      }

      final path =
          await AdhanDownloadService.getAssetSourcePath(muezzinId);
      debugPrint('🎵 محاولة تشغيل: $muezzinId → $path');

      if (path == null) {
        debugPrint('⚠️ مسار الأذان غير موجود: $muezzinId');
        _playDuaAfterAdhan();
        return;
      }

      await _audioPlayer.play(AssetSource(path));
      if (mounted) {
        setState(() {
          _isPlayingAdhan = true;
          _isIqamaMode = false;
        });
        _startAdhanPhraseRotation();
      }

      _audioPlayer.onPlayerComplete.first.then((_) async {
        if (mounted) setState(() => _isPlayingAdhan = false);
        _phraseTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 500));
        await _playDuaAfterAdhan();
      });
    } catch (e) {
      debugPrint('❌ فشل تشغيل الأذان: $e');
      _playDuaAfterAdhan();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🤲 الدعاء بعد الأذان
  // ═══════════════════════════════════════════════════════════
  Future<void> _playDuaAfterAdhan() async {
    if (_isMuted) {
      _startIqamaCountdown();
      return;
    }
    _phraseTimer?.cancel();

    try {
      final duaPlayer = AudioPlayer();
      await duaPlayer.play(
        AssetSource('adhan/dua/dua_after_adhan.mp3'),
      );
      if (mounted) {
        setState(() {
          _isPlayingDua = true;
          _activeAdhanText = 'اللهم رب هذه الدعوة التامة';
        });
      }

      await duaPlayer.onPlayerComplete.first;
      await duaPlayer.dispose();
      if (mounted) setState(() => _isPlayingDua = false);
      _startIqamaCountdown();
    } catch (e) {
      debugPrint('⚠️ فشل تشغيل الدعاء: $e');
      if (mounted) setState(() => _isPlayingDua = false);
      _startIqamaCountdown();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏰ مؤقت الإقامة
  // ═══════════════════════════════════════════════════════════
  void _startIqamaCountdown() {
    if (!mounted) return;

    setState(() {
      _showIqamaCounter = true;
      _iqamaRemaining = Duration(minutes: _iqamaMinutes);
      _activeAdhanText = 'انتظار الإقامة';
    });

    _iqamaTimer?.cancel();
    _iqamaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_iqamaRemaining.inSeconds > 0) {
        setState(() => _iqamaRemaining -= const Duration(seconds: 1));
      } else {
        timer.cancel();
        setState(() => _showIqamaCounter = false);
        _playIqama();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 تشغيل الإقامة
  // ═══════════════════════════════════════════════════════════
  Future<void> _playIqama() async {
    if (!mounted) return;

    debugPrint('🕌 بدء تشغيل الإقامة...');

    setState(() {
      _isIqamaMode = true;
      _activeAdhanText = _iqamaPhrases[0];
    });

    if (_isMuted) {
      _startIqamaPhraseRotation();
      return;
    }

    try {
      await _iqamaPlayer.play(AssetSource('adhan/iqama.mp3'));
      if (mounted) {
        setState(() => _isPlayingIqama = true);
        _startIqamaPhraseRotation();
      }

      _iqamaPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() => _isPlayingIqama = false);
          _phraseTimer?.cancel();
          _activeAdhanText = 'الصلاة';
        }
      });
    } catch (e) {
      debugPrint('⚠️ فشل تشغيل صوت الإقامة: $e');
      _startIqamaPhraseRotation();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔇 الإسكات
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleMute() async {
    if (_isMuted) {
      setState(() => _isMuted = false);
      if (_isPlayingAdhan || _isPlayingDua || _isPlayingIqama) return;

      if (_isIqamaMode) {
        _playIqama();
      } else {
        _playAdhan();
      }
    } else {
      setState(() => _isMuted = true);
      await _audioPlayer.stop();
      await _iqamaPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlayingAdhan = false;
          _isPlayingDua = false;
          _isPlayingIqama = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⚙️ إعدادات الإقامة
  // ═══════════════════════════════════════════════════════════
  Future<void> _showIqamaSettings() async {
    int tempMinutes = _iqamaMinutes;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C2541),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.timer, color: Color(0xFFD4AF37)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⏰ إقامة ${widget.prayerName}',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37), fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$tempMinutes دقيقة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الوقت بين الأذان والإقامة',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: tempMinutes.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: const Color(0xFFD4AF37),
                  label: '$tempMinutes',
                  onChanged: (v) =>
                      setDialogState(() => tempMinutes = v.round()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final prayerKey = 'iqama_${widget.prayerName}';
                  await prefs.setInt(prayerKey, tempMinutes);
                  if (mounted) {
                    setState(() {
                      _iqamaMinutes = tempMinutes;
                      if (_showIqamaCounter) {
                        _iqamaRemaining =
                            Duration(minutes: tempMinutes);
                      }
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ❌ إغلاق
  // ═══════════════════════════════════════════════════════════
  Future<void> _closeScreen() async {
    _iqamaTimer?.cancel();
    _phraseTimer?.cancel();
    await _audioPlayer.stop();
    await _iqamaPlayer.stop();
    if (mounted) Navigator.of(context).pop();
  }

  String _formatIqama(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 الواجهة
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: _isIqamaMode
                ? [const Color(0xFF2C1A0B), const Color(0xFF0B132B)]
                : [const Color(0xFF1C2541), const Color(0xFF0B132B)],
            stops: const [0.2, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                _buildSideDecorations(),
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildMainContent()),
                    _buildBottomButtons(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideDecorations() {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSideText(),
          _buildSideText(),
        ],
      ),
    );
  }

  Widget _buildSideText() {
    final color = _isIqamaMode
        ? const Color(0xFFFFB74D)
        : const Color(0xFFD4AF37);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: 0.25 + ((i % 3) * 0.15),
              child: Text(
                _activeAdhanText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  letterSpacing: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFFD4AF37), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    widget.cityName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_showIqamaCounter)
                    IconButton(
                      icon: const Icon(Icons.timer,
                          color: Color(0xFFD4AF37), size: 20),
                      onPressed: _showIqamaSettings,
                      tooltip: 'مدة الإقامة',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _closeScreen,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _gregorianDate,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              if (_hijriDate.isNotEmpty)
                Text(
                  _hijriDate,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          // 📖 الآية الكريمة (تظهر في وضع الإقامة)
          if (_isIqamaMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFD4AF37),
                    Color(0xFFB8860B),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _iqamaVerse,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        height: 1.8,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '📖 سورة النساء — الآية 103',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // الشعار النابض
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _isIqamaMode
                      ? [const Color(0xFF2C1A0B), const Color(0xFF0B132B)]
                      : [const Color(0xFF1C2541), const Color(0xFF0B132B)],
                ),
                border: Border.all(
                  color: _isIqamaMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD4AF37),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isIqamaMode
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFFD4AF37))
                        .withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isIqamaMode ? Icons.access_time_filled : Icons.mosque,
                  color: _isIqamaMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD4AF37),
                  size: 65,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Text(
            _isPlayingIqama
                ? '🕌 الإقامة الآن'
                : _isIqamaMode
                    ? '🕌 الإقامة'
                    : _showIqamaCounter
                        ? '⏰ انتظار الإقامة'
                        : '🕌 حان وقت صلاة',
            style: TextStyle(
              color: _isIqamaMode
                  ? const Color(0xFFFFB74D)
                  : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            widget.prayerName,
            style: TextStyle(
              color: _isIqamaMode
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFFD4AF37),
              fontSize: 54,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: 140,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _isIqamaMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD4AF37),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            widget.prayerTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: (_isIqamaMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD4AF37))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_isIqamaMode
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFFD4AF37))
                    .withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isIqamaMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD4AF37),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'أذان: ${widget.muezzinName}',
                  style: TextStyle(
                    color: _isIqamaMode
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFFD4AF37),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ⏰ مؤقت الإقامة
          if (_showIqamaCounter) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFD4AF37), width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    '⏰ الوقت المتبقي للإقامة',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatIqama(_iqamaRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _iqamaMinutes > 0
                            ? 1 -
                                (_iqamaRemaining.inSeconds /
                                    (_iqamaMinutes * 60))
                            : 0,
                        backgroundColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        color: const Color(0xFFD4AF37),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 🕌 حالة الإقامة
          if (_isPlayingIqama) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFB74D), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign,
                      color: Color(0xFFFFB74D), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _activeAdhanText,
                    style: const TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    String statusText;
    Color statusColor;

    if (_isPlayingAdhan) {
      statusText = '🎧 الأذان يُشغَّل الآن...';
      statusColor = Colors.white54;
    } else if (_isPlayingDua) {
      statusText = '🤲 جاري الدعاء بعد الأذان...';
      statusColor = Colors.white54;
    } else if (_isPlayingIqama) {
      statusText = '🕌 الإقامة تُشغَّل الآن...';
      statusColor = const Color(0xFFFFB74D);
    } else if (_isIqamaMode) {
      statusText = '🕌 انتهت الإقامة — أقيمت الصلاة';
      statusColor = const Color(0xFFFFB74D);
    } else if (_showIqamaCounter) {
      statusText = '⏰ في انتظار الإقامة...';
      statusColor = const Color(0xFFD4AF37);
    } else {
      statusText = '✅ انتهى الأذان';
      statusColor = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 13),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleMute,
                  icon: Icon(
                    _isMuted ? Icons.volume_up : Icons.volume_off,
                    size: 22,
                  ),
                  label: Text(_isMuted ? 'إلغاء الإسكات' : 'إسكات'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(
                        color: Color(0xFFD4AF37), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🕌 تقبّل الله صلاتك'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    _closeScreen();
                  },
                  icon: const Icon(Icons.check_circle, size: 22),
                  label: const Text('صليت'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _closeScreen,
              icon: const Icon(Icons.close, size: 22),
              label: const Text('إغلاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
