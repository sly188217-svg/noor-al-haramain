import 'package:hijri_date/hijri.dart';

class HijriService {
  static const List<String> _monthNames = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];

  static String getHijriDate(DateTime date) {
    try {
      final hijri = HijriDate.fromDate(date);
      final monthName = _monthNames[hijri.hMonth - 1];
      final day = hijri.hDay;
      final year = hijri.hYear;
      return '$day $monthName $year هـ';
    } catch (e) {
      return _getFallbackHijri(date);
    }
  }

  static String getShortHijri(DateTime date) {
    try {
      final hijri = HijriDate.fromDate(date);
      return '${hijri.hDay}/${hijri.hMonth}/${hijri.hYear} هـ';
    } catch (e) {
      return '--/--/---- هـ';
    }
  }

  static String _getFallbackHijri(DateTime date) {
    final year = 1445 + (date.year - 2024);
    final day = (date.difference(DateTime(date.year, 1, 1)).inDays % 354) + 1;
    final month = ((date.difference(DateTime(date.year, 1, 1)).inDays % 354) / 30).floor() + 1;
    return '$day/$month/$year هـ (تقريباً)';
  }
}
