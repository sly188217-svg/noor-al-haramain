import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLang = 'ar';

  String get currentLang => _currentLang;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLang = prefs.getString('current_lang') ?? 'ar';
    notifyListeners();
  }

  Future<void> changeLanguage(String langCode) async {
    _currentLang = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_lang', langCode);
  }
}
