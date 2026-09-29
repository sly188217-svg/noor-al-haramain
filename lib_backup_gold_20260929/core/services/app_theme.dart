import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// 🎨 نظام الثيمات - ورقي / ليلي / أطفال
/// ═══════════════════════════════════════════════════════════

class AppTheme {
  final String id;
  final String name;
  final String icon;
  final Color paperColor;
  final Color inkColor;
  final Color goldColor;
  final Color frameColor;
  final Color bgColor;

  const AppTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.paperColor,
    required this.inkColor,
    required this.goldColor,
    required this.frameColor,
    required this.bgColor,
  });

  static const List<AppTheme> all = [
    AppTheme(
      id: 'paper',
      name: 'ورقي',
      icon: '📜',
      paperColor: Color(0xFFFBF6E9),
      inkColor: Color(0xFF1A1A1A),
      goldColor: Color(0xFFB8860B),
      frameColor: Color(0xFF9C7A3C),
      bgColor: Color(0xFFF0E8D0),
    ),
    AppTheme(
      id: 'night',
      name: 'ليلي',
      icon: '🌙',
      paperColor: Color(0xFF1C2541),
      inkColor: Color(0xFFF5F5DC),
      goldColor: Color(0xFFD4AF37),
      frameColor: Color(0xFF8B7355),
      bgColor: Color(0xFF0B132B),
    ),
    AppTheme(
      id: 'kids',
      name: 'أطفال',
      icon: '🧸',
      paperColor: Color(0xFFFFF8E1),
      inkColor: Color(0xFF4A148C),
      goldColor: Color(0xFFE91E63),
      frameColor: Color(0xFF7B1FA2),
      bgColor: Color(0xFFFCE4EC),
    ),
    AppTheme(
      id: 'green',
      name: 'أخضر',
      icon: '🌿',
      paperColor: Color(0xFFF1F8E9),
      inkColor: Color(0xFF1B5E20),
      goldColor: Color(0xFF558B2F),
      frameColor: Color(0xFF33691E),
      bgColor: Color(0xFFDCEDC8),
    ),
    AppTheme(
      id: 'blue',
      name: 'أزرق',
      icon: '💙',
      paperColor: Color(0xFFE3F2FD),
      inkColor: Color(0xFF0D47A1),
      goldColor: Color(0xFF1976D2),
      frameColor: Color(0xFF1565C0),
      bgColor: Color(0xFFBBDEFB),
    ),
  ];

  static Future<AppTheme> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('app_theme') ?? 'paper';
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static Future<void> setCurrent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', id);
  }
}
