import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'services/kids_stories_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 📚 شاشة مكتبة القصص للأطفال
/// ✅ تحميل من الإنترنت
/// ✅ TTS للقراءة الصوتية
/// ✅ بحث وتصنيفات
/// ✅ آمنة على Linux (TTS لا يعمل، لكن لا ينهار)
/// ═══════════════════════════════════════════════════════════
class KidsStoriesScreen extends StatefulWidget {
  const KidsStoriesScreen({super.key});

  @override
  State<KidsStoriesScreen> createState() => _KidsStoriesScreenState();
}

class _KidsStoriesScreenState extends State<KidsStoriesScreen> {
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = true;
  bool _isSpeaking = false;
  bool _ttsAvailable = false;
  bool _hasError = false;
  String _errorMsg = '';
  String _selectedCategory = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _allStories = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _activeStory;
  double _speechRate = 0.4;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadStories();
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (e) {}
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 تهيئة TTS (آمنة)
  // ═══════════════════════════════════════════════════════════
  Future<void> _initTts() async {
    try {
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
      if (mounted) setState(() => _ttsAvailable = true);
      debugPrint('✅ TTS متاح');
    } catch (e) {
      debugPrint('⚠️ TTS غير متاح (طبيعي على Linux): $e');
      if (mounted) setState(() => _ttsAvailable = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 تحميل القصص
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadStories({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMsg = '';
    });

    try {
      final data = await KidsStoriesService.loadStories(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _allStories = List<Map<String, dynamic>>.from(data['stories'] ?? []);
        _categories =
            List<Map<String, dynamic>>.from(data['categories'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ فشل تحميل القصص: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg =
            'تعذر تحميل القصص. تأكد من اتصالك بالإنترنت وحاول مرة أخرى.';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 فلترة القصص
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStories {
    return _allStories.where((s) {
      final cat = _selectedCategory;
      final matchCat = cat == 'all' || s['category'] == cat;
      final q = _searchQuery.trim();
      final matchSearch = q.isEmpty ||
          (s['title'] ?? '').toString().contains(q) ||
          (s['text'] ?? '').toString().contains(q);
      return matchCat && matchSearch;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔊 تشغيل / إيقاف القراءة
  // ═══════════════════════════════════════════════════════════
  Future<void> _speakStory() async {
    if (_activeStory == null) return;

    if (!_ttsAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔊 القراءة الصوتية متاحة على الهاتف فقط'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_isSpeaking) {
      try {
        await _tts.stop();
      } catch (e) {}
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    try {
      await _tts.speak(_activeStory!['text'].toString());
    } catch (e) {
      debugPrint('⚠️ فشل TTS: $e');
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _openStory(Map<String, dynamic> story) {
    setState(() {
      _activeStory = story;
      _isSpeaking = false;
    });
    try {
      _tts.stop();
    } catch (e) {}
  }

  void _closeStory() {
    try {
      _tts.stop();
    } catch (e) {}
    setState(() {
      _activeStory = null;
      _isSpeaking = false;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 بناء الواجهة
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: Row(
          children: [
            const Text('🧒', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              _activeStory == null ? 'مكتبة القصص' : 'القصة',
              style: const TextStyle(color: Color(0xFFD4AF37)),
            ),
            if (_activeStory == null && _allStories.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '(${_allStories.length})',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        leading: _activeStory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeStory,
              )
            : null,
        actions: _activeStory == null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث القصص',
                  onPressed: () => _loadStories(force: true),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? _buildLoading()
          : _hasError
              ? _buildError()
              : _activeStory == null
                  ? _buildLibrary()
                  : _buildReader(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ حالة التحميل
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFD4AF37)),
          SizedBox(height: 16),
          Text(
            '📚 جاري تحميل القصص...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ❌ حالة الخطأ
  // ═══════════════════════════════════════════════════════════
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 80),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadStories(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📚 المكتبة الرئيسية
  // ═══════════════════════════════════════════════════════════
  Widget _buildLibrary() {
    return Column(
      children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '🔍 ابحث عن قصة...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFFD4AF37)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1C2541),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // التصنيفات
        SizedBox(
          height: 45,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildCategoryChip('all', 'الكل', '📚'),
              ..._categories.map(
                  (c) => _buildCategoryChip(c['id'], c['name'], c['emoji'])),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // عدد القصص
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '📖 ${_filteredStories.length} قصة',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // قائمة القصص
        Expanded(
          child: _filteredStories.isEmpty
              ? const Center(
                  child: Text('لا توجد قصص',
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredStories.length,
                  itemBuilder: (context, index) {
                    final story = _filteredStories[index];
                    final cat = _categories.firstWhere(
                      (c) => c['id'] == story['category'],
                      orElse: () => {'name': '', 'emoji': ''},
                    );
                    return _buildStoryCard(story, cat);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String id, String name, String emoji) {
    final isActive = _selectedCategory == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? const Color(0xFFD4AF37) : const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
          ),
        ),
        child: Center(
          child: Text(
            '$emoji $name',
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(
      Map<String, dynamic> story, Map<String, dynamic> cat) {
    final text = (story['text'] ?? '').toString();
    final preview =
        text.length > 100 ? '${text.substring(0, 100)}...' : text;

    return GestureDetector(
      onTap: () => _openStory(story),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C2541), Color(0xFF0F1A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Text(story['emoji'] ?? '📖',
                style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${cat['emoji']} ${cat['name']}',
                        style: const TextStyle(
                            color: Color(0xFFD4AF37), fontSize: 10),
                      ),
                      if (story['duration'] != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time,
                            color: Colors.white38, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          story['duration'].toString(),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFFD4AF37), size: 14),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 قارئ القصة
  // ═══════════════════════════════════════════════════════════
  Widget _buildReader() {
    final story = _activeStory!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                        story['emoji'] ?? '📖',
                        style: const TextStyle(fontSize: 60),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      story['title'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (story['duration'] != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⏱️ ${story['duration']}',
                            style: const TextStyle(
                                color: Color(0xFFD4AF37), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 30),
                    Text(
                      story['text'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _speakStory,
              icon: Icon(
                _isSpeaking ? Icons.stop : Icons.volume_up,
                size: 22,
              ),
              label: Text(
                _isSpeaking ? '⏹ إيقاف القراءة' : '🔊 استمع للقصة',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSpeaking ? Colors.red : const Color(0xFFD4AF37),
                foregroundColor:
                    _isSpeaking ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🐢', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.2,
                  max: 0.8,
                  divisions: 6,
                  activeColor: const Color(0xFFD4AF37),
                  label: _speechRate.toStringAsFixed(1),
                  onChanged: _ttsAvailable
                      ? (v) async {
                          setState(() => _speechRate = v);
                          try {
                            await _tts.setSpeechRate(v);
                          } catch (e) {}
                        }
                      : null,
                ),
              ),
              const Text('🐇', style: TextStyle(fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}
