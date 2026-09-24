import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/providers/language_provider.dart';
import 'core/services/notification_service.dart';
import 'features/adhan/adhan_screen.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تحميل ملف .env
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ تم تحميل ملف .env');
  } catch (e) {
    debugPrint('⚠️ تعذر تحميل .env: $e');
  }

  // 2. تهيئة Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ تم تهيئة Firebase');
  } catch (e) {
    debugPrint('❌ فشل تهيئة Firebase: $e');
  }

  // 3. تسجيل دخول مجهول
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('✅ تسجيل دخول مجهول ناجح');
    } else {
      debugPrint(
          '✅ المستخدم مسجّل: ${FirebaseAuth.instance.currentUser?.uid}');
    }
  } catch (e) {
    debugPrint('❌ فشل تسجيل الدخول المجهول: $e');
  }

  // 4. تفعيل Firebase App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    debugPrint('✅ تم تفعيل App Check (Debug Mode)');
    debugPrint('🔑 Debug Token: A0CD6B2F-9F70-4037-B04C-7C1D58CE299D');
  } catch (e) {
    debugPrint('⚠️ فشل تفعيل App Check: $e');
  }

  // 5. تهيئة الإشعارات + طلب صلاحية ملء الشاشة
  try {
    await NotificationService.initialize();
    // ✅ طلب صلاحية ملء الشاشة (مطلوب لأندرويد 14+)
    await NotificationService.requestFullScreenIntentPermission();
    debugPrint('✅ تم تهيئة الإشعارات + طلب صلاحية ملء الشاشة');
  } catch (e) {
    debugPrint('⚠️ فشل تهيئة الإشعارات: $e');
  }

  // 6. ErrorWidget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: const Color(0xFF0B132B),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  details.exceptionAsString(),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        title: 'نور الحرمين',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFF0B132B),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ar', 'SA'),
        routes: {
          '/adhan': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>?;
            return AdhanScreen(
              prayerName: args?['prayerName'] ?? 'الصلاة',
              prayerTime: args?['prayerTime'] ?? '--:--',
              cityName: args?['cityName'] ?? '',
              muezzinName: args?['muezzinName'] ?? '',
            );
          },
        },
        home: const SplashScreen(),
      ),
    );
  }
}
