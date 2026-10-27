import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/firebase_ai_service.dart';
import '../../../core/services/usage_service.dart';
import '../../../widgets/professional_ui.dart';
import '../../premium/premium_screen.dart';
import '../../recitation/recitation_screen.dart';
import '../../quran/read_with_me_screen.dart';
import '../../quran/services/quran_service.dart';
import '../../quran/models/surah_model.dart';

class AiTab extends StatefulWidget {
  const AiTab({super.key});
  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541).withValues(alpha: 0.8),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF4A90E2)),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'المساعد الذكي "المرشد"' : 'Al-Murshid Assistant',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A90E2),
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: [
            Tab(text: isArabic ? '📖 تلاوة وتصحيح' : '📖 Recite'),
            Tab(text: isArabic ? '🎙️ اقرأ معي' : '🎙️ Read with Me'),
            Tab(text: isArabic ? '💬 محادثة' : '💬 Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const RecitationScreen(),
          _ReadWithMeTab(isArabic: isArabic),
          _ChatTab(isArabic: isArabic),
        ],
      ),
    );
  }
}

class _ReadWithMeTab extends StatefulWidget {
  final bool isArabic;
  const _ReadWithMeTab({required this.isArabic});
  @override
  State<_ReadWithMeTab> createState() => _ReadWithMeTabState();
}

class _ReadWithMeTabState extends State<_ReadWithMeTab> {
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isLoadingSurahs = true;
  int _remainingReadWithMe = 4;
  List<SurahModel> _surahs = [];
  List<SurahModel> _filteredSurahs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _loadSurahs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPremium() async {
    final premium = await UsageService.isPremium();
    final remaining = await UsageService.remainingReadWithMe();
    if (!mounted) return;
    setState(() {
      _isPremium = premium;
      _remainingReadWithMe = remaining;
      _isLoading = false;
    });
  }

