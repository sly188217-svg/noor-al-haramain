import 'ayah_model.dart';

class SurahModel {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;
  final List<AyahModel>? ayahs;

  SurahModel({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
    this.ayahs,
  });

  /// ✅ getter محسوب لعدد الآيات (في حال كان الحقل 0)
  int get ayahCount {
    if (numberOfAyahs > 0) return numberOfAyahs;
    return ayahs?.length ?? 0;
  }

  /// ✅ getter لعرض نوع السورة بالعربية
  String get revelationTypeAr {
    if (revelationType == 'Meccan') return 'مكية';
    if (revelationType == 'Medinan') return 'مدنية';
    return revelationType.isNotEmpty ? revelationType : '—';
  }

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    final ayahsList = json['ayahs'] != null
        ? (json['ayahs'] as List)
            .map((a) => AyahModel.fromJson(a))
            .toList()
        : <AyahModel>[];

    // ✅ إذا numberOfAyahs مفقود، نأخذ عدد الآيات من القائمة
    final numberOfAyahsRaw =
        (json['numberOfAyahs'] as num?)?.toInt() ?? 0;
    final finalNumberOfAyahs =
        numberOfAyahsRaw > 0 ? numberOfAyahsRaw : ayahsList.length;

    return SurahModel(
      number: (json['number'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      englishName: json['englishName']?.toString() ?? '',
      englishNameTranslation:
          json['englishNameTranslation']?.toString() ?? '',
      numberOfAyahs: finalNumberOfAyahs,
      revelationType: json['revelationType']?.toString() ?? '',
      ayahs: ayahsList,
    );
  }
}
