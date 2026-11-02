import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_service.dart';

/// ═══════════════════════════════════════════════════════════
/// 💎 خدمة الاستخدام — Premium لـ 3 ميزات فقط
///
/// ✅ مجاني دائماً: كل التطبيق (صلاة، أذكار، مصحف، مكتبة، بث...)
///
/// 💎 Premium (اشتراك):
///   1. المرشد الذكي     → 3 محاولات مجاناً يومياً
///   2. التصحيح الذكي   → محاولتان مجاناً يومياً
///   3. اقرأ معي         → محاولتان مجاناً يومياً
/// ═══════════════════════════════════════════════════════════
class UsageService {
  // ═══════════════════════════════════════════════════════════
  // 📊 حدود التجربة المجانية
  // ═══════════════════════════════════════════════════════════
  static const int freeChatsPerDay = 3;          // 🤖 3 أسئلة للمرشد
  static const int freeRecitationsPerDay = 2;    // 🎙️ محاولتان للتصحيح
  static const int freeReadWithMePerDay = 2;     // 📖 محاولتان لاقرأ معي

  // ═══════════════════════════════════════════════════════════
  // 💎 هل المستخدم Premium؟
  // ═══════════════════════════════════════════════════════════
  static Future<bool> isPremium() async {
    return PremiumService.isPremium;
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 المرشد الذكي — 3 مجاناً يومياً
  // ═══════════════════════════════════════════════════════════
  static Future<int> remainingChats() async {
    if (await isPremium()) return 999999;
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, 'chat');
    final used = prefs.getInt('chats_used_today') ?? 0;
    return (freeChatsPerDay - used).clamp(0, freeChatsPerDay);
  }

  static Future<bool> canChat() async {
    if (await isPremium()) return true;
    return (await remainingChats()) > 0;
  }

  static Future<void> incrementChat() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt('chats_used_today') ?? 0;
    await prefs.setInt('chats_used_today', used + 1);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎙️ تصحيح التلاوة — محاولتان مجاناً يومياً
  // ═══════════════════════════════════════════════════════════
  static Future<int> remainingRecitations() async {
    if (await isPremium()) return 999999;
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, 'recitation');
    final used = prefs.getInt('recitations_used_today') ?? 0;
    return (freeRecitationsPerDay - used).clamp(0, freeRecitationsPerDay);
  }

  static Future<bool> canRecite() async {
    if (await isPremium()) return true;
    return (await remainingRecitations()) > 0;
  }

  static Future<void> incrementRecitation() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt('recitations_used_today') ?? 0;
    await prefs.setInt('recitations_used_today', used + 1);
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 اقرأ معي — محاولتان مجاناً يومياً
  // ═══════════════════════════════════════════════════════════
  static Future<int> remainingReadWithMe() async {
    if (await isPremium()) return 999999;
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, 'read');
    final used = prefs.getInt('read_used_today') ?? 0;
    return (freeReadWithMePerDay - used).clamp(0, freeReadWithMePerDay);
  }

  static Future<bool> canReadWithMe() async {
    if (await isPremium()) return true;
    return (await remainingReadWithMe()) > 0;
  }

  static Future<void> incrementReadWithMe() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt('read_used_today') ?? 0;
    await prefs.setInt('read_used_today', used + 1);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 إعادة التصفير اليومية
  // ═══════════════════════════════════════════════════════════
  static Future<void> _resetIfNewDay(
      SharedPreferences prefs, String type) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('${type}_last_date');

    if (lastDate != today) {
      await prefs.setInt('${type}_used_today', 0);
      await prefs.setString('${type}_last_date', today);
      debugPrint('🔄 تم إعادة تصفير $type');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧪 تصفير كل العدادات (للمطور)
  // ═══════════════════════════════════════════════════════════
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chats_used_today');
    await prefs.remove('recitations_used_today');
    await prefs.remove('read_used_today');
    await prefs.remove('chat_last_date');
    await prefs.remove('recitation_last_date');
    await prefs.remove('read_last_date');
    debugPrint('🧪 تم تصفير كل العدادات');
  }
}
