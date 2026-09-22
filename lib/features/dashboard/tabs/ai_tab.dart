import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/firebase_ai_service.dart';
import '../../../core/services/usage_service.dart';
import '../../recitation/recitation_screen.dart';
import '../../quran/read_with_me_screen.dart';
import '../../quran/services/quran_service.dart';
import '../../quran/models/surah_model.dart';

/// ═══════════════════════════════════════════════════════════
/// تبويب المساعد الذكي — المرشد + اقرأ معي
/// ═══════════════════════════════════════════════════════════
class AiTab extends StatefulWidget {
  const AiTab({super.key});

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab>
    with SingleTickerProviderStateMixin {
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
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'المساعد الذكي "المرشد"' : 'Al-Murshid Assistant',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
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

/// ═══════════════════════════════════════════════════════════
/// تبويب اقرأ معي — جميع السور 114
/// ═══════════════════════════════════════════════════════════
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
    if (!mounted) return;
    setState(() {
      _isPremium = premium;
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
      return s.name.contains(q) ||
          s.number.toString() == q ||
          s.number.toString().startsWith(q);
    }).toList();

    setState(() => _filteredSurahs = filtered);
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.star, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text(
              'ميزة Premium',
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          '🎙️ "اقرأ معي" متاحة للمشتركين فقط.\n\n'
          '✨ استمع للقارئ مع تظليل الكلمات\n'
          '✨ سجّل تلاوتك واحصل على تصحيح فوري\n'
          '✨ جميع سور القرآن (114 سورة)\n'
          '✨ تتبّع تقدمك في الحفظ\n'
          '✨ مثالية لتعليم الأطفال\n\n'
          '💎 اشترك الآن بـ \$2.99/شهر\n'
          'أو \$22.99/سنة (وفّر 36%)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _activatePremiumForTesting();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('💎 اشترك الآن'),
          ),
        ],
      ),
    );
  }

  Future<void> _activatePremiumForTesting() async {
    await UsageService.activatePremium();
    if (!mounted) return;
    setState(() => _isPremium = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم تفعيل Premium (وضع الاختبار)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }

    if (!_isPremium) {
      return _buildPremiumLockScreen();
    }

    return _buildAccessScreen();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔒 شاشة القفل
  // ═══════════════════════════════════════════════════════════
  Widget _buildPremiumLockScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              ),
              child: const Icon(
                Icons.mic,
                color: Color(0xFFD4AF37),
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🎙️ اقرأ معي',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'استمع للقارئ مع تظليل الكلمات\n'
              'سجّل تلاوتك واحصل على تصحيح فوري\n'
              'جميع سور القرآن (114 سورة)\n'
              'مثالية لتعليم الأطفال والأجانب',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    '💎 اشترك الآن',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '\$2.99 / شهر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'أو \$22.99 / سنة (وفّر 36%)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showPremiumDialog,
              icon: const Icon(Icons.star),
              label: const Text(
                '💎 اشترك الآن',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _activatePremiumForTesting,
              child: const Text(
                '🎁 تجربة مجانية',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ شاشة الوصول — جميع السور 114
  // ═══════════════════════════════════════════════════════════
  Widget _buildAccessScreen() {
    return Column(
      children: [
        // شريط Premium
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: 0.2),
                const Color(0xFFD4AF37).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37)),
          ),
          child: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
              SizedBox(width: 8),
              Text(
                'Premium مُفعّل',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.menu_book, color: Color(0xFFD4AF37), size: 18),
              SizedBox(width: 4),
              Text(
                '114 سورة',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // شريط البحث
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            onChanged: _filterSurahs,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '🔍 ابحث عن سورة...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFFD4AF37)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Color(0xFFD4AF37)),
                      onPressed: () {
                        _searchController.clear();
                        _filterSurahs('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1C2541).withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // قائمة السور
        Expanded(
          child: _isLoadingSurahs
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFD4AF37)))
              : _filteredSurahs.isEmpty
                  ? const Center(
                      child: Text(
                        '❌ لا توجد نتائج',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredSurahs.length,
                      itemBuilder: (context, index) {
                        return _buildSurahCard(_filteredSurahs[index]);
                      },
                    ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بطاقة السورة
  // ═══════════════════════════════════════════════════════════
  Widget _buildSurahCard(SurahModel surah) {
    final isMeccan = surah.revelationType == 'Meccan';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSurah(surah.number),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // رقم السورة في شكل زخرفي
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${surah.number}',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // اسم السورة + معلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isMeccan
                                      ? Colors.orange
                                      : Colors.green)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMeccan ? 'مكية' : 'مدنية',
                              style: TextStyle(
                                color: isMeccan
                                    ? Colors.orange
                                    : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${surah.numberOfAyahs} آية',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // سهم
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFD4AF37),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSurah(int surahNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadWithMeScreen(surahNumber: surahNumber),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// تبويب المحادثة الذكية — مع سجل المحادثات
/// ═══════════════════════════════════════════════════════════
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
  bool _isPremium = false;
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
    try {
      final premium = await UsageService.isPremium();
      final remaining = await UsageService.remainingChats();
      if (!mounted) return;
      setState(() {
        _isPremium = premium;
        _remainingChats = remaining;
      });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey) ?? '[]';
      final list = jsonDecode(raw) as List;
      if (!mounted) return;
      setState(() {
        _savedConversations =
            list.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      debugPrint('⚠️ فشل تحميل السجل: $e');
    }
  }

  Future<void> _saveCurrentChat() async {
    if (_messages.isEmpty) return;
    try {
      final now = DateTime.now();
      final firstText = _messages.first['text'] ?? 'محادثة';
      final title = firstText.length > 50
          ? '${firstText.substring(0, 50)}...'
          : firstText;

      final entry = {
        'date':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'title': title,
        'messages':
            _messages.map((m) => Map<String, String>.from(m)).toList(),
      };

      _savedConversations.removeWhere((c) => c['title'] == title);
      _savedConversations.insert(0, entry);
      if (_savedConversations.length > 20) {
        _savedConversations = _savedConversations.sublist(0, 20);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_savedConversations));
    } catch (e) {
      debugPrint('⚠️ فشل حفظ السجل: $e');
    }
  }

  void _newChat() {
    _saveCurrentChat();
    setState(() => _messages.clear());
  }

  void _openConversation(Map<String, dynamic> conv) {
    _saveCurrentChat();
    setState(() {
      _messages.clear();
      final msgs = conv['messages'] as List? ?? [];
      for (final m in msgs) {
        _messages.add(Map<String, String>.from(m));
      }
    });
    _scrollToBottom();
  }

  Future<void> _deleteConversation(int index) async {
    setState(() => _savedConversations.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_savedConversations));
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1C2541),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '📚 سجل المحادثات',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _savedConversations.isEmpty
                  ? const Center(
                      child: Text(
                        'لا يوجد سجل بعد',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _savedConversations.length,
                      itemBuilder: (context, index) {
                        final c = _savedConversations[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2541)
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.chat,
                                color: Color(0xFFD4AF37)),
                            title: Text(
                              c['title'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              c['date'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 18),
                              onPressed: () async {
                                await _deleteConversation(index);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _showHistory();
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _openConversation(c);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final canChat = await UsageService.canChat();
    if (!canChat) {
      _showLimitDialog();
      return;
    }

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

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text('انتهى الحد اليومي',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18)),
          ],
        ),
        content: const Text(
          'لقد استخدمت 3 أسئلة مجانية اليوم.\n⏰ يمكنك المحاولة مجدداً غداً.',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF0B132B),
          child: Row(
            children: [
              Icon(
                _isPremium ? Icons.star : Icons.chat_bubble_outline,
                color: const Color(0xFFD4AF37),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _isPremium
                    ? 'Premium — غير محدود'
                    : 'متبقي: $_remainingChats سؤال',
                style: const TextStyle(
                    color: Color(0xFFD4AF37), fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.history,
                    color: Color(0xFFD4AF37), size: 20),
                onPressed: _showHistory,
                tooltip: 'السجل',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.add_comment,
                    color: Color(0xFFD4AF37), size: 20),
                onPressed: _newChat,
                tooltip: 'محادثة جديدة',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
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
                        widget.isArabic
                            ? '👋 اسأل المرشد أي سؤال ديني'
                            : '👋 Ask Al-Murshid',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final isUser = m['role'] == 'user';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(colors: [
                                  Color(0xFF1C2541),
                                  Color(0xFF0B132B)
                                ])
                              : const LinearGradient(colors: [
                                  Color(0xFFD4AF37),
                                  Color(0xFFB8860B)
                                ]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                            bottomRight: isUser
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          m['text']!,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black,
                            fontSize: 15,
                            height: 1.6,
                            fontFamily: isUser ? null : 'Amiri',
                          ),
                          textAlign:
                              isUser ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isLoading)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Color(0xFFD4AF37), strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isArabic
                      ? 'المرشد يكتب...'
                      : 'Al-Murshid is typing...',
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
              top: BorderSide(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: widget.isArabic
                        ? 'اكتب سؤالك هنا...'
                        : 'Type your question...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send,
                      color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
