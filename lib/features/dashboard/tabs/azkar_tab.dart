import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/providers/language_provider.dart';

/// تبويب الأذكار، الأدعية، الرقية الشرعية، التسبيح الذكي، والبث المباشر للحرمين
class AzkarTab extends StatefulWidget {
  const AzkarTab({super.key});

  @override
  State<AzkarTab> createState() => _AzkarTabState();
}

class _AzkarTabState extends State<AzkarTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== 📖 أذكار الصباح (من حصن المسلم) =====
  final List<Map<String, dynamic>> _morningAzkar = [
    {'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.', 'count': 1},
    {'text': 'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.', 'count': 4},
    {'text': 'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ.', 'count': 1},
    {'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 3},
  ];

  // ===== 📖 أذكار المساء =====
  final List<Map<String, dynamic>> _eveningAzkar = [
    {'text': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ فَتْحَهَا وَنَصْرَهَا وَنُورَهَا وَبَرَكَتَهَا وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهَا وَشَرِّ مَا بَعْدَهَا.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.', 'count': 4},
  ];

  // ===== 📖 أذكار النوم =====
  final List<Map<String, dynamic>> _sleepAzkar = [
    {'text': 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا.', 'count': 1},
    {'text': 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', 'count': 3},
    {'text': 'بِاسْمِكَ رَبِّ وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ.', 'count': 1},
    {'text': 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَكَفَانَا وَآوَانَا، فَكَمْ مِمَّنْ لَا كَافِيَ لَهُ وَلَا مُؤْوِيَ.', 'count': 1},
  ];

  // ===== 📖 أذكار بعد الصلاة =====
  final List<Map<String, dynamic>> _prayerAzkar = [
    {'text': 'أَسْتَغْفِرُ اللَّهَ (ثلاثاً) اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ (10 مرات بعد المغرب والصبح).', 'count': 10},
    {'text': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.', 'count': 1},
  ];

  // ===== 🤲 أدعية من القرآن والسنة =====
  final List<Map<String, String>> _duas = [
    {'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'reference': 'البقرة 201'},
    {'text': 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ', 'reference': 'آل عمران 8'},
    {'text': 'رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا وَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ', 'reference': 'آل عمران 147'},
    {'text': 'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ', 'reference': 'الأعراف 23'},
    {'text': 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِنْ لِسَانِي يَفْقَهُوا قَوْلِي', 'reference': 'طه 25-28'},
    {'text': 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا', 'reference': 'الفرقان 74'},
    {'text': 'رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا وَثَبِّتْ أَقْدَامَنَا وَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ', 'reference': 'البقرة 250'},
    {'text': 'رَبَّنَا لَا تَجْعَلْنَا فِتْنَةً لِلْقَوْمِ الظَّالِمِينَ وَنَجِّنَا بِرَحْمَتِكَ مِنَ الْقَوْمِ الْكَافِرِينَ', 'reference': 'يونس 85-86'},
    {'text': 'رَبَّنَا اغْفِرْ لَنَا وَلِإِخْوَانِنَا الَّذِينَ سَبَقُونَا بِالْإِيمَانِ وَلَا تَجْعَلْ فِي قُلُوبِنَا غِلًّا لِلَّذِينَ آمَنُوا', 'reference': 'الحشر 10'},
    {'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى', 'reference': 'مسلم'},
  ];

  // ===== 🕋 الرقية الشرعية =====
  final List<Map<String, String>> _ruqyah = [
    {'text': 'بِسْمِ اللَّهِ أَرْقِيكَ مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنٍ حَاسِدٍ، اللَّهُ يَشْفِيكَ بِسْمِ اللَّهِ أَرْقِيكَ.', 'count': '3'},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ غَضَبِهِ وَعِقَابِهِ وَشَرِّ عِبَادِهِ وَمِنْ هَمَزَاتِ الشَّيَاطِينِ وَأَنْ يَحْضُرُونِ.', 'count': '3'},
    {'text': 'أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.', 'count': '3'},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.', 'count': '3'},
    {'text': 'اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَاسَ اشْفِ أَنْتَ الشَّافِي لَا شِفَاءَ إِلَّا شِفَاؤُكَ شِفَاءً لَا يُغَادِرُ سَقَمًا.', 'count': '3'},
  ];

  // ===== 📺 البث المباشر للحرمين (روابط يوتيوب رسمية) =====
  final List<Map<String, String>> _liveStreams = [
    {'name': 'الحرم المكي', 'nameEn': 'Makkah Haram', 'icon': '🕋', 'url': 'https://www.youtube.com/watch?v=4xW89jPcLhc'},
    {'name': 'المدينة المنورة', 'nameEn': 'Madinah Haram', 'icon': '🕌', 'url': 'https://www.youtube.com/watch?v=8Y1HGYhV3sw'},
  ];

  // ===== 📿 التسبيح الذكي =====
  int _tasbihCount = 0;
  String _selectedDhikr = 'سبحان الله';
  final List<String> _dhikrList = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'استغفر الله',
    'لا حول ولا قوة إلا بالله',
    'سبحان الله وبحمده',
    'سبحان الله العظيم',
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

  Future<void> _loadTasbihPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDhikr = prefs.getString('tasbih_dhikr');
    final savedCount = prefs.getInt('tasbih_count');
    if (savedDhikr != null) setState(() => _selectedDhikr = savedDhikr);
    if (savedCount != null) setState(() => _tasbihCount = savedCount);
  }

  Future<void> _saveTasbihPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasbih_dhikr', _selectedDhikr);
    await prefs.setInt('tasbih_count', _tasbihCount);
  }

  void _incrementTasbih() {
    HapticFeedback.mediumImpact();
    setState(() => _tasbihCount++);
    _saveTasbihPreference();
  }

  void _resetTasbih() {
    HapticFeedback.heavyImpact();
    setState(() => _tasbihCount = 0);
    _saveTasbihPreference();
  }

  // ============================================================
  //  تشغيل البث المباشر داخل التطبيق باستخدام YoutubePlayer
  // ============================================================
  void _showLiveStream(String url) {
    // استخراج videoId من الرابط
    String videoId = YoutubePlayer.convertUrlToId(url) ?? '';
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ رابط غير صالح')),
      );
      return;
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: false,
        isLive: true,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: Container(
          height: 350,
          width: double.maxFinite,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            children: [
              // شريط العنوان
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C2541),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.live_tv, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'بث مباشر',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () {
                        controller.dispose();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // مشغل الفيديو
              Expanded(
                child: YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFFD4AF37),
                  bottomActions: [
                    CurrentPosition(),
                    ProgressBar(
                      isExpanded: true,
                      colors: const ProgressBarColors(
                        playedColor: Color(0xFFD4AF37),
                        handleColor: Color(0xFFD4AF37),
                      ),
                    ),
                    RemainingDuration(),
                    FullScreenButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  بناء قائمة الأذكار
  // ============================================================
  Widget _buildAzkarList(List<Map<String, dynamic>> items, bool isArabic, String title) {
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
                  color: const Color(0xFF1C2541).withOpacity(0.6),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🔄 ${count} ${isArabic ? 'مرات' : 'times'}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.repeat, color: Color(0xFFD4AF37), size: 18),
                          onPressed: () {},
                          tooltip: 'تكرار',
                        ),
                      ],
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

  // ============================================================
  //  بناء قائمة الأدعية
  // ============================================================
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
            color: const Color(0xFF1C2541).withOpacity(0.6),
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

  // ============================================================
  //  بناء قائمة الرقية الشرعية
  // ============================================================
  Widget _buildRuqyahList(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _ruqyah.length,
      itemBuilder: (context, index) {
        final item = _ruqyah[index];
        final count = int.tryParse(item['count'] ?? '1') ?? 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withOpacity(0.6),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 0.5),
                    ),
                    child: Text(
                      '🔄 ${count} ${isArabic ? 'مرات' : 'times'}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Color(0xFFD4AF37), size: 20),
                    onPressed: () {},
                    tooltip: 'استماع',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  //  بناء البث المباشر
  // ============================================================
  Widget _buildLiveStreams(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _liveStreams.length,
      itemBuilder: (context, index) {
        final stream = _liveStreams[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
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
                color: Colors.red.withOpacity(0.2),
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
            onTap: () => _showLiveStream(stream['url']!),
          ),
        );
      },
    );
  }

  // ============================================================
  //  بناء التسبيح الذكي
  // ============================================================
  Widget _buildSmartTasbih(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: DropdownButton<String>(
              value: _selectedDhikr,
              dropdownColor: const Color(0xFF1C2541),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              underline: const SizedBox(),
              isExpanded: true,
              items: _dhikrList.map((dhikr) {
                return DropdownMenuItem(
                  value: dhikr,
                  child: Text(
                    dhikr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Amiri',
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDhikr = value);
                  _saveTasbihPreference();
                }
              },
            ),
          ),
          const SizedBox(height: 30),

          GestureDetector(
            onTap: _incrementTasbih,
            onLongPress: _resetTasbih,
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
                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_tasbihCount',
                  style: const TextStyle(
                    color: Color(0xFF0B132B),
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic
                ? '👆 اضغط للعد، اضغط مطولاً لإعادة الضبط'
                : '👆 Tap to count, long press to reset',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('$_tasbihCount', isArabic ? 'العدد الحالي' : 'Current'),
                _buildStatCard('33', isArabic ? 'الهدف' : 'Target'),
                _buildStatCard(
                  '${_tasbihCount >= 33 ? '✅' : '⏳'}',
                  isArabic ? 'الحالة' : 'Status',
                ),
              ],
            ),
          ),
        ],
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

  // ============================================================
  //  بناء الواجهة الرئيسية
  // ============================================================
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
              tabs: [
                Tab(text: isArabic ? '🕌 أذكار' : '🕌 Adhkar'),
                Tab(text: isArabic ? '🤲 أدعية' : '🤲 Duas'),
                Tab(text: isArabic ? '🕋 رقية' : '🕋 Ruqyah'),
                Tab(text: isArabic ? '📺 بث مباشر' : '📺 Live'),
                Tab(text: isArabic ? '📿 تسبيح' : '📿 Tasbih'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAzkarList(
                  [..._morningAzkar, ..._eveningAzkar, ..._sleepAzkar, ..._prayerAzkar],
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
