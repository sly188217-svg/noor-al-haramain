import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'core/providers/language_provider.dart';
import 'core/providers/theme_provider.dart'; // ✅
import 'core/services/notification_service.dart';
import 'core/services/periodic_azkar_service.dart';
import 'core/services/premium_service.dart';
import 'core/services/security_service.dart';
import 'features/adhan/adhan_screen.dart';
import 'features/security/security_block_screen.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await dotenv.load(fileName: 'assets/.env'); } catch (e) {}
  
  SecurityReport? securityReport;
  try { securityReport = await SecurityService.runFullCheck(); } catch (e) {}
  if (securityReport != null && !securityReport.isSafe && !kDebugMode) {
    runApp(SecurityBlockApp(issues: securityReport.issues));
    return;
  }
  
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) {}
  try {
    if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {}
  try {
    await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug, appleProvider: AppleProvider.debug);
  } catch (e) {}
  try { await PremiumService.initialize(); } catch (e) {}
  try {
    await NotificationService.initialize();
    await NotificationService.requestFullScreenIntentPermission();
  } catch (e) {}
  try { await PeriodicAzkarService.start(); } catch (e) {}

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
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text('حدث خطأ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(details.exceptionAsString(), style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'نور الحرمين',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            
            // ✅ الوضع الداكن (الأزرق الملكي)
            darkTheme: ThemeData(
              useMaterial3: false,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFF0B132B), // الأزرق الملكي الداكن
              fontFamily: 'Amiri',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1C2541),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            
            // ✅ الوضع المضيء (الأزرق الفاتح)
            theme: ThemeData(
              useMaterial3: false,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFFF5F7FA), // خلفية فاتحة مريحة
              fontFamily: 'Amiri',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF4A90E2), // أزرق ساطع
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
            locale: const Locale('ar', 'SA'),
            routes: {
              '/adhan': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                return AdhanScreen(
                  prayerName: args?['prayerName'] ?? 'الصلاة',
                  prayerTime: args?['prayerTime'] ?? '--:--',
                  cityName: args?['cityName'] ?? '',
                  muezzinName: args?['muezzinName'] ?? '',
                  isIqamaOnly: args?['isIqamaOnly'] == true,
                );
              },
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class SecurityBlockApp extends StatelessWidget {
  final List<String> issues;
  const SecurityBlockApp({super.key, required this.issues});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: SecurityBlockScreen(issues: issues));
  }
}
