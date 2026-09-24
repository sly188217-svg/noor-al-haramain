import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/adhan_download_service.dart';
import '../../core/services/hijri_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 🕌 شاشة الأذان ملء الشاشة الاحترافية
/// ✅ الأذان + الدعاء بعد الأذان تلقائياً
/// ✅ عدّاد الإقامة
/// ✅ أزرار: صليت / أقيمت الصلاة
/// ✅ التاريخ الهجري + الميلادي + المدينة
/// ═══════════════════════════════════════════════════════════
class AdhanScreen extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final String cityName;
  final String muezzinName;

  const AdhanScreen({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.cityName,
    required this.muezzinName,
  });

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  bool _isPlayingAdhan = false;
  bool _isPlayingDua = false;
  bool _isMuted = false;
  String _hijriDate = '';
  String _gregorianDate = '';

  // ⏰ عدّاد الإقامة
  int _iqamaMinutes = 15;
  Duration _iqamaRemaining = Duration.zero;
  Timer? _iqamaTimer;
  bool _showIqamaCounter = false;

  @override
  void initState() {
    super.initState();

    // التاريخ
    try {
      _hijriDate = HijriService.getHijriDate(DateTime.now());
    } catch (e) {
      _hijriDate = '';
    }

    // التاريخ الميلادي
    final now = DateTime.now();
    _gregorianDate = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    // الأنيميشن
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // تحميل وقت الإقامة
    _loadIqamaMinutes();

    // تشغيل الأذان
    _playAdhan();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iqamaTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadIqamaMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _iqamaMinutes = prefs.getInt('iqama_minutes') ?? 15;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎵 تشغيل الأذان ثم الدعاء تلقائياً
  // ═══════════════════════════════════════════════════════════
  Future<void> _playAdhan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muezzinId =
          prefs.getString('selected_muezzin') ?? 'adhan_sudais';

      final path =
          await AdhanDownloadService.getAssetSourcePath(muezzinId);
      if (path == null) {
        debugPrint('⚠️ الأذان غير متاح: $muezzinId');
        _playDuaAfterAdhan();
        return;
      }

      await _audioPlayer.play(AssetSource(path));
      if (mounted) setState(() => _isPlayingAdhan = true);

      // ✅ بعد انتهاء الأذان: تشغيل الدعاء
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
  // 🤲 تشغيل الدعاء بعد الأذان
  // ═══════════════════════════════════════════════════════════
  Future<void> _playDuaAfterAdhan() async {
    if (_isMuted) return;

    try {
      final duaPlayer = AudioPlayer();
      await duaPlayer.play(
        AssetSource('adhan/dua/dua_after_adhan.mp3'),
      );
      if (mounted) setState(() => _isPlayingDua = true);

      await duaPlayer.onPlayerComplete.first;
      await duaPlayer.dispose();
      if (mounted) setState(() => _isPlayingDua = false);

      // ✅ بعد الدعاء: إظهار عدّاد الإقامة
      _startIqamaCountdown();
    } catch (e) {
      debugPrint('⚠️ فشل تشغيل الدعاء: $e');
      if (mounted) setState(() => _isPlayingDua = false);
      _startIqamaCountdown();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏰ عدّاد الإقامة
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
        setState(() {
          _iqamaRemaining -= const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        setState(() => _showIqamaCounter = false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🔇 إسكات / إلغاء الإسكات
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleMute() async {
    if (_isMuted) {
      setState(() => _isMuted = false);
      if (_isPlayingAdhan || _isPlayingDua) return;
      // إعادة التشغيل
      await _playAdhan();
    } else {
      setState(() => _isMuted = true);
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlayingAdhan = false;
          _isPlayingDua = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❌ إغلاق الشاشة
  // ═══════════════════════════════════════════════════════════
  Future<void> _closeScreen() async {
    _iqamaTimer?.cancel();
    await _audioPlayer.stop();
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
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
            stops: [0.2, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── الجزء العلوي: التاريخ + المدينة ───
              _buildTopBar(),

              // ─── الجزء الأوسط: الشعار + الصلاة ───
              Expanded(child: _buildMainContent()),

              // ─── الجزء السفلي: الأزرار ───
              _buildBottomButtons(),
            ],
          ),
        ),
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
              // المدينة
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
              // زر الإغلاق
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _closeScreen,
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
                  color: Colors.white54,
                  fontSize: 12,
                ),
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
                ),
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37)
                        .withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.mosque,
                  color: Color(0xFFD4AF37),
                  size: 60,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            '🕌 حان وقت صلاة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            widget.prayerName,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 50,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: 120,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37),
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
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 12),

          // اسم المؤذن
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: const Color(0xFFD4AF37),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'أذان: ${widget.muezzinName}',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ⏰ عدّاد الإقامة
          if (_showIqamaCounter) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 2,
                ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // الحالة
          Text(
            _isPlayingAdhan
                ? '🎧 الأذان يُشغَّل الآن...'
                : _isPlayingDua
                    ? '🤲 جاري الدعاء بعد الأذان...'
                    : '✅ انتهى الأذان',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // صف الأزرار: إسكات + صليت
          Row(
            children: [
              // زر إسكات
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
                      color: Color(0xFFD4AF37),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // زر صليت
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

          // زر إغلاق
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
