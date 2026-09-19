import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/firebase_ai_service.dart';
import '../../../core/services/usage_service.dart';
import '../../recitation/recitation_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// تبويب المساعد الذكي — المرشد
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
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: [
            Tab(text: isArabic ? '📖 تلاوة وتصحيح' : '📖 Recite'),
            Tab(text: isArabic ? '💬 محادثة' : '💬 Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const RecitationScreen(),
          _ChatTab(isArabic: isArabic),
        ],
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
  int _remainingChats = 5;
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
        _savedConversations = list
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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
    setState(() {
      _messages.clear();
    });
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
    setState(() {
      _savedConversations.removeAt(index);
    });
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
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'لا يوجد سجل بعد',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
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
                style:
                    TextStyle(color: Color(0xFFD4AF37), fontSize: 18)),
          ],
        ),
        content: const Text(
          'لقد استخدمت 5 أسئلة مجانية اليوم.\n⏰ يمكنك المحاولة مجدداً غداً.',
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
