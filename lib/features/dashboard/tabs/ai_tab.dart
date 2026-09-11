import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../quran/models/surah_model.dart';
import '../../quran/models/ayah_model.dart';
import '../../quran/services/quran_service.dart';

class AiTab extends StatefulWidget {
  const AiTab({super.key});

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== متغيرات التعرف على الصوت =====
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // ===== متغيرات النطق =====
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // ===== متغيرات التلاوة والتصحيح =====
  String _userRecitation = '';
  String _correctAyahText = '';
  double _accuracy = 0.0;
  String _correctionFeedback = '';

  // ===== متغيرات السور والآيات =====
  List<SurahModel> _surahs = [];
  int _selectedSurahNumber = 1;
  int _selectedAyahNumber = 1;
  List<AyahModel> _ayahs = [];
  bool _isLoadingSurahs = false;
  bool _isLoadingAyahs = false;
  bool _isQuranLoaded = false;

  // ===== متغيرات المحادثة =====
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isAiLoading = false;

  // ===== إعدادات اللغة =====
  String _currentLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();
    _loadQuran();
    _loadChatHistory();
    _loadLanguage();
    _initSpeech();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  // ================================================================
  //  1. تهيئة النطق (TTS)
  // ================================================================
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ar');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  // ================================================================
  //  2. تحميل القرآن باستخدام الدالة الجديدة
  // ================================================================
  Future<void> _loadQuran() async {
    setState(() => _isLoadingSurahs = true);
    try {
      final surahs = await QuranService.loadQuran();
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _isQuranLoaded = true;
          _isLoadingSurahs = false;
        });
        await _loadAyahs(_selectedSurahNumber);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSurahs = false;
          _correctionFeedback = '⚠️ تعذر تحميل القرآن. تأكد من اتصالك بالإنترنت.';
        });
      }
    }
  }

  Future<void> _loadAyahs(int surahNumber) async {
    if (!_isQuranLoaded) return;
    setState(() => _isLoadingAyahs = true);
    try {
      final surah = await QuranService.getSurah(surahNumber);
      if (surah != null && surah.ayahs != null && surah.ayahs!.isNotEmpty) {
        setState(() {
          _ayahs = surah.ayahs!;
          _selectedAyahNumber = _ayahs.isNotEmpty ? _ayahs.first.number : 1;
          _isLoadingAyahs = false;
        });
        _updateCorrectAyah();
      } else {
        // إذا لم تكن الآيات موجودة، جرب جلبها من API
        final ayahs = await QuranService.fetchAyahsFromApi(surahNumber);
        setState(() {
          _ayahs = ayahs;
          _selectedAyahNumber = ayahs.isNotEmpty ? ayahs.first.number : 1;
          _isLoadingAyahs = false;
        });
        _updateCorrectAyah();
      }
    } catch (e) {
      setState(() {
        _isLoadingAyahs = false;
        _correctionFeedback = '⚠️ فشل تحميل الآيات: $e';
      });
    }
  }

  void _updateCorrectAyah() {
    final ayah = _ayahs.firstWhere(
      (a) => a.number == _selectedAyahNumber,
      orElse: () => _ayahs.isNotEmpty ? _ayahs.first : AyahModel(number: 0, text: ''),
    );
    setState(() {
      _correctAyahText = ayah.text;
      _userRecitation = '';
      _accuracy = 0.0;
      _correctionFeedback = '';
    });
  }

  // ================================================================
  //  3. التعرف على الصوت (Speech-to-Text)
  // ================================================================
  Future<void> _initSpeech() async {
    if (_speechAvailable) return;
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() {
              _isListening = false;
              if (_userRecitation.isNotEmpty) {
                _correctRecitation();
              }
            });
          }
        },
        onError: (error) => print('Speech error: $error'),
      );
      setState(() => _speechAvailable = available);
    } catch (e) {
      setState(() => _speechAvailable = false);
      print('Speech init error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ التعرف الصوتي غير متوفر على هذا الجهاز.')),
        );
        return;
      }
    }
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      _correctRecitation();
      return;
    }
    setState(() {
      _isListening = true;
      _userRecitation = '';
      _accuracy = 0.0;
      _correctionFeedback = '🎤 استمع...';
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _userRecitation = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'ar_SA',
    );
  }

  // ================================================================
  //  4. تصحيح التلاوة
  // ================================================================
  void _correctRecitation() {
    if (_userRecitation.isEmpty || _correctAyahText.isEmpty) {
      setState(() {
        _accuracy = 0.0;
        _correctionFeedback = '⚠️ لم يتم التعرف على تلاوتك أو الآية غير محددة.';
      });
      return;
    }

    String clean(String text) {
      return text
          .replaceAll(RegExp(r'[ًٌٍَُِّْ]'), '')
          .replaceAll(RegExp(r'[،؛؟!.]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final cleanedUser = clean(_userRecitation);
    final cleanedCorrect = clean(_correctAyahText);

    final userWords = cleanedUser.split(' ');
    final correctWords = cleanedCorrect.split(' ');
    int matched = 0;
    for (int i = 0; i < userWords.length && i < correctWords.length; i++) {
      if (userWords[i] == correctWords[i]) matched++;
    }
    final maxLen = max(userWords.length, correctWords.length);
    final matchPercent = maxLen > 0 ? (matched / maxLen) * 100 : 0;

    setState(() {
      _accuracy = matchPercent.toDouble();
      if (matchPercent >= 90) {
        _correctionFeedback = '🌟 ممتاز! تلاوتك صحيحة بنسبة ${matchPercent.toStringAsFixed(0)}%';
      } else if (matchPercent >= 70) {
        _correctionFeedback = '👍 جيد جداً، لكن هناك بعض الأخطاء. حاول مرة أخرى. (${matchPercent.toStringAsFixed(0)}%)';
      } else if (matchPercent >= 50) {
        _correctionFeedback = '⚠️ تحتاج إلى مراجعة التلاوة. (${matchPercent.toStringAsFixed(0)}%)';
      } else {
        _correctionFeedback = '❌ التلاوة غير مطابقة. استمع إلى النموذج الصحيح ثم حاول. (${matchPercent.toStringAsFixed(0)}%)';
      }
    });

    if (matchPercent < 50) {
      _speakAyah();
    }
  }

  // ================================================================
  //  5. النطق (Text-to-Speech)
  // ================================================================
  Future<void> _speakAyah() async {
    if (_correctAyahText.isEmpty) return;
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(_correctAyahText);
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
  }

  // ================================================================
  //  6. محادثة ذكية (Gemini AI)
  // ================================================================
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('chat_history');
    if (saved != null) {
      try {
        // استعادة المحادثة لاحقاً
      } catch (e) {}
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = _messages.length > 20 ? _messages.sublist(_messages.length - 20) : _messages;
    await prefs.setString('chat_history', toSave.toString());
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _chatController.clear();
      _isAiLoading = true;
    });
    _scrollToBottom();

    final reply = await AIService.askQuestion(text);

    setState(() {
      _messages.add({'role': 'assistant', 'text': reply});
      _isAiLoading = false;
    });
    _scrollToBottom();
    await _saveMessages();

    if (reply.length > 50) {
      _speakText(reply);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() => _messages.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم مسح المحادثة')),
    );
  }

  // ================================================================
  //  7. تحميل تفضيلات اللغة
  // ================================================================
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'ar';
    setState(() => _currentLanguage = lang);
  }

  // ================================================================
  //  8. بناء الواجهة
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B132B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2541),
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'المساعد الذكي "المرشد"' : 'Smart Assistant "Al-Murshid"',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFD4AF37),
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: isArabic ? '📖 تلاوة وتصحيح' : '📖 Recite & Correct'),
              Tab(text: isArabic ? '💬 محادثة ذكية' : '💬 Smart Chat'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRecitationTab(isArabic),
            _buildChatTab(isArabic),
          ],
        ),
      ),
    );
  }

  // ================================================================
  //  8-1. تبويب التلاوة والتصحيح
  // ================================================================
  Widget _buildRecitationTab(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingSurahs)
            const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          else if (_surahs.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedSurahNumber,
                    dropdownColor: const Color(0xFF1C2541),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'السورة' : 'Surah',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: const Color(0xFF0B132B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _surahs.map((s) {
                      return DropdownMenuItem<int>(
                        value: s.number,
                        child: Text('${s.number}. ${s.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedSurahNumber = value);
                        _loadAyahs(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _ayahs.isNotEmpty && _selectedAyahNumber <= _ayahs.last.number
                        ? _selectedAyahNumber
                        : (_ayahs.isNotEmpty ? _ayahs.first.number : 1),
                    dropdownColor: const Color(0xFF1C2541),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الآية' : 'Ayah',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: const Color(0xFF0B132B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _ayahs.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.number,
                        child: Text('${a.number}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAyahNumber = value;
                          _updateCorrectAyah();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          if (_correctAyahText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _correctAyahText,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 20,
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
                      ElevatedButton.icon(
                        onPressed: _speakAyah,
                        icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up,
                            color: Colors.black, size: 18),
                        label: Text(isArabic ? 'استمع' : 'Listen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _startListening,
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.black, size: 18),
                        label: Text(_isListening
                            ? (isArabic ? 'استمع...' : 'Listening...')
                            : (isArabic ? 'سجل تلاوتك' : 'Recite')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening ? Colors.red : const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          if (_userRecitation.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _userRecitation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Amiri',
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  if (_accuracy > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_accuracy.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _accuracy >= 70 ? Colors.green : Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _accuracy >= 70
                              ? (isArabic ? '✅ صحيح' : '✅ Correct')
                              : (isArabic ? '⚠️ يحتاج مراجعة' : '⚠️ Needs review'),
                          style: TextStyle(
                            color: _accuracy >= 70 ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          if (_correctionFeedback.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B132B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Text(
                _correctionFeedback,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isArabic
                  ? '💡 اضغط على زر "سجل تلاوتك" وتل الآية، سيقوم المرشد بتصحيح تلاوتك.'
                  : '💡 Press "Recite" and recite the verse, Al-Murshid will correct your recitation.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  //  8-2. تبويب المحادثة الذكية
  // ================================================================
  Widget _buildChatTab(bool isArabic) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          color: Color(0xFFD4AF37), size: 60),
                      const SizedBox(height: 16),
                      Text(
                        isArabic
                            ? '👋 اسأل المرشد أي سؤال ديني'
                            : '👋 Ask Al-Murshid any Islamic question',
                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? 'يمكنك الكتابة أو استخدام الميكروفون 🎤'
                            : 'You can type or use the microphone 🎤',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['role'] == 'user';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? LinearGradient(
                                  colors: [const Color(0xFF1C2541), const Color(0xFF0B132B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [const Color(0xFFD4AF37), const Color(0xFFB8860B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isUser ? const Color(0xFF1C2541) : const Color(0xFFD4AF37))
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          message['text']!,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black,
                            fontSize: 15,
                            height: 1.6,
                            fontFamily: isUser ? null : 'Amiri',
                          ),
                          textAlign: isUser ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isAiLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'المرشد يكتب...' : 'Al-Murshid is typing...',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            border: Border(
              top: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await _startListening();
                  if (_userRecitation.isNotEmpty) {
                    _chatController.text = _userRecitation;
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : const Color(0xFF1C2541),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? Colors.red : const Color(0xFFD4AF37).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : const Color(0xFFD4AF37),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendChatMessage(),
                  decoration: InputDecoration(
                    hintText: isArabic ? 'اكتب سؤالك هنا...' : 'Type your question...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendChatMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
