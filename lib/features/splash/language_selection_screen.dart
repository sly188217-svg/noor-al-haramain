import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/translation_service.dart';
import '../auth/auth_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _selectedLang;

  final Map<String, String> languages = {
    'ar': 'العربية (Arabic)',
    'en': 'English (الإنجليزية)',
    'es': 'Español (الإسبانية)',
    'fr': 'Français (الفرنسية)',
    'de': 'Deutsch (الألمانية)',
    'ru': 'Русский (الروسية)',
    'zh': '中文 (الصينية)',
  };

  @override
  void initState() {
    super.initState();
    _selectedLang = context.read<LanguageProvider>().currentLang;
  }

  Future<void> _saveAndContinue() async {
    await context.read<LanguageProvider>().setLanguage(_selectedLang);

    // ✅ نمرر selectedLang إلى AuthScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(selectedLang: _selectedLang),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: Text(
          TranslationService.getText(_selectedLang, 'select_language'),
          style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationService.getText(_selectedLang, 'select_language_desc'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: languages.keys.length,
                itemBuilder: (context, index) {
                  String key = languages.keys.elementAt(index);
                  String value = languages[key]!;
                  bool isSelected = (_selectedLang == key);

                  return ListTile(
                    tileColor: isSelected ? const Color(0xFF1C2541) : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Text(isSelected ? '✅' : '🔘', style: const TextStyle(fontSize: 22)),
                    title: Text(
                      value,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37)) : null,
                    onTap: () => setState(() => _selectedLang = key),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveAndContinue,
                child: Text(
                  TranslationService.getText(_selectedLang, 'confirm'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
