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

  /// ✅ يدعم fawazahmed0 API + formats أخرى
  factory HadithModel.fromJson(Map<String, dynamic> json) {
    // الرقم: 'hadithnumber' (fawazahmed0) أو 'number' أو 'id'
    final numRaw = json['hadithnumber'] ??
        json['number'] ??
        json['id'] ??
        json['hadithNumber'] ??
        0;
    final number = numRaw is int
        ? numRaw
        : int.tryParse(numRaw.toString()) ?? 0;

    // النص
    final text = json['text']?.toString() ??
        json['hadith']?.toString() ??
        json['arabic']?.toString() ??
        json['arabicText']?.toString() ??
        '';

    // الراوي
    final narrator = json['narrator']?.toString() ??
        json['rawi']?.toString() ??
        json['narratorName']?.toString();

    // الدرجة: grades (مصفوفة) أو grade أو rank
    String? grade;
    if (json['grades'] is List && (json['grades'] as List).isNotEmpty) {
      final first = (json['grades'] as List).first;
      if (first is Map) {
        grade = first['grade']?.toString() ?? first['name']?.toString();
      } else {
        grade = first.toString();
      }
    } else if (json['grade'] != null) {
      grade = json['grade'].toString();
    } else if (json['rank'] != null) {
      grade = json['rank'].toString();
    }

    // اسم الكتاب
    final bookName = json['bookName']?.toString() ??
        json['book']?.toString() ??
        (json['reference'] is Map
            ? json['reference']['book']?.toString()
            : null);

    return HadithModel(
      number: number,
      text: text,
      narrator: narrator,
      grade: grade,
      bookName: bookName,
    );
  }

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
