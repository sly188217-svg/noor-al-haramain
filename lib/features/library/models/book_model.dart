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
}
