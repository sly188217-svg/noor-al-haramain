import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar_model.dart';

class AzkarService {
  static List<AzkarCategory> _categories = [];
  static List<LiveStream> _liveStreams = [];

  static Future<void> loadData() async {
    try {
      // تحميل البيانات من ملف JSON
      final String jsonString = await rootBundle.loadString('assets/data/azkar.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);

      _categories = (data['categories'] as List)
          .map((cat) => AzkarCategory.fromJson(cat))
          .toList();

      _liveStreams = (data['liveStreams'] as List)
          .map((stream) => LiveStream.fromJson(stream))
          .toList();

      // تخزين مؤقت في SharedPreferences للوصول السريع
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('azkar_cached', jsonString);
    } catch (e) {
      // في حال فشل التحميل، استخدم البيانات المخزنة مؤقتاً
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('azkar_cached');
      if (cached != null) {
        final Map<String, dynamic> data = jsonDecode(cached);
        _categories = (data['categories'] as List)
            .map((cat) => AzkarCategory.fromJson(cat))
            .toList();
        _liveStreams = (data['liveStreams'] as List)
            .map((stream) => LiveStream.fromJson(stream))
            .toList();
      }
    }
  }

  static List<AzkarCategory> getCategories() => _categories;
  static List<LiveStream> getLiveStreams() => _liveStreams;
}
