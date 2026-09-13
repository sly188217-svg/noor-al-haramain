class HadithModel {
  final int number;
  final String text;
  final String? narrator;
  final String? grade;
  final String? bookName;

  HadithModel({
    required this.number,
    required this.text,
    this.narrator,
    this.grade,
    this.bookName,
  });

  /// ✅ JSON → HadithModel
  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      number: json['number'] is int
          ? json['number']
          : int.tryParse(json['number']?.toString() ?? '0') ?? 0,
      text: json['text']?.toString() ??
          json['hadith']?.toString() ??
          json['arabic']?.toString() ??
          '',
      narrator: json['narrator']?.toString() ??
          json['rawi']?.toString() ??
          json['narratorName']?.toString(),
      grade: json['grade']?.toString() ??
          json['rank']?.toString() ??
          json['sahih']?.toString(),
      bookName: json['bookName']?.toString() ?? json['book']?.toString(),
    );
  }

  /// ✅ HadithModel → JSON
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'text': text,
      'narrator': narrator,
      'grade': grade,
      'bookName': bookName,
    };
  }
}
