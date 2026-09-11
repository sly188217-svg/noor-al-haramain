import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/language_provider.dart';
import '../../library/models/book_model.dart';

/// عرض كتب السلف والأحاديث النبوية من API (دورر للحديث)
/// جميع البيانات تُجلب من الإنترنت، ولا توجد بيانات ثابتة في الكود
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<BookModel> _books = [];
  List<BookModel> _filteredBooks = [];
  bool _isLoading = false;
  bool _isLoadingHadiths = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // بيانات الأحاديث المؤقتة
  List<Map<String, dynamic>> _hadiths = [];
  String? _selectedBookName;
  int _currentPage = 1;
  int _totalHadiths = 0;
  bool _hasMoreHadiths = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  // ===================================================
  // 1. جلب الكتب من API
  // ===================================================
  Future<void> _loadBooks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final booksData = await _fetchBooksFromApi();
      
      if (booksData.isNotEmpty) {
        final List<BookModel> loadedBooks = booksData.map((item) {
          return BookModel(
            id: item['id']?.toString() ?? '',
            title: item['title'] ?? 'بدون عنوان',
            author: item['author'] ?? 'مجهول',
            category: item['category'] ?? 'الحديث',
            description: item['description'] ?? '',
            chapters: int.tryParse(item['chapters']?.toString() ?? '0') ?? 0,
            hadithCount: int.tryParse(item['hadithCount']?.toString() ?? '0') ?? 0,
            coverImage: item['coverImage']?.toString(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _books = loadedBooks;
            _filteredBooks = loadedBooks;
            _isLoading = false;
          });
        }
      } else {
        // إذا لم يتم جلب أي بيانات من API
        if (mounted) {
          setState(() {
            _errorMessage = '⚠️ لا توجد كتب متاحة حالياً. تأكد من اتصالك بالإنترنت.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '⚠️ فشل تحميل الكتب: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ===================================================
  // 2. جلب الكتب من API (دورر للحديث)
  // ===================================================
  Future<List<Map<String, dynamic>>> _fetchBooksFromApi() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.dorar.net/hadith/books'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('⚠️ فشل جلب الكتب من API: $e');
      return [];
    }
  }

  // ===================================================
  // 3. جلب أحاديث كتاب معين من API (مع Pagination)
  // ===================================================
  Future<void> _loadHadiths(String bookId, String bookName, {bool loadMore = false}) async {
    if (_isLoadingHadiths) return;
    if (!loadMore) {
      // بداية تحميل جديد
      _currentPage = 1;
      _hadiths = [];
      _hasMoreHadiths = true;
      if (mounted) {
        setState(() {
          _isLoadingHadiths = true;
          _selectedBookName = bookName;
        });
      }
    } else {
      if (!_hasMoreHadiths) return;
      setState(() => _isLoadingHadiths = true);
    }

    try {
      final apiId = await _getBookApiId(bookId);
      final hadithsData = await _fetchHadithsFromApi(apiId, _currentPage);

      if (mounted) {
        setState(() {
          _hadiths = [..._hadiths, ...hadithsData];
          _isLoadingHadiths = false;
          _currentPage++;
          _hasMoreHadiths = hadithsData.length >= 20;
        });
        
        if (!loadMore) {
          _showHadithsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHadiths = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ فشل تحميل الأحاديث: $e')),
        );
      }
    }
  }

  // ===================================================
  // 4. جلب معرف الكتاب من API (إذا كان مختلفاً)
  // ===================================================
  Future<String> _getBookApiId(String bookId) async {
    // إذا كان المعرف هو نفسه المعرف في API، نعيده
    // وإلا نبحث عن المعرف الصحيح من الخادم
    try {
      final response = await http.get(
        Uri.parse('https://api.dorar.net/hadith/books'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          final books = List<Map<String, dynamic>>.from(data['data']);
          final found = books.firstWhere(
            (b) => b['id'].toString() == bookId || b['title'] == bookId,
            orElse: () => books.first,
          );
          return found['id'].toString();
        }
      }
    } catch (e) {
      print('⚠️ فشل جلب معرف الكتاب: $e');
    }
    return bookId;
  }

  // ===================================================
  // 5. جلب الأحاديث من API
  // ===================================================
  Future<List<Map<String, dynamic>>> _fetchHadithsFromApi(String bookId, int page) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.dorar.net/hadith/books/$bookId/hadiths?limit=20&page=$page'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final hadiths = data['data']['hadiths'] ?? data['data'];
          _totalHadiths = data['data']['total'] ?? 0;
          if (hadiths is List) {
            return hadiths.map((h) {
              return {
                'text': h['text'] ?? h['arabic'] ?? '',
                'grade': h['grade'] ?? h['status'] ?? '',
                'narrator': h['narrator'] ?? '',
                'number': h['number'] ?? h['id'] ?? 0,
              };
            }).toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('⚠️ فشل جلب الأحاديث من API: $e');
      return [];
    }
  }

  // ===================================================
  // 6. عرض الأحاديث في نافذة منبثقة مع إمكانية التحميل
  // ===================================================
  void _showHadithsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C2541),
            title: Text(
              '📖 أحاديث $_selectedBookName',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: _hadiths.isEmpty && _isLoadingHadiths
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: _hadiths.length + (_hasMoreHadiths ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _hadiths.length) {
                                // زر تحميل المزيد
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton(
                                      onPressed: _isLoadingHadiths
                                          ? null
                                          : () {
                                              _loadHadiths(
                                                '', 
                                                _selectedBookName!, 
                                                loadMore: true
                                              );
                                              setDialogState(() {});
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD4AF37),
                                        foregroundColor: Colors.black,
                                      ),
                                      child: _isLoadingHadiths
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : const Text('تحميل المزيد'),
                                    ),
                                  ),
                                );
                              }

                              final hadith = _hadiths[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B132B).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      hadith['text'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Amiri',
                                        height: 1.6,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (hadith['grade'] != null && hadith['grade'] != '')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: hadith['grade'] == 'صحيح'
                                                  ? Colors.green.withOpacity(0.2)
                                                  : Colors.orange.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: hadith['grade'] == 'صحيح'
                                                    ? Colors.green
                                                    : Colors.orange,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              hadith['grade']!,
                                              style: TextStyle(
                                                color: hadith['grade'] == 'صحيح'
                                                    ? Colors.green
                                                    : Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (hadith['narrator'] != null && hadith['narrator'] != '')
                                          Text(
                                            '👤 ${hadith['narrator']}',
                                            style: const TextStyle(
                                              color: Color(0xFFD4AF37),
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (hadith['number'] != null && hadith['number'] != 0)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '🔢 رقم الحديث: ${hadith['number']}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (_totalHadiths > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'إجمالي الأحاديث: $_totalHadiths',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===================================================
  // 7. البحث والفلترة
  // ===================================================
  void _filterBooks(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredBooks = _books;
      } else {
        _filteredBooks = _books.where((book) {
          return book.title.contains(query) ||
              book.author.contains(query) ||
              book.description.contains(query);
        }).toList();
      }
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'all') {
        _filteredBooks = _books;
      } else {
        _filteredBooks = _books.where((b) => b.category == category).toList();
      }
    });
  }

  // ===================================================
  // 8. واجهة المستخدم
  // ===================================================
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final isArabic = lang == 'ar';

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 16),
            Text('جاري تحميل المكتبة...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.library_books, color: Colors.grey, size: 60),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'لا توجد كتب متاحة حالياً'
                    : 'No books available at the moment',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadBooks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Column(
        children: [
          // شريط البحث والتصفية
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: _filterBooks,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isArabic
                        ? '🔍 ابحث عن كتاب، مؤلف، أو موضوع...'
                        : '🔍 Search for a book, author, or topic...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('الكل', 'all'),
                      _buildCategoryChip('الحديث', 'الحديث'),
                      _buildCategoryChip('التفسير', 'التفسير'),
                      _buildCategoryChip('الفقه', 'الفقه'),
                      _buildCategoryChip('العقيدة', 'العقيدة'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // إحصائيات
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📚 ${_filteredBooks.length} كتاب',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '📖 ${_filteredBooks.fold(0, (sum, b) => sum + b.hadithCount)} حديث',
                  style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
                ),
              ],
            ),
          ),
          // قائمة الكتب
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredBooks.length,
              itemBuilder: (context, index) {
                final book = _filteredBooks[index];
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 50,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B132B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            book.coverImage ?? '📖',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      title: Text(
                        book.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '✍️ ${book.author}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📚 ${book.hadithCount} حديث • ${book.chapters} باب',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white24,
                        size: 14,
                      ),
                      onTap: () => _loadHadiths(book.id, book.title),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
            color: isSelected ? const Color(0xFF0B132B) : Colors.white70,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF0B132B),
        onSelected: (selected) {
          if (!mounted) return;
          if (selected) {
            _filterByCategory(value);
          }
        },
      ),
    );
  }
}
