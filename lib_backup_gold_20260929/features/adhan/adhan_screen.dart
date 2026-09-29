import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/adhan_download_service.dart';
import '../../core/services/hijri_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🕌 شاشة الأذان والإقامة — باللون الأحمر
/// ✅ نص ثابت على الجوانب
/// ✅ الآية الكريمة في وضع الإقامة
/// ✅ أذان → دعاء → مؤقت → إقامة
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
  late AnimationController _sideTextController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sideTextAnimation;

  // ═══════════════════════════════════════════════════════════
  // 🎨 لوحة الألوان الحمراء
  // ═══════════════════════════════════════════════════════════
  static const Color _primary = Color(0xFFE53935);
  static const Color _primaryLight = Color(0xFFFF5252);
  static const Color _primaryDark = Color(0xFFB71C1C);
  static const Color _bg = Color(0xFF0B132B);

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

  // 🕌 الآية الكريمة
  static const String _iqamaVerse =
      'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا';

  // ═══════════════════════════════════════════════════════════
  // 📿 النصوص الجانبية الثابتة
  // ═══════════════════════════════════════════════════════════
  static const String _rightSideText = 'اللهم صل على محمد';
  static const String _leftSideText = 'لا حول ولا قوة إلا بالله';

  // ⏰ الأوقات الافتراضية للإقامة
  static const Map<String, int> _defaultIqamaTimes = {
    'الفجر': 20,
    'الظهر': 15,
    'العصر': 15,
    'المغرب': 7,
    'العشاء': 15,
  };

  // 📜 نصوص الإقامة
  static const List<String> _iqamaPhrases = [
    'قد قامت الصلاة',
    'قد قامت الصلاة',
    'الله أكبر',
    'لا إله إلا الله',
  ];

  String _activeIqamaText = 'قد قامت الصلاة';
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
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // ✅ أنيميشن النص الجانبي
    _sideTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _sideTextAnimation = Tween<double>(begin: 0.15, end: 0.5).animate(
      CurvedAnimation(parent: _sideTextController, curve: Curves.easeInOut),
    );

    _loadIqamaMinutes();

    if (widget.isIqamaOnly) {
      _isIqamaMode = true;
      _activeIqamaText = _iqamaPhrases[0];
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _playIqama();
      });
    } else {
      _playAdhan();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _sideTextController.dispose();
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
      saved ??= _defaultIqamaTimes[widget.prayerName] ?? 15;
      if (mounted) setState(() => _iqamaMinutes = saved!);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 📜 تدوير نصوص الإقامة
  // ═══════════════════════════════════════════════════════════
  void _startIqamaPhraseRotation() {
    _phraseTimer?.cancel();
    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _phraseIndex = (_phraseIndex + 1) % _iqamaPhrases.length;
        _activeIqamaText = _iqamaPhrases[_phraseIndex];
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
        muezzinId = 'adhan_sudais';
      }

      final path = await AdhanDownloadService.getAssetSourcePath(muezzinId);
      if (path == null) {
        _playDuaAfterAdhan();
        return;
      }

      await _audioPlayer.play(AssetSource(path));
      if (mounted) {
        setState(() {
          _isPlayingAdhan = true;
          _isIqamaMode = false;
        });
      }

      _audioPlayer.onPlayerComplete.first.then((_) async {
        if (mounted) setState(() => _isPlayingAdhan = false);
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

    try {
      final duaPlayer = AudioPlayer();
      await duaPlayer.play(AssetSource('adhan/dua/dua_after_adhan.mp3'));
      if (mounted) setState(() => _isPlayingDua = true);
      await duaPlayer.onPlayerComplete.first;
      await duaPlayer.dispose();
      if (mounted) setState(() => _isPlayingDua = false);
      _startIqamaCountdown();
    } catch (e) {
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

    setState(() {
      _isIqamaMode = true;
      _activeIqamaText = _iqamaPhrases[0];
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
          _activeIqamaText = 'الصلاة';
        }
      });
    } catch (e) {
      debugPrint('⚠️ فشل تشغيل الإقامة: $e');
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
              side: const BorderSide(color: _primary, width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.timer, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⏰ إقامة ${widget.prayerName}',
                    style: const TextStyle(color: _primary, fontSize: 16),
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
                  activeColor: _primary,
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
                        _iqamaRemaining = Duration(minutes: tempMinutes);
                      }
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
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
      backgroundColor: _bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: _isIqamaMode
                ? [const Color(0xFF2C0B0B), _bg]
                : [const Color(0xFF2C1A1A), _bg],
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

  // ═══════════════════════════════════════════════════════════
  // 📿 النصوص الجانبية الثابتة
  // ═══════════════════════════════════════════════════════════
  Widget _buildSideDecorations() {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSideColumn(_leftSideText),
          _buildSideColumn(_rightSideText),
        ],
      ),
    );
  }

  Widget _buildSideColumn(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AnimatedBuilder(
              animation: _sideTextAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _sideTextAnimation.value + ((i % 3) * 0.1),
                  child: Transform.scale(
                    scale: 1.0 + ((i % 2) * 0.05),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: _primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: _primary.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔝 الشريط العلوي
  // ═══════════════════════════════════════════════════════════
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
                      color: _primaryLight, size: 18),
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
                          color: _primaryLight, size: 20),
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
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_hijriDate.isNotEmpty)
                Text(
                  _hijriDate,
                  style: const TextStyle(
                    color: _primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          // 📖 الآية الكريمة
          if (_isIqamaMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book, color: Colors.white, size: 18),
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
                color: Color(0xFFFF5252),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 المحتوى الرئيسي
  // ═══════════════════════════════════════════════════════════
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
                  colors: [
                    _primaryDark.withValues(alpha: 0.6),
                    _bg,
                  ],
                ),
                border: Border.all(color: _primaryLight, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.mosque,
                  color: _primaryLight,
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
              color:
                  _isIqamaMode ? _primaryLight : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            widget.prayerName,
            style: TextStyle(
              color: _isIqamaMode ? _primaryLight : _primary,
              fontSize: 54,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              height: 1.2,
              shadows: [
                Shadow(
                  color: _primary.withValues(alpha: 0.7),
                  blurRadius: 20,
                ),
              ],
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
                  _isIqamaMode ? _primaryLight : _primary,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _primaryLight,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'أذان: ${widget.muezzinName}',
                  style: TextStyle(
                    color: _primaryLight,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '⏰ الوقت المتبقي للإقامة',
                    style: TextStyle(
                      color: _primaryLight,
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
                            _primary.withValues(alpha: 0.2),
                        color: _primaryLight,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryLight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign,
                      color: Color(0xFFFF5252), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _activeIqamaText,
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
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

  // ═══════════════════════════════════════════════════════════
  // 🔻 الأزرار السفلية
  // ═══════════════════════════════════════════════════════════
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
      statusColor = _primaryLight;
    } else if (_isIqamaMode) {
      statusText = '🕌 انتهت الإقامة — أقيمت الصلاة';
      statusColor = _primaryLight;
    } else if (_showIqamaCounter) {
      statusText = '⏰ في انتظار الإقامة...';
      statusColor = _primaryLight;
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
                    foregroundColor: _primaryLight,
                    side: const BorderSide(
                        color: Color(0xFFFF5252), width: 2),
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
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                shadowColor: _primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
