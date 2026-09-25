import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/providers/language_provider.dart';

class AzkarTab extends StatefulWidget {
  const AzkarTab({super.key});

  @override
  State<AzkarTab> createState() => _AzkarTabState();
}

class _AzkarTabState extends State<AzkarTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ═══════════════════════════════════════════════════════════
  // أذكار الصباح
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _morningAzkar = [
    {'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.', 'count': 1},
    {'text': 'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 4},
  ];

  // ═══════════════════════════════════════════════════════════
  // أذكار المساء
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _eveningAzkar = [
    {'text': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ فَتْحَهَا وَنَصْرَهَا وَنُورَهَا وَبَرَكَتَهَا وَهُدَاهَا.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 4},
  ];

  // ═══════════════════════════════════════════════════════════
  // أذكار النوم
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _sleepAzkar = [
    {'text': 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا.', 'count': 1},
    {'text': 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', 'count': 3},
    {'text': 'بِاسْمِكَ رَبِّ وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا.', 'count': 1},
  ];

  // ═══════════════════════════════════════════════════════════
  // أذكار بعد الصلاة
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _prayerAzkar = [
    {'text': 'أَسْتَغْفِرُ اللَّهَ (ثلاثاً) اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', 'count': 1},
    {'text': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.', 'count': 1},
  ];

  // ═══════════════════════════════════════════════════════════
  // الأدعية
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _duas = [
    {'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'reference': 'البقرة 201'},
    {'text': 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ', 'reference': 'آل عمران 8'},
    {'text': 'رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا', 'reference': 'آل عمران 147'},
    {'text': 'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ', 'reference': 'الأعراف 23'},
    {'text': 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي', 'reference': 'طه 25-26'},
    {'text': 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا', 'reference': 'الفرقان 74'},
  ];

  // ═══════════════════════════════════════════════════════════
  // الرقية الشرعية
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _ruqyah = [
    {'text': 'بِسْمِ اللَّهِ أَرْقِيكَ مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنٍ حَاسِدٍ، اللَّهُ يَشْفِيكَ.', 'count': '3'},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ غَضَبِهِ وَعِقَابِهِ وَشَرِّ عِبَادِهِ.', 'count': '3'},
    {'text': 'أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.', 'count': '3'},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ.', 'count': '3'},
    {'text': 'اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَاسَ اشْفِ أَنْتَ الشَّافِي لَا شِفَاءَ إِلَّا شِفَاؤُكَ.', 'count': '3'},
  ];

  // ═══════════════════════════════════════════════════════════
  // 📺 البث المباشر — روابط m3u8 تعمل عالمياً
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _liveStreams = [
    {
      'name': 'الحرم المكي',
      'nameEn': 'Makkah Live',
      'icon': '🕋',
      'url': 'https://win.holol.com/live/quran/playlist.m3u8',
    },
    {
      'name': 'المسجد النبوي',
      'nameEn': 'Madinah Live',
      'icon': '🕌',
      'url': 'https://win.holol.com/live/sunnah/playlist.m3u8',
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // السبحة
  // ═══════════════════════════════════════════════════════════
  int _tasbihCount = 0;
  String _selectedDhikr = 'سبحان الله';
  Map<String, int> _tasbihCounts = {};

  final List<String> _dhikrList = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'استغفر الله',
    'لا حول ولا قوة إلا بالله',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTasbihPreference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📿 دوال السبحة
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadTasbihPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDhikr = prefs.getString('tasbih_dhikr');
    final savedCounts = prefs.getString('tasbih_counts');

    if (!mounted) return;

    Map<String, int> loadedCounts = {};
    if (savedCounts != null) {
      try {
        final decoded = jsonDecode(savedCounts) as Map<String, dynamic>;
        loadedCounts = decoded.map(
            (key, value) => MapEntry(key, (value as num).toInt()));
      } catch (_) {
        loadedCounts = {};
      }
    }

    setState(() {
      if (savedDhikr != null) _selectedDhikr = savedDhikr;
      _tasbihCounts = loadedCounts;
      _tasbihCount = _tasbihCounts[_selectedDhikr] ?? 0;
    });
  }

  Future<void> _saveTasbihPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _tasbihCounts[_selectedDhikr] = _tasbihCount;
    await prefs.setString('tasbih_dhikr', _selectedDhikr);
    await prefs.setString('tasbih_counts', jsonEncode(_tasbihCounts));
  }

  void _incrementTasbih() {
    HapticFeedback.mediumImpact();
    setState(() => _tasbihCount++);
    _saveTasbihPreference();
  }

  void _decrementTasbih() {
    if (_tasbihCount <= 0) return;
    HapticFeedback.lightImpact();
    setState(() => _tasbihCount--);
    _saveTasbihPreference();
  }

  Future<void> _resetCurrentTasbih() async {
    if (_tasbihCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('🔄 إعادة تعيين',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: Text('هل تريد إعادة تعيين عداد "$_selectedDhikr"؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black),
            child: const Text('إعادة'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      setState(() => _tasbihCount = 0);
      _tasbihCounts[_selectedDhikr] = 0;
      _saveTasbihPreference();
    }
  }

  Future<void> _resetAllTasbih() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('⚠️ تحذير',
            style: TextStyle(color: Colors.orange)),
        content: const Text(
            'هل تريد حذف جميع العدادات لكل الأذكار؟\nلا يمكن التراجع!',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _tasbihCounts.clear();
        _tasbihCount = 0;
      });
      _saveTasbihPreference();
    }
  }

  void _changeDhikr(String newDhikr) {
    _tasbihCounts[_selectedDhikr] = _tasbihCount;
    setState(() {
      _selectedDhikr = newDhikr;
      _tasbihCount = _tasbihCounts[newDhikr] ?? 0;
    });
    _saveTasbihPreference();
  }

  // ═══════════════════════════════════════════════════════════
  // 📺 عرض البث المباشر (m3u8)
  // ═══════════════════════════════════════════════════════════
  Future<void> _showLiveStream(String url, String title) async {
    // شاشة تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
    );

    try {
      // إنشاء video player controller
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
      );

      await videoController.initialize();
      await videoController.play();

      // إغلاق شاشة التحميل
      if (!mounted) return;
      Navigator.pop(context);

      // إنشاء chewie controller
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: videoController.value.aspectRatio > 0
            ? videoController.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFD4AF37),
          handleColor: const Color(0xFFD4AF37),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white54,
        ),
      );

      // عرض النافذة
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37)),
            ),
            child: Column(
              children: [
                // شريط العنوان
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C2541),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.live_tv,
                          color: Color(0xFFD4AF37), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text(
                        '🔴 LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFFD4AF37), size: 20),
                        onPressed: () {
                          chewieController.dispose();
                          videoController.dispose();
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),
                ),
                // مشغل الفيديو
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(11)),
                    child: Chewie(controller: chewieController),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
        // تنظيف عند الإغلاق
        try {
          chewieController.dispose();
          videoController.dispose();
        } catch (_) {}
      });
    } catch (e) {
      // إغلاق شاشة التحميل
      if (mounted) Navigator.pop(context);

      // إظهار الخطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ تعذر تحميل البث: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('❌ Live stream error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // بناء قائمة الأذكار
  // ═══════════════════════════════════════════════════════════
  Widget _buildAzkarList(
      List<Map<String, dynamic>> items, bool isArabic, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final count = item['count'] ?? 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item['text']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontFamily: 'Amiri',
                        height: 1.8,
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔄 $count ${isArabic ? 'مرات' : 'times'}',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بناء الأدعية
  // ═══════════════════════════════════════════════════════════
  Widget _buildDuasList(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _duas.length,
      itemBuilder: (context, index) {
        final dua = _duas[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dua['text']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontFamily: 'Amiri',
                  height: 1.8,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                '📖 ${dua['reference']}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بناء الرقية
  // ═══════════════════════════════════════════════════════════
  Widget _buildRuqyahList(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _ruqyah.length,
      itemBuilder: (context, index) {
        final item = _ruqyah[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item['text']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontFamily: 'Amiri',
                  height: 1.8,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 0.5),
                ),
                child: Text(
                  '🔄 ${item['count']} ${isArabic ? 'مرات' : 'times'}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بناء البث المباشر
  // ═══════════════════════════════════════════════════════════
  Widget _buildLiveStreams(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _liveStreams.length,
      itemBuilder: (context, index) {
        final stream = _liveStreams[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Text(
              stream['icon']!,
              style: const TextStyle(fontSize: 36),
            ),
            title: Text(
              isArabic ? stream['name']! : stream['nameEn']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red, width: 0.5),
              ),
              child: const Text(
                '🔴 LIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.play_circle_fill,
              color: Color(0xFFD4AF37),
              size: 40,
            ),
            onTap: () => _showLiveStream(
              stream['url']!,
              isArabic ? stream['name']! : stream['nameEn']!,
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بناء السبحة
  // ═══════════════════════════════════════════════════════════
  Widget _buildSmartTasbih(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // اختيار الذكر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: DropdownButton<String>(
              value: _selectedDhikr,
              dropdownColor: const Color(0xFF1C2541),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              underline: const SizedBox(),
              isExpanded: true,
              items: _dhikrList.map((dhikr) {
                final count = _tasbihCounts[dhikr] ?? 0;
                return DropdownMenuItem(
                  value: dhikr,
                  child: Row(
                    children: [
                      Text(
                        dhikr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const Spacer(),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _changeDhikr(value);
              },
            ),
          ),

          const SizedBox(height: 24),

          // الدائرة الكبيرة — العداد
          GestureDetector(
            onTap: _incrementTasbih,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_tasbihCount',
                      style: const TextStyle(
                        color: Color(0xFF0B132B),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic ? 'اضغط للعد' : 'Tap to count',
                      style: const TextStyle(
                        color: Color(0xFF0B132B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // أزرار التحكم
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleButton(
                icon: Icons.remove,
                color: Colors.orange,
                tooltip: 'تقليل',
                onTap: _decrementTasbih,
              ),
              const SizedBox(width: 16),
              _buildCircleButton(
                icon: Icons.refresh,
                color: const Color(0xFFD4AF37),
                tooltip: 'إعادة تعيين',
                onTap: _resetCurrentTasbih,
              ),
              const SizedBox(width: 16),
              _buildCircleButton(
                icon: Icons.add,
                color: Colors.green,
                tooltip: 'زيادة',
                onTap: _incrementTasbih,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // إحصائيات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                    '$_tasbihCount', isArabic ? 'الحالي' : 'Current'),
                _buildStatCard('33', isArabic ? 'الهدف' : 'Target'),
                _buildStatCard(
                  _tasbihCount >= 33 ? '✅' : '⏳',
                  isArabic ? 'الحالة' : 'Status',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // سجل العدادات
          if (_tasbihCounts.values.any((v) => v > 0)) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '📊 سجل العدادات',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: _dhikrList.map((dhikr) {
                  final count = _tasbihCounts[dhikr] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            color: Color(0xFFD4AF37), size: 6),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dhikr,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // زر حذف الجميع
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAllTasbih,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('🗑️ حذف جميع العدادات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          Text(
            isArabic
                ? '💡 اضغط الدائرة للعد • استخدم الأزرار للتحكم'
                : '💡 Tap circle to count • Use buttons to control',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1C2541),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD4AF37),
              labelColor: const Color(0xFFD4AF37),
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabs: [
                Tab(text: isArabic ? '🕌 أذكار' : '🕌 Adhkar'),
                Tab(text: isArabic ? '🤲 أدعية' : '🤲 Duas'),
                Tab(text: isArabic ? '🕋 رقية' : '🕋 Ruqyah'),
                Tab(text: isArabic ? '📺 بث' : '📺 Live'),
                Tab(text: isArabic ? '📿 تسبيح' : '📿 Tasbih'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAzkarList(
                  [
                    ..._morningAzkar,
                    ..._eveningAzkar,
                    ..._sleepAzkar,
                    ..._prayerAzkar,
                  ],
                  isArabic,
                  isArabic ? '📖 الأذكار اليومية' : '📖 Daily Adhkar',
                ),
                _buildDuasList(isArabic),
                _buildRuqyahList(isArabic),
                _buildLiveStreams(isArabic),
                _buildSmartTasbih(isArabic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
