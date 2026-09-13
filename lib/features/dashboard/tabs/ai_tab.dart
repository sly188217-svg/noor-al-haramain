import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFF0B132B),
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
/// تبويب المحادثة الذكية
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

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // فحص الحد اليومي
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

    await UsageService.incrementChat();
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لقد استخدمت 5 أسئلة مجانية اليوم.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              '⏰ يمكنك المحاولة مجدداً غداً.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 16),
            Divider(color: Colors.white24),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                SizedBox(width: 8),
                Text(
                  'قريباً: نسخة Premium',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
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
        // شريط الحد اليومي
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    : 'متبقي: $_remainingChats سؤال اليوم',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 11,
                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child:
                      const Icon(Icons.send, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
