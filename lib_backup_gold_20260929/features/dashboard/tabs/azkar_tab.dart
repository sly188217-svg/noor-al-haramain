import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/language_provider.dart';

class AzkarTab extends StatefulWidget {
  const AzkarTab({super.key});

  @override
  State<AzkarTab> createState() => _AzkarTabState();
}

class _AzkarTabState extends State<AzkarTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🎨 لوحة الألوان الجديدة (أزرق)
  static const Color _primary = Color(0xFF4A90E2);
  static const Color _primaryDark = Color(0xFF2E5C8A);
  static const Color _primaryLight = Color(0xFF64B5F6);
  static const Color _bg = Color(0xFF0A1929);
  static const Color _surface = Color(0xFF132F4C);

  // ═══════════════════════════════════════════════════════════
  // 🌅 أذكار الصباح
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _morningAzkar = [
    {'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.', 'count': 1},
    {'text': 'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 4},
    {'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 3},
    {'text': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.', 'count': 7},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ.', 'count': 3},
    {'text': 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا.', 'count': 3},
    {'text': 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي.', 'count': 1},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', 'count': 3},
    {'text': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.', 'count': 1},
    {'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', 'count': 100},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', 'count': 10},
    {'text': 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', 'count': 100},
    {'text': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', 'count': 10},
  ];

  // 🌙 أذكار المساء
  final List<Map<String, dynamic>> _eveningAzkar = [
    {'text': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ فَتْحَهَا وَنَصْرَهَا وَنُورَهَا وَبَرَكَتَهَا وَهُدَاهَا.', 'count': 1},
    {'text': 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 4},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', 'count': 3},
    {'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.', 'count': 3},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ.', 'count': 3},
    {'text': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.', 'count': 7},
    {'text': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.', 'count': 1},
    {'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', 'count': 100},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', 'count': 10},
    {'text': 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', 'count': 100},
    {'text': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', 'count': 10},
  ];

  // 😴 أذكار النوم
  final List<Map<String, dynamic>> _sleepAzkar = [
    {'text': 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.', 'count': 1},
    {'text': 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', 'count': 3},
    {'text': 'بِاسْمِكَ رَبِّ وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا.', 'count': 1},
    {'text': 'سُبْحَانَ اللَّهِ.', 'count': 33},
    {'text': 'الْحَمْدُ لِلَّهِ.', 'count': 33},
    {'text': 'اللَّهُ أَكْبَرُ.', 'count': 34},
    {'text': 'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ.', 'count': 1},
    {'text': 'آيَةُ الْكُرْسِيِّ: اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...', 'count': 1},
    {'text': 'قُلْ هُوَ اللَّهُ أَحَدٌ... (سورة الإخلاص)', 'count': 3},
    {'text': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ... (سورة الفلق)', 'count': 3},
    {'text': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ... (سورة الناس)', 'count': 3},
  ];

  // 🕌 أذكار بعد الصلاة
  final List<Map<String, dynamic>> _prayerAzkar = [
    {'text': 'أَسْتَغْفِرُ اللَّهَ (ثلاثاً)، اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', 'count': 1},
    {'text': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.', 'count': 1},
    {'text': 'سُبْحَانَ اللَّهِ.', 'count': 33},
    {'text': 'الْحَمْدُ لِلَّهِ.', 'count': 33},
    {'text': 'اللَّهُ أَكْبَرُ.', 'count': 33},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', 'count': 1},
    {'text': 'آيَةُ الْكُرْسِيِّ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.', 'count': 1},
    {'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.', 'count': 1},
  ];

  // 🤲 أدعية قرآنية
  final List<Map<String, String>> _duas = [
    {'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'reference': 'البقرة 201'},
    {'text': 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ', 'reference': 'آل عمران 8'},
    {'text': 'رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا', 'reference': 'آل عمران 147'},
    {'text': 'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ', 'reference': 'الأعراف 23'},
    {'text': 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي', 'reference': 'طه 25-26'},
    {'text': 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا', 'reference': 'الفرقان 74'},
    {'text': 'رَبِّ زِدْنِي عِلْمًا', 'reference': 'طه 114'},
    {'text': 'رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا', 'reference': 'البقرة 286'},
    {'text': 'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ', 'reference': 'إبراهيم 41'},
    {'text': 'رَبِّ هَبْ لِي حُكْمًا وَأَلْحِقْنِي بِالصَّالِحِينَ', 'reference': 'الشعراء 83'},
  ];

  // 🕋 الرقية الشرعية
  final List<Map<String, String>> _ruqyah = [
    {'text': 'بِسْمِ اللَّهِ أَرْقِيكَ مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنٍ حَاسِدٍ، اللَّهُ يَشْفِيكَ.', 'count': '3'},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ غَضَبِهِ وَعِقَابِهِ، وَشَرِّ عِبَادِهِ.', 'count': '3'},
    {'text': 'أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.', 'count': '7'},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ.', 'count': '3'},
    {'text': 'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَاسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ.', 'count': '3'},
    {'text': 'أَسْأَلُ اللَّهَ الْعَظِيمَ رَبَّ الْعَرْشِ الْعَظِيمِ أَنْ يَشْفِيَكَ.', 'count': '7'},
  ];

  // 📺 البث المباشر
  final List<Map<String, String>> _liveStreams = [
    {
      'name': 'الحرم المكي',
      'nameEn': 'Makkah Live',
      'icon': '🕋',
      'url': 'https://www.youtube.com/@SaudiQuranTv/live',
    },
    {
      'name': 'المسجد النبوي',
      'nameEn': 'Madinah Live',
      'icon': '🕌',
      'url': 'https://www.youtube.com/@SaudiSunnahTv/live',
    },
  ];
  // 📿 السبحة
  int _tasbihCount = 0;
  String _selectedDhikr = 'سبحان الله';
  Map<String, int> _tasbihCounts = {};

  final List<String> _dhikrList = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله',
    'لا حول ولا قوة إلا بالله',
    'اللهم صل على محمد',
    'سبحان الله وبحمده',
    'لا إله إلا الله وحده لا شريك له',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
    final savedCounts = prefs.getString('tasbih_counts');
    if (!mounted) return;
    Map<String, int> loadedCounts = {};
    if (savedCounts != null) {
      try {
        final decoded = jsonDecode(savedCounts) as Map<String, dynamic>;
        loadedCounts = decoded.map(
            (key, value) => MapEntry(key, (value as num).toInt()));
      } catch (_) {}
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
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _primary, width: 1.5),
        ),
        title: const Text('🔄 إعادة تعيين',
            style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
        content: Text('هل تريد إعادة تعيين عداد "$_selectedDhikr"؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 4),
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
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.orange, width: 1.5),
        ),
        title:
            const Text('⚠️ تحذير', style: TextStyle(color: Colors.orange)),
        content: const Text(
            'هل تريد حذف جميع العدادات لكل الأذكار؟\nلا يمكن التراجع!',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 4),
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

  // ✅ فتح البث في يوتيوب مباشرة (أضمن طريقة)
  Future<void> _openLiveStream(String url, String title) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ تعذّر فتح $title')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ خطأ: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بناء الواجهات
  // ═══════════════════════════════════════════════════════════
  Widget _buildAzkarList(
      List<Map<String, dynamic>> items, bool isArabic, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryDark, _surface],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${items.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
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
                  gradient: LinearGradient(
                    colors: [
                      _surface.withValues(alpha: 0.9),
                      _bg.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item['text']!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontFamily: 'Amiri',
                            height: 1.8),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                          '🔄 $count ${isArabic ? 'مرات' : 'times'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
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
            gradient: LinearGradient(
              colors: [_surface.withValues(alpha: 0.9), _bg.withValues(alpha: 0.9)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dua['text']!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontFamily: 'Amiri',
                      height: 1.8),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl),
              const SizedBox(height: 8),
              Text('📖 ${dua['reference']}',
                  style: const TextStyle(color: _primaryLight, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

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
            gradient: LinearGradient(
              colors: [_surface.withValues(alpha: 0.9), _bg.withValues(alpha: 0.9)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item['text']!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontFamily: 'Amiri',
                      height: 1.8),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl),
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
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveStreams(bool isArabic) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _liveStreams.length,
      itemBuilder: (context, index) {
        final stream = _liveStreams[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_surface, _bg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _primary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openLiveStream(
                  stream['url']!,
                  isArabic ? stream['name']! : stream['nameEn']!),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(stream['icon']!,
                            style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isArabic ? stream['name']! : stream['nameEn']!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.red, width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        color: Colors.red, size: 8),
                                    SizedBox(width: 4),
                                    Text('LIVE',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('اضغط للمشاهدة',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _primaryDark],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartTasbih(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_surface, _bg],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButton<String>(
              value: _selectedDhikr,
              dropdownColor: _surface,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              underline: const SizedBox(),
              isExpanded: true,
              items: _dhikrList.map((dhikr) {
                final count = _tasbihCounts[dhikr] ?? 0;
                return DropdownMenuItem(
                  value: dhikr,
                  child: Row(
                    children: [
                      Text(dhikr,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Amiri')),
                      const Spacer(),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 30),
          // 🎯 الزر الدائري الكبير (3D)
          GestureDetector(
            onTap: _incrementTasbih,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [_primaryLight, _primary, _primaryDark],
                  stops: [0.1, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_primaryLight, _primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_tasbihCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ])),
                      const SizedBox(height: 6),
                      Text(isArabic ? 'اضغط للعد' : 'Tap to count',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildElevatedCircleButton(
                icon: Icons.remove,
                color: Colors.orange,
                onTap: _decrementTasbih,
              ),
              const SizedBox(width: 20),
              _buildElevatedCircleButton(
                icon: Icons.refresh,
                color: _primary,
                onTap: _resetCurrentTasbih,
              ),
              const SizedBox(width: 20),
              _buildElevatedCircleButton(
                icon: Icons.add,
                color: Colors.green,
                onTap: _incrementTasbih,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_tasbihCounts.values.any((v) => v > 0)) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('📊 سجل العدادات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_surface, _bg],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: _dhikrList.map((dhikr) {
                  final count = _tasbihCounts[dhikr] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            color: _primary, size: 8),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(dhikr,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Amiri')),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAllTasbih,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('🗑️ حذف جميع العدادات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 6,
                  shadowColor: Colors.red.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildElevatedCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: color.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryDark, _surface],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              isScrollable: true,
              tabs: [
                Tab(text: isArabic ? '🌅 صباح' : '🌅 Morning'),
                Tab(text: isArabic ? '🌙 مساء' : '🌙 Evening'),
                Tab(text: isArabic ? '😴 نوم' : '😴 Sleep'),
                Tab(text: isArabic ? '🕌 صلاة' : '🕌 Prayer'),
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
                _buildAzkarList(_morningAzkar, isArabic,
                    isArabic ? '🌅 أذكار الصباح' : 'Morning Azkar'),
                _buildAzkarList(_eveningAzkar, isArabic,
                    isArabic ? '🌙 أذكار المساء' : 'Evening Azkar'),
                _buildAzkarList(_sleepAzkar, isArabic,
                    isArabic ? '😴 أذكار النوم' : 'Sleep Azkar'),
                _buildAzkarList(_prayerAzkar, isArabic,
                    isArabic ? '🕌 بعد الصلاة' : 'After Prayer'),
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
