import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// خدمة تتبع الاستخدام — محلية بالكامل (بدون Firebase)
/// ═══════════════════════════════════════════════════════════
class UsageService {
  static const int freeRecitationLimit = 3;
  static const int freeChatLimit = 5;

  static String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// قراءة بيانات المستخدم (محلي)
  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('usage_last_reset') ?? _today;

    if (lastReset != _today) {
      await prefs.setInt('usage_daily_recitations', 0);
      await prefs.setInt('usage_daily_chats', 0);
      await prefs.setString('usage_last_reset', _today);
    }

    return {
      'subscription': prefs.getString('subscription') ?? 'free',
      'dailyRecitations': prefs.getInt('usage_daily_recitations') ?? 0,
      'dailyChats': prefs.getInt('usage_daily_chats') ?? 0,
      'totalRecitations': prefs.getInt('usage_total_recitations') ?? 0,
      'totalChats': prefs.getInt('usage_total_chats') ?? 0,
    };
  }

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('subscription') == 'premium';
  }

  static Future<bool> canRecite() async {
    if (await isPremium()) return true;
    final data = await getUserData();
    final count = data['dailyRecitations'] as int? ?? 0;
    return count < freeRecitationLimit;
  }

  static Future<bool> canChat() async {
    if (await isPremium()) return true;
    final data = await getUserData();
    final count = data['dailyChats'] as int? ?? 0;
    return count < freeChatLimit;
  }

  static Future<void> incrementRecitation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usage_daily_recitations',
        (prefs.getInt('usage_daily_recitations') ?? 0) + 1);
    await prefs.setInt('usage_total_recitations',
        (prefs.getInt('usage_total_recitations') ?? 0) + 1);
    await prefs.setString('usage_last_reset', _today);
  }

  static Future<void> incrementChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usage_daily_chats',
        (prefs.getInt('usage_daily_chats') ?? 0) + 1);
    await prefs.setInt('usage_total_chats',
        (prefs.getInt('usage_total_chats') ?? 0) + 1);
    await prefs.setString('usage_last_reset', _today);
  }

  static Future<int> remainingRecitations() async {
    if (await isPremium()) return -1;
    final data = await getUserData();
    final count = data['dailyRecitations'] as int? ?? 0;
    final remaining = freeRecitationLimit - count;
    return remaining < 0 ? 0 : remaining;
  }

  static Future<int> remainingChats() async {
    if (await isPremium()) return -1;
    final data = await getUserData();
    final count = data['dailyChats'] as int? ?? 0;
    final remaining = freeChatLimit - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// ترقية لـ Premium (محلي)
  static Future<void> upgradeToPremium({
    required String productId,
    required DateTime expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription', 'premium');
  }

  static Future<void> cancelPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription', 'free');
  }

  /// للتطوير — إعادة تعيين
  static Future<void> resetDailyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usage_daily_recitations', 0);
    await prefs.setInt('usage_daily_chats', 0);
  }
}
