import 'package:flutter/material.dart';
import '../../library/models/book_model.dart';
import '../../library/services/library_service.dart';
import 'library_book_detail.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<BookModel> _allBooks = [];
  List<BookModel> _filteredBooks = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    final books = LibraryService.getBooks();
    if (!mounted) return;
    setState(() {
      _allBooks = books;
      _filteredBooks = books;
    });
  }

  void _filterBooks(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredBooks = _allBooks.where((book) {
      final matchesQuery = _searchQuery.isEmpty ||
          book.title.contains(_searchQuery) ||
          book.author.contains(_searchQuery) ||
          book.description.contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'all' || book.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// ✅ عدد الكتب في كل فئة
  int _countByCategory(String category) {
    if (category == 'all') return _allBooks.length;
    return _allBooks.where((b) => b.category == category).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════
          // شريط البحث والتصفية
          // ═══════════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1C2541),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: _filterBooks,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '🔍 ابحث عن كتاب، مؤلف، أو موضوع...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFFD4AF37)),
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                          '📚 الكل', 'all', _countByCategory('all')),
                      _buildCategoryChip(
                          '📖 الحديث', 'الحديث', _countByCategory('الحديث')),
                      _buildCategoryChip(
                          '📖 التفسير', 'التفسير', _countByCategory('التفسير')),
                      _buildCategoryChip(
                          '⚖️ الفقه', 'الفقه', _countByCategory('الفقه')),
                      _buildCategoryChip(
                          '🕌 السيرة', 'السيرة', _countByCategory('السيرة')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════════
          // إحصائيات
          // ═══════════════════════════════════════════════════════
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📚 ${_filteredBooks.length} كتاب',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _selectedCategory == 'all'
                      ? '📂 كل الفئات'
                      : '📂 $_selectedCategory',
                  style: const TextStyle(
                      color: Color(0xFFD4AF37), fontSize: 12),
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════════
          // قائمة الكتب
          // ═══════════════════════════════════════════════════════
          Expanded(
            child: _filteredBooks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      return _buildBookCard(_filteredBooks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بطاقة الكتاب
  // ═══════════════════════════════════════════════════════════
  Widget _buildBookCard(BookModel book) {
    // ✅ أيقونة مختلفة لكل فئة
    IconData icon;
    Color iconColor;

    switch (book.category) {
      case 'الحديث':
        icon = Icons.menu_book;
        iconColor = const Color(0xFFD4AF37);
        break;
      case 'التفسير':
        icon = Icons.auto_stories;
        iconColor = Colors.lightBlue;
        break;
      case 'الفقه':
        icon = Icons.gavel;
        iconColor = Colors.green;
        break;
      case 'السيرة':
        icon = Icons.history_edu;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.book;
        iconColor = const Color(0xFFD4AF37);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(book: book),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // غلاف الكتاب
                Container(
                  width: 50,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                ),
                const SizedBox(width: 12),

                // تفاصيل الكتاب
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '✍️ ${book.author}',
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _buildBookMeta(book),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.category,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// نص فرعي حسب الفئة
  String _buildBookMeta(BookModel book) {
    switch (book.category) {
      case 'الحديث':
        return '📖 ${book.hadithCount} حديث • 📚 ${book.chapters} باب';
      case 'التفسير':
        return '📖 تفسير كامل للقرآن';
      case 'الفقه':
        return '⚖️ كتاب فقهي';
      case 'السيرة':
        return '🕌 سيرة نبوية';
      default:
        return '';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Chip الفئة
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryChip(String label, String value, int count) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? const Color(0xFF0B132B) : Colors.white70,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0B132B).withValues(alpha: 0.2)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0B132B)
                        : const Color(0xFFD4AF37),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF0B132B),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFD4AF37)
              : Colors.white12,
        ),
        onSelected: (selected) {
          if (!mounted) return;
          if (selected) _filterByCategory(value);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // الحالة الفارغة
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد كتب في هذه الفئة'
                  : 'لا نتائج لـ "$_searchQuery"',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isNotEmpty || _selectedCategory != 'all')
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                    _filteredBooks = _allBooks;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('مسح الفلاتر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
