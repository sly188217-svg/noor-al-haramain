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
}
