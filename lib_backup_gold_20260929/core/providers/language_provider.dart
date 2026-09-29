import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLang = 'ar';

  String get currentLang => _currentLang;

  void setLanguage(String lang) {
    if (lang != 'ar') return;
    if (_currentLang != lang) {
      _currentLang = lang;
      notifyListeners();
    }
  }
}
