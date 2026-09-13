class BookModel {
  final String id;
  final String title;
  final String author;
  final String category;
  final String description;
  final int chapters;
  final int hadithCount;
  final String? coverImage;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.chapters,
    required this.hadithCount,
    this.coverImage,
  });

  /// ✅ JSON → BookModel
  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      chapters: int.tryParse(json['chapters']?.toString() ?? '0') ?? 0,
      hadithCount:
          int.tryParse(json['hadithCount']?.toString() ?? '0') ?? 0,
      coverImage: json['coverImage']?.toString(),
    );
  }

  /// ✅ BookModel → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category,
      'description': description,
      'chapters': chapters,
      'hadithCount': hadithCount,
      'coverImage': coverImage,
    };
  }
}
