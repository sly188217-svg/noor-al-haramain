class AyahModel {
  final int number;          // الرقم العالمي (1-6236)
  final int numberInSurah;   // ✅ الرقم داخل السورة (1-7، 1-286...)
  final String text;
  final String? translation;
  final int? page;
  final int? juz;

  AyahModel({
    required this.number,
    required this.numberInSurah,
    required this.text,
    this.translation,
    this.page,
    this.juz,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json) {
    return AyahModel(
      number: (json['number'] as num?)?.toInt() ?? 0,
      // ✅ نأخذ numberInSurah، وإن لم يوجد نستخدم number
      numberInSurah: (json['numberInSurah'] as num?)?.toInt() ??
          (json['number'] as num?)?.toInt() ??
          0,
      text: json['text']?.toString() ?? '',
      translation: json['translation']?.toString() ??
          json['translation']?['text']?.toString(),
      page: (json['page'] as num?)?.toInt(),
      juz: (json['juz'] as num?)?.toInt(),
    );
  }
}
