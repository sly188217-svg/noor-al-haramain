class AyahModel {
  final int number;
  final String text;
  final String? translation;
  final int? page;
  final int? juz;

  AyahModel({
    required this.number,
    required this.text,
    this.translation,
    this.page,
    this.juz,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json) {
    return AyahModel(
      number: json['number'] ?? 0,
      text: json['text'] ?? '',
      translation: json['translation'] ?? json['translation']?['text'],
      page: json['page'],
      juz: json['juz'],
    );
  }
}
