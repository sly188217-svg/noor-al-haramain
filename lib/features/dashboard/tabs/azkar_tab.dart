import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  // 🌅 أذكار الصباح (15)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _morningAzkar = [
    {
      'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.',
      'count': 1
    },
    {
      'text': 'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.',
      'count': 4
    },
    {
      'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
      'count': 3
    },
    {
      'text': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
      'count': 7
    },
    {
      'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ.',
      'count': 3
    },
    {
      'text': 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا.',
      'count': 3
    },
    {
      'text': 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي.',
      'count': 1
    },
    {
      'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
      'count': 3
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.',
      'count': 1
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
      'count': 100
    },
    {
      'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': 10
    },
    {
      'text': 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.',
      'count': 100
    },
    {
      'text': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.',
      'count': 10
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // 🌙 أذكار المساء (12)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _eveningAzkar = [
    {
      'text': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ فَتْحَهَا وَنَصْرَهَا وَنُورَهَا وَبَرَكَتَهَا وَهُدَاهَا.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ.',
      'count': 4
    },
    {
      'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
      'count': 3
    },
    {
      'text': 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
      'count': 3
    },
    {
      'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ.',
      'count': 3
    },
    {
      'text': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
      'count': 7
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.',
      'count': 1
    },
    {
      'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
      'count': 100
    },
    {
      'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': 10
    },
    {
      'text': 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.',
      'count': 100
    },
    {
      'text': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.',
      'count': 10
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // 😴 أذكار النوم (10)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _sleepAzkar = [
    {
      'text': 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.',
      'count': 3
    },
    {
      'text': 'بِاسْمِكَ رَبِّ وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا.',
      'count': 1
    },
    {
      'text': 'سُبْحَانَ اللَّهِ.',
      'count': 33
    },
    {
      'text': 'الْحَمْدُ لِلَّهِ.',
      'count': 33
    },
    {
      'text': 'اللَّهُ أَكْبَرُ.',
      'count': 34
    },
    {
      'text': 'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ.',
      'count': 1
    },
    {
      'text': 'آيَةُ الْكُرْسِيِّ: اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...',
      'count': 1
    },
    {
      'text': 'قُلْ هُوَ اللَّهُ أَحَدٌ... (سورة الإخلاص)',
      'count': 3
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ... (سورة الفلق)',
      'count': 3
    },
    {
      'text': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ... (سورة الناس)',
      'count': 3
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // 🕌 أذكار بعد الصلاة (10)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _prayerAzkar = [
    {
      'text': 'أَسْتَغْفِرُ اللَّهَ (ثلاثاً)، اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
      'count': 1
    },
    {
      'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.',
      'count': 1
    },
    {
      'text': 'سُبْحَانَ اللَّهِ.',
      'count': 33
    },
    {
      'text': 'الْحَمْدُ لِلَّهِ.',
      'count': 33
    },
    {
      'text': 'اللَّهُ أَكْبَرُ.',
      'count': 33
    },
    {
      'text': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': 1
    },
    {
      'text': 'آيَةُ الْكُرْسِيِّ.',
      'count': 1
    },
    {
      'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.',
      'count': 1
    },
    {
      'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.',
      'count': 1
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // 📿 أذكار عامة (15)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, dynamic>> _generalAzkar = [
    {'text': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ.', 'count': 1},
    {'text': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا اللَّهُ.', 'count': 1},
    {'text': 'أَسْتَغْفِرُ اللَّهَ.', 'count': 1},
    {'text': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ.', 'count': 1},
    {'text': 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ.', 'count': 1},
    {'text': 'اللَّهُمَّ اغْفِرْ لِي وَلِوَالِدَيَّ.', 'count': 1},
    {'text': 'اللَّهُمَّ ارْحَمْنِي وَارْحَمْ وَالِدَيَّ.', 'count': 1},
    {'text': 'حَسْبِيَ اللَّهُ وَنِعْمَ الْوَكِيلُ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ.', 'count': 1},
    {'text': 'اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي.', 'count': 1},
    {'text': 'اللَّهُمَّ أَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي.', 'count': 1},
    {'text': 'اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ.', 'count': 1},
    {'text': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى.', 'count': 1},
    {'text': 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ.', 'count': 1},
  ];

  // ═══════════════════════════════════════════════════════════
  // 🤲 أدعية قرآنية (15)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _duas = [
    {'text': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'reference': 'البقرة 201'},
    {'text': 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ', 'reference': 'آل عمران 8'},
    {'text': 'رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا', 'reference': 'آل عمران 147'},
    {'text': 'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ', 'reference': 'الأعراف 23'},
    {'text': 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي', 'reference': 'طه 25-26'},
    {'text': 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا', 'reference': 'الفرقان 74'},
    {'text': 'رَبِّ زِدْنِي عِلْمًا', 'reference': 'طه 114'},
    {'text': 'رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا', 'reference': 'البقرة 286'},
    {'text': 'رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا', 'reference': 'البقرة 286'},
    {'text': 'رَبَّنَا وَآتِنَا مَا وَعَدْتَنَا عَلَى رُسُلِكَ وَلَا تُخْزِنَا يَوْمَ الْقِيَامَةِ', 'reference': 'آل عمران 194'},
    {'text': 'رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِنْ ذُرِّيَّتِي', 'reference': 'إبراهيم 40'},
    {'text': 'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ', 'reference': 'إبراهيم 41'},
    {'text': 'رَبِّ هَبْ لِي حُكْمًا وَأَلْحِقْنِي بِالصَّالِحِينَ', 'reference': 'الشعراء 83'},
    {'text': 'رَبَّنَا وَسِعْتَ كُلَّ شَيْءٍ رَحْمَةً وَعِلْمًا فَاغْفِرْ لِلَّذِينَ تَابُوا', 'reference': 'غافر 7'},
    {'text': 'رَبَّنَا اصْرِفْ عَنَّا عَذَابَ جَهَنَّمَ إِنَّ عَذَابَهَا كَانَ غَرَامًا', 'reference': 'الفرقان 65'},
  ];

  // ═══════════════════════════════════════════════════════════
  // 🕋 الرقية الشرعية (8)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _ruqyah = [
    {'text': 'بِسْمِ اللَّهِ أَرْقِيكَ مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنٍ حَاسِدٍ، اللَّهُ يَشْفِيكَ.', 'count': '3'},
    {'text': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ غَضَبِهِ وَعِقَابِهِ، وَشَرِّ عِبَادِهِ، وَمِنْ هَمَزَاتِ الشَّيَاطِينِ وَأَنْ يَحْضُرُونِ.', 'count': '3'},
    {'text': 'أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.', 'count': '7'},
    {'text': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ.', 'count': '3'},
    {'text': 'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَاسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ.', 'count': '3'},
    {'text': 'أَسْأَلُ اللَّهَ الْعَظِيمَ رَبَّ الْعَرْشِ الْعَظِيمِ أَنْ يَشْفِيَكَ.', 'count': '7'},
    {'text': 'الفَاتِحَةُ (قراءة سورة الفاتحة).', 'count': '7'},
    {'text': 'المُعَوِّذَتَانِ (الإخلاص + الفلق + الناس).', 'count': '3'},
  ];

  // ═══════════════════════════════════════════════════════════
  // 📺 البث المباشر — HLS (بدون يوتيوب)
  // ═══════════════════════════════════════════════════════════
  final List<Map<String, String>> _liveStreams = [
    {
      'name': 'الحرم المكي',
      'nameEn': 'Makkah Live',
      'icon': '🕋',
      'url': 'https://win.holol.com/live/quran/playlist.m3u8',
      'fallback': 'https://www.youtube.com,
    },
    {
      'name': 'المسجد النبوي',
      'nameEn': 'Madinah Live',
      'icon': '🕌',
      'url': 'https://win.holol.com/live/sunnah/playlist.m3u8',
      'fallback': 'https://www.youtube.com/@SaudiSunnahTv/live',
    },

  // ═══════════════════════════════════════════════════════════
  // 📿 السبحة
  // ═══════════════════════════════════════════════════════════
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
    _tabController = TabController(length: 6, vsync: this);
    _loadTasbihPreference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📿 السبحة
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
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('🔄 إعادة تعيين',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: Text('هل تريد إعادة تعيين عداد "$_selectedDhikr"؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
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
        title: const Text('⚠️ تحذير', style: TextStyle(color: Colors.orange)),
        content: const Text('هل تريد حذف جميع العدادات لكل الأذكار؟\nلا يمكن التراجع!',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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
  // 📺 فتح البث المباشر
  // ═══════════════════════════════════════════════════════════
  void _openLiveStream(Map<String, String> stream, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HlsPlayerScreen(
          url: stream['url']!,
          fallbackUrl: stream['fallback'],
          title: title,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بناء الأذكار
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
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${items.length}',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37),
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
                  color: const Color(0xFF1C2541).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
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
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          '🔄 $count ${isArabic ? 'مرات' : 'times'}',
                          style: const TextStyle(
                              color: Color(0xFFD4AF37),
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
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
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
                  style: const TextStyle(
                      color: Color(0xFFD4AF37), fontSize: 12)),
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
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 0.5),
                ),
                child: Text('🔄 ${item['count']} ${isArabic ? 'مرات' : 'times'}',
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Text(stream['icon']!,
                style: const TextStyle(fontSize: 36)),
            title: Text(isArabic ? stream['name']! : stream['nameEn']!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            subtitle: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red, width: 0.5),
              ),
              child: const Text('🔴 LIVE',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            trailing: const Icon(Icons.play_circle_fill,
                color: Color(0xFFD4AF37), size: 40),
            onTap: () => _openLiveStream(
                stream, isArabic ? stream['name']! : stream['nameEn']!),
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
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Color(0xFFD4AF37),
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
          const SizedBox(height: 24),
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
                    Text('$_tasbihCount',
                        style: const TextStyle(
                            color: Color(0xFF0B132B),
                            fontSize: 48,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(isArabic ? 'اضغط للعد' : 'Tap to count',
                        style: const TextStyle(
                            color: Color(0xFF0B132B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
          if (_tasbihCounts.values.any((v) => v > 0)) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('📊 سجل العدادات',
                  style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
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
                          child: Text(dhikr,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Amiri')),
                        ),
                        Text('$count',
                            style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
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
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ],
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
                Tab(text: isArabic ? '🌅 صباح' : '🌅 Morning'),
                Tab(text: isArabic ? '🌙 مساء' : '🌙 Evening'),
                Tab(text: isArabic ? '😴 نوم' : '😴 Sleep'),
                Tab(text: isArabic ? '🕌 صلاة' : '🕌 Prayer'),
                Tab(text: isArabic ? '🤲 أدعية' : '🤲 Duas'),
                Tab(text: isArabic ? '🕋 رقية' : '🕋 Ruqyah'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAzkarList(_morningAzkar, isArabic, isArabic ? '🌅 أذكار الصباح' : 'Morning'),
                _buildAzkarList(_eveningAzkar, isArabic, isArabic ? '🌙 أذكار المساء' : 'Evening'),
                _buildAzkarList(_sleepAzkar, isArabic, isArabic ? '😴 أذكار النوم' : 'Sleep'),
                _buildAzkarList(_prayerAzkar, isArabic, isArabic ? '🕌 بعد الصلاة' : 'After Prayer'),
                _buildDuasList(isArabic),
                _buildRuqyahList(isArabic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📺 HLS Player Screen
// ═══════════════════════════════════════════════════════════
class HlsPlayerScreen extends StatefulWidget {
  final String url;
  final String? fallbackUrl;
  final String title;

  const HlsPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.fallbackUrl,
  });

  @override
  State<HlsPlayerScreen> createState() => _HlsPlayerScreenState();
}

class _HlsPlayerScreenState extends State<HlsPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36',
        },
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.orange, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    '⚠️ تعذّر التشغيل\n$errorMessage',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ HLS error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        foregroundColor: const Color(0xFFD4AF37),
        title: Row(
          children: [
            const Icon(Icons.live_tv, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                    fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text('🔴 LIVE',
                style: TextStyle(
                    color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  SizedBox(height: 16),
                  Text('جاري تحميل البث...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: Colors.orange, size: 80),
                        const SizedBox(height: 16),
                        const Text(
                          '⚠️ تعذّر تشغيل البث المباشر',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _hasError = false;
                            });
                            _initializePlayer();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('🔄 إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Chewie(controller: _chewieController!),
    );
  }
}
