import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../library/models/book_model.dart';
import '../../library/services/library_service.dart';

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  List<HadithModel> _hadiths = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadHadiths();
  }

  Future<void> _loadHadiths() async {
    setState(() => _isLoading = true);
    final hadiths = await LibraryService.fetchHadiths(
      bookId: widget.book.id,
      start: _currentPage,
      limit: _limit,
    );
    setState(() {
      _hadiths = hadiths;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() {
      _currentPage++;
      _isLoading = true;
    });
    final moreHadiths = await LibraryService.fetchHadiths(
      bookId: widget.book.id,
      start: _currentPage,
      limit: _limit,
    );
    setState(() {
      _hadiths.addAll(moreHadiths);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
            ),
            Text(
              widget.book.author,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
      body: _isLoading && _hadiths.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : Column(
              children: [
                // معلومات الكتاب
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✍️ ${widget.book.author}',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.book.description,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          _buildStatChip('📚', '${widget.book.chapters} باب'),
                          const SizedBox(height: 4),
                          _buildStatChip('📖', '${widget.book.hadithCount} حديث'),
                        ],
                      ),
                    ],
                  ),
                ),
                // قائمة الأحاديث
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _hadiths.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _hadiths.length) {
                        return _buildLoadMoreButton();
                      }
                      final hadith = _hadiths[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              hadith.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'رقم: ${hadith.number}',
                                    style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (hadith.grade != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: hadith.grade == 'صحيح'
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: hadith.grade == 'صحيح'
                                            ? Colors.green
                                            : Colors.orange,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      hadith.grade!,
                                      style: TextStyle(
                                        color: hadith.grade == 'صحيح'
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
            ),
    );
  }

  Widget _buildStatChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Text(
        '$icon $label',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }
    return Center(
      child: TextButton(
        onPressed: _loadMore,
        child: const Text(
          'تحميل المزيد',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
      ),
    );
  }
}
