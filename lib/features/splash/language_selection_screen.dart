import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/language_provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});
  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const Color _primary = Color(0xFF4A90E2);
  static const Color _bg = Color(0xFF0B132B);

  final Map<String, String> _languages = {
    'ar': 'العربية', 'en': 'English', 'fr': 'Français', 'es': 'Español',
    'tr': 'Türkçe', 'ur': 'اردو', 'id': 'Bahasa Indonesia', 'bn': 'বাংলা',
    'fa': 'فارسی', 'de': 'Deutsch', 'ru': 'Русский', 'zh': '中文',
    'hi': 'हिन्दी', 'sw': 'Kiswahili',
  };

  Future<void> _selectLanguage(String code) async {
    final langProvider = context.read<LanguageProvider>();
    await langProvider.changeLanguage(code);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.watch<LanguageProvider>().currentLang;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.mosque, color: _primary, size: 70),
              const SizedBox(height: 12),
              const Text('نور الحرمين', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
              const SizedBox(height: 8),
              const Text('اختر لغتك المفضلة', style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final code = _languages.keys.elementAt(index);
                    final name = _languages.values.elementAt(index);
                    final isSelected = currentLang == code;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? _primary : Colors.white24, width: isSelected ? 2 : 1),
                      ),
                      child: ListTile(
                        leading: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? _primary : Colors.white54),
                        title: Text(name, style: TextStyle(color: isSelected ? _primary : Colors.white, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        onTap: () => _selectLanguage(code),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
