import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'services/api_service.dart';
import 'services/app_snack.dart';
import 'services/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final themeMode = switch (mode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          title: '数独 Sudoku',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF455A64),
            ),
            scaffoldBackgroundColor: lightAppColors.background,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightAppColors.primary,
                foregroundColor: lightAppColors.onPrimary,
              ),
            ),
            extensions: const [lightAppColors],
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF455A64),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: darkAppColors.background,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkAppColors.primary,
                foregroundColor: darkAppColors.onPrimary,
              ),
            ),
            extensions: const [darkAppColors],
          ),
          themeMode: themeMode,
          themeAnimationDuration: Duration.zero,
          themeAnimationCurve: Curves.easeInOut,
          home: const SplashScreen(),
          scaffoldMessengerKey: appMessengerKey,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final stopwatch = Stopwatch()..start();
    await ApiService.loadServerAddress();
    await loadThemeMode();
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('login_username');
    final phone = prefs.getString('login_phone');

    // 保证启动转圈至少可见约 800ms，避免一闪而过
    final remain = 800 - stopwatch.elapsedMilliseconds;
    if (remain > 0) {
      await Future.delayed(Duration(milliseconds: remain));
    }
    if (!mounted) {
      return;
    }
    if (username != null && phone != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(username: username, phone: phone),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      ),
    );
  }
}
