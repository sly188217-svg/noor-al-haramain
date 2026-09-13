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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Column(
        children: [
          // شريط البحث والتصفية
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
                      _buildCategoryChip('الكل', 'all'),
                      _buildCategoryChip('الحديث', 'الحديث'),
                      _buildCategoryChip('التفسير', 'التفسير'),
                      _buildCategoryChip('الفقه', 'الفقه'),
                      _buildCategoryChip('السيرة', 'السيرة'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // إحصائيات
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📚 ${_filteredBooks.length} كتاب',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '📖 ${_filteredBooks.fold<int>(0, (sum, b) => sum + b.hadithCount)} حديث',
                  style: const TextStyle(
                      color: Color(0xFFD4AF37), fontSize: 12),
                ),
              ],
            ),
          ),

          // قائمة الكتب
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

  Widget _buildBookCard(BookModel book) {
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
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.menu_book,
                      color: Color(0xFFD4AF37),
                      size: 28,
                    ),
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
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '📚 ${book.hadithCount} حديث • ${book.chapters} باب',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
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

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? const Color(0xFF0B132B) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                color: Colors.grey, size: 60),
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
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                    _filteredBooks = _allBooks;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text('مسح الفلاتر'),
              ),
          ],
        ),
      ),
    );
  }
}