  Future<void> _loadSurahs() async {
    try {
      final surahs = await QuranService.loadQuran();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _filteredSurahs = surahs;
        _isLoadingSurahs = false;
      });
    } catch (e) {
      debugPrint('❌ فشل تحميل السور: $e');
      if (mounted) setState(() => _isLoadingSurahs = false);
    }
  }

  void _filterSurahs(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredSurahs = _surahs);
      return;
    }
    final q = query.trim();
    final filtered = _surahs.where((s) {
      return s.name.contains(q) || s.number.toString() == q || s.number.toString().startsWith(q);
    }).toList();
    setState(() => _filteredSurahs = filtered);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
    if (!_isPremium) return _buildPremiumLockScreen();
    return _buildAccessScreen();
  }

  Widget _buildPremiumLockScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ProCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                ),
                child: const Icon(Icons.mic, color: Color(0xFF4A90E2), size: 60),
              ),
              const SizedBox(height: 24),
              const Text('🎙️ اقرأ معي', style: TextStyle(color: Color(0xFF4A90E2), fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
              const SizedBox(height: 12),
              const Text('استمع للقارئ مع تظليل الكلمات\nسجّل تلاوتك واحصل على تصحيح فوري\nجميع سور القرآن (114 سورة)\nمثالية لتعليم الأطفال والأجانب',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.8)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(_remainingReadWithMe > 0 ? '🎁 تجربة مجانية: $_remainingReadWithMe محاولات' : '🔒 انتهت التجربة المجانية',
                      style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_remainingReadWithMe > 0 ? 'جرّب الميزة مجاناً ثم اشترك للاستخدام غير المحدود' : 'عاود غداً لتجربة جديدة أو اشترك الآن',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_remainingReadWithMe > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadWithMeScreen(surahNumber: 1))).then((_) => _checkPremium());
                  },
                  icon: const Icon(Icons.play_arrow, size: 22),
                  label: const Text('🎁 ابدأ التجربة المجانية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ProCard(
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF4A90E2), size: 20),
                const SizedBox(width: 8),
                const Text('Premium مُفعّل', style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.menu_book, color: Color(0xFF4A90E2), size: 18),
                const SizedBox(width: 4),
                const Text('114 سورة', style: TextStyle(color: Color(0xFF4A90E2), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _searchController,
              onChanged: _filterSurahs,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '🔍 ابحث عن سورة...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingSurahs
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
              : _filteredSurahs.isEmpty
                  ? const Center(child: Text('❌ لا توجد نتائج', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSurahs.length,
                      itemBuilder: (context, index) => _buildSurahCard(_filteredSurahs[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildSurahCard(SurahModel surah) {
    final isMeccan = surah.revelationType == 'Meccan';
    return ProCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReadWithMeScreen(surahNumber: surah.number))).then((_) => _checkPremium());
        },
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF4A90E2), width: 1.5),
          ),
          child: Center(child: Text('${surah.number}', style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri'))),
        ),
        title: Text(surah.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (isMeccan ? Colors.orange : Colors.green).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(isMeccan ? 'مكية' : 'مدنية', style: TextStyle(color: isMeccan ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text('${surah.numberOfAyahs} آية', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF4A90E2), size: 16),
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  final bool isArabic;
  const _ChatTab({required this.isArabic});
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  int _remainingChats = 3;
  List<Map<String, dynamic>> _savedConversations = [];
  static const String _historyKey = 'chat_history_v1';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadHistory();
  }

  @override
  void dispose() {
    _saveCurrentChat();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final remaining = await UsageService.remainingChats();
    if (!mounted) return;
    setState(() => _remainingChats = remaining);
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey) ?? '[]';
      final list = jsonDecode(raw) as List;
      if (!mounted) return;
      setState(() => _savedConversations = list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {}
  }

  Future<void> _saveCurrentChat() async {
    if (_messages.isEmpty) return;
    try {
      final now = DateTime.now();
      final firstText = _messages.first['text'] ?? 'محادثة';
      final title = firstText.length > 50 ? '${firstText.substring(0, 50)}...' : firstText;
      final entry = {
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'title': title,
        'messages': _messages.map((m) => Map<String, String>.from(m)).toList(),
      };
      _savedConversations.removeWhere((c) => c['title'] == title);
      _savedConversations.insert(0, entry);
      if (_savedConversations.length > 20) _savedConversations = _savedConversations.sublist(0, 20);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_savedConversations));
    } catch (e) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    final canChat = await UsageService.canChat();
    if (!canChat) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();
    final reply = await FirebaseAiService.askQuestion(text);
    final remaining = await UsageService.remainingChats();
    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'assistant', 'text': reply});
      _isLoading = false;
      _remainingChats = remaining;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0B132B).withValues(alpha: 0.5),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Color(0xFF4A90E2), size: 16),
              const SizedBox(width: 6),
              Text('متبقي: $_remainingChats سؤال', style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 12)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.add_comment, color: Color(0xFF4A90E2), size: 20), onPressed: () => setState(() => _messages.clear())),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.smart_toy, color: Color(0xFF4A90E2), size: 60),
                      const SizedBox(height: 16),
                      Text(widget.isArabic ? '👋 اسأل المرشد أي سؤال ديني' : '👋 Ask Al-Murshid', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final isUser = m['role'] == 'user';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        child: ProCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            m['text']!,
                            style: TextStyle(color: isUser ? Colors.white : const Color(0xFF4A90E2), fontSize: 15, height: 1.6, fontFamily: isUser ? null : 'Amiri'),
                            textAlign: isUser ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF4A90E2), strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(widget.isArabic ? 'المرشد يكتب...' : 'Al-Murshid is typing...', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.8),
            border: Border(top: BorderSide(color: const Color(0xFF4A90E2).withValues(alpha: 0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: ProCard(
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white), // ✅ إصلاح: جعل النص أبيض ليكون مرئياً
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: widget.isArabic ? 'اكتب سؤالك هنا...' : 'Type your question...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
