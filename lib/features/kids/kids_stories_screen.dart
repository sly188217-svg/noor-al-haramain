import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// ═══════════════════════════════════════════════════════════
/// 🧒 قصص الأطفال — قراءة صوتية (TTS)
/// ═══════════════════════════════════════════════════════════
class KidsStoriesScreen extends StatefulWidget {
  const KidsStoriesScreen({super.key});

  @override
  State<KidsStoriesScreen> createState() => _KidsStoriesScreenState();
}

class _KidsStoriesScreenState extends State<KidsStoriesScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  int _currentStoryIndex = 0;
  double _speechRate = 0.4;

  final List<Map<String, String>> _stories = [
    {
      'title': 'قصة النبي نوح عليه السلام',
      'emoji': '🚢',
      'text': '''
كان النبي نوح عليه السلام رجلاً صالحاً، دعا قومه إلى عبادة الله وحده لسنوات طويلة.
لكن قومه لم يستجيبوا له، فأمره الله ببناء سفينة كبيرة.
بنى نوح السفينة، ثم جمع فيها من كل الحيوانات زوجين.
ثم جاء الطوفان وأغرق الكافرين، ونجا نوح والمؤمنون معه في السفينة.
''',
    },
    {
      'title': 'قصة النبي إبراهيم عليه السلام',
      'emoji': '🕋',
      'text': '''
كان النبي إبراهيم عليه السلام يحب الله كثيراً.
كان قومه يعبدون الأصنام، لكنه أخبرهم أن الله واحد لا شريك له.
حطم إبراهيم الأصنام ليريهم أنها لا تنفع ولا تضر.
ثم بنى مع ابنه إسماعيل الكعبة في مكة.
''',
    },
    {
      'title': 'قصة النبي يوسف عليه السلام',
      'emoji': '⭐',
      'text': '''
رأى يوسف عليه السلام في منامه أحد عشر كوكباً والشمس والقمر يسجدون له.
حسده إخوته فألقوه في البئر، ثم صار عبداً في مصر.
لكنه صبر وتقرب إلى الله، وأصبح عزيز مصر.
ثم سامح إخوته وجمع الله شمله بأبيه يعقوب.
''',
    },
    {
      'title': 'قصة النبي موسى عليه السلام',
      'emoji': '🌊',
      'text': '''
وُلد موسى عليه السلام في زمن فرعون الذي كان يقتل الأطفال.
ألقته أمه في النيل، فرباه فرعون في قصره.
كبر موسى وهرب إلى مدين، ثم كلمه الله في الوادي المقدس.
أرسله الله إلى فرعون ليدعوه إلى الإيمان، لكنه رفض.
فأنجى الله موسى وقومه، وأغرق فرعون في البحر.
''',
    },
    {
      'title': 'قصة النبي محمد ﷺ',
      'emoji': '🕌',
      'text': '''
وُلد النبي محمد ﷺ في مكة يتيماً.
كان صادقاً أميناً، حتى لقبه قومه بالصادق الأمين.
نزل عليه الوحي في غار حراء وهو في الأربعين من عمره.
دعا الناس إلى عبادة الله وحده، وصبر على الأذى.
ثم هاجر إلى المدينة، وانتشر الإسلام في الجزيرة العربية.
''',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _tts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speakStory() async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    final text = _stories[_currentStoryIndex]['text']!;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  void _nextStory() {
    _tts.stop();
    setState(() {
      _isSpeaking = false;
      _currentStoryIndex =
          (_currentStoryIndex + 1) % _stories.length;
    });
  }

  void _prevStory() {
    _tts.stop();
    setState(() {
      _isSpeaking = false;
      _currentStoryIndex =
          (_currentStoryIndex - 1 + _stories.length) % _stories.length;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentStoryIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: const Row(
          children: [
            Text('🧒', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('قصص الأطفال',
                style: TextStyle(color: Color(0xFFD4AF37))),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // قائمة القصص
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _stories.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentStoryIndex;
                  return GestureDetector(
                    onTap: () {
                      _tts.stop();
                      setState(() {
                        _isSpeaking = false;
                        _currentStoryIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFD4AF37)
                            : const Color(0xFF1C2541),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFD4AF37)
                              : Colors.white24,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_stories[index]['emoji']} قصة ${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة القصة
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1C2541), Color(0xFF0F1A2E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          story['emoji']!,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        story['title']!,
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(color: Colors.white24, height: 30),
                      Text(
                        story['text']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Amiri',
                          height: 2.0,
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار التحكم
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _prevStory,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('السابقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2541),
                      foregroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _speakStory,
                    icon: Icon(_isSpeaking
                        ? Icons.stop
                        : Icons.volume_up),
                    label: Text(_isSpeaking
                        ? '⏹ إيقاف'
                        : '🔊 استمع للقصة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpeaking
                          ? Colors.red
                          : const Color(0xFFD4AF37),
                      foregroundColor:
                          _isSpeaking ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _nextStory,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('التالية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2541),
                      foregroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // سرعة القراءة
            Row(
              children: [
                const Text('🐢',
                    style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Slider(
                    value: _speechRate,
                    min: 0.2,
                    max: 0.8,
                    divisions: 6,
                    activeColor: const Color(0xFFD4AF37),
                    label: _speechRate.toStringAsFixed(1),
                    onChanged: (v) async {
                      setState(() => _speechRate = v);
                      await _tts.setSpeechRate(v);
                    },
                  ),
                ),
                const Text('🐇',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
